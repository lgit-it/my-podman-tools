# Odoo 18 + Postgres 16 + n8n + Nginx su Podman (kit “a pezzi”)

Questo pacchetto scompone lo script monolitico in componenti eseguibili separatamente:

1. **Ambiente e variabili**: `.env` + `scripts/00-env.sh`
2. **Containerfile** (e build immagini locali): `containerfiles/*` + `scripts/20-build-images.sh`
3. **Creazione container + servizi systemd**: `scripts/30-create-containers.sh` + `scripts/40-install-systemd.sh`
4. **(Opzionale) TLS Let's Encrypt**: `scripts/50-letsencrypt-webroot.sh`
5. **Export/Import per migrazione host**: `scripts/90-export-bundle.sh` + `scripts/91-import-bundle.sh`

## Prerequisiti
- Ubuntu (testato su 22.04/24.04/25.04) con accesso root (o sudo).
- DNS dei domini già puntato all’IP del server (se usi TLS).

## Quick start (ordine suggerito)
```bash


# 1) configura variabili
cp .env.example .env
nano .env

# 2) prepara host (install pacchetti, directory, secrets, config)
sudo bash scripts/10-init-host.sh

# 3) build immagini locali (obbligatorio per Odoo)
sudo bash scripts/20-build-images.sh

# 4) crea i container
sudo bash scripts/30-create-containers.sh

# 5) installa e abilita servizi systemd
sudo bash scripts/40-install-systemd.sh

# 6) (opzionale) TLS Let's Encrypt (webroot)
sudo bash scripts/50-letsencrypt-webroot.sh
```

## Volumi host (Odoo)
Il kit espone (per default) queste directory (modificabili in `.env`):
- `odoo/data`  -> `/var/lib/odoo` (filestore + sessioni)
- `odoo/logs`  -> `/var/log/odoo`
- `odoo/backups` -> `/var/lib/odoo/backups`
- `odoo/repo-standard` -> `/mnt/extra-addons`
- `odoo/repo-custom` -> `/mnt/custom-addons`
- `odoo/config/odoo.conf` -> `/etc/odoo/odoo.conf`

## Nginx e n8n
- Nginx usa `nginx/conf.d/` e `nginx/snippets/` su host.
- n8n usa `n8n/data/` su host e `secrets/n8n.env` per config/env.

## Export / migrazione
Per creare un bundle trasferibile:
```bash
sudo bash scripts/90-export-bundle.sh
# genera un tar.gz in ./exports/
```
Sul nuovo host:
```bash
# copia il tar.gz sul nuovo host e poi:
sudo bash scripts/91-import-bundle.sh /path/to/export.tar.gz
```

## Note su SELinux (:Z)
Il parametro `:Z` è utile su host con SELinux (RHEL/Fedora). Su Ubuntu di norma non serve.
Nel kit è controllato da `VOLUME_LABEL` in `.env` (default vuoto).
