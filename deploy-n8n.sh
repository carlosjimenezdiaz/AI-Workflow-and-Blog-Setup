#!/bin/bash

set -e  # Termina el script si ocurre un error

echo "==== N8N + PostgreSQL Deployment ===="

# Función para leer y validar entrada
read_input() {
  local var_name=$1
  local prompt=$2
  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt: " input
    if [[ -z "$input" ]]; then
      echo "❌ El valor no puede estar vacío. Intenta de nuevo."
    fi
  done
  eval "$var_name='$input'"
}

read_input DOMAIN_BASE "Base domain (e.g., carlosjimenezdiaz.com)"
read_input SUBDOMAIN "Subdomain for n8n (e.g., n8nserver)"
read_input DB_NAME "Database name (e.g., n8n_db)"
read_input DB_USER "Database user"
read_input DB_PASSWORD "Database password"
read_input TIMEZONE "Timezone (e.g., America/New_York)"
read_input SSL_EMAIL "Email for Let's Encrypt"
read_input N8N_USER "Username to access n8n (basic auth)"
read_input N8N_PASSWORD "Password for n8n (basic auth)"

DOMAIN="${SUBDOMAIN}.${DOMAIN_BASE}"

echo "➡️  Actualizando sistema..."
apt-get update && apt-get upgrade -y

echo "➡️  Instalando paquetes base..."
apt-get install -y nano vim tree htop curl wget unzip git make \
  build-essential software-properties-common apt-transport-https \
  ca-certificates gnupg lsb-release ufw tmux zsh

# Verificar e instalar Docker si no está
if ! command -v docker &> /dev/null; then
  echo "⚙️  Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
fi

# Verificar e instalar Docker Compose V2 si no está
if ! docker compose version &> /dev/null; then
  echo "⚙️  Instalando Docker Compose V2..."
  mkdir -p ~/.docker/cli-plugins/
  curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
fi

echo "➡️  Preparando stack..."
mkdir -p ~/n8n_stack && cd ~/n8n_stack

echo "✅ Escribiendo archivo .env"
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

echo "✅ Escribiendo docker-compose.yml"
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
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - WEBHOOK_TUNNEL_URL=https://${DOMAIN}
      - N8N_HOST=0.0.0.0
      - TZ=${TIMEZONE}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${DOMAIN}`)"
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

# Asegurar permisos de acme.json si existe
mkdir -p letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

echo "🚀 Levantando el stack con Docker Compose..."
docker compose up -d --build

echo "✅ Despliegue completado en https://${DOMAIN}"
