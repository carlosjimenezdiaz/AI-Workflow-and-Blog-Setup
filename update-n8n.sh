#!/bin/bash

echo "🚀 Actualizando solo el servicio de n8n..."

STACK_DIR=~/docker-stack  # Ajusta si tu stack está en otra ruta
cd "$STACK_DIR" || { echo "❌ No se encuentra el directorio $STACK_DIR"; exit 1; }

# ====== Backup automático del volumen n8n_data ======
BACKUP_DIR="$STACK_DIR/backups"
mkdir -p "$BACKUP_DIR"

echo "🗂️ Realizando backup del volumen n8n_data..."
docker run --rm \
  -v n8n_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine \
  tar czf /backup/n8n_backup_$(date +%F_%H-%M-%S).tar.gz -C /data .

echo "✅ Backup creado en: $BACKUP_DIR"

# ====== Actualización de n8n ======
echo "📦 Descargando la última imagen de n8n..."
docker pull n8nio/n8n:latest

echo "♻️ Reconstruyendo y reiniciando el contenedor de n8n..."
docker compose up -d --no-deps --build --force-recreate n8n

echo "✅ n8n ha sido actualizado y reiniciado correctamente sin perder datos."
