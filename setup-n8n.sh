#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${1:? "FQDN for n8n required (e.g., n8n.smrutiaisolution.fun)"}
EMAIL=${2:? "Email for Let's Encrypt required"}

DB_HOST=${3:-""}      # e.g., pgsql.smrutiaisolution.fun
DB_PORT=${4:-"5432"}
DB_DATABASE=${5:-"postgres"}
DB_USER=${6:-""}
DB_PASS=${7:-""}

# Install base dependencies
echo "📦 Installing Docker, Nginx & Certbot..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io nginx certbot python3-certbot-nginx

echo "🚀 Enabling Docker service..."
systemctl enable --now docker

# Obtain SSL for n8n
echo "🔒 Obtaining SSL for $DOMAIN"
cat >/tmp/nginx-n8n.conf <<EOF
server {
  listen 80;
  server_name $DOMAIN;
  return 301 https://\$host\$request_uri;
}
EOF
mv /tmp/nginx-n8n.conf /etc/nginx/sites-available/n8n_temp
ln -sf /etc/nginx/sites-available/n8n_temp /etc/nginx/sites-enabled/n8n_temp
nginx -t && systemctl reload nginx

certbot --non-interactive --agree-tos --nginx --redirect -m "$EMAIL" -d "$DOMAIN"

rm /etc/nginx/sites-enabled/n8n_temp
nginx -t && systemctl reload nginx

# Prepare volume and ensure permissions
mkdir -p /var/n8n
chown 1000:1000 /var/n8n

# Prepare CA certs if PostgreSQL used
if [[ -n "$DB_HOST" ]]; then
  mkdir -p pki
  cp /etc/letsencrypt/live/$DB_HOST/chain.pem pki/lets-root-chain.pem
fi

# Launch n8n container
echo "🐳 Launching n8n container..."
docker run -d \
  --restart unless-stopped \
  --name n8n \
  -p 5678:5678 \
  -v /var/n8n:/home/node/.n8n \
  $( [[ -n "$DB_HOST" ]] && echo "-v $(pwd)/pki:/opt/custom-certificates" ) \
  -e N8N_HOST="$DOMAIN" \
  -e WEBHOOK_URL="https://$DOMAIN/" \
  -e WEBHOOK_TUNNEL_URL="https://$DOMAIN/" \
  $( [[ -n "$DB_HOST" ]] && cat <<EOD
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=$DB_HOST \
  -e DB_POSTGRESDB_PORT=$DB_PORT \
  -e DB_POSTGRESDB_DATABASE=$DB_DATABASE \
  -e DB_POSTGRESDB_USER=$DB_USER \
  -e DB_POSTGRESDB_PASSWORD=$DB_PASS \
  -e DB_POSTGRESDB_SSLMODE=require \
  -e DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true
EOD
  ) \
  n8nio/n8n:latest

# Ensure CA permissions for DB SSL
if [[ -n "$DB_HOST" ]]; then
  docker exec --user 0 n8n chown -R 1000:1000 /opt/custom-certificates
fi

# Configure Nginx proxy
echo "🌐 Configuring Nginx proxy..."
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

# Wait until n8n fully starts
echo -n "⏳ Waiting for n8n to start..."
until curl -fs http://127.0.0.1:5678 >/dev/null; do
  echo -n "."
  sleep 2
done
echo " done!"

echo "✅ n8n is now available at https://$DOMAIN"
if [[ -n "$DB_HOST" ]]; then
  echo "✅ Connected to PostgreSQL at $DB_HOST using SSL!"
fi
