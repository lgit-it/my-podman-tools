# Installa servizi Windows per container Podman usando NSSM
# Uso: .\scripts-windows\40-install-services.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

Require-Administrator
Test-Command "podman"

Write-Log "Verifica/Installazione NSSM (Non-Sucking Service Manager)..."

# Verifica se NSSM è già installato
$nssmPath = Get-Command nssm -ErrorAction SilentlyContinue

if (-not $nssmPath) {
    Write-Log "NSSM non trovato, installazione in corso..."

    # Prova con winget prima
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id=NSSM.NSSM --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install nssm -y
    } else {
        Write-Log "Nessun package manager trovato. Scarica NSSM manualmente da https://nssm.cc/download" -Level "ERROR"
        exit 1
    }

    # Ricarica PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Ricontrolla
    $nssmPath = Get-Command nssm -ErrorAction SilentlyContinue
    if (-not $nssmPath) {
        Write-Log "NSSM non installato correttamente" -Level "ERROR"
        exit 1
    }
}

Write-Log "NSSM trovato: $($nssmPath.Source)" -Level "SUCCESS"

# Funzione helper per creare servizio Windows
function Install-PodmanService {
    param(
        [string]$ServiceName,
        [string]$ContainerName,
        [string]$DisplayName,
        [string]$Description,
        [string[]]$DependsOn = @()
    )

    Write-Log "Configurazione servizio: $ServiceName"

    # Rimuovi servizio esistente se presente
    $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Rimozione servizio esistente: $ServiceName"
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        nssm remove $ServiceName confirm
    }

    # Trova path completo di podman.exe
    $podmanExe = (Get-Command podman).Source

    # Installa servizio
    nssm install $ServiceName $podmanExe "start" "-a" $ContainerName

    # Configura display name e description
    nssm set $ServiceName DisplayName $DisplayName
    nssm set $ServiceName Description $Description

    # Configura output logging
    $logDir = Join-Path $BASE_DIR "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    nssm set $ServiceName AppStdout (Join-Path $logDir "${ServiceName}_stdout.log")
    nssm set $ServiceName AppStderr (Join-Path $logDir "${ServiceName}_stderr.log")

    # Configura restart automatico
    nssm set $ServiceName AppStopMethodSkip 6
    nssm set $ServiceName AppStopMethodConsole 10000

    # Configura dipendenze
    if ($DependsOn.Count -gt 0) {
        $dependencyString = $DependsOn -join "/"
        nssm set $ServiceName DependOnService $dependencyString
    }

    # Configura startup type (automatic)
    nssm set $ServiceName Start SERVICE_AUTO_START

    Write-Log "Servizio $ServiceName installato" -Level "SUCCESS"
}

# Installa servizi nell'ordine corretto
Write-Log "Installazione servizi Windows..."

# 1. PostgreSQL (nessuna dipendenza)
Install-PodmanService `
    -ServiceName "PodmanPostgres" `
    -ContainerName "postgres" `
    -DisplayName "Podman PostgreSQL Container" `
    -Description "PostgreSQL 16 database server running in Podman container"

# 2. Odoo (dipende da PostgreSQL)
Install-PodmanService `
    -ServiceName "PodmanOdoo" `
    -ContainerName "odoo" `
    -DisplayName "Podman Odoo Container" `
    -Description "Odoo 18 ERP running in Podman container" `
    -DependsOn @("PodmanPostgres")

# 3. n8n (dipende da PostgreSQL)
Install-PodmanService `
    -ServiceName "PodmanN8n" `
    -ContainerName "n8n" `
    -DisplayName "Podman n8n Container" `
    -Description "n8n workflow automation running in Podman container" `
    -DependsOn @("PodmanPostgres")

# 4. Nginx (nessuna dipendenza diretta, ma potrebbe dipendere dai backend)
Install-PodmanService `
    -ServiceName "PodmanNginx" `
    -ContainerName "nginx" `
    -DisplayName "Podman Nginx Proxy Container" `
    -Description "Nginx reverse proxy running in Podman container" `
    -DependsOn @("PodmanOdoo", "PodmanN8n")

Write-Log "Avvio servizi..."

# Avvia i servizi nell'ordine corretto
Start-Service -Name "PodmanPostgres"
Write-Log "Attesa avvio PostgreSQL..." -Level "WARN"
Start-Sleep -Seconds 10

Start-Service -Name "PodmanOdoo"
Start-Service -Name "PodmanN8n"
Write-Log "Attesa avvio servizi backend..." -Level "WARN"
Start-Sleep -Seconds 5

Start-Service -Name "PodmanNginx"

Write-Log "Servizi avviati" -Level "SUCCESS"

Write-Log "Verifica stato servizi:"
Get-Service "PodmanPostgres", "PodmanOdoo", "PodmanN8n", "PodmanNginx" | Format-Table -AutoSize

Write-Log "Installazione servizi completata." -Level "SUCCESS"
Write-Log "Gestione servizi:"
Write-Log "  - Start-Service PodmanPostgres|PodmanOdoo|PodmanN8n|PodmanNginx"
Write-Log "  - Stop-Service PodmanPostgres|PodmanOdoo|PodmanN8n|PodmanNginx"
Write-Log "  - Restart-Service PodmanPostgres|PodmanOdoo|PodmanN8n|PodmanNginx"
Write-Log "  - Get-Service PodmanPostgres|PodmanOdoo|PodmanN8n|PodmanNginx"
