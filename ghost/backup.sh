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

TS=$(date +"%Y%m%d_%H%M%S")
OUTFILE="$BACKUP_DIR/ghost_backup_$TS.sql"

if docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T ghost_db \
  mysqldump -u"$GHOST_DB_USER" -p"$GHOST_DB_PASSWORD" "$GHOST_DB_NAME" > "$OUTFILE"; then
  echo "✅ Backup exitoso: $OUTFILE"
else
  echo "❌ Error al generar backup"
  exit 1
fi

ls -tp "$BACKUP_DIR"/*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --

echo "✅ Backup completado y backups antiguos eliminados."
