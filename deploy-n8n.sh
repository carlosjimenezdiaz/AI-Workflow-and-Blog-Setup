#!/bin/bash
set -e

echo "==== N8N + PostgreSQL + NGINX Deployment ===="

read_input() {
  local var_name=$1
  local prompt=$2
  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt: " input
    if [[ -z "$input" ]]; then
      echo "❌ El valor no puede estar vacío."
    fi
  done
  eval "$var_name='$input'"
}

read_input DOMAIN "Dominio completo (ej: aiserver.carlosjimenezdiaz.com)"
read_input DB_NAME "Nombre de la base de datos (ej: n8n_db)"
read_input DB_USER "Usuario de la base de datos"
read_input DB_PASSWORD "Contraseña de la base de datos"
read_input N8N_USER "Usuario para acceder a n8n"
read_input N8N_PASSWORD "Contraseña para n8n"
read_input TIMEZONE "Zona horaria (ej: America/New_York)"
read_input SSL_EMAIL "Email para Let's Encrypt (Certbot)"

if ! command -v docker &> /dev/null; then
  echo "🛠 Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
fi

if ! docker compose version &> /dev/null; then
  echo "🛠 Instalando Docker Compose V2..."
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
fi

apt update
apt install -y nginx certbot python3-certbot-nginx

mkdir -p ~/n8n_stack && cd ~/n8n_stack

cat <<EOF > .env
DOMAIN=${DOMAIN}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
N8N_USER=${N8N_USER}
N8N_PASSWORD=${N8N_PASSWORD}
TIMEZONE=${TIMEZONE}
EOF

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

  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
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
      - N8N_HOST=\${DOMAIN}
      - WEBHOOK_TUNNEL_URL=https://\${DOMAIN}
      - TZ=\${TIMEZONE}
    depends_on:
      - postgres

volumes:
  postgres_data:
EOF

docker compose up -d

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
nginx -t && systemctl reload nginx

certbot --nginx --non-interactive --agree-tos --redirect --email ${SSL_EMAIL} -d ${DOMAIN}

echo -e "\n✅ Accede a: https://${DOMAIN}"
echo "🔐 Usuario: ${N8N_USER}"
