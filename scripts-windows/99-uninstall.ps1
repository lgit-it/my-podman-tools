# Disinstalla servizi Windows e rimuove container
# ATTENZIONE: Questo script NON rimuove i dati in BASE_DIR
# Uso: .\scripts-windows\99-uninstall.ps1 (esegui come Amministratore)

param(
    [switch]$RemoveData = $false
)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

Require-Administrator

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host " DISINSTALLAZIONE PODMAN STACK" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

Write-Host "Questo script eseguira':" -ForegroundColor Yellow
Write-Host "  1. Arresto e rimozione servizi Windows" -ForegroundColor White
Write-Host "  2. Arresto e rimozione container Podman" -ForegroundColor White
Write-Host "  3. Rimozione immagini custom (opzionale)" -ForegroundColor White

if ($RemoveData) {
    Write-Host "  4. RIMOZIONE DATI in $BASE_DIR (FLAG -RemoveData attivo!)" -ForegroundColor Red
} else {
    Write-Host "  4. Dati in $BASE_DIR verranno preservati" -ForegroundColor Green
}

Write-Host ""
Write-Host "ATTENZIONE: Questa operazione non puo' essere annullata!" -ForegroundColor Red
Write-Host ""

$response = Read-Host "Continuare con la disinstallazione? (yes/no)"
if ($response -ne "yes") {
    Write-Host "Disinstallazione annullata." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 1: Rimuovi servizi Windows
Write-Log "Rimozione servizi Windows..."

$services = @("PodmanNginx", "PodmanN8n", "PodmanOdoo", "PodmanPostgres")

foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        Write-Log "Rimozione servizio: $serviceName"

        # Ferma servizio
        if ($service.Status -eq "Running") {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        }

        # Attesa
        Start-Sleep -Seconds 2

        # Rimuovi con NSSM
        if (Get-Command nssm -ErrorAction SilentlyContinue) {
            nssm remove $serviceName confirm
        } else {
            Write-Log "NSSM non trovato, usa sc.exe" -Level "WARN"
            sc.exe delete $serviceName
        }

        Write-Log "Servizio $serviceName rimosso" -Level "SUCCESS"
    } else {
        Write-Log "Servizio $serviceName non trovato" -Level "WARN"
    }
}

# Step 2: Ferma e rimuovi container
Write-Log "Arresto e rimozione container Podman..."

$containers = @("nginx", "n8n", "odoo", "postgres")

foreach ($containerName in $containers) {
    Write-Log "Rimozione container: $containerName"

    # Stop
    podman stop $containerName 2>$null

    # Remove
    podman rm -f $containerName 2>$null

    Write-Log "Container $containerName rimosso" -Level "SUCCESS"
}

# Step 3: Rimuovi immagini custom (chiedi conferma)
Write-Host ""
$removeImages = Read-Host "Rimuovere anche le immagini custom? (yes/no)"

if ($removeImages -eq "yes") {
    Write-Log "Rimozione immagini custom..."

    $images = @(
        "local/odoo-custom:$ODOO_BRANCH",
        "local/nginx-proxy:latest"
    )

    foreach ($imageName in $images) {
        Write-Log "Rimozione immagine: $imageName"
        podman rmi -f $imageName 2>$null
    }

    Write-Log "Immagini custom rimosse" -Level "SUCCESS"
}

# Step 4: Rimuovi dati (solo se flag attivo)
if ($RemoveData) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " ATTENZIONE: RIMOZIONE DATI" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stai per rimuovere TUTTI I DATI in: $BASE_DIR" -ForegroundColor Red
    Write-Host "Questa operazione e' IRREVERSIBILE!" -ForegroundColor Red
    Write-Host ""

    $confirmDelete = Read-Host "Confermi la rimozione dei dati? Digita 'DELETE' per confermare"

    if ($confirmDelete -eq "DELETE") {
        Write-Log "Rimozione dati in $BASE_DIR..." -Level "WARN"

        if (Test-Path $BASE_DIR) {
            Remove-Item -Path $BASE_DIR -Recurse -Force
            Write-Log "Dati rimossi" -Level "SUCCESS"
        } else {
            Write-Log "Directory $BASE_DIR non trovata" -Level "WARN"
        }
    } else {
        Write-Log "Rimozione dati annullata, dati preservati" -Level "WARN"
    }
} else {
    Write-Log "Dati in $BASE_DIR preservati (usa -RemoveData per rimuoverli)" -Level "SUCCESS"
}

# Step 5: Rimuovi network Podman (opzionale)
Write-Host ""
$removeNetwork = Read-Host "Rimuovere network Podman '$PODMAN_NET'? (yes/no)"

if ($removeNetwork -eq "yes") {
    Write-Log "Rimozione network: $PODMAN_NET"
    podman network rm $PODMAN_NET 2>$null
    Write-Log "Network rimossa" -Level "SUCCESS"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " DISINSTALLAZIONE COMPLETATA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (-not $RemoveData) {
    Write-Host "I dati sono ancora presenti in: $BASE_DIR" -ForegroundColor Yellow
    Write-Host "Per reinstallare:" -ForegroundColor Green
    Write-Host "  1. .\scripts-windows\20-build-images.ps1" -ForegroundColor White
    Write-Host "  2. .\scripts-windows\30-create-containers.ps1" -ForegroundColor White
    Write-Host "  3. .\scripts-windows\40-install-services.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Per rimuovere anche i dati:" -ForegroundColor Yellow
    Write-Host "  .\scripts-windows\99-uninstall.ps1 -RemoveData" -ForegroundColor White
}

Write-Host ""
