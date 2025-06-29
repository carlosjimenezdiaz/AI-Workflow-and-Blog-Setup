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

BACKUP_DIR="$SCRIPT_DIR/backup"
mkdir -p "$BACKUP_DIR"

send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" \
    -d parse_mode="Markdown"
}

# Detectar contenedor MySQL
MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep ghost_db | head -n 1)
if [ -z "$MYSQL_CONTAINER" ]; then
  MSG="❌ *Backup Ghost falló:* Contenedor ghost_db no está corriendo."
  echo "$MSG"
  send_telegram "$MSG"
  exit 1
fi

# Fecha y nombres
TS=$(date +"%Y%m%d_%H%M%S")
DB_BACKUP="$BACKUP_DIR/ghost_db_backup_$TS.sql"
CONTENT_BACKUP="$BACKUP_DIR/ghost_content_backup_$TS.tar.gz"

# Backup MySQL
if docker exec "$MYSQL_CONTAINER" mysqldump -u"$GHOST_DB_USER" -p"$GHOST_DB_PASSWORD" "$GHOST_DB_NAME" > "$DB_BACKUP"; then
  echo "✅ Backup base de datos exitoso."
else
  MSG="❌ *Backup Ghost falló durante mysqldump.*"
  echo "$MSG"
  send_telegram "$MSG"
  exit 1
fi

# Backup de volumen ghost_content
if docker run --rm \
  -v ghost_content:/ghost_content \
  -v "$BACKUP_DIR":/backup \
  alpine tar -czf /backup/"ghost_content_backup_$TS.tar.gz" -C /ghost_content .; then
  echo "✅ Backup de contenido exitoso."
else
  MSG="❌ *Backup Ghost falló al comprimir contenido.*"
  echo "$MSG"
  send_telegram "$MSG"
  exit 1
fi

# Enviar notificación a Telegram
DB_SIZE=$(du -h "$DB_BACKUP" | cut -f1)
CONTENT_SIZE=$(du -h "$CONTENT_BACKUP" | cut -f1)
MSG="✅ *Backup exitoso de Ghost*\n📦 DB: \`ghost_db_backup_$TS.sql\` (*$DB_SIZE*)\n🗂 Content: \`ghost_content_backup_$TS.tar.gz\` (*$CONTENT_SIZE*)\n📅 Fecha: *$TS*"
send_telegram "$MSG"
echo -e "$MSG"

# Rotar backups: mantener últimos 10 archivos por tipo
ls -tp "$BACKUP_DIR"/ghost_db_backup_*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --
ls -tp "$BACKUP_DIR"/ghost_content_backup_*.tar.gz | grep -v '/$' | tail -n +11 | xargs -r rm --

echo "✅ Todo completado."

