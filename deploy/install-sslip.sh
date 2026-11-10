#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Credit Ventures – one-command install using free sslip.io domains.
#   api.<VPS-IP>.sslip.io    -> backend API
#   admin.<VPS-IP>.sslip.io  -> admin panel
# Usage on a fresh Ubuntu VPS (as root):
#   bash install-sslip.sh
# Private repo? run with a GitHub token:  GIT_TOKEN=ghp_xxx bash install-sslip.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REPO="github.com/ganeshrprajapati29/Credit_venture.git"
DIR=/opt/credit-ventures

if [ "$(id -u)" -ne 0 ]; then echo "Run as root: sudo bash $0" >&2; exit 1; fi

apt-get update -y && apt-get install -y git curl

IP="${VPS_IP:-$(curl -4 -fsS https://api.ipify.org || curl -4 -fsS https://ifconfig.me)}"
if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Could not detect public IPv4. Run again with VPS_IP=1.2.3.4" >&2; exit 1
fi
API_DOMAIN="api.${IP}.sslip.io"
ADMIN_DOMAIN="admin.${IP}.sslip.io"
echo "VPS IP: $IP"
echo "API:    $API_DOMAIN"
echo "Admin:  $ADMIN_DOMAIN"

URL="https://${REPO}"
[ -n "${GIT_TOKEN:-}" ] && URL="https://${GIT_TOKEN}@${REPO}"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$URL" "$DIR" || { echo "Clone failed. If the repo is private run: GIT_TOKEN=<github token> bash $0" >&2; exit 1; }
fi

cd "$DIR"
API_DOMAIN="$API_DOMAIN" ADMIN_DOMAIN="$ADMIN_DOMAIN" ADMIN_LOGIN_EMAIL="${ADMIN_LOGIN_EMAIL:-admin@creditventures.in}" \
  bash deploy/setup-vps.sh

cat <<MSG

==================================================================
 Credit Ventures is live
   API health : https://${API_DOMAIN}/api/v1/health
   Admin panel: https://${ADMIN_DOMAIN}
   Admin login: see the email/password printed above (also in ${DIR}/backend/.env)

 APK API_URL  : https://${API_DOMAIN}/api/v1
 Put this in GitHub -> Settings -> Secrets and variables -> Actions
 -> Variables -> API_URL, then re-run "Build Android APK".
==================================================================
MSG
