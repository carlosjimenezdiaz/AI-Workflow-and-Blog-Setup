#!/bin/bash

set -e  # Exit on error

echo "==== N8N + PostgreSQL + NGINX Deployment ===="

# Ask for user inputs
read_input() {
  local var_name=$1
  local prompt=$2
  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt: " input
    if [[ -z "$input" ]]; then
      echo "❌ No puede estar vacío. Intenta de nuevo."
    fi
  done
  eval "$var_name='$input'"
}

read_input DOMAIN "Dominio completo para n8n (ej: aiserver.carlosjimenezdiaz.com)"
read_input DB_NAME "Nombre de la base de datos"
read_input DB_USER "Usuario de la base de datos"
read_input DB_PASSWORD "Contraseña de la base de datos"
read_input N8N_USER "Usuario de acceso a n8n"
read_input N8N_PASSWORD "Contraseña de acceso a n8n"
read_input TIMEZONE "Zona horaria (ej: America/New_York)"
read_input SSL_EMAIL "Email para Let's Encrypt"

mkdir -p ~/n8n_stack && cd ~/n8n_stack

# Crear archivo .env
cat <<EOF > .env
DOMAIN=${DOMAIN}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
N8N_USER=${N8N_USER}
N8N_PASSWORD=${N8N_PASSWORD}
TIMEZONE=${TIMEZONE}
SSL_EMAIL=${SSL_EMAIL}
EOF

# Crear docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_DB: \${DB_NAME}
      POSTGRES_USER: \${DB_USER}
      POSTGRES_PASSWORD: \${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - internal

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
      - N8N_HOST=n8n
      - N8N_PORT=5678
      - TZ=\${TIMEZONE}
    networks:
      - internal
    depends_on:
      - postgres

networks:
  internal:

volumes:
  postgres_data:
EOF

# Levantar servicios primero
echo "🚀 Levantando contenedores..."
docker compose up -d
sleep 10

# Crear archivo NGINX para n8n
NGINX_CONF="/etc/nginx/sites-available/n8n"
cat <<EOF | sudo tee \$NGINX_CONF
upstream n8n {
    server 127.0.0.1:5678;
}

server {
    listen 80;
    server_name \${DOMAIN};

    location / {
        proxy_pass http://n8n;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -sf \$NGINX_CONF /etc/nginx/sites-enabled/n8n

# Verificar y recargar NGINX
sudo nginx -t && sudo systemctl reload nginx

# Generar certificado SSL
echo "🔐 Solicitando certificado SSL con Certbot..."
sudo certbot --nginx -d \$DOMAIN --non-interactive --agree-tos -m \$SSL_EMAIL

echo "✅ Despliegue completo. Visita: https://\$DOMAIN"
