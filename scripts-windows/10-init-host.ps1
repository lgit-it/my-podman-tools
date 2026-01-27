# Inizializza host Windows per deployment Podman
# Crea directory, genera segreti, configura template
# Uso: .\scripts-windows\10-init-host.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

Require-Administrator

Write-Log "Verifica prerequisiti..."

# Verifica che Podman sia installato
Test-Command "podman"

Write-Log "Creazione directory persistenti in $BASE_DIR ..."

# Crea tutte le directory necessarie
$directories = @(
    $PG_DATA_DIR, $PG_CONF_DIR, $PG_INIT_DIR,
    $ODOO_BUILD_DIR, $ODOO_DATA_DIR, $ODOO_LOG_DIR, $ODOO_BACKUP_DIR, $ODOO_CONF_DIR,
    $ODOO_STD_ADDONS_DIR, $ODOO_CUST_ADDONS_DIR,
    $N8N_DATA_DIR,
    $NGINX_CONFD_DIR, $NGINX_LOG_DIR, $NGINX_SNIPPETS_DIR, $NGINX_WEBROOT_DIR, $NGINX_LE_DIR,
    $SECRETS_DIR,
    (Join-Path $ROOT_DIR "exports")
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Log "Creata directory: $dir"
    }
}

# Imposta permessi restrittivi su SECRETS_DIR
$acl = Get-Acl $SECRETS_DIR
$acl.SetAccessRuleProtection($true, $false)
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
    "FullControl",
    "Allow"
)
$acl.SetAccessRule($accessRule)
Set-Acl -Path $SECRETS_DIR -AclObject $acl

Write-Log "Verifica Podman network: $PODMAN_NET"

# Verifica/crea network Podman
$networkExists = podman network exists $PODMAN_NET 2>$null
if ($LASTEXITCODE -ne 0) {
    podman network create $PODMAN_NET
    Write-Log "Network Podman creata: $PODMAN_NET" -Level "SUCCESS"
}

Write-Log "Pull immagini base..."
podman pull $POSTGRES_IMAGE
podman pull $N8N_IMAGE
podman pull $NGINX_IMAGE

Write-Log "Generazione segreti (solo se mancanti)..."

Write-IfMissing -Path (Join-Path $SECRETS_DIR "postgres_super_pass.txt") -Content (New-RandomBase64)
Write-IfMissing -Path (Join-Path $SECRETS_DIR "odoo_db_pass.txt") -Content (New-RandomBase64)
Write-IfMissing -Path (Join-Path $SECRETS_DIR "n8n_db_pass.txt") -Content (New-RandomBase64)
Write-IfMissing -Path (Join-Path $SECRETS_DIR "n8n_encryption_key.txt") -Content (New-RandomHex -Length 32)

# Carica segreti per uso nei template
$Script:POSTGRES_SUPER_PASS = Get-Content (Join-Path $SECRETS_DIR "postgres_super_pass.txt") -Raw
$Script:ODOO_DB_PASS = Get-Content (Join-Path $SECRETS_DIR "odoo_db_pass.txt") -Raw
$Script:N8N_DB_PASS = Get-Content (Join-Path $SECRETS_DIR "n8n_db_pass.txt") -Raw
$Script:N8N_ENCRYPTION_KEY = Get-Content (Join-Path $SECRETS_DIR "n8n_encryption_key.txt") -Raw

# Trim newlines
$Script:POSTGRES_SUPER_PASS = $POSTGRES_SUPER_PASS.Trim()
$Script:ODOO_DB_PASS = $ODOO_DB_PASS.Trim()
$Script:N8N_DB_PASS = $N8N_DB_PASS.Trim()
$Script:N8N_ENCRYPTION_KEY = $N8N_ENCRYPTION_KEY.Trim()

# Imposta variabili d'ambiente per rendering template
[Environment]::SetEnvironmentVariable("POSTGRES_SUPER_PASS", $Script:POSTGRES_SUPER_PASS, "Process")
[Environment]::SetEnvironmentVariable("ODOO_DB_PASS", $Script:ODOO_DB_PASS, "Process")
[Environment]::SetEnvironmentVariable("N8N_DB_PASS", $Script:N8N_DB_PASS, "Process")
[Environment]::SetEnvironmentVariable("N8N_ENCRYPTION_KEY", $Script:N8N_ENCRYPTION_KEY, "Process")

# Protocollo n8n
if ($ENABLE_LETSENCRYPT -eq "1") {
    $Script:N8N_PROTOCOL = "https"
} else {
    $Script:N8N_PROTOCOL = "http"
}
[Environment]::SetEnvironmentVariable("N8N_PROTOCOL", $Script:N8N_PROTOCOL, "Process")

Write-Log "Scrittura config Postgres/Odoo/Nginx/N8n (solo se mancanti)..."

# PostgreSQL configs
Write-IfMissing -Path (Join-Path $PG_CONF_DIR "postgresql.conf") -Content (Get-Content (Join-Path $ROOT_DIR "templates\postgres\postgresql.conf") -Raw)
Write-IfMissing -Path (Join-Path $PG_CONF_DIR "pg_hba.conf") -Content (Get-Content (Join-Path $ROOT_DIR "templates\postgres\pg_hba.conf") -Raw)

# PostgreSQL init SQL
$pgInitPath = Join-Path $PG_INIT_DIR "01-init.sql"
if (-not (Test-Path $pgInitPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\postgres\01-init.sql.tpl") -DestinationPath $pgInitPath
}

# Odoo config
$odooConfPath = Join-Path $ODOO_CONF_DIR "odoo.conf"
if (-not (Test-Path $odooConfPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\odoo\odoo.conf.tpl") -DestinationPath $odooConfPath
}

# Secrets env files
$pgEnvPath = Join-Path $SECRETS_DIR "postgres.env"
if (-not (Test-Path $pgEnvPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\secrets\postgres.env.tpl") -DestinationPath $pgEnvPath
}

$n8nEnvPath = Join-Path $SECRETS_DIR "n8n.env"
if (-not (Test-Path $n8nEnvPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\secrets\n8n.env.tpl") -DestinationPath $n8nEnvPath
}

# Nginx configs
Write-IfMissing -Path (Join-Path $NGINX_SNIPPETS_DIR "proxy-headers.conf") -Content (Get-Content (Join-Path $ROOT_DIR "templates\nginx\proxy-headers.conf") -Raw)

$odooNginxPath = Join-Path $NGINX_CONFD_DIR "odoo.conf"
if (-not (Test-Path $odooNginxPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\nginx\odoo.http.conf.tpl") -DestinationPath $odooNginxPath
}

$n8nNginxPath = Join-Path $NGINX_CONFD_DIR "n8n.conf"
if (-not (Test-Path $n8nNginxPath)) {
    Invoke-RenderTemplate -SourcePath (Join-Path $ROOT_DIR "templates\nginx\n8n.http.conf.tpl") -DestinationPath $n8nNginxPath
}

Write-Log "NOTA: Permessi volumi gestiti automaticamente da Podman Desktop (WSL2 backend)" -Level "WARN"
Write-Log "Init host completato." -Level "SUCCESS"
