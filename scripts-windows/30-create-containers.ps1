# Crea container Podman (Postgres, Odoo, n8n, Nginx)
# Uso: .\scripts-windows\30-create-containers.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

#Require-Administrator
Test-Command "podman"

Write-Log "Rimozione container esistenti (se presenti)..."

# Stop containers
podman stop postgres odoo n8n nginx 2>$null
# Remove containers
podman rm -f postgres odoo n8n nginx 2>$null

Write-Log "Configurazione port binding..."

# Porte bindate su localhost se BIND_LOCALHOST=1
if ($BIND_LOCALHOST -eq "1") {
    $PG_BIND = "127.0.0.1:${POSTGRES_HOST_PORT}:5432"
    $ODOO_BIND = "127.0.0.1:${ODOO_HOST_PORT}:8069"
    $ODOO_LP_BIND = "127.0.0.1:${ODOO_LONGPOLL_HOST_PORT}:8072"
    $ODOO_DEBUG_BIND = "127.0.0.1:8765:8765"
    $N8N_BIND = "127.0.0.1:${N8N_HOST_PORT}:5678"
} else {
    $PG_BIND = "${POSTGRES_HOST_PORT}:5432"
    $ODOO_BIND = "${ODOO_HOST_PORT}:8069"
    $ODOO_LP_BIND = "${ODOO_LONGPOLL_HOST_PORT}:8072"
    $ODOO_DEBUG_BIND = "8765:8765"
    $N8N_BIND = "${N8N_HOST_PORT}:5678"
}

Write-Log "Creazione container Postgres..."

podman create `
    --name postgres `
    --network $PODMAN_NET `
    --hostname postgres `
    --network-alias postgres `
    -p $PG_BIND `
    --env-file (Join-Path $SECRETS_DIR "postgres.env") `
    -v "postgres_data:/var/lib/postgresql/data${VOL_LBL}" `
    -v "${PG_INIT_DIR}:/docker-entrypoint-initdb.d${VOL_LBL}" `
    -v "${PG_CONF_DIR}:/etc/postgresql${VOL_LBL}" `
    $POSTGRES_IMAGE `
    -c "config_file=/etc/postgresql/postgresql.conf" `
    -c "hba_file=/etc/postgresql/pg_hba.conf"

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante creazione container Postgres" -Level "ERROR"
    exit 1
}

Write-Log "Container Postgres creato" -Level "SUCCESS"

Write-Log "Creazione container Odoo..."

podman create `
    --name odoo `
    --network $PODMAN_NET `
    --hostname odoo `
    --network-alias odoo `
    -p $ODOO_BIND `
    -p $ODOO_LP_BIND `
    -p $ODOO_DEBUG_BIND `
    -v "${ODOO_DATA_DIR}:/var/lib/odoo${VOL_LBL}" `
    -v "${ODOO_LOG_DIR}:/var/log/odoo${VOL_LBL}" `
    -v "${ODOO_BACKUP_DIR}:/var/lib/odoo/backups${VOL_LBL}" `
    -v "${ODOO_STD_ADDONS_DIR}:/mnt/extra-addons${VOL_LBL}" `
    -v "${ODOO_CUST_ADDONS_DIR}:/mnt/custom-addons${VOL_LBL}" `
    -v "$(Join-Path $ODOO_CONF_DIR "odoo.conf"):/etc/odoo/odoo.conf${VOL_LBL}" `
    "local/odoo-custom:$ODOO_BRANCH"

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante creazione container Odoo" -Level "ERROR"
    exit 1
}

Write-Log "Container Odoo creato" -Level "SUCCESS"

Write-Log "Creazione container n8n..."

podman create `
    --name n8n `
    --network $PODMAN_NET `
    -p $N8N_BIND `
    --env-file (Join-Path $SECRETS_DIR "n8n.env") `
    -v "${N8N_DATA_DIR}:/home/node/.n8n${VOL_LBL}" `
    $N8N_IMAGE

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante creazione container n8n" -Level "ERROR"
    exit 1
}

Write-Log "Container n8n creato" -Level "SUCCESS"

Write-Log "Creazione container Nginx reverse-proxy..."

podman create `
    --name nginx `
    --network $PODMAN_NET `
    -p "${NGINX_HTTP_PORT}:80" `
    -p "${NGINX_HTTPS_PORT}:443" `
    -v "${NGINX_CONFD_DIR}:/etc/nginx/conf.d${VOL_LBL}" `
    -v "${NGINX_SNIPPETS_DIR}:/etc/nginx/snippets${VOL_LBL}" `
    -v "${NGINX_WEBROOT_DIR}:/var/www/certbot${VOL_LBL}" `
    -v "${NGINX_LE_DIR}:/etc/letsencrypt:ro" `
    "local/nginx-proxy:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Log "Errore durante creazione container Nginx" -Level "ERROR"
    exit 1
}

Write-Log "Container Nginx creato" -Level "SUCCESS"

Write-Log "Container creati." -Level "SUCCESS"
Write-Log "Avvio manuale: podman start postgres odoo n8n nginx"
Write-Log "Oppure installa servizi Windows: .\scripts-windows\40-install-services.ps1"
