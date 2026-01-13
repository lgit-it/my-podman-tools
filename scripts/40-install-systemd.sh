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

log "Genero unit systemd (podman generate systemd --new)"
tmpd="$(mktemp -d)"
pushd "${tmpd}" >/dev/null

podman generate systemd --new --files --name postgres
podman generate systemd --new --files --name odoo
podman generate systemd --new --files --name n8n
podman generate systemd --new --files --name nginx-proxy

log "Installo unit in /etc/systemd/system"
cp -f ./*.service /etc/systemd/system/

popd >/dev/null
rm -rf "${tmpd}"

log "Override dipendenze: odoo e n8n dopo postgres"
mkdir -p /etc/systemd/system/container-odoo.service.d
cat >/etc/systemd/system/container-odoo.service.d/override.conf <<'EOF'
[Unit]
After=container-postgres.service
Requires=container-postgres.service
EOF

mkdir -p /etc/systemd/system/container-n8n.service.d
cat >/etc/systemd/system/container-n8n.service.d/override.conf <<'EOF'
[Unit]
After=container-postgres.service
Requires=container-postgres.service
EOF

log "Override dipendenze: nginx dopo odoo+n8n (best effort)"
mkdir -p /etc/systemd/system/container-nginx-proxy.service.d
cat >/etc/systemd/system/container-nginx-proxy.service.d/override.conf <<'EOF'
[Unit]
After=container-odoo.service container-n8n.service
Wants=container-odoo.service container-n8n.service
EOF

systemctl daemon-reload

log "Enable & start servizi"
systemctl enable --now container-postgres.service
systemctl enable --now container-odoo.service
systemctl enable --now container-n8n.service
systemctl enable --now container-nginx-proxy.service

log "Stato servizi:"
systemctl --no-pager --full status container-postgres.service container-odoo.service container-n8n.service container-nginx-proxy.service | sed -n '1,40p' || true
