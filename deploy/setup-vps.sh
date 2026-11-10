#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Credit Ventures – VPS setup that is SAFE for servers already running other
# projects (Ubuntu 22.04 / 24.04 / 26.04).
#
# What it will NOT do:
#   - remove or edit other Nginx sites (only adds credit-ventures.conf)
#   - enable/alter the firewall (only adds allow rules if ufw is already active)
#   - upgrade an existing Node.js, or touch other PM2 apps / MongoDB databases
#   - use a port that is already taken (API port is picked automatically)
#
# Usage (as root, from the repository root on the VPS):
#   API_DOMAIN=api.example.com ADMIN_DOMAIN=admin.example.com bash deploy/setup-vps.sh
# Optional env:
#   MONGO_URI=...        use an existing / Atlas MongoDB instead of installing one
#   API_PORT=5100        force the API port
#   LETSENCRYPT_EMAIL=.. email for SSL expiry notices
#   SKIP_SSL=1           skip certbot
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
ENV_FILE="$REPO_DIR/backend/.env"
DB_NAME=credit_ventures

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m!! $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m" >&2; exit 1; }
port_used() { ss -ltnH "( sport = :$1 )" 2>/dev/null | grep -q .; }
env_get() { [ -f "$ENV_FILE" ] && grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- || true; }

[ "$(id -u)" -eq 0 ] || die "Please run as root (sudo)."

# ------------------------------------------------------------------ packages
log "Installing base packages (only missing ones)"
apt-get update -y || warn "apt-get update reported errors – continuing"
apt-get install -y curl gnupg ca-certificates lsb-release git openssl iproute2

# Port 80 must be served by Nginx (we only add a site to it)
if ! command -v nginx >/dev/null; then
  if port_used 80; then
    die "Port 80 is used by another web server (not Nginx). Stopping so your existing sites are not affected."
  fi
  apt-get install -y nginx
fi
systemctl is-active --quiet nginx || systemctl start nginx

if ! command -v node >/dev/null; then
  log "Installing Node.js 22"
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
NODE_MAJOR="$(node -v | sed 's/^v\([0-9]*\).*/\1/')"
[ "$NODE_MAJOR" -ge 18 ] || die "Node.js $(node -v) is too old (need 18+). Upgrade it manually so other apps are not affected."
echo "Using Node.js $(node -v) (left unchanged)"

if ! command -v pm2 >/dev/null; then
  log "Installing PM2"
  npm install -g pm2
fi

# ------------------------------------------------------------------ MongoDB
MONGO_URI="${MONGO_URI:-$(env_get MONGO_URI)}"
if [ -z "$MONGO_URI" ]; then
  if port_used 27017; then
    log "Existing MongoDB found on 27017 – using a separate database '$DB_NAME'"
    MONGO_URI="mongodb://127.0.0.1:27017/$DB_NAME"
  else
    log "Installing MongoDB 8.0"
    CODENAME="$(lsb_release -cs)"
    case "$CODENAME" in jammy|noble) ;; *) warn "No MongoDB packages for '$CODENAME' yet – using the Ubuntu 24.04 (noble) build"; CODENAME=noble ;; esac
    curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/8.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-8.0.list
    apt-get update -y || true
    if apt-get install -y mongodb-org; then
      systemctl enable --now mongod
      for _ in $(seq 1 20); do port_used 27017 && break; sleep 1; done
      MONGO_URI="mongodb://127.0.0.1:27017/$DB_NAME"
    elif command -v docker >/dev/null; then
      warn "apt install failed – running MongoDB in Docker on 127.0.0.1:27018 instead"
      rm -f /etc/apt/sources.list.d/mongodb-org-8.0.list
      docker inspect credit-ventures-mongo >/dev/null 2>&1 || \
        docker run -d --name credit-ventures-mongo --restart unless-stopped \
          -p 127.0.0.1:27018:27017 -v credit-ventures-mongo:/data/db mongo:8
      for _ in $(seq 1 30); do port_used 27018 && break; sleep 1; done
      MONGO_URI="mongodb://127.0.0.1:27018/$DB_NAME"
    else
      rm -f /etc/apt/sources.list.d/mongodb-org-8.0.list
      die "Could not install MongoDB on this Ubuntu version.
  Easiest fix: create a free MongoDB Atlas cluster (https://www.mongodb.com/atlas), then run again with
  MONGO_URI='mongodb+srv://USER:PASS@cluster.xxxx.mongodb.net/$DB_NAME' bash $0"
    fi
  fi
fi

# ------------------------------------------------------------------ folders / user
log "Creating app user and folders"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
mkdir -p "$UPLOAD_DIR" "$ADMIN_WEB" "$APP_ROOT/logs"
chown -R "$APP_USER":"$APP_USER" "$UPLOAD_DIR" "$APP_ROOT/logs"
chmod 750 "$UPLOAD_DIR"

# ------------------------------------------------------------------ backend
log "Installing backend dependencies"
cd "$REPO_DIR/backend"
npm ci --omit=dev

log "Checking MongoDB connection"
MONGO_URI="$MONGO_URI" node -e "
const m=require('mongoose');
m.connect(process.env.MONGO_URI,{serverSelectionTimeoutMS:15000})
 .then(async()=>{await m.connection.db.collection('_cv_check').insertOne({ok:1});await m.connection.db.collection('_cv_check').drop();console.log('MongoDB OK');process.exit(0)})
 .catch(e=>{console.error('MongoDB connection failed:',e.message);process.exit(1)})" \
  || die "Cannot use MongoDB at $MONGO_URI. If your MongoDB needs a password, run again with MONGO_URI='mongodb://user:pass@127.0.0.1:27017/$DB_NAME?authSource=admin'"

# API port: keep the one in .env, else first free port from 5000
API_PORT="${API_PORT:-$(env_get PORT)}"
if [ -z "$API_PORT" ]; then
  API_PORT=5000
  while port_used "$API_PORT"; do API_PORT=$((API_PORT + 1)); done
fi
echo "API port: $API_PORT"

ADMIN_LOGIN_EMAIL="${ADMIN_LOGIN_EMAIL:-admin@${ADMIN_DOMAIN#admin.}}"
if [ ! -f "$ENV_FILE" ]; then
  log "Creating backend/.env with fresh secrets"
  ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-12)@Cv1"
  cat > "$ENV_FILE" <<ENV
NODE_ENV=production
PORT=${API_PORT}
MONGO_URI=${MONGO_URI}
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
  chmod 600 "$ENV_FILE"
  echo "  First admin login: ${ADMIN_LOGIN_EMAIL} / ${ADMIN_PASSWORD}"
else
  sed -i "s#^PORT=.*#PORT=${API_PORT}#; s#^MONGO_URI=.*#MONGO_URI=${MONGO_URI}#" "$ENV_FILE"
  echo "  Keeping existing backend/.env (admin login is in that file)"
fi
chown -R "$APP_USER":"$APP_USER" "$REPO_DIR/backend"

# ------------------------------------------------------------------ admin panel
log "Building admin panel"
cd "$REPO_DIR/admin"
npm ci
VITE_API_URL="https://${API_DOMAIN}/api/v1" npm run build
rm -rf "${ADMIN_WEB:?}"/*
cp -r dist/* "$ADMIN_WEB"/

# ------------------------------------------------------------------ nginx (adds one site only)
log "Adding Nginx site credit-ventures.conf"
CONF=/etc/nginx/sites-available/credit-ventures.conf
if [ -f "$CONF" ] && grep -q "managed by Certbot" "$CONF"; then
  echo "  Existing SSL config kept (only updating API port)"
  sed -i -E "s#proxy_pass http://127.0.0.1:[0-9]+;#proxy_pass http://127.0.0.1:${API_PORT};#" "$CONF"
else
  sed -e "s/__API_DOMAIN__/${API_DOMAIN}/g" -e "s/__ADMIN_DOMAIN__/${ADMIN_DOMAIN}/g" \
      -e "s#__ADMIN_WEB__#${ADMIN_WEB}#g" -e "s/__API_PORT__/${API_PORT}/g" \
      "$REPO_DIR/deploy/nginx.conf" > "$CONF"
fi
ln -sf "$CONF" /etc/nginx/sites-enabled/credit-ventures.conf
if ! nginx -t; then
  rm -f /etc/nginx/sites-enabled/credit-ventures.conf
  die "Nginx config test failed – our site was removed again, existing sites untouched."
fi
systemctl reload nginx

# ------------------------------------------------------------------ PM2 (only our app)
log "Starting API with PM2 (other PM2 apps are not touched)"
cd "$REPO_DIR"
APP_UID="$APP_USER" APP_DIR="$REPO_DIR/backend" LOG_DIR="$APP_ROOT/logs" \
  pm2 startOrReload deploy/ecosystem.config.js --env production --update-env
pm2 save
systemctl is-enabled --quiet pm2-root 2>/dev/null || pm2 startup systemd -u root --hp /root >/dev/null || true

for _ in $(seq 1 20); do curl -fsS "http://127.0.0.1:${API_PORT}/api/v1/health" >/dev/null 2>&1 && break; sleep 1; done
curl -fsS "http://127.0.0.1:${API_PORT}/api/v1/health" >/dev/null 2>&1 && echo "API is running on port ${API_PORT}" \
  || warn "API did not respond yet – check: pm2 logs credit-ventures-api"

# ------------------------------------------------------------------ firewall: only add rules if ufw is already on
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp >/dev/null && ufw allow 443/tcp >/dev/null && echo "ufw: allowed 80/443"
fi

# ------------------------------------------------------------------ SSL
if [ "$SKIP_SSL" != "1" ]; then
  log "Requesting SSL certificates (only for our two domains)"
  command -v certbot >/dev/null || apt-get install -y certbot python3-certbot-nginx
  EMAIL_ARG="--register-unsafely-without-email"
  [ -n "$LETSENCRYPT_EMAIL" ] && EMAIL_ARG="-m $LETSENCRYPT_EMAIL"
  certbot --nginx --non-interactive --agree-tos $EMAIL_ARG --redirect --cert-name credit-ventures \
    -d "$API_DOMAIN" -d "$ADMIN_DOMAIN" \
    || warn "certbot failed – site still works on http://. Retry later: certbot --nginx --cert-name credit-ventures -d $API_DOMAIN -d $ADMIN_DOMAIN"
fi

# ------------------------------------------------------------------ backups
log "Installing daily backup cron (02:30)"
install -m 750 "$REPO_DIR/deploy/backup.sh" /usr/local/bin/credit-ventures-backup
echo "30 2 * * * root ENV_FILE=$ENV_FILE /usr/local/bin/credit-ventures-backup >> /var/log/credit-ventures-backup.log 2>&1" > /etc/cron.d/credit-ventures-backup

log "Done!"
echo "  API:    https://${API_DOMAIN}/api/v1/health"
echo "  Admin:  https://${ADMIN_DOMAIN}"
echo "  APK API_URL: https://${API_DOMAIN}/api/v1"
