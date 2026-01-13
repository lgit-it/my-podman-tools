#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: sudo bash scripts/91-import-bundle.sh /path/to/bundle_YYYYmmdd_HHMMSS.tar.gz" >&2
  exit 1
fi

BUNDLE="$1"
if [[ ! -f "${BUNDLE}" ]]; then
  echo "ERRORE: bundle non trovato: ${BUNDLE}" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd tar

log "Estraggo bundle..."
tar -xzf "${BUNDLE}" -C /

log "Re-import completato. Ora puoi:"
echo "  1) verificare .env (in ${ROOT_DIR}/.env)"
echo "  2) sudo bash scripts/10-init-host.sh   (idempotente; non sovrascrive i file già presenti)"
echo "  3) sudo bash scripts/20-build-images.sh"
echo "  4) sudo bash scripts/30-create-containers.sh"
echo "  5) sudo bash scripts/40-install-systemd.sh"
