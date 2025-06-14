#!/bin/bash

# =============== CONFIGURACIÓN INTERACTIVA ===============
echo "▶ Principal Domain (ej: tu-dominio.com):"
read -r DOMAIN_NAME

echo "▶ Sub-Domain for n8n (ej: n8n):"
read -r SUBDOMAIN

echo "▶ Email for the SSL certificate:"
read -r SSL_EMAIL

echo "▶ Time Zone (like: America/New_York):"
read -r TIMEZONE

echo "▶ DB Name:"
read -r DB_NAME

echo "▶ Username for the DB:"
read -r DB_USER

echo "▶ Password for the DB:"
read -rs DB_PASSWORD
echo ""

# =============== PREPARACIÓN DEL SISTEMA ===============
echo "▶ Actualizando paquetes del sistema..."
sudo apt-get update && sudo apt-get upgrade -y

# =============== INSTALACIÓN DE DOCKER Y DOCKER COMPOSE PLUGIN V2 ===============
echo "▶ Configurando repositorio oficial de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "▶ Instalando Docker + Docker Compose V2..."
sudo apt-get update

while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
  echo "⚠️ Esperando a que se libere el bloqueo de APT..."
  sleep 3
done

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker no se instaló correctamente. Abortando."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "❌ Docker Compose plugin no se instaló correctamente. Abortando."
  exit 1
fi

echo "✅ Docker: $(docker --version)"
echo "✅ Docker Compose: $(docker compose version)"

# =============== CONFIGURACIÓN DE N8N ===============
echo "▶ Estructura de carpetas para n8n..."
mkdir -p ~/n8n-compose/local-files
mkdir -p ~/n8n-compose/letsencrypt
touch ~/n8n-compose/letsencrypt/acme.json
chmod 600 ~/n8n-compose/letsencrypt/acme.json
cd ~/n8n-compose || exit 1

echo "▶ Creando archivo .env..."
cat <<EOF > .env
DOMAIN_NAME=${DOMAIN_NAME}
SUBDOMAIN=${SUBDOMAIN}
GENERIC_TIMEZONE=${TIMEZONE}
SSL_EMAIL=${SSL_EMAIL}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
EOF

echo "▶ Creando docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: \${DB_USER}
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_DB: \${DB_NAME}
    ports:
      - 5432:5432
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
      - DB_POSTGRESDB_DATABASE=\${DB_NAME}
      - DB_POSTGRESDB_USER=\${DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${DB_PASSWORD}
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

# =============== DESPLIEGUE FINAL ===============
echo "▶ Levantando contenedores con Docker Compose..."
sudo docker compose up -d

echo ""
echo "✅ n8n está corriendo con éxito."
echo "🌐 Abre: https://${SUBDOMAIN}.${DOMAIN_NAME}"
echo "🧠 Crea tu cuenta de administrador y activa la licencia Fair Code."
