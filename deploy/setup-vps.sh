#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Credit Ventures – one-time VPS setup (Ubuntu 22.04 / 24.04)
#
# Installs Node.js 22, MongoDB 8, Nginx, PM2 and Certbot, then deploys the
# backend API and the admin panel with HTTPS.
#
# Usage (as root, from the repository root on the VPS):
#   sudo API_DOMAIN=api.example.com ADMIN_DOMAIN=admin.example.com \
#        LETSENCRYPT_EMAIL=you@example.com bash deploy/setup-vps.sh
#
# Point both DNS A records to the VPS IP before running (needed for SSL).
# Set SKIP_SSL=1 to skip certbot (e.g. while DNS is not ready yet).
# ---------------------------------------------------------------------------
set -euo pipefail

: "${API_DOMAIN:?Set API_DOMAIN, e.g. api.example.com}"
: "${ADMIN_DOMAIN:?Set ADMIN_DOMAIN, e.g. admin.example.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
SKIP_SSL="${SKIP_SSL:-0}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT=/var/www/credit-ventures
UPLOAD_DIR="$APP_ROOT/uploads"
ADMIN_WEB="$APP_ROOT/admin"
APP_USER=creditv

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

log "Installing base packages"
apt-get update -y
apt-get install -y curl gnupg ca-certificates lsb-release nginx ufw git

if ! command -v node >/dev/null || ! node -v | grep -qE '^v(2[0-9])'; then
  log "Installing Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! command -v mongod >/dev/null; then
  log "Installing MongoDB 8.0"
  CODENAME="$(lsb_release -cs)"
  curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/8.0 multiverse" \
    > /etc/apt/sources.list.d/mongodb-org-8.0.list
  apt-get update -y
  apt-get install -y mongodb-org
fi
systemctl enable --now mongod

if ! command -v pm2 >/dev/null; then
  log "Installing PM2"
  npm install -g pm2
fi

log "Creating app user and folders"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
mkdir -p "$UPLOAD_DIR" "$ADMIN_WEB" "$APP_ROOT/logs"
chown -R "$APP_USER":"$APP_USER" "$UPLOAD_DIR" "$APP_ROOT/logs"
chmod 750 "$UPLOAD_DIR"

log "Installing backend dependencies"
cd "$REPO_DIR/backend"
npm ci --omit=dev

ADMIN_LOGIN_EMAIL="${ADMIN_LOGIN_EMAIL:-admin@${ADMIN_DOMAIN#admin.}}"
if [ ! -f .env ]; then
  log "Creating backend/.env with fresh secrets"
  ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)@Cv1"
  cat > .env <<ENV
NODE_ENV=production
PORT=5000
MONGO_URI=mongodb://127.0.0.1:27017/credit_ventures
JWT_SECRET=$(openssl rand -hex 48)
JWT_ADMIN_SECRET=$(openssl rand -hex 48)
JWT_EXPIRES_IN=30d
JWT_ADMIN_EXPIRES_IN=12h
CORS_ORIGINS=https://${ADMIN_DOMAIN},http://${ADMIN_DOMAIN}
UPLOAD_DIR=${UPLOAD_DIR}
MAX_UPLOAD_MB=8
ADMIN_NAME=Super Admin
ADMIN_EMAIL=${ADMIN_LOGIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ENV
  chmod 600 .env
  chown "$APP_USER":"$APP_USER" .env
  echo "  First admin login: ${ADMIN_LOGIN_EMAIL} / ${ADMIN_PASSWORD}"
  echo "  (saved in backend/.env – change it after first login)"
fi

log "Building admin panel"
cd "$REPO_DIR/admin"
npm ci
VITE_API_URL="https://${API_DOMAIN}/api/v1" npm run build
rm -rf "${ADMIN_WEB:?}"/*
cp -r dist/* "$ADMIN_WEB"/

log "Configuring Nginx"
sed -e "s/__API_DOMAIN__/${API_DOMAIN}/g" -e "s/__ADMIN_DOMAIN__/${ADMIN_DOMAIN}/g" -e "s#__ADMIN_WEB__#${ADMIN_WEB}#g" \
  "$REPO_DIR/deploy/nginx.conf" > /etc/nginx/sites-available/credit-ventures.conf
ln -sf /etc/nginx/sites-available/credit-ventures.conf /etc/nginx/sites-enabled/credit-ventures.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

log "Starting API with PM2"
cd "$REPO_DIR"
chown -R "$APP_USER":"$APP_USER" "$REPO_DIR/backend"
APP_UID="$APP_USER" APP_DIR="$REPO_DIR/backend" LOG_DIR="$APP_ROOT/logs" pm2 startOrReload deploy/ecosystem.config.js --env production
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null

log "Firewall"
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null

if [ "$SKIP_SSL" != "1" ]; then
  log "Requesting SSL certificates (Let's Encrypt)"
  apt-get install -y certbot python3-certbot-nginx
  EMAIL_ARG="--register-unsafely-without-email"
  [ -n "$LETSENCRYPT_EMAIL" ] && EMAIL_ARG="-m $LETSENCRYPT_EMAIL"
  certbot --nginx --non-interactive --agree-tos $EMAIL_ARG --redirect -d "$API_DOMAIN" -d "$ADMIN_DOMAIN" || \
    echo "!! certbot failed – check DNS records, then run: certbot --nginx -d $API_DOMAIN -d $ADMIN_DOMAIN"
fi

log "Installing daily backup cron (02:30)"
install -m 750 "$REPO_DIR/deploy/backup.sh" /usr/local/bin/credit-ventures-backup
echo "30 2 * * * root /usr/local/bin/credit-ventures-backup >> /var/log/credit-ventures-backup.log 2>&1" > /etc/cron.d/credit-ventures-backup

log "Done!"
echo "  API:    https://${API_DOMAIN}/api/v1/health"
echo "  Admin:  https://${ADMIN_DOMAIN}"
echo "  Build the APK with API_URL=https://${API_DOMAIN}/api/v1"
