#!/bin/bash

echo "🚀 Updating your Docker stack (n8n, Traefik, DBs...) without downtime or data loss..."

# Ruta del stack
STACK_DIR=~/n8n_stack
cd "$STACK_DIR" || { echo "❌ Stack directory not found: $STACK_DIR"; exit 1; }

# 1. Descargar las últimas imágenes
echo "📦 Pulling latest Docker images..."
docker compose pull

# 2. Levantar los servicios con reconstrucción (sin bajar los contenedores antes)
echo "♻️ Rebuilding and restarting containers..."
docker compose up -d --build

echo "✅ Update complete. Services are running."
