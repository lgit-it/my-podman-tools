# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Modular Podman-based deployment kit for running Odoo 18 + PostgreSQL 16 + n8n + Nginx on **Linux (Ubuntu)** and **Windows**. The project decomposes a monolithic setup into separately executable components for easier maintenance and migration.

**Supported Platforms:**
- **Linux**: Ubuntu 22.04/24.04/25.04 with bash scripts and systemd
- **Windows**: Windows 10/11 with PowerShell scripts and Windows Services (NSSM)

**Container Stack:**
- **Odoo 18**: Custom-built from source with venv, debugpy support for remote debugging (port 8678)
- **PostgreSQL 16**: Database server with custom init scripts and configuration
- **n8n**: Workflow automation platform
- **Nginx**: Reverse proxy with optional Let's Encrypt TLS support

## Deployment Workflow

### Linux (Ubuntu)

Scripts must be executed in numbered order as root:

```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Initialize host (install packages, create directories, generate secrets)
sudo bash scripts/10-init-host.sh

# 3. Build local container images (required for Odoo)
sudo bash scripts/20-build-images.sh

# 4. Create Podman containers
sudo bash scripts/30-create-containers.sh

# 5. Install and enable systemd services (Quadlet)
sudo bash scripts/40-install-systemd.sh

# 6. Optional: Configure Let's Encrypt TLS
sudo bash scripts/50-letsencrypt-webroot.sh
```

**Management Commands:**
```bash
# Check status of all services
sudo bash scripts/60-status.sh

# Export bundle for migration
sudo bash scripts/90-export-bundle.sh

# Import bundle on new host
sudo bash scripts/91-import-bundle.sh /path/to/bundle.tar.gz
```

### Windows (PowerShell)

Scripts must be executed in numbered order as Administrator (see [README-WINDOWS.md](README-WINDOWS.md) for detailed guide):

```powershell
# 1. Configure environment
Copy-Item .env.example.windows .env
notepad .env

# 2. Initialize host (create directories, generate secrets, pull images)
.\scripts-windows\10-init-host.ps1

# 3. Build local container images (required for Odoo)
.\scripts-windows\20-build-images.ps1

# 4. Create Podman containers
.\scripts-windows\30-create-containers.ps1

# 5. Install and enable Windows Services (via NSSM)
.\scripts-windows\40-install-services.ps1

# Optional: One-command deployment
.\deploy-windows.ps1
```

**Management Commands:**
```powershell
# Check status of all services
.\scripts-windows\60-status.ps1

# Export bundle for migration
.\scripts-windows\90-export-bundle.ps1

# Import bundle on new host
.\scripts-windows\91-import-bundle.ps1 C:\path\to\bundle.zip

# Uninstall services (preserves data)
.\scripts-windows\99-uninstall.ps1

# Uninstall services and remove data
.\scripts-windows\99-uninstall.ps1 -RemoveData
```

**Windows-Specific Notes:**
- Uses Podman Desktop with WSL2 backend
- Windows Services managed via NSSM (Non-Sucking Service Manager)
- Path format: `C:\PodmanData` instead of `/srv/containers`
- SELinux volume labels not applicable (VOLUME_LABEL should be empty)
- UID/GID permissions handled automatically by WSL2 path translation

## Architecture Patterns

### Configuration Management

**Linux (Bash)**:
- **Environment Loading**: All scripts source [scripts/00-env.sh](scripts/00-env.sh) which loads [.env](.env) and computes derived paths
- **Shared Utilities**: [scripts/lib.sh](scripts/lib.sh) provides reusable functions (`require_root`, `log`, `apt_install`, `render_template`, etc.)
- **Template Rendering**: Configuration files in [templates/](templates/) use `${VAR}` placeholders, rendered via `envsubst` or bash substitution

**Windows (PowerShell)**:
- **Environment Loading**: Scripts dot-source [scripts-windows/00-env.ps1](scripts-windows/00-env.ps1) which loads [.env](.env) and computes derived paths
- **Shared Utilities**: [scripts-windows/lib.ps1](scripts-windows/lib.ps1) provides reusable functions (`Require-Administrator`, `Write-Log`, `Invoke-RenderTemplate`, etc.)
- **Template Rendering**: Same template files in [templates/](templates/), rendered via regex replacement in PowerShell

### Secrets Management
- Secrets stored in `${SECRETS_DIR}` (default: `/srv/containers/secrets`) with mode 0700
- Generated once with `write_if_missing()` - never overwritten on re-runs
- Includes: PostgreSQL superuser password, Odoo/n8n DB passwords, n8n encryption key
- Secrets referenced via `--env-file` in container creation

### Podman Network
- All containers connected to `${PODMAN_NET}` (default: `appnet`) for internal communication
- Containers use hostnames for service discovery (postgres, odoo, n8n, nginx)
- Host port binding controlled by `BIND_LOCALHOST` (.env variable):
  - `BIND_LOCALHOST=1`: Binds to 127.0.0.1 (backend services not exposed)
  - `BIND_LOCALHOST=0`: Binds to 0.0.0.0 (all interfaces)

### Volume Permissions
- **Odoo**: Fixed UID/GID (default: 1089:1089) set via `ODOO_UID`/`ODOO_GID` in [.env](.env)
- **PostgreSQL/n8n**: UIDs extracted from images using `get_uid_from_image()` (mounts image, reads /etc/passwd)
- **SELinux**: Volume label suffix `${VOL_LBL}` (`:Z` for RHEL/Fedora, empty for Ubuntu) appended to volume mounts

### Systemd Integration (Linux)
- Uses Podman Quadlet (generates systemd units from `.container` files in `/etc/containers/systemd`)
- Service dependencies: Odoo and n8n wait for PostgreSQL via `After=`/`Requires=`
- Services enabled via `[Install]` section in Quadlet files
- Note: [scripts/40-install-systemd.sh](scripts/40-install-systemd.sh:19-79) currently has placeholder configs - actual config should match created containers

### Windows Services Integration
- Uses NSSM (Non-Sucking Service Manager) to wrap `podman start` commands as Windows Services
- Service naming: `PodmanPostgres`, `PodmanOdoo`, `PodmanN8n`, `PodmanNginx`
- Service dependencies: Odoo and n8n depend on PostgreSQL, Nginx depends on Odoo and n8n
- Services configured for automatic startup
- Logs written to `${BASE_DIR}\logs\<ServiceName>_stdout.log` and `<ServiceName>_stderr.log`
- Management via PowerShell: `Get-Service`, `Start-Service`, `Stop-Service`, `Restart-Service`

## Key File Locations

**Host-Mounted Volumes** (Linux default: `/srv/containers`, Windows default: `C:\PodmanData`):
```
/srv/containers/
├── postgres/
│   ├── data/          # PostgreSQL data directory
│   ├── conf/          # postgresql.conf, pg_hba.conf
│   └── init/          # 01-init.sql (creates odoo/n8n databases)
├── odoo/
│   ├── data/          # Filestore, sessions
│   ├── logs/          # Odoo logs
│   ├── backups/       # Database backups
│   ├── config/        # odoo.conf
│   ├── repo-standard/ # Extra addons mount point
│   └── repo-custom/   # Custom addons mount point
├── n8n/
│   └── data/          # n8n workflows and data
├── nginx/
│   ├── conf.d/        # Site configurations (odoo.conf, n8n.conf)
│   ├── snippets/      # proxy-headers.conf
│   ├── logs/          # Nginx logs
│   ├── www/           # Webroot for Let's Encrypt challenges
│   └── letsencrypt/   # TLS certificates
└── secrets/
    ├── postgres.env   # POSTGRES_PASSWORD, etc.
    ├── n8n.env        # N8N_DB_PASSWORD, N8N_ENCRYPTION_KEY, etc.
    ├── *_pass.txt     # Individual secrets (postgres_super_pass, odoo_db_pass, n8n_db_pass)
    └── *.txt          # Other generated secrets
```

**Templates**: Rendered during [scripts/10-init-host.sh](scripts/10-init-host.sh)
- PostgreSQL: [templates/postgres/01-init.sql.tpl](templates/postgres/01-init.sql.tpl) (database initialization)
- Odoo: [templates/odoo/odoo.conf.tpl](templates/odoo/odoo.conf.tpl) (Odoo configuration)
- Nginx: [templates/nginx/*.conf.tpl](templates/nginx/) (HTTP/HTTPS reverse proxy configs)
- Secrets: [templates/secrets/*.env.tpl](templates/secrets/) (environment files for containers)

## Odoo Container Details

**Build**: [containerfiles/odoo/Containerfile](containerfiles/odoo/Containerfile)
- Built from Ubuntu 24.04 with Odoo cloned from GitHub (branch via `ODOO_BRANCH`)
- Uses Python venv at `/opt/odoo/venv` (PEP 668 compatible)
- Includes debugpy for remote debugging on port 8678
- Fixed UID/GID for simplified host volume permissions

**Ports**:
- 8069: Main HTTP interface
- 8072: Longpolling/websocket
- 8678: Debugpy remote debugging (listen mode, not wait-for-client)

**Running Odoo Commands**:
```bash
# Enter Odoo container
podman exec -it odoo bash

# Run odoo-bin directly (as odoo user inside container)
podman exec -u odoo odoo python3 /opt/odoo/odoo/odoo-bin --help

# Update module list
podman exec -u odoo odoo python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf -u base --stop-after-init

# Install module
podman exec -u odoo odoo python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf -i module_name --stop-after-init
```

## Debugging and Troubleshooting

**Container Logs**:
```bash
podman logs -f postgres
podman logs -f odoo
podman logs -f n8n
podman logs -f nginx
```

**Service Status (Linux)**:
```bash
systemctl status postgres.service
systemctl status odoo.service
systemctl status n8n.service
systemctl status nginx.service
```

**Service Status (Windows)**:
```powershell
Get-Service PodmanPostgres, PodmanOdoo, PodmanN8n, PodmanNginx
.\scripts-windows\60-status.ps1
```

**Remote Debugging Odoo** (VSCode):
- Odoo container runs debugpy on 0.0.0.0:8678
- Add launch.json configuration with `"host": "localhost"`, `"port": 8678`, `"pathMappings": [{"localRoot": "${workspaceFolder}", "remoteRoot": "/opt/odoo/odoo"}]`

**Nginx Configuration Changes**:
- Edit files in `/srv/containers/nginx/conf.d/`
- Reload: `podman exec nginx nginx -s reload`
- Test config: `podman exec nginx nginx -t`

## Migration and Backup

**Export Process** ([scripts/90-export-bundle.sh](scripts/90-export-bundle.sh)):
1. Stops all systemd services
2. Creates tar.gz of `${BASE_DIR}`, `.env`, templates, containerfiles, scripts
3. Restarts services
4. Bundle saved to `./exports/bundle_YYYYMMDD_HHMMSS.tar.gz`

**Import Process** ([scripts/91-import-bundle.sh](scripts/91-import-bundle.sh)):
1. Extracts bundle to root filesystem
2. Recreates directory structure
3. Ready for container recreation and systemd installation

**Note**: Import assumes clean target host; run [scripts/10-init-host.sh](scripts/10-init-host.sh) first if packages/podman network missing.

## Important Environment Variables

See [.env.example](.env.example) for all options. Key variables:

- `ODOO_DOMAIN`, `N8N_DOMAIN`: Hostnames for Nginx reverse proxy
- `ENABLE_LETSENCRYPT`: Enable TLS certificate automation (0 or 1)
- `ODOO_BRANCH`: Odoo git branch to clone (default: 18.0)
- `BASE_DIR`: Root directory for all persistent data (default: /srv/containers)
- `BIND_LOCALHOST`: Bind ports to 127.0.0.1 (1) or 0.0.0.0 (0)
- `VOLUME_LABEL`: SELinux label suffix (`:Z` for RHEL/Fedora, empty for Ubuntu)
- `ODOO_UID`/`ODOO_GID`: User/group ID for Odoo (must match host user owning odoo volumes)

## Modification Guidelines

**Adding/Changing Services**:
1. Update [.env.example](.env.example) with new configuration variables
2. Add/modify Containerfile in [containerfiles/](containerfiles/)
3. Update [scripts/20-build-images.sh](scripts/20-build-images.sh) to build new image
4. Add container creation logic in [scripts/30-create-containers.sh](scripts/30-create-containers.sh)
5. Add Quadlet config in [scripts/40-install-systemd.sh](scripts/40-install-systemd.sh)
6. Update export/import scripts if new volumes needed

**Changing Odoo Version**:
1. Update `ODOO_BRANCH` in [.env](.env)
2. Rebuild image: `sudo bash scripts/20-build-images.sh`
3. Recreate container: `sudo bash scripts/30-create-containers.sh`
4. Restart service: `sudo systemctl restart odoo.service`

**Script Development (Linux)**:
- Always source [scripts/00-env.sh](scripts/00-env.sh) first (loads `.env` + computed paths)
- Import [scripts/lib.sh](scripts/lib.sh) for shared utilities
- Use `require_root` at script start for sudo-required operations
- Use `log()` for timestamped output
- Use `write_if_missing()` to avoid overwriting existing configs/secrets
- Use `render_template()` for config file generation from templates

**Script Development (Windows)**:
- Always dot-source [scripts-windows/00-env.ps1](scripts-windows/00-env.ps1) first: `. .\scripts-windows\00-env.ps1`
- Import [scripts-windows/lib.ps1](scripts-windows/lib.ps1) for shared utilities
- Use `Require-Administrator` at script start for admin-required operations
- Use `Write-Log` for timestamped output with color coding
- Use `Write-IfMissing` to avoid overwriting existing configs/secrets
- Use `Invoke-RenderTemplate` for config file generation from templates

## Cross-Platform Considerations

### Path Conventions

| Aspect | Linux | Windows |
|--------|-------|---------|
| Base directory | `/srv/containers` | `C:\PodmanData` |
| Path separator | `/` (slash) | `\` (backslash) |
| .env example file | `.env.example` | `.env.example.windows` |
| Scripts directory | `scripts/` | `scripts-windows/` |

### Service Management

| Aspect | Linux | Windows |
|--------|-------|---------|
| Service manager | systemd | NSSM (Windows Services) |
| Service names | `postgres`, `odoo`, `n8n`, `nginx` | `PodmanPostgres`, `PodmanOdoo`, `PodmanN8n`, `PodmanNginx` |
| Start service | `systemctl start odoo` | `Start-Service PodmanOdoo` |
| Stop service | `systemctl stop odoo` | `Stop-Service PodmanOdoo` |
| Service status | `systemctl status odoo` | `Get-Service PodmanOdoo` |

### Volume Permissions

| Aspect | Linux | Windows |
|--------|-------|---------|
| UID/GID | Explicit via `chown` | Automatic via WSL2 translation |
| SELinux labels | `:Z` suffix required on RHEL/Fedora | Not applicable (leave empty) |
| Ownership | Must match container user | Handled transparently |

### Bundle Migration

**Linux → Linux**: Direct import, no changes needed
**Windows → Windows**: Direct import, verify paths in `.env`
**Linux → Windows**:
1. Extract bundle
2. Modify `.env`: change paths from `/srv/containers` to `C:\PodmanData`
3. Set `VOLUME_LABEL=` (empty, no SELinux)
4. Run Windows deployment scripts

**Windows → Linux**:
1. Extract bundle
2. Modify `.env`: change paths from `C:\PodmanData` to `/srv/containers`
3. Set `VOLUME_LABEL=:Z` if on RHEL/Fedora, or empty for Ubuntu
4. Run Linux deployment scripts

### Development Workflow

When modifying the project to support both platforms:

1. **Containerfiles**: Remain identical (Linux-based, work on both)
2. **Templates**: Remain identical (same config file format)
3. **Scripts**: Maintain parallel implementations
   - Bash scripts in `scripts/` for Linux
   - PowerShell scripts in `scripts-windows/` for Windows
4. **.env files**: Provide platform-specific examples
   - `.env.example` for Linux (Unix paths)
   - `.env.example.windows` for Windows (Windows paths)
5. **Documentation**:
   - [README.md](README.md) focuses on Linux
   - [README-WINDOWS.md](README-WINDOWS.md) focuses on Windows
   - [CLAUDE.md](CLAUDE.md) covers both platforms

### Podman Backend Differences

**Linux**: Native Podman running directly on the host
**Windows**: Podman Desktop with WSL2 backend (Linux VM inside Windows)

Implications:
- Performance on Windows may be slightly lower due to WSL2 overhead
- File I/O on Windows goes through WSL2 translation layer
- Network binding on Windows requires firewall rules for external access
- Container images are the same (Linux-based) on both platforms

**Script Development (Windows)**:
- Always dot-source [scripts-windows/00-env.ps1](scripts-windows/00-env.ps1) first: `. .\scripts-windows\00-env.ps1`
- Import [scripts-windows/lib.ps1](scripts-windows/lib.ps1) for shared utilities
- Use `Require-Administrator` at script start for admin-required operations
- Use `Write-Log` for timestamped output with color coding
- Use `Write-IfMissing` to avoid overwriting existing configs/secrets
- Use `Invoke-RenderTemplate` for config file generation from templates

## Cross-Platform Considerations

### Path Conventions

| Aspect | Linux | Windows |
|--------|-------|---------|
| Base directory | `/srv/containers` | `C:\PodmanData` |
| Path separator | `/` (slash) | `\` (backslash) |
| .env example file | `.env.example` | `.env.example.windows` |
| Scripts directory | `scripts/` | `scripts-windows/` |

### Service Management

| Aspect | Linux | Windows |
|--------|-------|---------|
| Service manager | systemd | NSSM (Windows Services) |
| Service names | `postgres`, `odoo`, `n8n`, `nginx` | `PodmanPostgres`, `PodmanOdoo`, `PodmanN8n`, `PodmanNginx` |
| Start service | `systemctl start odoo` | `Start-Service PodmanOdoo` |
| Stop service | `systemctl stop odoo` | `Stop-Service PodmanOdoo` |
| Service status | `systemctl status odoo` | `Get-Service PodmanOdoo` |

### Volume Permissions

| Aspect | Linux | Windows |
|--------|-------|---------|
| UID/GID | Explicit via `chown` | Automatic via WSL2 translation |
| SELinux labels | `:Z` suffix required on RHEL/Fedora | Not applicable (leave empty) |
| Ownership | Must match container user | Handled transparently |

### Bundle Migration

**Linux → Linux**: Direct import, no changes needed
**Windows → Windows**: Direct import, verify paths in `.env`
**Linux → Windows**:
1. Extract bundle
2. Modify `.env`: change paths from `/srv/containers` to `C:\PodmanData`
3. Set `VOLUME_LABEL=` (empty, no SELinux)
4. Run Windows deployment scripts

**Windows → Linux**:
1. Extract bundle
2. Modify `.env`: change paths from `C:\PodmanData` to `/srv/containers`
3. Set `VOLUME_LABEL=:Z` if on RHEL/Fedora, or empty for Ubuntu
4. Run Linux deployment scripts

### Development Workflow

When modifying the project to support both platforms:

1. **Containerfiles**: Remain identical (Linux-based, work on both)
2. **Templates**: Remain identical (same config file format)
3. **Scripts**: Maintain parallel implementations
   - Bash scripts in `scripts/` for Linux
   - PowerShell scripts in `scripts-windows/` for Windows
4. **.env files**: Provide platform-specific examples
   - `.env.example` for Linux (Unix paths)
   - `.env.example.windows` for Windows (Windows paths)
5. **Documentation**:
   - [README.md](README.md) focuses on Linux
   - [README-WINDOWS.md](README-WINDOWS.md) focuses on Windows
   - [CLAUDE.md](CLAUDE.md) covers both platforms

### Podman Backend Differences

**Linux**: Native Podman running directly on the host
**Windows**: Podman Desktop with WSL2 backend (Linux VM inside Windows)

Implications:
- Performance on Windows may be slightly lower due to WSL2 overhead
- File I/O on Windows goes through WSL2 translation layer
- Network binding on Windows requires firewall rules for external access
- Container images are the same (Linux-based) on both platforms
