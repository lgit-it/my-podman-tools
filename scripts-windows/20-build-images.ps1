# Build immagini container custom (Odoo, Nginx)
# Uso: .\scripts-windows\20-build-images.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

#Require-Administrator
Test-Command "podman"

Write-Log "Build immagine Odoo custom (local/odoo-custom:$ODOO_BRANCH)..."

podman build `
    --build-arg "ODOO_BRANCH=$ODOO_BRANCH" `
    --build-arg "ODOO_CORE_REPO=$ODOO_CORE_REPO" `
    --build-arg "ODOO_UID=$ODOO_UID" `
    --build-arg "ODOO_GID=$ODOO_GID" `
    -t "local/odoo-custom:$ODOO_BRANCH" `
    -f (Join-Path $ROOT_DIR "containerfiles\odoo\Containerfile") `
    (Join-Path $ROOT_DIR "containerfiles\odoo")

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante build Odoo" -Level "ERROR"
    exit 1
}

Write-Log "Build immagine Odoo completato" -Level "SUCCESS"

Write-Log "Build immagine Nginx (opzionale, wrapper)..."

podman build `
    -t "local/nginx-proxy:latest" `
    -f (Join-Path $ROOT_DIR "containerfiles\nginx\Containerfile") `
    (Join-Path $ROOT_DIR "containerfiles\nginx")

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante build Nginx" -Level "ERROR"
    exit 1
}

Write-Log "Build immagine Nginx completato" -Level "SUCCESS"
Write-Log "Build completato." -Level "SUCCESS"
