#!/bin/bash
set -e

echo "🔧 Actualizando Ubuntu y paquetes..."
sudo apt update && sudo apt upgrade -y

# ======================= Docker =======================
echo "🐳 Verificando Docker..."
if ! command -v docker &> /dev/null; then
  echo "⚙️ Instalando Docker..."
  sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
  sudo usermod -aG docker $USER
  echo "✅ Docker instalado. Reinicia sesión y vuelve a ejecutar este script."
  exit 0
else
  echo "✅ Docker ya está instalado."
fi

# ================= Docker Compose v2 =================
echo "🔍 Verificando Docker Compose v2..."
if ! docker compose version &> /dev/null; then
  echo "⚠️ docker compose no encontrado. Instalando plugin manualmente..."
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
  echo "✅ Docker Compose instalado manualmente."
else
  echo "✅ Docker Compose está disponible."
fi

# ================= Interactive Input =================
echo "▶ Email para SSL Let's Encrypt:"
read -r SSL_EMAIL
echo "▶ Zona Horaria (ej: America/New_York):"
read -r TIMEZONE

echo "▶ Subdominio para n8n? (s/n):"
read -r USE_N8N_SUBDOMAIN
if [[ "$USE_N8N_SUBDOMAIN" =~ ^[Ss]$ ]]; then
  echo "▶ Subdominio para n8n (ej: n8n):"
  read -r N8N_SUB
  echo "▶ Dominio principal para n8n:"
  read -r N8N_BASE
  N8N_DOMAIN="${N8N_SUB}.${N8N_BASE}"
else
  echo "▶ Dominio completo para n8n:"
  read -r N8N_DOMAIN
fi

echo "▶ DB nombre para n8n:"
read -r N8N_DB
echo "▶ DB usuario para n8n:"
read -r N8N_DB_USER
echo "▶ DB contraseña para n8n:"
read -rs N8N_DB_PASSWORD
echo ""

echo "▶ Subdominio para Ghost? (s/n):"
read -r USE_GHOST_SUBDOMAIN
if [[ "$USE_GHOST_SUBDOMAIN" =~ ^[Ss]$ ]]; then
  echo "▶ Subdominio para Ghost (ej: blog):"
  read -r GHOST_SUB
  echo "▶ Dominio principal para Ghost:"
  read -r GHOST_BASE
  GHOST_DOMAIN="${GHOST_SUB}.${GHOST_BASE}"
else
  echo "▶ Dominio completo para Ghost:"
  read -r GHOST_DOMAIN
fi

echo "▶ DB nombre para Ghost:"
read -r GHOST_DB
echo "▶ DB usuario para Ghost:"
read -r GHOST_DB_USER
echo "▶ DB contraseña para Ghost:"
read -rs GHOST_DB_PASSWORD
echo ""

echo "▶ Admin API Key de Ghost (formato key_id:secret):"
read -r GHOST_ADMIN_API_KEY
echo ""
echo "▶ Usuario admin para Postgres:"
read -r DB_ADMIN_USER
echo "▶ Contraseña admin para Postgres:"
read -rs DB_ADMIN_PASSWORD
echo ""

# ================= Create folders + files =================
BASE_DIR=~/docker-stack
mkdir -p "$BASE_DIR"/{n8n,ghost,ghost-token-service,letsencrypt,backups}
touch "$BASE_DIR/letsencrypt/acme.json"; chmod 600 "$BASE_DIR/letsencrypt/acme.json"
cd "$BASE_DIR" || exit 1

# --- ghost-token-service ---
cat <<EOF > ghost-token-service/app.py
import jwt; import datetime
from flask import Flask, jsonify
import os
app = Flask(__name__)
@app.route("/ghost-token")
def get_ghost_token():
    key = os.getenv("GHOST_ADMIN_API_KEY")
    kid, secret = key.split(":")
    iat = int(datetime.datetime.utcnow().timestamp())
    payload = {"iat": iat, "exp": iat+300, "aud": "/admin/"}
    token = jwt.encode(payload, bytes.fromhex(secret), algorithm="HS256", headers={"kid": kid})
    return jsonify({"token": token})
EOF

cat <<EOF > ghost-token-service/requirements.txt
Flask
PyJWT
EOF

cat <<EOF > ghost-token-service/Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . /app
RUN pip install --no-cache-dir -r requirements.txt
ENV FLASK_APP=app.py
CMD ["flask","run","--host=0.0.0.0","--port=5000"]
EOF

# --- .env ---
cat <<EOF > .env
SSL_EMAIL=${SSL_EMAIL}
TIMEZONE=${TIMEZONE}
DB_ADMIN_USER=${DB_ADMIN_USER}
DB_ADMIN_PASSWORD=${DB_ADMIN_PASSWORD}
N8N_DOMAIN=${N8N_DOMAIN}
N8N_DB=${N8N_DB}
N8N_DB_USER=${N8N_DB_USER}
N8N_DB_PASSWORD=${N8N_DB_PASSWORD}
GHOST_DOMAIN=${GHOST_DOMAIN}
GHOST_DB=${GHOST_DB}
GHOST_DB_USER=${GHOST_DB_USER}
GHOST_DB_PASSWORD=${GHOST_DB_PASSWORD}
GHOST_ADMIN_API_KEY=${GHOST_ADMIN_API_KEY}
EOF

# --- ghost Dockerfile ---
cat <<EOF > ghost/Dockerfile
FROM ghost:latest
USER root
RUN npm install knex pg --save
USER node
EOF

# --- docker-compose.yml ---
cat <<EOF > docker-compose.yml
version: "3.8"
services:
  traefik:
    image: traefik:latest; restart: always
    command:
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --certificatesresolvers.myresolver.acme.httpchallenge=true
      - --certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web
      - --certificatesresolvers.myresolver.acme.email=\${SSL_EMAIL}
      - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
    ports: ["80:80","443:443"]
    volumes: ["/var/run/docker.sock:/var/run/docker.sock:ro","letsencrypt:/letsencrypt"]
    networks: ["internal"]
  postgres:
    image: postgres:latest; restart: always
    environment:
      POSTGRES_USER: \${DB_ADMIN_USER}
      POSTGRES_PASSWORD: \${DB_ADMIN_PASSWORD}
    volumes: ["postgres_data:/var/lib/postgresql/data"]
    networks: ["internal"]
  mysql:
    image: mysql:latest; restart: always
    environment:
      MYSQL_DATABASE: \${GHOST_DB}
      MYSQL_USER: \${GHOST_DB_USER}
      MYSQL_PASSWORD: \${GHOST_DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${DB_ADMIN_PASSWORD}
    volumes: ["ghost_db_data:/var/lib/mysql"]
    networks: ["internal"]
  n8n:
    image: n8nio/n8n; restart: always
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_DATABASE: \${N8N_DB}
      DB_POSTGRESDB_USER: \${N8N_DB_USER}
      DB_POSTGRESDB_PASSWORD: \${N8N_DB_PASSWORD}
      N8N_HOST: \${N8N_DOMAIN}
      N8N_PORT: 5678
      WEBHOOK_URL: https://\${N8N_DOMAIN}/
      TZ: \${TIMEZONE}
    volumes: ["n8n_data:/home/node/.n8n"]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`\${N8N_DOMAIN}\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks: ["internal"]
    depends_on: ["postgres"]
  ghost:
    build: { context: ./ghost }
    restart: always
    environment:
      database__client: mysql
      database__connection__host: mysql
      database__connection__user: \${GHOST_DB_USER}
      database__connection__password: \${GHOST_DB_PASSWORD}
      database__connection__database: \${GHOST_DB}
      url: https://\${GHOST_DOMAIN}
    volumes: ["ghost_content:/var/lib/ghost/content"]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ghost.rule=Host(\`\${GHOST_DOMAIN}\`)"
      - "traefik.http.routers.ghost.entrypoints=websecure"
      - "traefik.http.routers.ghost.tls.certresolver=myresolver"
      - "traefik.http.services.ghost.loadbalancer.server.port=2368"
    networks: ["internal"]
    depends_on: ["mysql"]
  ghost-token-service:
    build: { context: ./ghost-token-service }
    restart: always
    environment:
      GHOST_ADMIN_API_KEY: \${GHOST_ADMIN_API_KEY}
    ports: ["5050:5000"]
    networks: ["internal"]
networks: { internal: {} }
volumes:
  postgres_data: {}
  n8n_data: {}
  ghost_db_data: {}
  ghost_content: {}
  letsencrypt: {}
EOF

# ================= Backup n8n_data =================
echo "🗂️ Haciendo backup del volumen n8n_data..."
docker run --rm -v n8n_data:/data -v "$BASE_DIR/backups":/backup alpine \
  tar czf /backup/n8n_backup_$(date +%F_%H-%M-%S).tar.gz -C /data .

# ================= Deploy =================
echo "🚀 Iniciando todo el stack..."
docker compose up -d --build

echo ""
echo "✅ ¡Despliegue completo!"
echo "🌐 n8n:   https://${N8N_DOMAIN}"
echo "🌐 Ghost: https://${GHOST_DOMAIN}"
echo "🔑 Ghost Token Service: http://$(hostname -I | awk '{print $1}'):5050/ghost-token"
