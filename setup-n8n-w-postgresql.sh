#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${1:? "n8n FQDN (e.g., n8n.example.com)"}
EMAIL=${2:? "Email for Let's Encrypt"}
DB_HOST=${3:-"postgres host"}
DB_PORT=${4:-"postgres db name - 5432 usually"}
DB_DATABASE=${5:-"postgres db name - postgres usually"}
DB_USER=${6:-"postgres user"}
DB_PASS=${7:-"postgres password"}

echo "📦 Installing Docker, Nginx & Certbot..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io nginx certbot python3-certbot-nginx

echo "🚀 Enabling Docker..."
systemctl enable --now docker

echo "🌐 Initial nginx config to allow Certbot..."
mkdir -p /etc/nginx/sites-available
cat <<EOF >/etc/nginx/sites-available/${DOMAIN}.init
server {
  listen 80;
  server_name ${DOMAIN};
  location / { return 200 'OK'; add_header Content-Type text/plain; }
}
EOF

ln -sf /etc/nginx/sites-available/${DOMAIN}.init /etc/nginx/sites-enabled/${DOMAIN}.init
systemctl reload nginx

echo "🔐 Obtaining TLS certificate using Certbot..."
certbot --non-interactive --agree-tos --nginx --redirect -m "${EMAIL}" -d "${DOMAIN}"

echo "🛠️ Writing final nginx configuration (HTTP→HTTPS + proxy)..."
cat <<EOF >/etc/nginx/sites-available/n8n
server {
  listen 80;
  server_name ${DOMAIN};
  return 301 https://\$host\$request_uri;
}
server {
  listen 443 ssl http2;
  server_name ${DOMAIN};

  ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
  include             /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

  location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
    proxy_buffering off;
    proxy_cache off;
  }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
rm -f /etc/nginx/sites-enabled/${DOMAIN}.init
systemctl reload nginx

echo "🗄️ Creating n8n data directory..."
mkdir -p /var/n8n
chown 1000:1000 /var/n8n

echo "🐳 Starting n8n Docker container..."

# Build docker run command progressively
DOCKER_CMD=(docker run -d \
  --name n8n --restart unless-stopped \
  -p 5678:5678 \
  -v /var/n8n:/home/node/.n8n \
  -e N8N_HOST="${DOMAIN}" \
  -e WEBHOOK_URL="https://${DOMAIN}/" \
  -e WEBHOOK_TUNNEL_URL="https://${DOMAIN}/"\
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_RUNNERS_MODE=internal \
  -e N8N_RUNNERS_TASK_REQUEST_TIMEOUT=120 \
  -e N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true)

# Add PostgreSQL env if DB_HOST is provided
if [ -n "${DB_HOST}" ]; then
  DOCKER_CMD+=(
    -e DB_TYPE=postgresdb
    -e DB_POSTGRESDB_HOST="${DB_HOST}"
    -e DB_POSTGRESDB_PORT="${DB_PORT}"
    -e DB_POSTGRESDB_DATABASE="${DB_DATABASE}"
    -e DB_POSTGRESDB_USER="${DB_USER}"
    -e DB_POSTGRESDB_PASSWORD="${DB_PASS}"
    -e DB_POSTGRESDB_SSLMODE=require
    -e DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
  )
fi

DOCKER_CMD+=(n8nio/n8n:latest)

# Run the built command
"${DOCKER_CMD[@]}"

echo -n "⏳ Waiting for n8n to start..."
until curl -fs http://127.0.0.1:5678 >/dev/null; do
  printf "."
  sleep 2
done
echo " ✅ n8n is ready!"

echo "🎉 Setup complete — access your instance at: https://${DOMAIN}"
