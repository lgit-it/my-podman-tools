# PowerShell Environment Loader
# Carica .env (stile KEY=VALUE) e definisce variabili derivate
# Uso: . .\scripts-windows\00-env.ps1

$ErrorActionPreference = "Stop"

# Determina ROOT_DIR dal percorso dello script
$Script:ROOT_DIR = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Script:ENV_FILE = Join-Path $ROOT_DIR ".env"

if (-not (Test-Path $ENV_FILE)) {
    Write-Error "ERRORE: manca $ENV_FILE. Crea da .env.example"
    exit 1
}

# Carica variabili da .env
Get-Content $ENV_FILE | ForEach-Object {
    $line = $_.Trim()

    # Salta righe vuote e commenti
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    # Parse KEY=VALUE
    if ($line -match '^([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Rimuovi quote se presenti
        $value = $value -replace '^["'']|["'']$', ''

        # Imposta variabile di script accessibile globalmente
        Set-Variable -Name $key -Value $value -Scope Script

        # Esporta anche come variabile d'ambiente
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Normalizza path (rimuovi trailing slash)
$Script:BASE_DIR = $BASE_DIR.TrimEnd('\', '/')
$Script:SECRETS_DIR = $SECRETS_DIR.TrimEnd('\', '/')

# Path derivati / standardizzati
$Script:PG_DATA_DIR = Join-Path $BASE_DIR "postgres\data"
$Script:PG_CONF_DIR = Join-Path $BASE_DIR "postgres\conf"
$Script:PG_INIT_DIR = Join-Path $BASE_DIR "postgres\init"

$Script:ODOO_DIR = Join-Path $BASE_DIR "odoo"
$Script:ODOO_DATA_DIR = Join-Path $ODOO_DIR "data"
$Script:ODOO_LOG_DIR = Join-Path $ODOO_DIR "logs"
$Script:ODOO_BACKUP_DIR = Join-Path $ODOO_DIR "backups"
$Script:ODOO_CONF_DIR = Join-Path $ODOO_DIR "config"
$Script:ODOO_STD_ADDONS_DIR = Join-Path $ODOO_DIR "repo-standard"
$Script:ODOO_CUST_ADDONS_DIR = Join-Path $ODOO_DIR "repo-custom"
$Script:ODOO_BUILD_DIR = Join-Path $ODOO_DIR "build"

$Script:N8N_DATA_DIR = Join-Path $BASE_DIR "n8n\data"

$Script:NGINX_DIR = Join-Path $BASE_DIR "nginx"
$Script:NGINX_LOG_DIR = Join-Path $NGINX_DIR "logs"
$Script:NGINX_CONFD_DIR = Join-Path $NGINX_DIR "conf.d"
$Script:NGINX_SNIPPETS_DIR = Join-Path $NGINX_DIR "snippets"
$Script:NGINX_WEBROOT_DIR = Join-Path $NGINX_DIR "www"
$Script:NGINX_LE_DIR = Join-Path $NGINX_DIR "letsencrypt"

# Volume label suffix (vuoto su Windows, non supporta SELinux)
$Script:VOL_LBL = ""

# Helper: costruisce bind su localhost o 0.0.0.0 a seconda di BIND_LOCALHOST
function Get-HostBind {
    param(
        [int]$Port
    )

    if ($Script:BIND_LOCALHOST -eq "1") {
        return "127.0.0.1:${Port}:${Port}"
    } else {
        return "${Port}:${Port}"
    }
}

Write-Host "Environment loaded from $ENV_FILE" -ForegroundColor Green
