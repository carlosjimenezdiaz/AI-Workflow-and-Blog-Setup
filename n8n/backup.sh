#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env no encontrado"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

BACKUP_DIR="$SCRIPT_DIR/backups"
mkdir -p "$BACKUP_DIR"

send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" \
    -d parse_mode="Markdown"
}

# Verificar contenedor
if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" ps | grep -q postgres_n8n; then
  MSG="❌ *Backup n8n falló:* Contenedor postgres_n8n no está corriendo."
  echo "$MSG"
  send_telegram "$MSG"
  exit 1
fi

TS=$(date +"%Y%m%d_%H%M%S")
OUTFILE="$BACKUP_DIR/n8n_backup_$TS.sql"

# Hacer backup
if docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T postgres_n8n pg_dump -U "$DB_USER" "$DB_NAME" > "$OUTFILE"; then
  SIZE=$(du -h "$OUTFILE" | cut -f1)
  MSG="✅ *Backup exitoso de n8n*\n📁 Archivo: \`$OUTFILE\`\n💾 Tamaño: *$SIZE*\n📅 Fecha: *$TS*"
  echo -e "$MSG"
  send_telegram "$MSG"
else
  MSG="❌ *Backup de n8n falló durante pg_dump.*"
  echo "$MSG"
  send_telegram "$MSG"
  exit 1
fi

# Limpiar backups viejos
ls -tp "$BACKUP_DIR"/*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --

echo "✅ Todo completado."
