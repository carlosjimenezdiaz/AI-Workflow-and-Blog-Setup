🚀 Self-Host **n8n** + **Ghost** with **Docker Compose + NGINX + Certbot**
This project provides a plug-and-play script to self-host a full-featured automation and publishing stack — including n8n for workflow automation, Ghost for professional blogging all backed by PostgreSQL and served securely through NGINX with free SSL via Certbot.

Whether you're automating tasks, building a blog, or managing financial content, this setup gives you full control, privacy, and scalability. Perfect for developers, creators, startups, and digital entrepreneurs.

📦 What's Included
- 🧩 One-click shell script: deploy-n8n.sh
- 🐳 Docker Compose stack:
- n8n – Workflow automation platform
- Ghost – Headless CMS and blogging platform
- PostgreSQL – Persistent storage engine (with separate DBs per service)
- NGINX – Reverse proxy with virtual host support
- 🔒 Certbot – Free SSL certificates via Let's Encrypt
- 🔁 Auto-renewal of SSL certificates every 60 days via systemd
- 🌐 Multi-domain/subdomain support via NGINX server blocks
- 💾 Persistent volumes for all apps and data

🖥 Requirements
Make sure you have:
- ✅ Ubuntu 22.04 LTS (or compatible) VM
- ✅ Root or sudo access
- ✅ Registered domain(s) or subdomains (e.g. n8n.example.com, blog.example.com, postiz.example.com)
- ✅ DNS A records pointing to your VM
- ✅ Ports 80 and 443 open for HTTP/HTTPS access
- ✅ Put the .env file at the same level of the .sh file and populate all the fields with your information.

Questions: send me an email to **cjimenez.diaz@gmail.com**
