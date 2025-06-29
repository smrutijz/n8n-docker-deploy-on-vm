#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${1:? "n8n FQDN (e.g., n8n.example.com)"}
EMAIL=${2:? "Email for Let's Encrypt"}
DB_HOST=${3:-""}      # e.g., pgsql.example.com
DB_PORT=${4:-"5432"}
DB_DATABASE=${5:-"postgres"}
DB_USER=${6:-""}
DB_PASS=${7:-""}

# 1️⃣ Install base packages
echo "📦 Installing Docker, Nginx & Certbot..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io nginx certbot python3-certbot-nginx

echo "🚀 Enabling Docker..."
systemctl enable --now docker

# 2️⃣ Obtain SSL for n8n
echo "🔒 Getting TLS cert for $DOMAIN"
cat >/tmp/n8n-temp.conf <<EOF
server { listen 80; server_name $DOMAIN; return 301 https://\$host\$request_uri; }
EOF
mv /tmp/n8n-temp.conf /etc/nginx/sites-available/n8n_temp
ln -sf /etc/nginx/sites-available/n8n_temp /etc/nginx/sites-enabled/n8n_temp
nginx -t && systemctl reload nginx

certbot --non-interactive --agree-tos --nginx --redirect -m "$EMAIL" -d "$DOMAIN"

rm /etc/nginx/sites-enabled/n8n_temp
nginx -t && systemctl reload nginx

# 3️⃣ Prepare n8n directories and CA (for DB)
mkdir -p /var/n8n && chown 1000:1000 /var/n8n

if [[ -n "$DB_HOST" ]]; then
  LIVE_DIR="/etc/letsencrypt/live/$DB_HOST"
  if [[ -f "$LIVE_DIR/chain.pem" ]]; then
    mkdir -p pki
    cp "$LIVE_DIR/chain.pem" pki/lets-root-chain.pem
    echo "✅ Found and copied chain.pem for $DB_HOST"
  else
    echo "⚠️ No chain.pem for $DB_HOST yet; DB SSL validation will use insecure mode."
  fi
fi

# 4️⃣ Launch n8n container
echo "🐳 Deploying n8n container..."
docker run -d --restart unless-stopped --name n8n -p 5678:5678 \
  -v /var/n8n:/home/node/.n8n \
  $( [[ -d "pki" ]] && echo "-v $(pwd)/pki:/opt/custom-certificates" ) \
  -e N8N_HOST="$DOMAIN" \
  -e WEBHOOK_URL="https://$DOMAIN/" \
  -e WEBHOOK_TUNNEL_URL="https://$DOMAIN/" \
  $( [[ -n "$DB_HOST" ]] && \
     echo "-e DB_TYPE=postgresdb \
     -e DB_POSTGRESDB_HOST=$DB_HOST \
     -e DB_POSTGRESDB_PORT=$DB_PORT \
     -e DB_POSTGRESDB_DATABASE=$DB_DATABASE \
     -e DB_POSTGRESDB_USER=$DB_USER \
     -e DB_POSTGRESDB_PASSWORD=$DB_PASS \
     -e DB_POSTGRESDB_SSLMODE=require \
     -e DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=$( [[ -f "pki/lets-root-chain.pem" ]] && echo true || echo false )" ) \
  n8nio/n8n:latest

# 5️⃣ Adjust permissions for mounted CA
if [[ -d "pki" ]]; then
  docker exec --user 0 n8n chown -R 1000:1000 /opt/custom-certificates
fi

# 6️⃣ Configure Nginx proxy
echo "🌐 Configuring Nginx for n8n..."
cat >/etc/nginx/sites-available/n8n <<EOF
server {
  listen 80;
  server_name $DOMAIN;

  location / {
    proxy_pass http://127.0.0.1:5678;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
    proxy_set_header Expect "";
  }
}
EOF
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# 7️⃣ Wait for n8n to start
echo -n "⏳ Waiting for n8n to be ready..."
until curl -fs http://127.0.0.1:5678 >/dev/null; do
  printf "."
  sleep 2
done
echo " ✅"

echo "🎉 Setup complete!"
echo "🔗 n8n → https://$DOMAIN"
if [[ -n "$DB_HOST" ]]; then
  echo "🔐 PostgreSQL will be connected at $DB_HOST"
  echo "   SSL validation = $( [[ -f "pki/lets-root-chain.pem" ]] && echo enabled || echo insecure )"
fi
