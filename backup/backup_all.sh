#!/bin/bash
set -e

# === CONFIGURACIÓN ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$SCRIPT_DIR/backups"
BACKUP_N8N_DIR="$BACKUP_DIR/backups_n8n"
BACKUP_GHOST_DIR="$BACKUP_DIR/backups_ghost"

mkdir -p "$BACKUP_N8N_DIR"
mkdir -p "$BACKUP_GHOST_DIR"

# === FUNCIÓN TELEGRAM ===
send_telegram() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" \
    -d parse_mode="Markdown"
}

# === BACKUP N8N ===
echo "📦 Iniciando backup de n8n..."
ENV_N8N="$SCRIPT_DIR/../n8n/.env"
if [ ! -f "$ENV_N8N" ]; then
  echo "❌ .env de n8n no encontrado."
else
  export $(grep -v '^#' "$ENV_N8N" | xargs)

  if docker compose -f "$SCRIPT_DIR/../n8n/docker-compose.yml" ps | grep -q postgres_n8n; then
    TS=$(date +"%Y%m%d_%H%M%S")
    OUTFILE="$BACKUP_N8N_DIR/n8n_backup_$TS.sql"

    if docker compose -f "$SCRIPT_DIR/../n8n/docker-compose.yml" exec -T postgres_n8n pg_dump -U "$DB_USER" "$DB_NAME" > "$OUTFILE"; then
      SIZE=$(du -h "$OUTFILE" | cut -f1)
      MSG="✅ *Backup exitoso de n8n*\n📁 Archivo: \`$OUTFILE\`\n💾 Tamaño: *$SIZE*\n📅 Fecha: *$TS*"
      echo -e "$MSG"
      send_telegram "$MSG"
    else
      MSG="❌ *Backup de n8n falló durante pg_dump.*"
      echo "$MSG"
      send_telegram "$MSG"
    fi

    # Rotar backups
    ls -tp "$BACKUP_N8N_DIR"/n8n_backup_*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --
  else
    MSG="❌ *Backup n8n falló:* Contenedor postgres_n8n no está corriendo."
    echo "$MSG"
    send_telegram "$MSG"
  fi
fi

# === BACKUP GHOST ===
echo "📦 Iniciando backup de Ghost..."
ENV_GHOST="$SCRIPT_DIR/../ghost/.env"
if [ ! -f "$ENV_GHOST" ]; then
  echo "❌ .env de Ghost no encontrado."
else
  export $(grep -v '^#' "$ENV_GHOST" | xargs)

  MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep ghost_db | head -n 1)
  if [ -z "$MYSQL_CONTAINER" ]; then
    MSG="❌ *Backup Ghost falló:* Contenedor ghost_db no está corriendo."
    echo "$MSG"
    send_telegram "$MSG"
  else
    TS=$(date +"%Y%m%d_%H%M%S")
    DB_BACKUP="$BACKUP_GHOST_DIR/ghost_db_backup_$TS.sql"
    CONTENT_BACKUP="$BACKUP_GHOST_DIR/ghost_content_backup_$TS.tar.gz"

    # Backup MySQL
    if docker exec "$MYSQL_CONTAINER" mysqldump -u"$GHOST_DB_USER" -p"$GHOST_DB_PASSWORD" "$GHOST_DB_NAME" > "$DB_BACKUP"; then
      echo "✅ Backup base de datos Ghost exitoso."
    else
      MSG="❌ *Backup Ghost falló durante mysqldump.*"
      echo "$MSG"
      send_telegram "$MSG"
    fi

    # Backup contenido Ghost
    if docker run --rm \
      -v ghost_content:/ghost_content \
      -v "$BACKUP_GHOST_DIR":/backup \
      alpine tar -czf /backup/"ghost_content_backup_$TS.tar.gz" -C /ghost_content .; then
      echo "✅ Backup contenido Ghost exitoso."
    else
      MSG="❌ *Backup Ghost falló al comprimir contenido.*"
      echo "$MSG"
      send_telegram "$MSG"
    fi

    DB_SIZE=$(du -h "$DB_BACKUP" | cut -f1)
    CONTENT_SIZE=$(du -h "$CONTENT_BACKUP" | cut -f1)
    MSG="✅ *Backup exitoso de Ghost*\n📦 DB: \`ghost_db_backup_$TS.sql\` (*$DB_SIZE*)\n🗂 Content: \`ghost_content_backup_$TS.tar.gz\` (*$CONTENT_SIZE*)\n📅 Fecha: *$TS*"
    echo -e "$MSG"
    send_telegram "$MSG"

    # Rotar backups
    ls -tp "$BACKUP_GHOST_DIR"/ghost_db_backup_*.sql | grep -v '/$' | tail -n +11 | xargs -r rm --
    ls -tp "$BACKUP_GHOST_DIR"/ghost_content_backup_*.tar.gz | grep -v '/$' | tail -n +11 | xargs -r rm --
  fi
fi

echo "✅ Todos los backups completados."
