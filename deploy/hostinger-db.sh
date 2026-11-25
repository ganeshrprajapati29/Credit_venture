#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Give the Hostinger-hosted API access to the Credit Ventures database on this VPS.
#
# SAFE for servers with other projects:
#   - does NOT change the existing MongoDB (no bindIp / auth changes)
#   - starts a separate, password-protected MongoDB in Docker on its own port
#   - copies the credit_ventures database into it and points the VPS API to it too,
#     so the VPS API and the Hostinger API share the same data
#
# Usage (as root, on the VPS):
#   cd /opt/credit-ventures && git pull && bash deploy/hostinger-db.sh
# Optional:
#   HOSTINGER_IP=1.2.3.4   only this IP may connect to the database port
#   DB_PORT=27019          public port for the database (default: first free from 27019)
# ---------------------------------------------------------------------------
set -euo pipefail

log() { echo -e "\n\033[1;34m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m!! $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m" >&2; exit 1; }
port_used() { ss -ltnH "( sport = :$1 )" 2>/dev/null | grep -q .; }

[ "$(id -u)" -eq 0 ] || die "Please run as root (sudo)."

DB_NAME=credit_ventures
CONTAINER=cv-mongo-public
STATE=/root/.cv-mongo-public.env
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/backend/.env"

# ------------------------------------------------------------------ current database
OLD_URI=""
[ -f "$ENV_FILE" ] && OLD_URI="$(grep -E '^MONGO_URI=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)"
[ -n "$OLD_URI" ] || OLD_URI="mongodb://127.0.0.1:27017/$DB_NAME"

# ------------------------------------------------------------------ docker
if ! command -v docker >/dev/null; then
  log "Installing Docker"
  apt-get update -y || true
  apt-get install -y docker.io || die "Could not install Docker."
fi
systemctl enable --now docker >/dev/null 2>&1 || true

# ------------------------------------------------------------------ credentials (kept between runs)
if [ -f "$STATE" ]; then
  # shellcheck disable=SC1090
  . "$STATE"
else
  ROOT_PASS="$(openssl rand -hex 24)"
  APP_PASS="$(openssl rand -hex 20)"
  if [ -z "${DB_PORT:-}" ]; then
    DB_PORT=27019
    while port_used "$DB_PORT"; do DB_PORT=$((DB_PORT + 1)); done
  fi
  umask 077
  printf 'ROOT_PASS=%s\nAPP_PASS=%s\nDB_PORT=%s\n' "$ROOT_PASS" "$APP_PASS" "$DB_PORT" > "$STATE"
fi

# ------------------------------------------------------------------ separate MongoDB with password
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  log "Starting a separate password-protected MongoDB on port $DB_PORT"
  docker run -d --name "$CONTAINER" --restart unless-stopped \
    -p "0.0.0.0:${DB_PORT}:27017" -v cv-mongo-public:/data/db \
    -e MONGO_INITDB_ROOT_USERNAME=cvroot -e MONGO_INITDB_ROOT_PASSWORD="$ROOT_PASS" \
    mongo:8 >/dev/null
fi
docker start "$CONTAINER" >/dev/null 2>&1 || true

# ADMIN_URI: from the VPS host (published port) · IN_URI: inside the container (always 27017)
ADMIN_URI="mongodb://cvroot:${ROOT_PASS}@127.0.0.1:${DB_PORT}/?authSource=admin"
IN_URI="mongodb://cvroot:${ROOT_PASS}@127.0.0.1:27017/?authSource=admin"
log "Waiting for MongoDB"
for _ in $(seq 1 60); do
  docker exec "$CONTAINER" mongosh --quiet "$IN_URI" --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 && break
  sleep 2
done
docker exec "$CONTAINER" mongosh --quiet "$IN_URI" --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 \
  || { docker logs --tail 30 "$CONTAINER"; die "MongoDB container did not start."; }

# app user (read/write on credit_ventures only)
docker exec "$CONTAINER" mongosh --quiet "$IN_URI" --eval "
const a=db.getSiblingDB('admin');
if(!a.getUser('cvapp')) a.createUser({user:'cvapp',pwd:'${APP_PASS}',roles:[{role:'readWrite',db:'${DB_NAME}'}]});
else a.updateUser('cvapp',{pwd:'${APP_PASS}'});" >/dev/null
echo "  Database user 'cvapp' ready"

# ------------------------------------------------------------------ copy existing data (only if the new DB is empty)
COUNT="$(docker exec "$CONTAINER" mongosh --quiet "$IN_URI" --eval "db.getSiblingDB('${DB_NAME}').getCollectionNames().length")"
case "$OLD_URI" in *":${DB_PORT}/"*) COUNT=1 ;; esac  # already migrated earlier
if [ "${COUNT:-0}" = "0" ]; then
  log "Copying existing '$DB_NAME' data from the current MongoDB"
  if docker run --rm --network host mongo:8 sh -c \
      "mongodump --uri='${OLD_URI}' --archive --quiet | mongorestore --uri='${ADMIN_URI}' --archive --quiet --nsInclude='${DB_NAME}.*'"; then
    echo "  Data copied"
  else
    warn "Could not copy old data (fresh database will be used – the API creates defaults on first start)"
  fi
else
  echo "  Database already has data – not copying again"
fi

LOCAL_URI="mongodb://cvapp:${APP_PASS}@127.0.0.1:${DB_PORT}/${DB_NAME}?authSource=admin"

# ------------------------------------------------------------------ point the VPS API to the same database
if [ -f "$ENV_FILE" ] && command -v pm2 >/dev/null && pm2 describe credit-ventures-api >/dev/null 2>&1; then
  log "Pointing the VPS API to the shared database"
  cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%s)"
  sed -i "s#^MONGO_URI=.*#MONGO_URI=${LOCAL_URI}#" "$ENV_FILE"
  pm2 restart credit-ventures-api --update-env >/dev/null && pm2 save >/dev/null
  echo "  VPS API restarted (other PM2 apps untouched)"
fi

# ------------------------------------------------------------------ optional: only allow the Hostinger IP
if [ -n "${HOSTINGER_IP:-}" ]; then
  log "Allowing only $HOSTINGER_IP on port $DB_PORT"
  iptables -D DOCKER-USER -p tcp -m conntrack --ctorigdstport "$DB_PORT" ! -s "$HOSTINGER_IP" -j DROP 2>/dev/null || true
  iptables -I DOCKER-USER -p tcp -m conntrack --ctorigdstport "$DB_PORT" ! -s "$HOSTINGER_IP" -j DROP
fi
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow "${DB_PORT}/tcp" >/dev/null || true
fi

# ------------------------------------------------------------------ result
PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
REMOTE_URI="mongodb://cvapp:${APP_PASS}@${PUBLIC_IP}:${DB_PORT}/${DB_NAME}?authSource=admin"

docker exec "$CONTAINER" mongosh --quiet "mongodb://cvapp:${APP_PASS}@${PUBLIC_IP}:${DB_PORT}/${DB_NAME}?authSource=admin" \
  --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 \
  && echo -e "\n\033[1;32mPublic connection test OK\033[0m" \
  || warn "Public connection test failed – open TCP port ${DB_PORT} in your VPS provider firewall (hPanel → VPS → Firewall)."

echo -e "\n\033[1;32m==================== DONE ====================\033[0m"
echo "Put this in Hostinger → Node.js app → Environment variables → MONGO_URI, then Restart:"
echo
echo "  ${REMOTE_URI}"
echo
echo "Then open: https://<your-hostinger-domain>/api/v1/health  →  \"status\":\"ok\""
