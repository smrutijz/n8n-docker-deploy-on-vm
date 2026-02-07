#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# n8n “One-Shot” Installer for Google Cloud free-tier VMs
# v2.2.1 – 2025-06-21 (SSE/WebSocket keep-alive + wait-until-ready)
#
# Usage (inside the VM)
#   curl -SSL <RAW_URL_OF_THIS_FILE> | sudo bash -s "your-domain.com" "admin@domain.com"
# ─────────────────────────────────────────────────────────────

set -euo pipefail

DOMAIN=${1:? "First arg must be the domain (FQDN)"}
EMAIL=${2:? "Second arg must be a valid email address"}

echo -e "\n📦  Installing Docker, Nginx & Certbot …"
apt-get update -y
DEBIAN_FRONTEND=noninteractive \
apt-get install -y docker.io nginx certbot python3-certbot-nginx

echo -e "\n🚀  Enabling Docker service …"
systemctl enable --now docker

echo -e "\n🗄️  Preparing persistent volume …"
mkdir -p /var/n8n
chown 1000:1000 /var/n8n        # UID 1000 = node user in the image

echo -e "\n🐳  Launching n8n container …"
docker run -d --restart unless-stopped --name n8n -p 5678:5678 \
  -e N8N_HOST="$DOMAIN" \
  -e WEBHOOK_URL="https://$DOMAIN/" \
  -e WEBHOOK_TUNNEL_URL="https://$DOMAIN/" \
  -e N8N_BLOCK_JS_CODE_SANDBOX=true \
  -e N8N_RUNNERS_ENABLED=false \
  -e N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true \
  -v /var/n8n:/home/node/.n8n \
  n8nio/n8n:latest

echo -e "\n🌐  Writing Nginx site …"
cat >/etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # keep browser ↔ nginx socket alive > Chrome’s 60 s default
    keepalive_timeout 70s;

    location / {
        proxy_pass http://127.0.0.1:5678;

        # WebSocket / SSE essentials
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;

        # instant flush, no buffering
        proxy_buffering off;
        proxy_cache     off;

        # accept very long-running streams (24 h)
        proxy_read_timeout  86400s;
        proxy_send_timeout 86400s;

        # avoid 100-continue glass wall
        proxy_set_header Expect "";
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# 🔥 remove the distro’s default site to avoid 502 clashes
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

nginx -t && systemctl reload nginx

echo -e "\n🔒  Obtaining Let’s Encrypt certificate …"
certbot --non-interactive --agree-tos --nginx --redirect \
        -m "$EMAIL" -d "$DOMAIN"

# Make sure any rewritten proxy_pass keeps the correct port
sed -i 's|proxy_pass http://localhost/|proxy_pass http://127.0.0.1:5678/|g' \
      /etc/nginx/sites-available/n8n

# Keep ONLY our v-host enabled
for f in /etc/nginx/sites-enabled/*; do
  [ "\$(basename "\$f")" = "n8n" ] || rm -f "\$f"
done

nginx -t && systemctl reload nginx

echo -n "⏳  Waiting for n8n to finish first-run migrations"
until curl -fs http://127.0.0.1:5678 >/dev/null 2>&1; do
  echo -n "."
  sleep 3
done
echo -e " done!\n"

echo -e "✅  All set!  Open →  https://$DOMAIN   (first load ≈ 60 s)\n"