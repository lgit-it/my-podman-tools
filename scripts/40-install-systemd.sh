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

# 1. Postgres
cat > "${QUADLET_DIR}/postgres.container" <<EOF
[Unit]
Description=PostgreSQL Container

[Container]
Image=postgres:latest
ContainerName=postgres
# Aggiungi qui i tuoi volumi o variabili d'ambiente, es:
# Environment=POSTGRES_PASSWORD=password
# Volume=/opt/postgres/data:/var/lib/postgresql/data:Z

[Install]
WantedBy=multi-user.target default.target
EOF

# 2. Odoo
cat > "${QUADLET_DIR}/odoo.container" <<EOF
[Unit]
Description=Odoo Container
After=postgres.service
Requires=postgres.service

[Container]
Image=odoo:latest
ContainerName=odoo
# Link al database
Environment=HOST=postgres

[Install]
WantedBy=multi-user.target default.target
EOF

# 3. n8n
cat > "${QUADLET_DIR}/n8n.container" <<EOF
[Unit]
Description=n8n Container
After=postgres.service
Requires=postgres.service

[Container]
Image=n8nio/n8n:latest
ContainerName=n8n

[Install]
WantedBy=multi-user.target default.target
EOF

# 4. Nginx Proxy
cat > "${QUADLET_DIR}/.container" <<EOF
[Unit]
Description=Nginx Proxy Container
After=odoo.service n8n.service
Wants=odoo.service n8n.service

[Container]
Image=nginx:latest
ContainerName=

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
systemctl start postgres.service odoo.service n8n.service .service


log "Stato servizi:"
systemctl --no-pager --full status postgres.service odoo.service n8n.service .service | sed -n '1,40p' || true