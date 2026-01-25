#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd podman

log "Rimozione container esistenti (se presenti)..."
podman stop  postgres odoo n8n  nginx 
podman rm -f postgres odoo n8n  nginx  >/dev/null 2>&1 || true

# Porte bindate su localhost se BIND_LOCALHOST=1
if [[ "${BIND_LOCALHOST:-1}" == "1" ]]; then
  PG_BIND="127.0.0.1:${POSTGRES_HOST_PORT}:5432"
  ODOO_BIND="127.0.0.1:${ODOO_HOST_PORT}:8069"
  ODOO_LP_BIND="127.0.0.1:${ODOO_LONGPOLL_HOST_PORT}:8072"
  ODOO_DEBUG_BIND="127.0.0.1:${ODOO_DEBUG_HOST_PORT}:8678"
  N8N_BIND="127.0.0.1:${N8N_HOST_PORT}:5678"
else
  PG_BIND="${POSTGRES_HOST_PORT}:5432"
  ODOO_BIND="${ODOO_HOST_PORT}:8069"
  ODOO_LP_BIND="${ODOO_LONGPOLL_HOST_PORT}:8072"
  ODOO_DEBUG_BIND="${ODOO_DEBUG_HOST_PORT}:8678"
  N8N_BIND="${N8N_HOST_PORT}:5678"
fi

log "Creazione container Postgres..."
podman create \
  --name postgres \
  --network "${PODMAN_NET}" \
  --hostname postgres \
  --network-alias postgres \
  -p "${PG_BIND}" \
  --env-file "${SECRETS_DIR}/postgres.env" \
  -v "${PG_DATA_DIR}:/var/lib/postgresql/data${VOL_LBL}" \
  -v "${PG_INIT_DIR}:/docker-entrypoint-initdb.d${VOL_LBL}" \
  -v "${PG_CONF_DIR}:/etc/postgresql${VOL_LBL}" \
  "${POSTGRES_IMAGE}" \
  -c "config_file=/etc/postgresql/postgresql.conf" \
  -c "hba_file=/etc/postgresql/pg_hba.conf"

log "Creazione container Odoo..."
podman create \
  --name odoo \
  --network "${PODMAN_NET}" \
  --hostname odoo \
  --network-alias odoo \
  -p "${ODOO_BIND}" \
  -p "${ODOO_LP_BIND}" \
  -p "${ODOO_DEBUG_BIND}" \
  -v "${ODOO_DATA_DIR}:/var/lib/odoo${VOL_LBL}" \
  -v "${ODOO_LOG_DIR}:/var/log/odoo${VOL_LBL}" \
  -v "${ODOO_BACKUP_DIR}:/var/lib/odoo/backups${VOL_LBL}" \
  -v "${ODOO_STD_ADDONS_DIR}:/mnt/extra-addons${VOL_LBL}" \
  -v "${ODOO_CUST_ADDONS_DIR}:/mnt/custom-addons${VOL_LBL}" \
  -v "${ODOO_CONF_DIR}/odoo.conf:/etc/odoo/odoo.conf${VOL_LBL}" \
  "local/odoo-custom:${ODOO_BRANCH}"

log "Creazione container n8n..."
podman create \
  --name n8n \
  --network "${PODMAN_NET}" \
  -p "${N8N_BIND}" \
  --env-file "${SECRETS_DIR}/n8n.env" \
  -v "${N8N_DATA_DIR}:/home/node/.n8n${VOL_LBL}" \
  "${N8N_IMAGE}"

log "Creazione container Nginx reverse-proxy..."
# Nginx è esposto su 80/443 verso Internet; i backend restano su localhost.
podman create \
  --name  nginx\
  --network "${PODMAN_NET}" \
  -p "${NGINX_HTTP_PORT}:80" \
  -p "${NGINX_HTTPS_PORT}:443" \
  -v "${NGINX_CONFD_DIR}:/etc/nginx/conf.d${VOL_LBL}" \
  -v "${NGINX_SNIPPETS_DIR}:/etc/nginx/snippets${VOL_LBL}" \
  -v "${NGINX_WEBROOT_DIR}:/var/www/certbot${VOL_LBL}" \
  -v "${NGINX_LE_DIR}:/etc/letsencrypt${VOL_LBL}" \
  "local/nginx-proxy:latest"

log "Container creati."
log "Avvio manuale (se vuoi testare prima di systemd): podman start postgres odoo n8n nginx"
