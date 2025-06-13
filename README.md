# 🚀 Self-Host n8n with Docker Compose + Traefik

This project provides a **plug-and-play script** to self-host [n8n](https://n8n.io) — the powerful workflow automation tool — on **any Linux cloud VM**, with full HTTPS support and no usage limits. Whether you’re using AWS, DigitalOcean, Google Cloud, or Oracle Cloud, this setup gives you complete control, privacy, and flexibility.

---

## 📦 What's Included

- One-click shell script (`install_n8n.sh`)
- Docker Compose setup for n8n + Traefik reverse proxy
- Free SSL certificates via Let's Encrypt
- Persistent storage for workflows and files
- Support for custom domain (e.g., `n8n.yourdomain.com`)
- Access to paid n8n features via Fair Code license

---

## 🖥 Requirements

Before running the script, ensure you have:

- A cloud VM with **Ubuntu 22.04 LTS** or compatible
- Root or `sudo` access to the VM
- A registered **domain or subdomain**
- DNS **A record** pointing to your VM's **public IP**
- Ports **80** and **443** open in the firewall/security group

---

## 🚀 Quick Start Guide

### 1. SSH into Your VM

Use your cloud provider’s console or terminal:

```bash
ssh your-user@your-vm-ip

### 2. Download the Script
curl -O https://raw.githubusercontent.com/yourusername/your-repo/main/install_n8n.sh
chmod +x install_n8n.sh

### 3. Edit Your Domain Settings
nano install_n8n.sh

### 4. Run the Script
./install_n8n.sh


## 🛠 Updating Your n8n Instance
cd ~/n8n-compose
sudo docker compose pull
sudo docker compose down
sudo docker compose up -d

## 🔧 Troubleshooting SSL Issues
If HTTPS fails (e.g., certificate wasn’t issued properly):

cd ~/n8n-compose
sudo docker compose down
sudo rm -rf ./letsencrypt/acme.json
sudo docker compose up -d


## 💾 Optional: Setup Scheduled Backups
Use your cloud provider’s snapshot system to create automatic backups of your VM's disk.
Recommended: Daily snapshot schedule for quick recovery from configuration errors or upgrades gone wrong.

## 🧠 Why Self-Host n8n?
💰 No monthly limits or fees
🔐 Full control over your workflows and data
🧱 Build private integrations without exposing APIs
🛠 Extend with custom nodes and logic
🚀 Perfect for startups, agencies, engineers, and makers

## 📘 Resources
n8n Documentation
Traefik Docs
Docker Compose Docs

## 📄 License
This project is released under the MIT License.

## 🙌 Credits
Created by Carlos Jimenez — feel free to fork, star ⭐, and share!
