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

log "Richiedo certificati Let's Encrypt via webroot..."
# Richiede che 80 sia raggiungibile e che i DNS puntino al server.
echo "${NGINX_WEBROOT_DIR}  esiste e ha i permessi corretti."
echo "${LETSENCRYPT_EMAIL} è l'email di contatto per Let's Encrypt."
echo "${ODOO_DOMAIN} ${N8N_DOMAIN} sono i domini per cui richiedo i certificati."


# certbot certonly --webroot \
#   -w "${NGINX_WEBROOT_DIR}" \
#   -m "${LETSENCRYPT_EMAIL}" \
#   --agree-tos --no-eff-email --non-interactive \
#   -d "${ODOO_DOMAIN}" \
#   -d "${N8N_DOMAIN}"

log "Copio certificati in ${NGINX_LE_DIR} (per mount read-only nel container nginx)..."
mkdir -p "${NGINX_LE_DIR}"
rsync -a /etc/letsencrypt/ "${NGINX_LE_DIR}/"

log "Rigenero conf nginx in HTTPS..."
render_template "${ROOT_DIR}/templates/nginx/odoo.https.conf.tpl" "${NGINX_CONFD_DIR}/odoo.conf"
render_template "${ROOT_DIR}/templates/nginx/n8n.https.conf.tpl"  "${NGINX_CONFD_DIR}/n8n.conf"

log "Reload container nginx-proxy (systemd)..."
systemctl restart container-nginx-proxy.service || {
  log "WARN: restart via systemd fallito, provo podman restart"
  podman restart nginx-proxy || true
}

log "TLS abilitato."
