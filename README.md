# 🚀 Self-Host n8n + Ghost with Docker Compose + Traefik
This project provides a **plug-and-play script** to self-host [n8n](https://n8n.io) (workflow automation) and [Ghost](https://ghost.org) (professional blogging platform) on **any Linux cloud VM**, with full HTTPS support, no usage limits, and a unified PostgreSQL backend. Whether you're running on AWS, DigitalOcean, Google Cloud, or Oracle Cloud, this setup gives you complete control, privacy, and extendability — perfect for automation pros, bloggers, and indie devs.

---

## 📦 What's Included
- 🧩 One-click shell script: `deploy-stack.sh`
- 🐳 Docker Compose setup with:
  - [n8n](https://n8n.io) – workflow automation
  - [Ghost](https://ghost.org) – blogging CMS
  - PostgreSQL – shared database engine (with separate DBs for each service)
  - Traefik – reverse proxy with automatic HTTPS
- 🔒 Free SSL certificates via Let's Encrypt
- 💾 Persistent volumes for workflows and Ghost content
- 🌍 Full domain or subdomain support for each app

---

## 🖥 Requirements
Before running the script, make sure you have:

- ✅ A cloud VM with **Ubuntu 22.04 LTS** or compatible
- ✅ `sudo` or root access to the VM
- ✅ A registered **domain or subdomain** for each service
- ✅ DNS **A record(s)** pointing to your VM's **public IP**
- ✅ Open ports: **80** and **443**

---

## 🚀 Updating the VM
- **Step 1**. Use your cloud provider’s console or terminal to login to your VM
- **Step 2**. curl -O https://raw.githubusercontent.com/carlosjimenezdiaz/AI-Workflow-and-Blog-Setup/main/setup-datascience-vm.sh
- **Step 3**. Run the following command: chmod +x setup-data science-vm.sh
- **Step 4**. Run the following command: ./setup-datascience-vm.sh

## 🚀 Deploying N8N
- **Step 1**. Use your cloud provider’s console or terminal to login to your VM
- **Step 2**. curl -O https://raw.githubusercontent.com/carlosjimenezdiaz/AI-Workflow-and-Blog-Setup/main/deploy-n8n.sh
- **Step 3**. Run the following command: chmod +x deploy-n8n.sh
- **Step 4**. Run the following command: ./deploy-n8n.sh
---

### 🛠 Updating Services (n8n / Ghost / Traefik)
- cd ~/n8n-compose
- sudo docker compose pull
- sudo docker compose down
- sudo docker compose up -d

### 💾 Optional: Setup Scheduled Backups
Use your cloud provider’s snapshot system to create automatic backups of your VM's disk.
Recommended: Daily snapshot schedule for quick recovery from configuration errors or upgrades gone wrong.

---

### 🧠 Why Self-Host n8n?
- 💰 No monthly limits or fees
- 🔐 Full control over your workflows and data
- 🧱 Build private integrations without exposing APIs
- 🛠 Extend with custom nodes and logic
- 🚀 Perfect for startups, agencies, engineers, and makers

### 📘 Resources
- n8n Documentation
- Traefik Docs
- Docker Compose Docs

### 📄 License
This project is released under the MIT License.

### 🙌 Credits
Created by Carlos Jimenez — feel free to fork, star ⭐, and share! If you have any questions, send me an email to cjimenez.diaz@gmail.com (happy to help)
