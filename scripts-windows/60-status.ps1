# Verifica stato servizi e container Podman
# Uso: .\scripts-windows\60-status.ps1

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

Test-Command "podman"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STATO SERVIZI WINDOWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica servizi Windows
$services = @("PodmanPostgres", "PodmanOdoo", "PodmanN8n", "PodmanNginx")
$servicesExist = $false

foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        $servicesExist = $true
        $status = $service.Status
        $color = if ($status -eq "Running") { "Green" } else { "Red" }

        Write-Host "$serviceName : " -NoNewline
        Write-Host "$status" -ForegroundColor $color
    }
}

if (-not $servicesExist) {
    Write-Host "Nessun servizio Windows installato." -ForegroundColor Yellow
    Write-Host "Esegui: .\scripts-windows\40-install-services.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STATO CONTAINER PODMAN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica container Podman
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=^(postgres|odoo|n8n|nginx)$"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HEALTH CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica connettività ai servizi
$checks = @(
    @{Name="PostgreSQL"; Host="localhost"; Port=$POSTGRES_HOST_PORT; Enabled=$true},
    @{Name="Odoo HTTP"; Host="localhost"; Port=$ODOO_HOST_PORT; Enabled=$true},
    @{Name="Odoo Longpoll"; Host="localhost"; Port=$ODOO_LONGPOLL_HOST_PORT; Enabled=$true},
    @{Name="n8n"; Host="localhost"; Port=$N8N_HOST_PORT; Enabled=$true},
    @{Name="Nginx HTTP"; Host="localhost"; Port=$NGINX_HTTP_PORT; Enabled=$true},
    @{Name="Nginx HTTPS"; Host="localhost"; Port=$NGINX_HTTPS_PORT; Enabled=($ENABLE_LETSENCRYPT -eq "1")}
)

foreach ($check in $checks) {
    if (-not $check.Enabled) {
        continue
    }

    $name = $check.Name
    $host = $check.Host
    $port = $check.Port

    try {
        $connection = Test-NetConnection -ComputerName $host -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($connection) {
            Write-Host "$name (${host}:${port}) : " -NoNewline
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host "$name (${host}:${port}) : " -NoNewline
            Write-Host "FAIL" -ForegroundColor Red
        }
    } catch {
        Write-Host "$name (${host}:${port}) : " -NoNewline
        Write-Host "FAIL" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " INFORMAZIONI ACCESSO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Odoo:"
Write-Host "  - URL interna: http://localhost:$ODOO_HOST_PORT" -ForegroundColor Cyan
Write-Host "  - URL pubblica: http://$ODOO_DOMAIN" -ForegroundColor Cyan
if ($ENABLE_LETSENCRYPT -eq "1") {
    Write-Host "  - URL HTTPS: https://$ODOO_DOMAIN" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "n8n:"
Write-Host "  - URL interna: http://localhost:$N8N_HOST_PORT" -ForegroundColor Cyan
Write-Host "  - URL pubblica: http://$N8N_DOMAIN" -ForegroundColor Cyan
if ($ENABLE_LETSENCRYPT -eq "1") {
    Write-Host "  - URL HTTPS: https://$N8N_DOMAIN" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "PostgreSQL:"
Write-Host "  - Host: localhost" -ForegroundColor Cyan
Write-Host "  - Port: $POSTGRES_HOST_PORT" -ForegroundColor Cyan
Write-Host "  - Database Odoo: odoo" -ForegroundColor Cyan
Write-Host "  - Database n8n: n8n" -ForegroundColor Cyan

Write-Host ""
