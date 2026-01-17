# Deploy a Free n8n Instance on Google Cloud

This project provides a one-shot installer to deploy n8n — a powerful open-source workflow automation tool — on a free-tier Google Cloud VM with HTTPS support via Let's Encrypt. It's ideal for individuals or small teams looking to self-host n8n at zero cost using Google Cloud’s generous free compute offering. The setup script installs Docker, Nginx, Certbot, and n8n (with optional sqlite-default, and powerful postgraes), configures reverse proxying, and automatically provisions SSL certificates.

**⚠️Note:** It is not production-ready and is recommended only for small, personal workflows.

---

## 1. Create a Free Tier VM

> **Note:** Google Cloud Free Tier VM types, quotas, and features might change in the future. Always follow the latest official guidelines here:  
> [Google Cloud Free Tier Features](https://cloud.google.com/free/docs/free-cloud-features)


- Go to the [Google Cloud Console](https://console.cloud.google.com/).
- Navigate to **Compute Engine → VM Instances → Create Instance**.
- Select the **"E2-micro"** machine type (this is included in the Google Cloud Free Tier).
- Choose **Ubuntu (stable version)** as the OS.
- **Before creating the VM, enable these firewall options:**
  - **HTTP traffic:** Allows web traffic to your server (port 80).
  - **HTTPS traffic:** Allows secure web traffic (port 443).
  - **Allow Load Balancer Health checks:** Needed for Google Cloud's load balancer and uptime checks.
- **Why?** These firewall rules ensure your server is accessible for web and secure traffic, and can be monitored for uptime.

---

## 2. Reserve a Static External IP (optional)

- After your VM is ready, go to **VPC Network → External IP addresses**.
- Click "Reserve" next to your VM to assign a static IP.
- **Why?** This ensures your server's IP doesn't change, so your DNS always points to the right place.

---

## 3. Update Your DNS

- Go to your domain provider's dashboard.
- Add an **A record** pointing your subdomain (e.g., `n8n.yourdomain.com`) to your VM's external IP.

---

## 4. Open Firewall Ports for n8n

- In Google Cloud Console, go to **VPC Network → Firewall**.
- Add a rule to allow **TCP connections from 0.0.0.0/0** (all IPs) for ports **5678** (n8n default), and **5687, 5689** if needed.
- **Why?** This allows external access to your n8n instance on those ports.

---

## 5. Deploy n8n

Open SSH from GCP "Compute Engine" instance, and follw the steps:

1. **Install Git (if not already installed):**
   ```bash
   sudo apt update && sudo apt install git -y
   sudo apt-get update && sudo apt-get install -y nano

   ```

2. **Clone this repo and enter the directory:**
   ```bash
   if [ ! -d "n8n-docker-deploy-on-vm" ]; then
   git clone https://github.com/smrutijz/n8n-docker-deploy-on-vm.git
   fi

   cd n8n-docker-deploy-on-vm
   git pull
   ```

3. **Run the setup script:**

   *Option 1 (with default SQLite)*
- First arg should be your domain-name (FQDN)
- Second arg should be your email-id
   ```bash
   chmod +x ./setup-n8n-w-sqlite.sh
   sudo ./setup-n8n-w-sqlite.sh '<your-domain-name>' '<your-email-id>'
   ```
   *Option 2 (with PostGreSQL)*
- First arg should be your domain-name (FQDN)
- Second arg should be your email-id
- Third arg PostgreSQL host name
- Forth arg PostgreSQL port number (usually 5432)
- Fifth PostgreSQL database name (usually postgres)
- Sixth PostgreSQL user name
- Sevent PostgreSQL user password
   ```bash
   chmod +x ./setup-n8n-w-postgresql.sh
   sudo bash setup-n8n-w-postgresql.sh \
  '<your-domain-name>' \
  '<your-email-id>' \
  '<your-postgres-host-name>' \
  '<your-postgres-port>' \
  '<your-postgres-db-name>' \
  '<your-postgres-username>' \
  '<your-postgres-password>'
   ```


---

## 6. Update or Re-deploy n8n (Docker)

To update your n8n Docker container or clean up old images:

1. **Pull the latest n8n image:**
   ```bash
   sudo docker pull n8nio/n8n:latest
   sudo docker images
   sudo docker ps -a
   ```

2. **Stop and remove the existing container:**
   ```bash
   sudo docker stop <CONTAINER_ID>
   sudo docker rm <CONTAINER_ID>
   ```

3. **Run the updated container (PostgreSQL, and SQLite example):**
If you want to run the n8n Docker container manually (without the setup script), use one of the following commands:

**For SQLite (default, recommended for simple setups):**
```bash
sudo docker run -d \
  --name n8n --restart unless-stopped \
  -p 5678:5678 \
  -v /var/n8n:/home/node/.n8n \
  -e N8N_HOST=<DOMAIN> \
  -e WEBHOOK_URL="https://<DOMAIN>/" \
  -e WEBHOOK_TUNNEL_URL="https://<DOMAIN>/" \
  n8nio/n8n:latest
```

**For PostgreSQL (advanced, for production or team use):**
```bash
sudo docker run -d \
  --name n8n --restart unless-stopped \
  -p 5678:5678 \
  -v /var/n8n:/home/node/.n8n \
  -e N8N_HOST=<DOMAIN> \
  -e WEBHOOK_URL="https://<DOMAIN>/" \
  -e WEBHOOK_TUNNEL_URL="https://<DOMAIN>/" \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=<DB_HOST> \
  -e DB_POSTGRESDB_PORT=<DB_PORT> \
  -e DB_POSTGRESDB_DATABASE=<DB_DATABASE> \
  -e DB_POSTGRESDB_USER=<DB_USER> \
  -e DB_POSTGRESDB_PASSWORD=<DB_PASS> \
  -e DB_POSTGRESDB_SSLMODE=require \
  -e DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false \
  n8nio/n8n:latest
```

Replace placeholders (e.g., `<DOMAIN>`, `<DB_HOST>`, etc.) with your actual values.

4. **Clean up unused containers and images:**
   ```bash
   sudo docker ps -a
   sudo docker images
   sudo docker rmi <UNUSED-IMAGE-ID>
   ```

Replace placeholders (e.g., `<CONTAINER_ID>`, `<UNUSED-CONTAINER-ID>`) with your actual values.

---


## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

For any questions or support, please contact **Smruti** at [smrutijz@hotmail.com](mailto:smrutijz@hotmail.com).

Connect with me on [LinkedIn](https://www.linkedin.com/in/smrutijz/).

You can also chat with my AI bot, **SmrutiRBot**, on Telegram! Simply scan the QR code below to get started:

[![SmrutiRBot](img/smruti-r-bot-telegram-qr-code.png)](https://t.me/SmrutiRBot)
