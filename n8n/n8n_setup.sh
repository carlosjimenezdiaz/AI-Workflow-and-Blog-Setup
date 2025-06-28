#!/bin/bash

set -e

# === Validar y cargar archivo .env ===
if [ ! -f .env ]; then
  echo "❌ Archivo .env no encontrado. Asegúrate de tenerlo en el mismo directorio que este script."
  exit 1
fi

echo "📦 Cargando variables desde .env..."
export $(grep -v '^#' .env | xargs)

# Extraer dominio base (sin www)
BASE_DOMAIN=$(echo $N8N_DOMAIN | sed 's/^www\.//')

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

echo "=== Despliegue de n8n ==="

echo "✅ Generando docker-compose.yml"
cat <<'EOF' > docker-compose.yml
services:
  postgres_n8n:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data_n8n:/var/lib/postgresql/data
    networks: [fullnet]

  n8n:
    image: n8nio/n8n
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres_n8n
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - WEBHOOK_URL=https://${N8N_DOMAIN}
      - VUE_APP_URL_BASE_API=https://${N8N_DOMAIN}
      - TZ=${TIMEZONE}
    ports:
      - "5678:5678"
    networks: [fullnet]

volumes:
  postgres_data_n8n:
  postgres-volume:

networks:
  fullnet:
    driver: bridge
EOF

echo "✅ Iniciando stack completo..."
docker compose down || true
docker compose up -d --build

echo "✅ Configurando NGINX para $N8N_DOMAIN y $BASE_DOMAIN..."
cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name ${N8N_DOMAIN} ${BASE_DOMAIN};

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}

# Redirigir www → sin www (opcional pero recomendado)
server {
    listen 80;
    server_name www.${BASE_DOMAIN};
    return 301 https://${BASE_DOMAIN}\$request_uri;
}
EOF

ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

echo "🔍 Verificando configuración de NGINX..."
if nginx -t; then
  echo "✅ NGINX válido. Recargando..."
  systemctl reload nginx
else
  echo "❌ Error en la configuración de NGINX. Abortando..."
  exit 1
fi

echo "✅ Solicitando certificados SSL para $N8N_DOMAIN y $BASE_DOMAIN..."
if certbot --nginx -d $N8N_DOMAIN -d $BASE_DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL; then
  echo "✅ Certificado SSL generado con éxito."
else
  echo "❌ Error al generar certificado SSL con Certbot."
  exit 1
fi

echo "✅ Todo está desplegado en:"
echo "- n8n: https://${N8N_DOMAIN} (o https://${BASE_DOMAIN})"

echo "✅ Creando backup script diario para n8n..."
mkdir -p ~/n8n
cat <<'EOF' > ~/n8n/backup.sh
#!/bin/bash
set -e
cd "$(dirname "$0")"

ENV=".env"
if [ ! -f "$ENV" ]; then echo "❌ .env no encontrado"; exit 1; fi
export $(grep -v '^#' "$ENV" | xargs)

mkdir -p ~/n8n/backups
TS=$(date +"%Y%m%d_%H%M%S")

docker compose exec -T postgres_n8n pg_dump -U "$DB_USER" "$DB_NAME" > ~/n8n/backups/n8n_backup_$TS.sql

ls -tp ~/n8n/backups/*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --
EOF

chmod +x ~/n8n/backup.sh
(crontab -l 2>/dev/null; echo "0 4 * * * ~/n8n/backup.sh >> ~/n8n/backup.log 2>&1") | crontab -

echo "✅ Configuración y backups completos."
