#!/bin/bash

# =============== INTERACTIVO ===============
echo "▶ Email para SSL Let's Encrypt:"
read -r SSL_EMAIL

echo "▶ Zona Horaria (ej: America/New_York):"
read -r TIMEZONE

# ========== n8n ==============
echo "▶ ¿Quieres usar un subdominio para n8n? (s/n):"
read -r USE_N8N_SUBDOMAIN

if [[ "$USE_N8N_SUBDOMAIN" =~ ^[Ss]$ ]]; then
  echo "▶ Subdominio para n8n (ej: n8n):"
  read -r N8N_SUB
  echo "▶ Dominio principal para n8n (ej: tudominio.com):"
  read -r N8N_BASE
  N8N_DOMAIN="${N8N_SUB}.${N8N_BASE}"
else
  echo "▶ Dominio completo para n8n (sin subdominio):"
  read -r N8N_DOMAIN
fi

echo "▶ Nombre de la base de datos para n8n:"
read -r N8N_DB
echo "▶ Usuario de la base de datos para n8n:"
read -r N8N_DB_USER
echo "▶ Contraseña del usuario de n8n:"
read -rs N8N_DB_PASSWORD
echo ""

# ========== Ghost ==============
echo "▶ ¿Quieres usar un subdominio para Ghost? (s/n):"
read -r USE_GHOST_SUBDOMAIN

if [[ "$USE_GHOST_SUBDOMAIN" =~ ^[Ss]$ ]]; then
  echo "▶ Subdominio para Ghost (ej: blog):"
  read -r GHOST_SUB
  echo "▶ Dominio principal para Ghost (ej: tudominio.com):"
  read -r GHOST_BASE
  GHOST_DOMAIN="${GHOST_SUB}.${GHOST_BASE}"
else
  echo "▶ Dominio completo para Ghost (sin subdominio):"
  read -r GHOST_DOMAIN
fi

echo "▶ Nombre de la base de datos para Ghost:"
read -r GHOST_DB
echo "▶ Usuario de la base de datos para Ghost:"
read -r GHOST_DB_USER
echo "▶ Contraseña del usuario de Ghost:"
read -rs GHOST_DB_PASSWORD
echo ""

# ========== PostgreSQL Admin ==========
echo "▶ Usuario administrador para PostgreSQL (ej: admin):"
read -r DB_ADMIN_USER
echo "▶ Contraseña del usuario administrador:"
read -rs DB_ADMIN_PASSWORD
echo ""

# =============== CREACIÓN DE ESTRUCTURA ===============
BASE_DIR=~/docker-stack
mkdir -p "$BASE_DIR"/{n8n,ghost,letsencrypt}
touch "$BASE_DIR/letsencrypt/acme.json"
chmod 600 "$BASE_DIR/letsencrypt/acme.json"
cd "$BASE_DIR" || exit 1

# =============== ENV FILE =================
echo "▶ Generando .env..."
cat <<EOF > .env
SSL_EMAIL=${SSL_EMAIL}
TIMEZONE=${TIMEZONE}

# PostgreSQL
DB_ADMIN_USER=${DB_ADMIN_USER}
DB_ADMIN_PASSWORD=${DB_ADMIN_PASSWORD}

# n8n
N8N_DOMAIN=${N8N_DOMAIN}
N8N_DB=${N8N_DB}
N8N_DB_USER=${N8N_DB_USER}
N8N_DB_PASSWORD=${N8N_DB_PASSWORD}

# ghost
GHOST_DOMAIN=${GHOST_DOMAIN}
GHOST_DB=${GHOST_DB}
GHOST_DB_USER=${GHOST_DB_USER}
GHOST_DB_PASSWORD=${GHOST_DB_PASSWORD}
EOF

# =============== DOCKERFILE GHOST =================
echo "▶ Generando Dockerfile de Ghost personalizado..."
cat <<EOF > ghost/Dockerfile
FROM ghost:latest

USER root
RUN npm install knex pg --save
USER node
EOF

# =============== DOCKER-COMPOSE =================
echo "▶ Generando docker-compose.yml..."
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
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks:
      - internal

  postgres:
    image: postgres:latest
    restart: always
    environment:
      POSTGRES_USER: \${DB_ADMIN_USER}
      POSTGRES_PASSWORD: \${DB_ADMIN_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - internal

  mysql:
    image: mysql:latest
    restart: always
    environment:
      MYSQL_DATABASE: \${GHOST_DB}
      MYSQL_USER: \${GHOST_DB_USER}
      MYSQL_PASSWORD: \${GHOST_DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: \${DB_ADMIN_PASSWORD}
    volumes:
      - ghost_db_data:/var/lib/mysql
    networks:
      - internal

  n8n:
    image: n8nio/n8n
    restart: always
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
    volumes:
      - n8n_data:/home/node/.n8n
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`\${N8N_DOMAIN}\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks:
      - internal
    depends_on:
      - postgres

  ghost:
    build:
      context: ./ghost
    restart: always
    environment:
      database__client: mysql
      database__connection__host: mysql
      database__connection__user: \${GHOST_DB_USER}
      database__connection__password: \${GHOST_DB_PASSWORD}
      database__connection__database: \${GHOST_DB}
      url: https://\${GHOST_DOMAIN}
    volumes:
      - ghost_content:/var/lib/ghost/content
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ghost.rule=Host(\`\${GHOST_DOMAIN}\`)"
      - "traefik.http.routers.ghost.entrypoints=websecure"
      - "traefik.http.routers.ghost.tls.certresolver=myresolver"
      - "traefik.http.services.ghost.loadbalancer.server.port=2368"
    networks:
      - internal
    depends_on:
      - mysql

networks:
  internal:

volumes:
  postgres_data:
  n8n_data:
  ghost_db_data:
  ghost_content:
  letsencrypt:
EOF

# =============== DESPLIEGUE =================
echo "▶ Levantando contenedores con Docker Compose..."
docker compose up -d --build

echo ""
echo "✅ ¡Despliegue completo!"
echo "🌐 n8n:   https://${N8N_DOMAIN}"
echo "🌐 Ghost: https://${GHOST_DOMAIN}"
