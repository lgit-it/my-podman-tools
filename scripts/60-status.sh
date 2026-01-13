#!/usr/bin/env bash
set -euo pipefail

echo "== Podman ps =="
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "== Systemd =="
systemctl --no-pager --full status \
  container-postgres.service \
  container-odoo.service \
  container-n8n.service \
  container-nginx-proxy.service \
  | sed -n '1,120p' || true
