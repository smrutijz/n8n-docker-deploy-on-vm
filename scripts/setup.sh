#!/bin/bash

set -e

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Install Nginx
sudo apt install -y nginx

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Certbot for SSL
sudo apt install -y certbot python3-certbot-nginx

# Substitute NGINX domain variable and deploy config
export $(grep N8N_HOST_DOMAIN .env | xargs)
envsubst < ./nginx/n8n.conf > /tmp/n8n.conf
sudo cp /tmp/n8n.conf /etc/nginx/sites-available/n8n
sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Start n8n
sudo docker-compose up -d

echo ""
echo "n8n and Nginx are running."
echo "Now obtain your SSL certificate by running:"
echo "  sudo certbot --nginx -d $N8N_HOST_DOMAIN"
echo ""
echo "After SSL, access your instance at: https://$N8N_HOST_DOMAIN"