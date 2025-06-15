#!/bin/bash

echo "🚀 Actualizando n8n..."

STACK_DIR=~/docker-stack  # Cambia si tu stack está en otro lado
cd "$STACK_DIR" || { echo "❌ No se encuentra $STACK_DIR"; exit 1; }

echo "📦 Descargando última imagen de n8n..."
docker pull n8nio/n8n:latest

echo "♻️ Reiniciando solo el servicio de n8n..."
docker compose up -d --no-deps --build --force-recreate n8n

echo "✅ n8n ha sido actualizado y reiniciado correctamente."
