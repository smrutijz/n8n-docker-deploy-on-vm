# Deploy a Free n8n Instance on Google Cloud & Supabase

---

## Get Your Free Supabase Instance (for postgresql)

- Sign up for a free Supabase account and create a new project: [Supabase Free Tier Pricing](https://supabase.com/pricing)
- Use the database credentials from your Supabase project in your `.env` file.

---

## 1. Create a Free Tier VM

> **Note:** Google Cloud Free Tier VM types, quotas, and features might change in the future. Always follow the latest official guidelines here:  
> [Google Cloud Free Tier Features](https://cloud.google.com/free/docs/free-cloud-features)


- Go to the [Google Cloud Console](https://console.cloud.google.com/).
- Navigate to **Compute Engine → VM Instances → Create Instance**.
- Select the **"E2-micro"** machine type (this is included in the Google Cloud Free Tier).
- Choose **Ubuntu 20.04 LTS** as the OS.
- **Before creating the VM, enable these firewall options:**
  - **HTTP traffic:** Allows web traffic to your server (port 80).
  - **HTTPS traffic:** Allows secure web traffic (port 443).
  - **Allow Load Balancer Health checks:** Needed for Google Cloud's load balancer and uptime checks.
- **Why?** These firewall rules ensure your server is accessible for web and secure traffic, and can be monitored for uptime.

---

## 2. Reserve a Static External IP

- After your VM is ready, go to **VPC Network → External IP addresses**.
- Click "Reserve" next to your VM to assign a static IP.
- **Why?** This ensures your server's IP doesn't change, so your DNS always points to the right place.

---

## 3. Update Your DNS

- Go to your domain provider's dashboard.
- Add an **A record** pointing your subdomain (e.g., `n8n.yourdomain.com`) to your VM's external static IP.

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
   sudo apt update
   sudo apt install git -y
   sudo apt install nano -y
   ```

2. **Clone this repo and enter the directory:**
   ```bash
   rm -rf n8n-docker-deploy-on-vm

   if [ ! -d "n8n-docker-deploy-on-vm" ]; then
   git clone <your-repo-url> n8n-docker-deploy-on-vm
   # git clone https://github.com/smrutijz/n8n-docker-deploy-on-vm.git > n8n-docker-deploy-on-vm
   fi

   cd n8n-docker-deploy-on-vm
   ```

3. **How to Edit `.env` in Your VM**
  
   The setup script will automatically create a `.env` file from `.env.example` if it does not exist.

   Edit the `.env` or ``.env.example`` file with your credentials:

   ```bash
   nano .env.example
   ```

4. **Run the setup script:**
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```

5. **Obtain SSL certificate:**
   ```bash
   sudo certbot --nginx -d <your-domain>
   # sudo certbot --nginx -d n8n.smrutiaisolution.fun
   ```

6. **Access n8n at:** [https://<your-domain>](https://<your-domain>)


## Notes

- Change all passwords and secrets before deploying to production.
- For troubleshooting, check Docker and Nginx logs.