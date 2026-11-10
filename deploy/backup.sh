#!/usr/bin/env bash
# Daily backup of the Credit Ventures database + uploaded documents. Keeps 14 days.
set -euo pipefail
ENV_FILE="${ENV_FILE:-/opt/credit-ventures/backend/.env}"
DEST=/var/backups/credit-ventures
STAMP=$(date +%Y%m%d-%H%M)
mkdir -p "$DEST"
URI="$(grep -E '^MONGO_URI=' "$ENV_FILE" | cut -d= -f2-)"

if command -v mongodump >/dev/null; then
  mongodump --quiet --uri="$URI" --archive="$DEST/db-$STAMP.gz" --gzip
elif command -v docker >/dev/null && docker inspect credit-ventures-mongo >/dev/null 2>&1; then
  docker exec credit-ventures-mongo mongodump --quiet --db credit_ventures --archive --gzip > "$DEST/db-$STAMP.gz"
else
  echo "$(date) mongodump not found – database backup skipped"
fi
tar -czf "$DEST/uploads-$STAMP.tar.gz" -C /var/www/credit-ventures uploads
chmod 600 "$DEST"/*-"$STAMP".* 2>/dev/null || true
find "$DEST" -type f -mtime +14 -delete
echo "$(date) backup ok: $STAMP"
