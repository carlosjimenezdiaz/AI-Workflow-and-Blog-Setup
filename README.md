🚀 Self-Host n8n with Docker Compose + NGINX + Certbot
This project provides a plug-and-play script to self-host n8n, the powerful workflow automation tool, with PostgreSQL for persistence, NGINX as reverse proxy, and free HTTPS via Certbot — all running on your own Linux VM.

Gain full control over your workflows, automate anything, and scale without limits — ideal for developers, startups, creators, and automation pros.

📦 What's Included
- 🧩 One-click shell script: deploy-n8n.sh
- 🐳 Docker Compose stack:
- n8n – Workflow automation platform
- PostgreSQL – For persistent storage
- NGINX – Reverse proxy with virtual host support
- 🔒 Free SSL certificates via Certbot (Let's Encrypt)
- 🔁 Auto-renewal of SSL every 60 days via systemd timer
- 🌐 Multi-subdomain support with NGINX server blocks
- 💾 Persistent volumes for workflows and data

🖥 Requirements
Make sure you have:
- ✅ Ubuntu 22.04 LTS (or compatible) VM
- ✅ Root or sudo access
- ✅ Registered domain or subdomains (e.g. n8n.example.com)
- ✅ DNS A record(s) pointing to your VM
- ✅ Ports 80 and 443 open (for HTTP/HTTPS)

🚀 Deployment Steps
SSH into your VM

Download and run the setup script:
- curl -O https://raw.githubusercontent.com/carlosjimenezdiaz/AI-Workflow-and-Blog-Setup/main/deploy-n8n.sh
- chmod +x deploy-n8n.sh
- ./deploy-n8n.sh

🔁 Auto-Renewal of SSL Certificates
Certbot is installed with a systemd timer that runs:
- certbot renew --quiet --nginx
