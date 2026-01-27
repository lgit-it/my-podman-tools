# Script di deployment completo per Windows
# Esegue tutti gli step in sequenza
# Uso: .\deploy-windows.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Verifica privilegi amministratore
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRORE: Questo script richiede privilegi di Amministratore." -ForegroundColor Red
    Write-Host "Tasto destro su PowerShell > 'Esegui come amministratore'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DEPLOYMENT PODMAN STACK SU WINDOWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ROOT_DIR = $PSScriptRoot

# Verifica che .env esista
$envFile = Join-Path $ROOT_DIR ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "File .env non trovato!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Crealo da .env.example.windows:" -ForegroundColor Yellow
    Write-Host "  Copy-Item .env.example.windows .env" -ForegroundColor Yellow
    Write-Host "  notepad .env" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "File .env trovato: $envFile" -ForegroundColor Green
Write-Host ""

# Chiedi conferma
Write-Host "Questo script eseguira' i seguenti passaggi:" -ForegroundColor Yellow
Write-Host "  1. Inizializzazione host (directory, segreti, network)" -ForegroundColor White
Write-Host "  2. Build immagini container custom (Odoo, Nginx)" -ForegroundColor White
Write-Host "  3. Creazione container Podman" -ForegroundColor White
Write-Host "  4. Installazione servizi Windows" -ForegroundColor White
Write-Host "  5. Verifica stato finale" -ForegroundColor White
Write-Host ""

$response = Read-Host "Continuare? (yes/no)"
if ($response -ne "yes") {
    Write-Host "Deployment annullato." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 1: Init Host
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 1: INIZIALIZZAZIONE HOST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script1 = Join-Path $ROOT_DIR "scripts-windows\10-init-host.ps1"
& $script1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRORE durante inizializzazione host" -ForegroundColor Red
    exit 1
}

# Step 2: Build Images
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: BUILD IMMAGINI" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script2 = Join-Path $ROOT_DIR "scripts-windows\20-build-images.ps1"
& $script2

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRORE durante build immagini" -ForegroundColor Red
    exit 1
}

# Step 3: Create Containers
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: CREAZIONE CONTAINER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script3 = Join-Path $ROOT_DIR "scripts-windows\30-create-containers.ps1"
& $script3

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRORE durante creazione container" -ForegroundColor Red
    exit 1
}

# Step 4: Install Services
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: INSTALLAZIONE SERVIZI WINDOWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script4 = Join-Path $ROOT_DIR "scripts-windows\40-install-services.ps1"
& $script4

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRORE durante installazione servizi" -ForegroundColor Red
    exit 1
}

# Step 5: Status Check
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: VERIFICA STATO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Attesa per stabilizzazione servizi
Write-Host "Attesa stabilizzazione servizi (15 secondi)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

$script5 = Join-Path $ROOT_DIR "scripts-windows\60-status.ps1"
& $script5

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " DEPLOYMENT COMPLETATO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "I servizi sono ora attivi e configurati per avvio automatico." -ForegroundColor Green
Write-Host ""
Write-Host "PROSSIMI PASSI:" -ForegroundColor Yellow
Write-Host "  - Accedi a Odoo: http://localhost:8069" -ForegroundColor White
Write-Host "  - Accedi a n8n: http://localhost:5678" -ForegroundColor White
Write-Host "  - Configura domini DNS per accesso pubblico" -ForegroundColor White
Write-Host "  - (Opzionale) Configura Let's Encrypt per HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "GESTIONE SERVIZI:" -ForegroundColor Yellow
Write-Host "  - Stato: .\scripts-windows\60-status.ps1" -ForegroundColor White
Write-Host "  - Start: Start-Service Podman*" -ForegroundColor White
Write-Host "  - Stop: Stop-Service Podman*" -ForegroundColor White
Write-Host "  - Logs: podman logs -f <container-name>" -ForegroundColor White
Write-Host ""
