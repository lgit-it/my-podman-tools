# Deployment Podman su Windows

Guida per il deployment di Odoo 18 + PostgreSQL 16 + n8n + Nginx su **Windows** usando **Podman Desktop** e **PowerShell**.

## Indice

- [Prerequisiti](#prerequisiti)
- [Installazione](#installazione)
- [Configurazione](#configurazione)
- [Deployment](#deployment)
- [Gestione Servizi](#gestione-servizi)
- [Troubleshooting](#troubleshooting)
- [Migrazione](#migrazione)
- [Differenze con Linux](#differenze-con-linux)

## Prerequisiti

### Software Richiesto

1. **Windows 10/11** (build 19041 o superiore per WSL2)
2. **PowerShell 5.1+** (incluso in Windows) o **PowerShell 7+** (consigliato)
3. **Podman Desktop** con backend WSL2
4. **NSSM** (Non-Sucking Service Manager) - installato automaticamente dagli script

### Installazione Podman Desktop

1. Scarica Podman Desktop da: https://podman-desktop.io/downloads
2. Installa seguendo la procedura guidata
3. Avvia Podman Desktop e completa la configurazione iniziale
4. Verifica l'installazione:

```powershell
podman --version
```

### Configurazione WSL2 (se necessario)

Se Podman Desktop richiede WSL2 ma non è installato:

```powershell
# Abilita WSL2
wsl --install

# Riavvia il computer
# Dopo il riavvio, imposta WSL2 come versione predefinita
wsl --set-default-version 2
```

### Installazione Package Manager (opzionale)

Per installare NSSM automaticamente, è consigliato avere **winget** (incluso in Windows 11) o **Chocolatey**:

#### Winget (Windows 11, già incluso)
```powershell
# Verifica installazione
winget --version
```

#### Chocolatey (Windows 10/11)
```powershell
# Installa Chocolatey (esegui come Amministratore)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

## Installazione

### 1. Clone o Download del Repository

```powershell
# Clone con git
git clone <repository-url>
cd my-podman-tools

# Oppure scarica e estrai lo ZIP del repository
```

### 2. Configurazione PowerShell Execution Policy

Per eseguire gli script PowerShell, potresti dover modificare la policy di esecuzione:

```powershell
# Verifica policy corrente
Get-ExecutionPolicy

# Se Restricted, imposta su RemoteSigned (consigliato)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Configurazione

### 1. Crea file .env

```powershell
# Copia il template Windows
Copy-Item .env.example.windows .env

# Modifica con il tuo editor preferito
notepad .env
```

### 2. Variabili Importanti da Configurare

Apri [.env](.env) e modifica:

```ini
# Domini pubblici (configurali nel tuo DNS)
ODOO_DOMAIN=odoo.tuodominio.it
N8N_DOMAIN=n8n.tuodominio.it

# Directory dati (usa path Windows-style)
BASE_DIR=C:\PodmanData
SECRETS_DIR=C:\PodmanData\secrets

# Porte (modifica se hai conflitti)
POSTGRES_HOST_PORT=5432
ODOO_HOST_PORT=8069
ODOO_LONGPOLL_HOST_PORT=8072
N8N_HOST_PORT=5678
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# Bind localhost (1=solo 127.0.0.1, 0=tutte le interfacce)
BIND_LOCALHOST=1

# Let's Encrypt (0=disabilitato, 1=abilitato)
ENABLE_LETSENCRYPT=0
LETSENCRYPT_EMAIL=admin@tuodominio.it
```

**IMPORTANTE**: Su Windows usa sempre path Windows-style:
- ✅ Corretto: `C:\PodmanData`
- ❌ Errato: `/srv/containers` o `C:/PodmanData`

## Deployment

### Workflow Completo

Esegui gli script **in ordine** come **Amministratore**:

#### 1. Inizializza Host

```powershell
# Apri PowerShell come Amministratore
# Tasto destro su PowerShell > "Esegui come amministratore"

cd C:\path\to\my-podman-tools
.\scripts-windows\10-init-host.ps1
```

Questo script:
- Crea directory in `BASE_DIR`
- Genera segreti casuali
- Configura Podman network
- Pull immagini base (PostgreSQL, n8n, Nginx)
- Renderizza template configurazioni

#### 2. Build Immagini Custom

```powershell
.\scripts-windows\20-build-images.ps1
```

Questo script:
- Builda immagine Odoo custom da source
- Builda immagine Nginx custom

#### 3. Crea Container

```powershell
.\scripts-windows\30-create-containers.ps1
```

Questo script:
- Rimuove container esistenti
- Crea nuovi container per PostgreSQL, Odoo, n8n, Nginx
- Configura volumi e network

#### 4. Installa Servizi Windows

```powershell
.\scripts-windows\40-install-services.ps1
```

Questo script:
- Installa NSSM (se mancante)
- Crea servizi Windows per tutti i container
- Configura dipendenze tra servizi
- Avvia automaticamente i servizi

#### 5. Verifica Stato

```powershell
.\scripts-windows\60-status.ps1
```

Output:
```
========================================
 STATO SERVIZI WINDOWS
========================================

PodmanPostgres : Running
PodmanOdoo : Running
PodmanN8n : Running
PodmanNginx : Running

========================================
 STATO CONTAINER PODMAN
========================================

NAMES       STATUS       PORTS
postgres    Up 2 minutes 127.0.0.1:5432->5432/tcp
odoo        Up 2 minutes 127.0.0.1:8069->8069/tcp, ...
n8n         Up 2 minutes 127.0.0.1:5678->5678/tcp
nginx       Up 2 minutes 0.0.0.0:80->80/tcp, ...
```

### Accesso alle Applicazioni

Dopo il deployment:

- **Odoo**: http://localhost:8069
- **n8n**: http://localhost:5678
- **PostgreSQL**: localhost:5432

Se hai configurato domini e Nginx:
- **Odoo**: http://odoo.tuodominio.it
- **n8n**: http://n8n.tuodominio.it

## Gestione Servizi

### Comandi PowerShell (esegui come Amministratore)

```powershell
# Visualizza stato
Get-Service Podman*

# Avvia tutti i servizi
Start-Service PodmanPostgres, PodmanOdoo, PodmanN8n, PodmanNginx

# Ferma tutti i servizi
Stop-Service PodmanNginx, PodmanN8n, PodmanOdoo, PodmanPostgres

# Riavvia un servizio
Restart-Service PodmanOdoo

# Avvia servizio singolo
Start-Service PodmanOdoo

# Ferma servizio singolo
Stop-Service PodmanOdoo
```

### Gestione via Services.msc

1. Premi `Win + R`
2. Digita `services.msc`
3. Cerca servizi che iniziano con "Podman"
4. Tasto destro > Start/Stop/Restart

### Comandi Podman Diretti

```powershell
# Visualizza container
podman ps -a

# Logs container
podman logs -f odoo
podman logs -f postgres
podman logs -f n8n
podman logs -f nginx

# Entra nel container
podman exec -it odoo bash
podman exec -it postgres bash

# Esegui comando in container
podman exec -u odoo odoo python3 /opt/odoo/odoo/odoo-bin --help
```

## Troubleshooting

### Problema: Script non si esegue

**Errore**: "impossibile caricare il file perché l'esecuzione di script è disabilitata"

**Soluzione**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problema: Podman non trovato

**Errore**: "comando podman non trovato"

**Soluzione**:
1. Verifica installazione Podman Desktop
2. Riavvia PowerShell
3. Controlla PATH:
```powershell
$env:Path
```

### Problema: Errore permessi directory

**Errore**: "Accesso negato" durante creazione directory

**Soluzione**: Esegui PowerShell come Amministratore

### Problema: Porta già in uso

**Errore**: "bind: address already in use"

**Soluzione**:
1. Modifica porte in [.env](.env)
2. Oppure trova processo che usa la porta:
```powershell
# Trova processo su porta 8069
Get-NetTCPConnection -LocalPort 8069 | Select-Object OwningProcess
Get-Process -Id <PID>
```

### Problema: Servizi non si avviano

**Soluzione**:
```powershell
# Verifica logs servizio
Get-EventLog -LogName Application -Source "PodmanOdoo" -Newest 10

# Oppure leggi logs NSSM
Get-Content C:\PodmanData\logs\PodmanOdoo_stderr.log -Tail 50
```

### Problema: Container non comunica

**Soluzione**:
```powershell
# Verifica network Podman
podman network inspect appnet

# Ricrea network
podman network rm appnet
podman network create appnet

# Ricrea container
.\scripts-windows\30-create-containers.ps1
```

## Migrazione

### Esporta da Host Windows

```powershell
# Esegui come Amministratore
.\scripts-windows\90-export-bundle.ps1
```

Output: `exports\bundle_YYYYMMDD_HHMMSS.zip`

Il bundle contiene:
- Tutti i dati container (`C:\PodmanData`)
- File `.env`
- Configurazioni (`templates/`)
- Containerfiles
- Scripts

### Importa su Nuovo Host Windows

```powershell
# Copia bundle su nuovo host
# Esegui come Amministratore

.\scripts-windows\91-import-bundle.ps1 C:\path\to\bundle_YYYYMMDD_HHMMSS.zip
```

Dopo l'import:
```powershell
# 1. Verifica .env
notepad .env

# 2. Build immagini
.\scripts-windows\20-build-images.ps1

# 3. Crea container
.\scripts-windows\30-create-containers.ps1

# 4. Installa servizi
.\scripts-windows\40-install-services.ps1

# 5. Verifica
.\scripts-windows\60-status.ps1
```

### Migrazione Linux → Windows

Se hai un bundle esportato da Linux:

1. Estrai bundle su Windows
2. Modifica `.env`:
   - Cambia path da `/srv/containers` a `C:\PodmanData`
   - Rimuovi o svuota `VOLUME_LABEL`
3. Segui procedura import normale

## Differenze con Linux

### Path e Filesystem

| Linux | Windows |
|-------|---------|
| `/srv/containers` | `C:\PodmanData` |
| `/` (slash) | `\` (backslash) |
| Case-sensitive | Case-insensitive |

### Gestione Servizi

| Linux | Windows |
|-------|---------|
| systemd | Windows Services (NSSM) |
| `systemctl start odoo` | `Start-Service PodmanOdoo` |
| `systemctl status odoo` | `Get-Service PodmanOdoo` |
| `journalctl -u odoo` | `podman logs odoo` |

### Permessi e UID/GID

Su Linux i permessi sono gestiti esplicitamente con `chown`. Su Windows con Podman Desktop (WSL2 backend), la traduzione path Windows↔WSL2 gestisce automaticamente i permessi.

### SELinux

Non applicabile su Windows. La variabile `VOLUME_LABEL` viene ignorata (lasciala vuota).

### Networking

Podman Desktop su Windows usa WSL2 come backend, quindi la rete funziona come su Linux ma con un layer di traduzione.

## Comandi Utili

### Backup Manuale

```powershell
# Ferma servizi
Stop-Service PodmanNginx, PodmanN8n, PodmanOdoo, PodmanPostgres

# Backup directory dati
Compress-Archive -Path C:\PodmanData -DestinationPath C:\backup\podman_backup_$(Get-Date -Format 'yyyyMMdd').zip

# Riavvia servizi
Start-Service PodmanPostgres, PodmanOdoo, PodmanN8n, PodmanNginx
```

### Pulizia Completa

```powershell
# Ferma e rimuovi servizi
Stop-Service PodmanNginx, PodmanN8n, PodmanOdoo, PodmanPostgres
nssm remove PodmanPostgres confirm
nssm remove PodmanOdoo confirm
nssm remove PodmanN8n confirm
nssm remove PodmanNginx confirm

# Rimuovi container
podman stop postgres odoo n8n nginx
podman rm -f postgres odoo n8n nginx

# Rimuovi immagini (opzionale)
podman rmi local/odoo-custom:18.0
podman rmi local/nginx-proxy:latest

# Rimuovi dati (ATTENZIONE!)
Remove-Item -Path C:\PodmanData -Recurse -Force
```

### Aggiornamento Odoo

```powershell
# 1. Modifica .env (se cambi branch)
notepad .env

# 2. Ferma servizi
Stop-Service PodmanOdoo

# 3. Rebuild immagine
.\scripts-windows\20-build-images.ps1

# 4. Ricrea container
.\scripts-windows\30-create-containers.ps1

# 5. Riavvia servizio
Start-Service PodmanOdoo
```

## Supporto

Per problemi o domande:
- Controlla i logs: `podman logs <container-name>`
- Verifica configurazione: `.\scripts-windows\60-status.ps1`
- Consulta documentazione Podman Desktop: https://podman-desktop.io/docs

## Licenza

Vedi [LICENSE](LICENSE) file.
