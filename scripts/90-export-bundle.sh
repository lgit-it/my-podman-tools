#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd tar

ts="$(date -u +'%Y%m%d_%H%M%S')"
out_dir="${ROOT_DIR}/exports"
mkdir -p "${out_dir}"

bundle="${out_dir}/bundle_${ts}.tar.gz"

log "Fermo servizi per snapshot coerente..."
systemctl stop container-.service container-odoo.service container-n8n.service container-postgres.service || true

log "Creo bundle in ${bundle}"
# Include BASE_DIR e .env (senza caricare segreti in chiaro in README; i segreti restano nel SECRETS_DIR)
tar -czf "${bundle}" \
  -C / \
  "${BASE_DIR#/}" \
  -C "${ROOT_DIR}" \
  ".env" \
  "README.md" \
  "templates" \
  "containerfiles" \
  "scripts"

log "Riavvio servizi..."
systemctl start container-postgres.service container-odoo.service container-n8n.service container-.service || true

log "Bundle creato: ${bundle}"
