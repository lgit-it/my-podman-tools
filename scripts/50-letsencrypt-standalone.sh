#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd certbot

if [[ "${ENABLE_LETSENCRYPT}" != "1" ]]; then
  echo "ENABLE_LETSENCRYPT!=1: non faccio nulla." >&2
  exit 0
fi

log "Richiedo certificati Let's Encrypt via standalone mode..."
# Richiede che 80 sia raggiungibile e che i DNS puntino al server.
echo "Email di contatto: ${LETSENCRYPT_EMAIL}"
echo "Domini: ${ODOO_DOMAIN} ${N8N_DOMAIN}"

log "Fermo container nginx (se in esecuzione) per liberare porta 80..."
podman stop nginx 2>/dev/null || true

log "Eseguo certbot in standalone mode..."
certbot certonly --standalone \
  -m "${LETSENCRYPT_EMAIL}" \
  --agree-tos --no-eff-email --non-interactive \
  -d "${ODOO_DOMAIN}" \
  -d "${N8N_DOMAIN}"

log "Copio certificati in ${NGINX_LE_DIR} (per mount read-only nel container nginx)..."
mkdir -p "${NGINX_LE_DIR}"
rsync -a /etc/letsencrypt/ "${NGINX_LE_DIR}/"

log "Rigenero conf nginx in HTTPS..."
render_template "${ROOT_DIR}/templates/nginx/odoo.https.conf.tpl" "${NGINX_CONFD_DIR}/odoo.conf"
render_template "${ROOT_DIR}/templates/nginx/n8n.https.conf.tpl"  "${NGINX_CONFD_DIR}/n8n.conf"

log "Riavvio container nginx..."
podman start nginx 2>/dev/null || {
  log "WARN: nginx non avviato. Avvialo manualmente con: podman start nginx"
}

log "TLS abilitato. Certificati in ${NGINX_LE_DIR}"
