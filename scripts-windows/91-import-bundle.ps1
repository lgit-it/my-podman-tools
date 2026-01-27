# Importa bundle esportato su nuovo host Windows
# Estrae dati e configurazioni
# Uso: .\scripts-windows\91-import-bundle.ps1 <path_to_bundle.zip> (esegui come Amministratore)

param(
    [Parameter(Mandatory=$true)]
    [string]$BundlePath
)

$ErrorActionPreference = "Stop"

# Funzioni di utilità base (prima di caricare lib.ps1)
function Write-LogBasic {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Verifica privilegi amministratore
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-LogBasic "Questo script richiede privilegi di Amministratore." -Level "ERROR"
    exit 1
}

# Verifica che il bundle esista
if (-not (Test-Path $BundlePath)) {
    Write-LogBasic "Bundle non trovato: $BundlePath" -Level "ERROR"
    exit 1
}

$bundleFullPath = Resolve-Path $BundlePath
Write-LogBasic "Importazione bundle: $bundleFullPath"

# Determina ROOT_DIR (directory corrente dello script)
$ROOT_DIR = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

# Crea temp directory per estrazione
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempDir = Join-Path $env:TEMP "podman_import_$timestamp"

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-LogBasic "Directory temporanea: $tempDir"

try {
    # Estrai bundle
    Write-LogBasic "Estrazione bundle..."
    Expand-Archive -Path $bundleFullPath -DestinationPath $tempDir -Force

    # Leggi manifest
    $manifestPath = Join-Path $tempDir "manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-LogBasic "Manifest trovato:"
        Write-LogBasic "  - Timestamp: $($manifest.timestamp)"
        Write-LogBasic "  - Hostname origine: $($manifest.hostname)"
        Write-LogBasic "  - Odoo Domain: $($manifest.odoo_domain)"
        Write-LogBasic "  - n8n Domain: $($manifest.n8n_domain)"
        Write-LogBasic "  - Base DIR origine: $($manifest.base_dir)"
    } else {
        Write-LogBasic "Manifest non trovato nel bundle" -Level "WARN"
    }

    # Verifica che .env sia presente nel bundle
    $envPath = Join-Path $tempDir ".env"
    if (-not (Test-Path $envPath)) {
        Write-LogBasic "File .env non trovato nel bundle" -Level "ERROR"
        exit 1
    }

    # Copia .env nel progetto (se non esiste già)
    $targetEnvPath = Join-Path $ROOT_DIR ".env"
    if (-not (Test-Path $targetEnvPath)) {
        Write-LogBasic "Copia .env nel progetto..."
        Copy-Item -Path $envPath -Destination $targetEnvPath -Force
    } else {
        Write-LogBasic ".env già presente, non sovrascritto" -Level "WARN"
        Write-LogBasic "Backup creato: ${targetEnvPath}.backup"
        Copy-Item -Path $targetEnvPath -Destination "${targetEnvPath}.backup" -Force
        Copy-Item -Path $envPath -Destination $targetEnvPath -Force
    }

    # Carica environment per BASE_DIR
    . (Join-Path $ROOT_DIR "scripts-windows\00-env.ps1")
    . (Join-Path $ROOT_DIR "scripts-windows\lib.ps1")

    Write-LogBasic "BASE_DIR target: $BASE_DIR"

    # Verifica se BASE_DIR esiste e contiene dati
    if (Test-Path $BASE_DIR) {
        Write-LogBasic "BASE_DIR già esistente: $BASE_DIR" -Level "WARN"

        # Chiedi conferma
        $response = Read-Host "Sovrascrivere? I dati esistenti saranno persi! (yes/no)"
        if ($response -ne "yes") {
            Write-LogBasic "Importazione annullata" -Level "WARN"
            exit 0
        }

        # Backup directory esistente
        $backupDir = "${BASE_DIR}_backup_$timestamp"
        Write-LogBasic "Backup di BASE_DIR esistente in: $backupDir"
        Move-Item -Path $BASE_DIR -Destination $backupDir -Force
    }

    # Crea BASE_DIR
    New-Item -ItemType Directory -Path $BASE_DIR -Force | Out-Null

    # Copia dati container
    $bundleContainersDir = Join-Path $tempDir "containers"
    if (Test-Path $bundleContainersDir) {
        Write-LogBasic "Copia dati container in $BASE_DIR..."
        Copy-Item -Path "$bundleContainersDir\*" -Destination $BASE_DIR -Recurse -Force
        Write-LogBasic "Dati container copiati" -Level "SUCCESS"
    } else {
        Write-LogBasic "Directory containers non trovata nel bundle" -Level "ERROR"
        exit 1
    }

    # Copia containerfiles
    $bundleContainerfiles = Join-Path $tempDir "containerfiles"
    if (Test-Path $bundleContainerfiles) {
        $targetContainerfiles = Join-Path $ROOT_DIR "containerfiles"
        Write-LogBasic "Copia containerfiles..."
        if (Test-Path $targetContainerfiles) {
            Remove-Item -Path $targetContainerfiles -Recurse -Force
        }
        Copy-Item -Path $bundleContainerfiles -Destination $targetContainerfiles -Recurse -Force
    }

    # Copia templates
    $bundleTemplates = Join-Path $tempDir "templates"
    if (Test-Path $bundleTemplates) {
        $targetTemplates = Join-Path $ROOT_DIR "templates"
        Write-LogBasic "Copia templates..."
        if (Test-Path $targetTemplates) {
            Remove-Item -Path $targetTemplates -Recurse -Force
        }
        Copy-Item -Path $bundleTemplates -Destination $targetTemplates -Recurse -Force
    }

    # Copia scripts-windows (se presente nel bundle, altrimenti mantieni quelli attuali)
    $bundleScripts = Join-Path $tempDir "scripts-windows"
    if (Test-Path $bundleScripts) {
        $targetScripts = Join-Path $ROOT_DIR "scripts-windows"
        Write-LogBasic "Copia scripts-windows..."
        # Backup degli script correnti
        if (Test-Path $targetScripts) {
            $scriptsBackup = "${targetScripts}_backup_$timestamp"
            Copy-Item -Path $targetScripts -Destination $scriptsBackup -Recurse -Force
            Write-LogBasic "Backup scripts correnti: $scriptsBackup"
        }
        Copy-Item -Path $bundleScripts -Destination $targetScripts -Recurse -Force
    }

    Write-LogBasic "Importazione completata." -Level "SUCCESS"
    Write-LogBasic ""
    Write-LogBasic "PROSSIMI PASSI:"
    Write-LogBasic "1. Verifica .env e modifica se necessario"
    Write-LogBasic "2. Esegui: .\scripts-windows\20-build-images.ps1"
    Write-LogBasic "3. Esegui: .\scripts-windows\30-create-containers.ps1"
    Write-LogBasic "4. Esegui: .\scripts-windows\40-install-services.ps1"
    Write-LogBasic "5. Verifica: .\scripts-windows\60-status.ps1"

} finally {
    # Pulizia temp directory
    if (Test-Path $tempDir) {
        Write-LogBasic "Pulizia directory temporanea..."
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
