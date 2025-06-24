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

echo "=== Despliegue de n8n + Ghost + Postiz ==="

# Leer variables
read_input() {
  local var_name=$1
  local prompt=$2
  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt: " input
    if [[ -z "$input" ]]; then echo "❌ No puede estar vacío."; fi
  done
  eval "$var_name='$input'"
}

mkdir -p ~/full_stack && cd ~/full_stack

echo "✅ Generando archivo .env"
cat <<EOF > .env
N8N_DOMAIN=$N8N_DOMAIN
GHOST_DOMAIN=$GHOST_DOMAIN
POSTIZ_DOMAIN=$POSTIZ_DOMAIN
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
GHOST_DB_NAME=$GHOST_DB_NAME
GHOST_DB_USER=$GHOST_DB_USER
GHOST_DB_PASSWORD=$GHOST_DB_PASSWORD
N8N_USER=$N8N_USER
N8N_PASSWORD=$N8N_PASSWORD
TIMEZONE=$TIMEZONE
SSL_EMAIL=$SSL_EMAIL
POSTIZ_JWT_SECRET=$POSTIZ_JWT_SECRET
EOF

echo "✅ Generando docker-compose.yml"
cat <<'EOF' > docker-compose.yml
services:
  postgres:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks: [fullnet]

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

  n8n:
    image: n8nio/n8n
    restart: always
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
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

  ghost_token_service:
    build: .
    container_name: ghost_token_service
    ports:
      - "3000:3000"
    restart: unless-stopped

volumes:
  postgres_data:
  ghost_content:
  ghost_db_data:
  postgres-volume:

networks:
  fullnet:
    driver: bridge
EOF

echo "✅ Iniciando stack completo..."
docker compose down || true
docker compose up -d --build

echo "✅ Configurando NGINX y certificados SSL..."
create_nginx_config() {
  local domain=$1
  cat <<EOF > /etc/nginx/sites-available/$domain
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$(get_port_for_domain $domain);
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain
}

get_port_for_domain() {
  case $1 in
    $N8N_DOMAIN) echo 5678 ;;
    $GHOST_DOMAIN) echo 2368 ;;
    $POSTIZ_DOMAIN) echo 5000 ;;
    *) echo "❌ Dominio desconocido" && exit 1 ;;
  esac
}

create_nginx_config $N8N_DOMAIN
create_nginx_config $GHOST_DOMAIN
create_nginx_config $POSTIZ_DOMAIN

nginx -t && systemctl reload nginx

echo "✅ Solicitando certificados SSL..."
certbot --nginx -d $N8N_DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL
certbot --nginx -d $GHOST_DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL
certbot --nginx -d $POSTIZ_DOMAIN --non-interactive --agree-tos -m $SSL_EMAIL

echo "✅ Todo está desplegado en:"
echo "- n8n: https://$N8N_DOMAIN"
echo "- Ghost: https://$GHOST_DOMAIN"
echo "- Postiz: https://$POSTIZ_DOMAIN"

echo "✅ Creando backup script diario para n8n y ghost..."
cat <<'EOF' > ~/full_stack/backup.sh
#!/bin/bash
set -e
cd "$(dirname "$0")"

ENV=".env"
if [ ! -f "$ENV" ]; then echo "❌ .env no encontrado"; exit 1; fi
export $(grep -v '^#' "$ENV" | xargs)

mkdir -p ~/full_stack/backups
TS=$(date +"%Y%m%d_%H%M%S")

docker compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" > ~/full_stack/backups/n8n_backup_$TS.sql
docker compose exec -T ghost_db mysqldump -u"$GHOST_DB_USER" -p"$GHOST_DB_PASSWORD" "$GHOST_DB_NAME" > ~/full_stack/backups/ghost_backup_$TS.sql

ls -tp ~/full_stack/backups/*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --
EOF

chmod +x ~/full_stack/backup.sh
(crontab -l 2>/dev/null; echo "0 4 * * * ~/full_stack/backup.sh >> ~/full_stack/backup.log 2>&1") | crontab -

echo "✅ Configuración y backups completos."
