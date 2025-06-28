#!/bin/bash

set -e

# === Validar y cargar archivo .env ===
if [ ! -f .env ]; then
  echo "❌ Archivo .env no encontrado. Asegúrate de tenerlo en el mismo directorio que este script."
  exit 1
fi

echo "📦 Cargando variables desde .env..."
export $(grep -v '^#' .env | xargs)

echo "=== Instalando herramientas necesarias ==="
apt update && apt install -y \
    git curl wget nano vim tree ca-certificates gnupg \
    lsb-release software-properties-common nginx certbot python3-certbot-nginx

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

mkdir -p ~/ghost_stack && cd ~/ghost_stack

echo "✅ Generando docker-compose.yml"
cat <<'EOF' > docker-compose.yml
services:
  ghost_db:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${GHOST_DB_PASSWORD}
      MYSQL_DATABASE: ${GHOST_DB_NAME}
      MYSQL_USER: ${GHOST_DB_USER}
      MYSQL_PASSWORD: ${GHOST_DB_PASSWORD}
    volumes:
      - ghost_db_data:/var/lib/mysql
    networks: [fullnet]

  ghost:
    image: ghost:5
    restart: unless-stopped
    depends_on:
      - ghost_db
    environment:
      url: https://${GHOST_DOMAIN}
      database__client: mysql
      database__connection__host: ghost_db
      database__connection__user: ${GHOST_DB_USER}
      database__connection__password: ${GHOST_DB_PASSWORD}
      database__connection__database: ${GHOST_DB_NAME}
      NODE_ENV: production
      GHOST_TRUST_PROXY: true
    volumes:
      - ghost_content:/var/lib/ghost/content
    ports:
      - "2368:2368"
    networks: [fullnet]

volumes:
  ghost_db_data:
  ghost_content:

networks:
  fullnet:
    driver: bridge
EOF

echo "✅ Iniciando stack Ghost..."
docker compose down || true
docker compose up -d --build

create_nginx_config() {
  local domain=$1
  cat <<EOF > /etc/nginx/sites-available/$domain
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:2368;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
}

create_nginx_config $GHOST_DOMAIN

nginx -t && systemctl reload nginx

echo "✅ Solicitando certificado SSL para Ghost..."
certbot --nginx -d $GHOST_DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL

echo "✅ Ghost desplegado en: https://$GHOST_DOMAIN"
