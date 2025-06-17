#!/bin/bash

echo "==== N8N + PostgreSQL Deployment ===="

read -p "Base domain (e.g., carlosjimenezdiaz.com): " DOMAIN_BASE
read -p "Subdomain for n8n (e.g., n8nserver): " SUBDOMAIN
read -p "Database name (e.g., n8n_db): " DB_NAME
read -p "Database user: " DB_USER
read -p "Database password: " DB_PASSWORD
read -p "Timezone (e.g., America/New_York): " TIMEZONE
read -p "Email for Let's Encrypt: " SSL_EMAIL
read -p "Username to access n8n (basic auth): " N8N_USER
read -p "Password for n8n (basic auth): " N8N_PASSWORD

DOMAIN="${SUBDOMAIN}.${DOMAIN_BASE}"

# Crear carpeta del stack
mkdir -p ~/n8n_stack && cd ~/n8n_stack

# Crear archivo .env
cat <<EOF > .env
DOMAIN_BASE=${DOMAIN_BASE}
SUBDOMAIN=${SUBDOMAIN}
DOMAIN=${DOMAIN}
TIMEZONE=${TIMEZONE}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
SSL_EMAIL=${SSL_EMAIL}
N8N_USER=${N8N_USER}
N8N_PASSWORD=${N8N_PASSWORD}
EOF

# Crear docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  traefik:
    image: traefik:latest
    restart: always
    command:
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --certificatesresolvers.myresolver.acme.httpchallenge=true
      - --certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.myresolver.acme.email=\${SSL_EMAIL}
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks: [traefik]

  postgres:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_DB: \${DB_NAME}
      POSTGRES_USER: \${DB_USER}
      POSTGRES_PASSWORD: \${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks: [internal]

  n8n:
    image: n8nio/n8n
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${DB_NAME}
      - DB_POSTGRESDB_USER=\${DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${DB_PASSWORD}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=\${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=\${N8N_PASSWORD}
      - WEBHOOK_TUNNEL_URL=https://\${DOMAIN}
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - TZ=\${TIMEZONE}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`\${DOMAIN}\`) || Host(\`www.\${DOMAIN}\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks:
      - traefik
      - internal
    depends_on:
      - postgres

networks:
  traefik:
  internal:

volumes:
  postgres_data:
  letsencrypt:
EOF

# Iniciar el stack
docker compose up -d --build
