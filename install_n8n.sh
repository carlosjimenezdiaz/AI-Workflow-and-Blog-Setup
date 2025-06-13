#!/bin/bash

# =============== CONFIGURATION ===============
echo "▶ Enter your domain name (e.g., yourdomain.com):"
read -r DOMAIN_NAME

echo "▶ Enter the subdomain to use for n8n (e.g., n8n):"
read -r SUBDOMAIN

echo "▶ Enter your email address for SSL certificate registration (e.g., youremail@gmail.com):"
read -r SSL_EMAIL

echo "▶ Enter your timezone (e.g., America/New_York):"
read -r TIMEZONE

# =============== SYSTEM SETUP ===============
echo "▶ Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

echo "▶ Installing dependencies..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release nano

# =============== DOCKER INSTALL ===============
echo "▶ Setting up Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "▶ Installing Docker & Docker Compose plugin..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "▶ Docker versions installed:"
docker --version
docker compose version

# =============== N8N SETUP ===============
echo "▶ Creating n8n directory structure..."
mkdir -p ~/n8n-compose/local-files
mkdir -p ~/n8n-compose/letsencrypt
chmod 600 ~/n8n-compose/letsencrypt/acme.json 2>/dev/null || touch ~/n8n-compose/letsencrypt/acme.json && chmod 600 ~/n8n-compose/letsencrypt/acme.json
cd ~/n8n-compose || exit 1

echo "▶ Creating .env file..."
cat <<EOF > .env
DOMAIN_NAME=${DOMAIN_NAME}
SUBDOMAIN=${SUBDOMAIN}
GENERIC_TIMEZONE=${TIMEZONE}
SSL_EMAIL=${SSL_EMAIL}
EOF

echo "▶ Creating docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: n8npass
      POSTGRES_DB: n8n_db
    volumes:
      - postgres_data:/var/lib/postgresql/data

  traefik:
    image: traefik
    restart: always
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.mytlschallenge.acme.tlschallenge=true
      - --certificatesresolvers.mytlschallenge.acme.email=\${SSL_EMAIL}
      - --certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./letsencrypt:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - 127.0.0.1:5678:5678
    depends_on:
      - postgres
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n_db
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=n8npass
      - N8N_HOST=\${SUBDOMAIN}.\${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${SUBDOMAIN}.\${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=\${GENERIC_TIMEZONE}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(\`\${SUBDOMAIN}.\${DOMAIN_NAME}\`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.entrypoints=websecure
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge

volumes:
  n8n_data:
  traefik_data:
  postgres_data:
EOF

# =============== LAUNCH ===============
echo "▶ Launching n8n with Docker Compose..."
sudo docker compose up -d

echo ""
echo "✅ n8n is now running!"
echo "🌐 Visit: https://${SUBDOMAIN}.${DOMAIN_NAME}"
echo "📥 Create your owner account and activate the free Fair Code license."
