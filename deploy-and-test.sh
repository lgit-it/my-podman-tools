#!/usr/bin/env bash
set -euo pipefail

# Deployment and testing script
# Run with: sudo bash deploy-and-test.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Starting deployment process..."
echo "========================================="

echo ""
echo "[1/4] Running 10-init-host.sh..."
bash "${ROOT_DIR}/scripts/10-init-host.sh"

echo ""
echo "[2/4] Running 20-build-images.sh..."
bash "${ROOT_DIR}/scripts/20-build-images.sh"

echo ""
echo "[3/4] Running 30-create-containers.sh..."
bash "${ROOT_DIR}/scripts/30-create-containers.sh"

echo ""
echo "[4/4] Starting containers manually (without systemd)..."
podman start postgres
sleep 3
podman start odoo
sleep 2
podman start n8n
sleep 1
podman start nginx

echo ""
echo "========================================="
echo "Checking container status..."
echo "========================================="
podman ps

echo ""
echo "========================================="
echo "Waiting 10 seconds for Odoo to start..."
echo "========================================="
sleep 10

echo ""
echo "========================================="
echo "Testing Odoo accessibility..."
echo "========================================="
echo "Testing HTTP on localhost:8069..."
curl -I http://localhost:8069 2>&1 | head -n 10 || echo "Connection failed"

echo ""
echo "Testing HTTP on 127.0.0.1:8069..."
curl -I http://127.0.0.1:8069 2>&1 | head -n 10 || echo "Connection failed"

echo ""
echo "========================================="
echo "Odoo logs (last 20 lines)..."
echo "========================================="
podman logs --tail 20 odoo

echo ""
echo "========================================="
echo "Deployment complete!"
echo "========================================="
echo "Access Odoo at: http://localhost:8069"
echo "Access n8n at: http://localhost:5678"
echo ""
echo "To view logs:"
echo "  podman logs -f odoo"
echo "  podman logs -f postgres"
echo "  podman logs -f n8n"
echo "  podman logs -f nginx"
