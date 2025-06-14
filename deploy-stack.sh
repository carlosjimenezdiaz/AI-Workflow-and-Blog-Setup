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
mkdir -p ~/docker-stack/{n8n/local-files,ghost,letsencrypt}
touch ~/docker-stack/letsencrypt/acme.json
chmod 600 ~/docker-stack/letsencrypt/acme.json
cd ~/docker-stack || exit 1

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

echo "▶ Generando docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:

  traefik:
    image: traefik
    restart: always
    command:
      - --api.insecure=false
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

  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: \${DB_ADMIN_USER}
      POSTGRES_PASSWORD: \${DB_ADMIN_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    depends_on:
      - postgres
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${N8N_DB}
      - DB_POSTGRESDB_USER=\${N8N_DB_USER}
      - DB_POSTGRESDB_PASSWORD=\${N8N_DB_PASSWORD}
      - N8N_HOST=\${N8N_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${N8N_DOMAIN}/
      - GENERIC_TIMEZONE=\${TIMEZONE}
    volumes:
      - ./n8n/local-files:/files
      - n8n_data:/home/node/.n8n
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(\`\${N8N_DOMAIN}\`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.entrypoints=websecure
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge

  ghost:
    image: ghost:latest
    restart: always
    depends_on:
      - postgres
    environment:
      database__client: postgres
      database__connection__host: postgres
      database__connection__user: \${GHOST_DB_USER}
      database__connection__password: \${GHOST_DB_PASSWORD}
      database__connection__database: \${GHOST_DB}
      url: https://\${GHOST_DOMAIN}
      TZ: \${TIMEZONE}
    volumes:
      - ghost_content:/var/lib/ghost/content
    labels:
      - traefik.enable=true
      - traefik.http.routers.ghost.rule=Host(\`\${GHOST_DOMAIN}\`)
      - traefik.http.routers.ghost.tls=true
      - traefik.http.routers.ghost.entrypoints=websecure
      - traefik.http.routers.ghost.tls.certresolver=mytlschallenge

volumes:
  ghost_content:
  n8n_data:
  postgres_data:
EOF

echo "▶ Levantando la pila con Docker Compose..."
sudo docker compose up -d

echo ""
echo "✅ ¡Todo está corriendo con éxito!"
echo "🌐 n8n:   https://${N8N_DOMAIN}"
echo "🌐 Ghost: https://${GHOST_DOMAIN}"
