#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root

log "Installazione pacchetti base..."
# apt_install ca-certificates curl git jq openssl \
#   podman uidmap slirp4netns fuse-overlayfs containernetworking-plugins \
#   nginx-full \
#   certbot

apt_install ca-certificates curl git jq openssl \
  podman uidmap slirp4netns fuse-overlayfs containernetworking-plugins \
#   nginx-full \
#   certbot

log "Creazione directory persistenti in ${BASE_DIR} ..."
mkdir -p \
  "${PG_DATA_DIR}" "${PG_CONF_DIR}" "${PG_INIT_DIR}" \
  "${ODOO_BUILD_DIR}" "${ODOO_DATA_DIR}" "${ODOO_LOG_DIR}" "${ODOO_BACKUP_DIR}" "${ODOO_CONF_DIR}" \
  "${ODOO_STD_ADDONS_DIR}" "${ODOO_CUST_ADDONS_DIR}" \
  "${N8N_DATA_DIR}"\
  "${NGINX_CONFD_DIR}" "${NGINX_LOG_DIR}" "${NGINX_SNIPPETS_DIR}" "${NGINX_WEBROOT_DIR}" "${NGINX_LE_DIR}" \
  "${SECRETS_DIR}" \
  "${ROOT_DIR}/exports"

chmod 700 "${SECRETS_DIR}"
chmod 755 "${NGINX_WEBROOT_DIR}"

log "Podman network: ${PODMAN_NET}"
if ! podman network exists "${PODMAN_NET}" >/dev/null 2>&1; then
  podman network create "${PODMAN_NET}"
fi

log "Pull immagini base..."
podman pull "${POSTGRES_IMAGE}"
podman pull "${N8N_IMAGE}"
podman pull "${NGINX_IMAGE}"

log "Generazione segreti (solo se mancanti)..."

write_if_missing "${SECRETS_DIR}/postgres_super_pass.txt" "$(rand_b64)"
write_if_missing "${SECRETS_DIR}/odoo_db_pass.txt" "$(rand_b64)"
write_if_missing "${SECRETS_DIR}/n8n_db_pass.txt" "$(rand_b64)"
write_if_missing "${SECRETS_DIR}/n8n_encryption_key.txt" "$(openssl rand -hex 32)"

POSTGRES_SUPER_PASS="$(cat "${SECRETS_DIR}/postgres_super_pass.txt")"
ODOO_DB_PASS="$(cat "${SECRETS_DIR}/odoo_db_pass.txt")"
N8N_DB_PASS="$(cat "${SECRETS_DIR}/n8n_db_pass.txt")"
N8N_ENCRYPTION_KEY="$(cat "${SECRETS_DIR}/n8n_encryption_key.txt")"

export POSTGRES_SUPER_PASS ODOO_DB_PASS N8N_DB_PASS N8N_ENCRYPTION_KEY

# Protocollo n8n (http/https)
if [[ "${ENABLE_LETSENCRYPT}" == "1" ]]; then
  N8N_PROTOCOL="https"
else
  N8N_PROTOCOL="http"
fi
export N8N_PROTOCOL

log "Scrittura config Postgres/Odoo/Nginx/N8n (solo se mancanti)..."
write_if_missing "${PG_CONF_DIR}/postgresql.conf" "$(cat "${ROOT_DIR}/templates/postgres/postgresql.conf")"
write_if_missing "${PG_CONF_DIR}/pg_hba.conf" "$(cat "${ROOT_DIR}/templates/postgres/pg_hba.conf")"

if [[ ! -f "${PG_INIT_DIR}/01-init.sql" ]]; then
  render_template "${ROOT_DIR}/templates/postgres/01-init.sql.tpl" "${PG_INIT_DIR}/01-init.sql"
  chmod 600 "${PG_INIT_DIR}/01-init.sql"
fi

if [[ ! -f "${ODOO_CONF_DIR}/odoo.conf" ]]; then
  render_template "${ROOT_DIR}/templates/odoo/odoo.conf.tpl" "${ODOO_CONF_DIR}/odoo.conf"
  chmod 600 "${ODOO_CONF_DIR}/odoo.conf"
fi

# secrets env files
if [[ ! -f "${SECRETS_DIR}/postgres.env" ]]; then
  render_template "${ROOT_DIR}/templates/secrets/postgres.env.tpl" "${SECRETS_DIR}/postgres.env"
  chmod 600 "${SECRETS_DIR}/postgres.env"
fi

if [[ ! -f "${SECRETS_DIR}/n8n.env" ]]; then
  render_template "${ROOT_DIR}/templates/secrets/n8n.env.tpl" "${SECRETS_DIR}/n8n.env"
  chmod 600 "${SECRETS_DIR}/n8n.env"
fi

# nginx snippets + site configs
write_if_missing "${NGINX_SNIPPETS_DIR}/proxy-headers.conf" "$(cat "${ROOT_DIR}/templates/nginx/proxy-headers.conf")"

if [[ ! -f "${NGINX_CONFD_DIR}/odoo.conf" ]]; then
  render_template "${ROOT_DIR}/templates/nginx/odoo.http.conf.tpl" "${NGINX_CONFD_DIR}/odoo.conf"
fi
if [[ ! -f "${NGINX_CONFD_DIR}/n8n.conf" ]]; then
  render_template "${ROOT_DIR}/templates/nginx/n8n.http.conf.tpl" "${NGINX_CONFD_DIR}/n8n.conf"
fi

log "Impostazione permessi volumi (data/log)..."

# Postgres: UID postgres letto dall’immagine
pg_uid="$(get_uid_from_image "${POSTGRES_IMAGE}" "postgres")"
chown -R "${pg_uid}:${pg_uid}" "${PG_DATA_DIR}"

# Odoo: UID/GID fissati
chown -R "${ODOO_UID}:${ODOO_GID}" "${ODOO_DATA_DIR}" "${ODOO_CONF_DIR}" "${ODOO_LOG_DIR}" "${ODOO_BACKUP_DIR}" "${ODOO_STD_ADDONS_DIR}" "${ODOO_CUST_ADDONS_DIR}"

# n8n: UID node letto dall’immagine
n8n_uid="$(get_uid_from_image "${N8N_IMAGE}" "node")"
chown -R "${n8n_uid}:${n8n_uid}" "${N8N_DATA_DIR}"

log "Init host completato."
