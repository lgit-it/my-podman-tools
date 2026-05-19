#!/usr/bin/env bash
# Rebuild/recreate the n8n container with the latest image.
# Leaves all other containers (postgres, odoo, nginx) untouched.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd podman

log "Pull ultima versione immagine n8n: ${N8N_IMAGE} ..."
podman pull "${N8N_IMAGE}"

log "Arresto e rimozione container n8n esistente (se presente)..."
podman stop n8n 2>/dev/null || true
podman rm   n8n 2>/dev/null || true

if [[ "${BIND_LOCALHOST:-1}" == "1" ]]; then
  N8N_BIND="127.0.0.1:${N8N_HOST_PORT}:5678"
else
  N8N_BIND="${N8N_HOST_PORT}:5678"
fi

log "Fix permessi directory dati n8n..."
n8n_uid="$(get_uid_from_image "${N8N_IMAGE}" "node")"
chown -R "${n8n_uid}:${n8n_uid}" "${N8N_DATA_DIR}"

log "Creazione container n8n..."
podman create \
  --name n8n \
  --network "${PODMAN_NET}" \
  -p "${N8N_BIND}" \
  --env-file "${SECRETS_DIR}/n8n.env" \
  --env "N8N_RESTRICT_FILE_ACCESS_TO:/home/node/n8n_data" \
  -v "${N8N_DATA_DIR}:/home/node/n8n_data:Z" \
  "${N8N_IMAGE}"

log "Avvio container n8n..."
podman start n8n

log "n8n ricreato e avviato con immagine: ${N8N_IMAGE}"
log "Per gestirlo via systemd: systemctl restart n8n.service"
