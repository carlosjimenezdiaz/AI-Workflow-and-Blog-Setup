#!/bin/bash

set -e

echo "🔧 Iniciando despliegue de n8n + PostgreSQL + NGINX + SSL..."

read_var() {
  local var="$1"
  local prompt="$2"
  local value=""
  while [[ -z "$value" ]]; do
    read -p "$prompt: " value
  done
  eval "$var='$value'"
}

read_var DOMAIN "Dominio completo (ej: aiserver.carlosjimenezdiaz.com)"
read_var DB_NAME "Nombre de la base de datos"
read_var DB_USER "Usuario de la base de datos"
read_var DB_PASSWORD "Contraseña de la base de datos"
read_var N8N_USER "Usuario para acceder a n8n"
read_var N8N_PASSWORD "Contraseña de n8n"
read_var SSL_EMAIL "Email para Let's Encrypt"
read_var TIMEZONE "Zona horaria (ej: America/New_York)"

mkdir -p ~/n8n_stack && cd ~/n8n_stack

# .env
cat <<EOF > .env
DOMAIN=${DOMAIN}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
N8N_USER=${N8N_USER}
N8N_PASSWORD=${N8N_PASSWORD}
SSL_EMAIL=${SSL_EMAIL}
TIMEZONE=${TIMEZONE}
EOF

# docker-compose.yml
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
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - WEBHOOK_URL=https://\${DOMAIN}
      - TZ=\${TIMEZONE}
    networks: [internal]
    container_name: n8n

volumes:
  postgres_data:

networks:
  internal:
EOF

echo "🌐 Verificando NGINX y Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx ufw

# NGINX conf
cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name ${DOMAIN};
    location / {
        proxy_pass http://n8n:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

nginx -t && systemctl reload nginx

echo "🔐 Solicitando certificado SSL con Certbot..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL

# HTTPS config
cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://n8n:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOF

nginx -t && systemctl reload nginx

echo "🚀 Levantando servicios..."
docker compose up -d

echo ""
echo "✅ Accede a n8n en: https://${DOMAIN}"
echo "📎 Callback URL OAuth2: https://${DOMAIN}/rest/oauth2-credential/callback"
