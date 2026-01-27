# PowerShell Utility Library
# Funzioni condivise per gli script di deployment
# Uso: . .\scripts-windows\lib.ps1

$ErrorActionPreference = "Stop"

# Verifica che lo script sia eseguito come Amministratore
function Require-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Error "Questo script richiede privilegi di Amministratore. Esegui PowerShell come Amministratore."
        exit 1
    }
}

# Log con timestamp
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Verifica che un comando esista
function Test-Command {
    param(
        [string]$CommandName
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Log "ERRORE: comando mancante: $CommandName" -Level "ERROR"
        exit 1
    }
}

# Genera stringa random base64
function New-RandomBase64 {
    param(
        [int]$Length = 32
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()

    return [Convert]::ToBase64String($bytes)
}

# Genera stringa random hex
function New-RandomHex {
    param(
        [int]$Length = 32
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()

    return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ''
}

# Scrive file solo se non esiste
function Write-IfMissing {
    param(
        [string]$Path,
        [string]$Content
    )

    if (-not (Test-Path $Path)) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Scrivi file con UTF8 senza BOM
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))

        # Imposta permessi restrittivi (solo owner)
        $acl = Get-Acl $Path
        $acl.SetAccessRuleProtection($true, $false)
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl

        Write-Log "File creato: $Path" -Level "SUCCESS"
    }
}

# Ottiene UID da immagine Podman (non applicabile direttamente su Windows)
# Su Windows Podman Desktop usa WSL2, quindi gli UID/GID sono gestiti internamente
# Questa funzione è un placeholder per compatibilità
function Get-UidFromImage {
    param(
        [string]$Image,
        [string]$Username
    )

    Write-Log "Get-UidFromImage non necessario su Windows (gestito da WSL2 backend)" -Level "WARN"
    return "1000"  # Default UID
}

# Render template sostituendo variabili ${VAR}
function Invoke-RenderTemplate {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Log "Template non trovato: $SourcePath" -Level "ERROR"
        exit 1
    }

    $content = Get-Content -Path $SourcePath -Raw

    # Sostituisci ${VAR} con valori dall'ambiente
    $content = [regex]::Replace($content, '\$\{([^}]+)\}', {
        param($match)
        $varName = $match.Groups[1].Value
        $value = Get-Variable -Name $varName -ValueOnly -Scope Script -ErrorAction SilentlyContinue

        if ($null -eq $value) {
            $value = [Environment]::GetEnvironmentVariable($varName)
        }

        if ($null -eq $value) {
            Write-Log "Variabile non trovata: $varName" -Level "WARN"
            return $match.Value
        }

        return $value
    })

    $dir = Split-Path -Parent $DestinationPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($DestinationPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Log "Template renderizzato: $SourcePath -> $DestinationPath" -Level "SUCCESS"
}

# Installa pacchetto con winget o chocolatey
function Install-Package {
    param(
        [string]$PackageName,
        [string]$WingetId = "",
        [string]$ChocoName = ""
    )

    # Preferisci winget se disponibile
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $id = if ($WingetId) { $WingetId } else { $PackageName }
        Write-Log "Installazione $PackageName con winget..."
        winget install --id=$id --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        $name = if ($ChocoName) { $ChocoName } else { $PackageName }
        Write-Log "Installazione $PackageName con chocolatey..."
        choco install $name -y
    } else {
        Write-Log "Nessun package manager trovato (winget o chocolatey)" -Level "ERROR"
        exit 1
    }
}

Write-Host "Library functions loaded" -ForegroundColor Green
