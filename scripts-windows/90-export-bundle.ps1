# Esporta bundle completo per migrazione
# Include: dati container, configurazioni, scripts, .env
# Uso: .\scripts-windows\90-export-bundle.ps1 (esegui come Amministratore)

$ErrorActionPreference = "Stop"

# Carica environment e libreria
. (Join-Path $PSScriptRoot "00-env.ps1")
. (Join-Path $PSScriptRoot "lib.ps1")

Require-Administrator
Test-Command "podman"

# Crea directory exports se non esiste
$exportsDir = Join-Path $ROOT_DIR "exports"
if (-not (Test-Path $exportsDir)) {
    New-Item -ItemType Directory -Path $exportsDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bundleName = "bundle_${timestamp}.zip"
$bundlePath = Join-Path $exportsDir $bundleName

Write-Log "Esportazione bundle in: $bundlePath"

# Ferma i servizi
Write-Log "Arresto servizi Windows..."

$services = @("PodmanNginx", "PodmanN8n", "PodmanOdoo", "PodmanPostgres")
foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Log "Arresto $serviceName..."
        Stop-Service -Name $serviceName -Force
    }
}

Write-Log "Attesa arresto completo..."
Start-Sleep -Seconds 5

# Crea temp directory per staging
$tempDir = Join-Path $env:TEMP "podman_bundle_$timestamp"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Write-Log "Directory temporanea: $tempDir"

try {
    # Copia BASE_DIR (dati container)
    Write-Log "Copia dati container da $BASE_DIR..."
    $bundleBaseDir = Join-Path $tempDir "containers"
    Copy-Item -Path $BASE_DIR -Destination $bundleBaseDir -Recurse -Force

    # Copia file progetto
    Write-Log "Copia configurazioni progetto..."

    $projectFiles = @(
        ".env",
        "containerfiles",
        "scripts-windows",
        "templates"
    )

    foreach ($item in $projectFiles) {
        $srcPath = Join-Path $ROOT_DIR $item
        $dstPath = Join-Path $tempDir $item

        if (Test-Path $srcPath) {
            Write-Log "Copia $item..."
            Copy-Item -Path $srcPath -Destination $dstPath -Recurse -Force
        }
    }

    # Crea file manifest
    $manifest = @{
        timestamp = $timestamp
        hostname = $env:COMPUTERNAME
        username = $env:USERNAME
        odoo_domain = $ODOO_DOMAIN
        n8n_domain = $N8N_DOMAIN
        base_dir = $BASE_DIR
        podman_version = (podman --version)
    }

    $manifestJson = $manifest | ConvertTo-Json -Depth 10
    $manifestPath = Join-Path $tempDir "manifest.json"
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

    # Crea archivio ZIP
    Write-Log "Creazione archivio ZIP..."
    Compress-Archive -Path "$tempDir\*" -DestinationPath $bundlePath -Force

    Write-Log "Bundle esportato: $bundlePath" -Level "SUCCESS"

    $bundleSize = (Get-Item $bundlePath).Length / 1MB
    Write-Log "Dimensione bundle: $([math]::Round($bundleSize, 2)) MB"

} finally {
    # Pulizia temp directory
    if (Test-Path $tempDir) {
        Write-Log "Pulizia directory temporanea..."
        Remove-Item -Path $tempDir -Recurse -Force
    }

    # Riavvia i servizi
    Write-Log "Riavvio servizi Windows..."

    # Avvia in ordine inverso
    $servicesReverse = @("PodmanPostgres", "PodmanOdoo", "PodmanN8n", "PodmanNginx")
    foreach ($serviceName in $servicesReverse) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Avvio $serviceName..."
            Start-Service -Name $serviceName

            # Attesa tra servizi
            if ($serviceName -eq "PodmanPostgres") {
                Start-Sleep -Seconds 10
            } else {
                Start-Sleep -Seconds 3
            }
        }
    }

    Write-Log "Servizi riavviati" -Level "SUCCESS"
}

Write-Log "Esportazione completata." -Level "SUCCESS"
Write-Log "Bundle salvato in: $bundlePath"
