#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd podman

log "Build immagine Odoo custom (local/odoo-custom:${ODOO_BRANCH})..."

podman build \
  --build-arg "ODOO_BRANCH=${ODOO_BRANCH}" \
  --build-arg "ODOO_CORE_REPO=${ODOO_CORE_REPO}" \
  --build-arg "ODOO_UID=${ODOO_UID}" \
  --build-arg "ODOO_GID=${ODOO_GID}" \
  -t "local/odoo-custom:${ODOO_BRANCH}" \
  -f "${ROOT_DIR}/containerfiles/odoo/Containerfile" \
  "${ROOT_DIR}/containerfiles/odoo"

log "Build immagine Nginx (opzionale, wrapper)..."

podman build \
  -t "local/nginx-proxy:latest" \
  -f "${ROOT_DIR}/containerfiles/nginx/Containerfile" \
  "${ROOT_DIR}/containerfiles/nginx"

log "Build completato."
