#!/usr/bin/env bash
set -euo pipefail

# Carica .env (stile KEY=VALUE) senza dipendenze esterne.
# Uso: source scripts/00-env.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERRORE: manca ${ENV_FILE}. Crea da .env.example" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

# Valori derivati / path standardizzati
BASE_DIR="${BASE_DIR%/}"
SECRETS_DIR="${SECRETS_DIR%/}"

PG_DATA_DIR="${BASE_DIR}/postgres/data"
PG_CONF_DIR="${BASE_DIR}/postgres/conf"
PG_INIT_DIR="${BASE_DIR}/postgres/init"

ODOO_DIR="${BASE_DIR}/odoo"
ODOO_DATA_DIR="${ODOO_DIR}/data"
ODOO_LOG_DIR="${ODOO_DIR}/logs"
ODOO_BACKUP_DIR="${ODOO_DIR}/backups"
ODOO_CONF_DIR="${ODOO_DIR}/config"
ODOO_STD_ADDONS_DIR="${ODOO_DIR}/repo-standard"
ODOO_CUST_ADDONS_DIR="${ODOO_DIR}/repo-custom"
ODOO_BUILD_DIR="${ODOO_DIR}/build"

N8N_DATA_DIR="${BASE_DIR}/n8n/data"

NGINX_DIR="${BASE_DIR}/nginx"
NGINX_LOG_DIR="${NGINX_DIR}/logs"
NGINX_CONFD_DIR="${NGINX_DIR}/conf.d"
NGINX_SNIPPETS_DIR="${NGINX_DIR}/snippets"
NGINX_WEBROOT_DIR="${NGINX_DIR}/www"
NGINX_LE_DIR="${NGINX_DIR}/letsencrypt"

# Volume label suffix (":Z" oppure vuoto)
VOL_LBL="${VOLUME_LABEL:-}"

# ====== Porte host (bind localhost) ======
# Puoi cambiare (es. 8069->18069) se hai conflitti.
BIND_LOCALHOST=1
POSTGRES_HOST_PORT=15432
ODOO_HOST_PORT=8069
ODOO_LONGPOLL_HOST_PORT=8072
ODOO_DEBUG_HOST_PORT=8678
N8N_HOST_PORT=5678
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443





# Helper: costruisce bind su localhost o 0.0.0.0 a seconda di BIND_LOCALHOST
host_bind() {
  local port="$1"
  if [[ "${BIND_LOCALHOST:-1}" == "1" ]]; then
    printf "127.0.0.1:%s:%s" "${port}" "${port}"
  else
    printf "%s:%s" "${port}" "${port}"
  fi
}
