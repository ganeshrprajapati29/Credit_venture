#!/usr/bin/env bash
# Daily backup of MongoDB + uploaded documents. Keeps the last 14 days.
set -euo pipefail
DEST=/var/backups/credit-ventures
STAMP=$(date +%Y%m%d-%H%M)
mkdir -p "$DEST"
mongodump --quiet --db credit_ventures --archive="$DEST/db-$STAMP.gz" --gzip
tar -czf "$DEST/uploads-$STAMP.tar.gz" -C /var/www/credit-ventures uploads
chmod 600 "$DEST"/*-"$STAMP".*
find "$DEST" -type f -mtime +14 -delete
echo "$(date) backup ok: $STAMP"
