#!/bin/bash
set -e

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Install Nginx
sudo apt install -y nginx

# Install Certbot for SSL
sudo apt install -y certbot python3-certbot-nginx

# Check if .env exists
if [ ! -f .env ]; then
  cp .env.example .env
  echo ".env file created. Please edit it with your credentials before running this script again."
  exit 0
fi

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

# Substitute NGINX domain variable and deploy config
export $(grep -E 'N8N_HOST' .env | xargs)
envsubst < ./nginx/n8n.conf > /tmp/n8n.conf
sudo cp /tmp/n8n.conf /etc/nginx/sites-available/n8n.conf
sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Start n8n
sudo docker-compose up -d
# ...existing code...