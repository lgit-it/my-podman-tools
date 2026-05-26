#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/00-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

require_root
ensure_cmd podman
ensure_cmd systemctl

QUADLET_DIR="/etc/containers/systemd"
mkdir -p "$QUADLET_DIR"

log "Configurazione Quadlet in $QUADLET_DIR"

# 4. Nginx Proxy
cat > "${QUADLET_DIR}/nginx.container" <<EOF
[Unit]
Description=Nginx Proxy Container


[Container]
Image=nginx:latest
ContainerName=nginx

[Install]
WantedBy=multi-user.target default.target
EOF

log "Ricarica systemd (generazione automatica unit Quadlet)"
systemctl daemon-reload

log "Enable & start servizi"
log "Ricarica systemd (generazione automatica unit Quadlet)"
systemctl daemon-reload

log "Start servizi (già abilitati tramite [Install] nel file Quadlet)"
# Nota: Usiamo solo 'start' o 'restart'. 
# L'enable è gestito automaticamente dal generatore Quadlet.
systemctl start postgres.service odoo.service n8n.service nginx.service


log "Stato servizi:"
systemctl --no-pager --full status postgres.service odoo.service n8n.service nginx.service | sed -n '1,40p' || true
