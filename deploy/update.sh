#!/usr/bin/env bash
# Pull the latest code and redeploy API + admin.
# Usage (as root, from repo root):  sudo API_DOMAIN=api.example.com bash deploy/update.sh
set -euo pipefail
: "${API_DOMAIN:?Set API_DOMAIN, e.g. api.example.com}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN_WEB=/var/www/credit-ventures/admin

cd "$REPO_DIR"
git pull --ff-only

cd backend
npm ci --omit=dev
chown -R creditv:creditv "$REPO_DIR/backend"

cd ../admin
npm ci
VITE_API_URL="https://${API_DOMAIN}/api/v1" npm run build
rm -rf "${ADMIN_WEB:?}"/*
cp -r dist/* "$ADMIN_WEB"/

pm2 reload credit-ventures-api
echo "Updated. Health: https://${API_DOMAIN}/api/v1/health"
