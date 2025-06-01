#!/bin/bash
set -e

PROJECT_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
cd "$PROJECT_ROOT"

# Update system packages
echo "🔄 Updating system..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "🔧 Installing base packages..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg

# Install NGINX
echo "🌐 Installing NGINX..."
sudo apt install -y nginx

# Install Certbot
echo "🔐 Installing Certbot for SSL..."
sudo apt install -y certbot python3-certbot-nginx

# Ensure .env exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
  echo "⚠️ .env file not found. Creating from template..."
  cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
  echo "Please update .env before running this script again."
  exit 1
fi

# Install Docker
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install -y docker-ce
else
  echo "✅ Docker is already installed."
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
  echo "🔧 Installing Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
else
  echo "✅ Docker Compose is already installed."
fi

# Setup NGINX reverse proxy
echo "🧩 Setting up NGINX config..."
export http_upgrade="\$http_upgrade"
export host="\$host"
export remote_addr="\$remote_addr"
export proxy_add_x_forwarded_for="\$proxy_add_x_forwarded_for"
export scheme="\$scheme"

envsubst < "$PROJECT_ROOT/nginx/n8n.conf" > /tmp/n8n.conf
sudo cp /tmp/n8n.conf /etc/nginx/sites-available/n8n.conf
sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n
sudo rm -f /etc/nginx/sites-enabled/default

# Reload NGINX
echo "♻️ Reloading NGINX..."
sudo nginx -t && sudo systemctl reload nginx

# Start containers
echo "🚀 Starting n8n with Docker Compose..."
sudo docker-compose -f "$PROJECT_ROOT/docker-compose.yml" up -d

# Optional SSL reminder
N8N_HOST=$(grep N8N_HOST "$PROJECT_ROOT/.env" | cut -d '=' -f2)
echo "🔐 You can now run SSL setup:"
echo "    sudo certbot --nginx -d $N8N_HOST"

echo "✅ Setup complete! Visit: https://$N8N_HOST"
