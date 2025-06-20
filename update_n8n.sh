#!/bin/bash

set -e

echo "🔄 Starting safe update for n8n..."

# Load .env file from current directory
if [[ -f .env ]]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ .env file not found!"
  exit 1
fi

# Timestamp for filenames
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Backup file name
BACKUP_FILE="n8n_backup_${TIMESTAMP}.sql"

# Step 1: Backup PostgreSQL database
echo "🗄️  Backing up PostgreSQL database..."
docker compose exec -T postgres pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"
echo "✅ Backup saved as $BACKUP_FILE"

# Step 2: Pull latest n8n image
echo "⬇️  Pulling latest n8n image..."
docker pull n8nio/n8n:latest

# Step 3: Restart Docker Compose stack
echo "♻️  Restarting containers..."
docker compose down
docker compose up -d

# Step 4: Restore backup (just in case the DB was recreated or cleared)
echo "♻️  Restoring backup into $DB_NAME..."
cat "$BACKUP_FILE" | docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME"
echo "✅ Backup restored"

echo "🚀 n8n successfully updated and available at: https://$DOMAIN"
