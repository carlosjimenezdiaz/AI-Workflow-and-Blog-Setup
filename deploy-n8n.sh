#!/bin/bash

set -e

echo "=== Instalando herramientas necesarias ==="
apt update && apt install -y \
    git \
    curl \
    wget \
    nano \
    vim \
    tree \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

echo "✅ Instalando Docker V2..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | bash
fi

echo "✅ Instalando Docker Compose V2 plugin..."
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

echo "🔁 Reiniciando Docker..."
systemctl restart docker
docker --version
docker compose version

echo "=== N8N + PostgreSQL + NGINX Deployment ==="

# Leer inputs
read_input() {
  local var_name=$1
  local prompt=$2
  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt: " input
    if [[ -z "$input" ]]; then
      echo "❌ No puede estar vacío."
    fi
  done
  eval "$var_name='$input'"
}

read_input DOMAIN "Dominio completo (ej: aiserver.carlosjimenezdiaz.com)"
read_input DB_NAME "Nombre de la base de datos (ej: n8n_db)"
read_input DB_USER "Usuario de la base de datos"
read_input DB_PASSWORD "Contraseña de la base de datos"
read_input N8N_USER "Usuario de acceso a n8n"
read_input N8N_PASSWORD "Contraseña de acceso a n8n"
read_input TIMEZONE "Zona horaria (ej: America/New_York)"
read_input SSL_EMAIL "Email para Let's Encrypt (ej: tu@correo.com)"

mkdir -p ~/n8n_stack && cd ~/n8n_stack

echo "✅ Creando .env"
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

echo "✅ Creando docker-compose.yml"
cat <<EOF > docker-compose.yml
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
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - WEBHOOK_URL=https://\${DOMAIN}
      - VUE_APP_URL_BASE_API=https://\${DOMAIN}
      - TZ=\${TIMEZONE}
    ports:
      - "5678:5678"
    networks: [internal]

volumes:
  postgres_data:

networks:
  internal:
EOF

echo "✅ Levantando servicios con Docker Compose..."
docker compose down || true
docker compose up -d --build

echo "✅ Esperando que n8n esté disponible..."
sleep 10

echo "✅ Instalando Certbot y NGINX si no existen..."
apt install -y nginx certbot python3-certbot-nginx

echo "✅ Configurando NGINX para ${DOMAIN}"
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

echo "✅ Verificando configuración de NGINX..."
nginx -t

echo "✅ Reiniciando NGINX..."
systemctl restart nginx

echo "✅ Solicitando certificado SSL para ${DOMAIN}..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${SSL_EMAIL}

echo "✅ Recargando NGINX con SSL..."
systemctl reload nginx

echo "✅ Despliegue completado"
echo "🌐 Accede a: https://${DOMAIN}"
echo "🔐 Callback OAuth2: https://${DOMAIN}/rest/oauth2-credential/callback"
