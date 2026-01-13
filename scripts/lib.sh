#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Esegui come root (es. sudo -i)"; exit 1
  fi
}

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends "$@"
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERRORE: comando mancante: $1" >&2; exit 1; }
}

rand_b64() { openssl rand -base64 32; }

write_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    umask 077
    mkdir -p "$(dirname "$path")"
    printf "%s\n" "$content" > "$path"
  fi
}

# Legge UID di un utente da un'immagine SENZA eseguire comandi dentro al container.
get_uid_from_image() {
  local image="$1"
  local username="$2"

  local mnt uid
  mnt="$(podman image mount "${image}")"

  if [[ ! -f "${mnt}/etc/passwd" ]]; then
    echo "ERROR: ${image} non contiene ${mnt}/etc/passwd (mount: ${mnt})" >&2
    podman image unmount "${image}" >/dev/null 2>&1 || podman image umount "${image}" >/dev/null 2>&1 || true
    return 1
  fi

  uid="$(grep -E "^${username}:" "${mnt}/etc/passwd" | head -n1 | cut -d: -f3 || true)"

  podman image unmount "${image}" >/dev/null 2>&1 || podman image umount "${image}" >/dev/null 2>&1 || true

  if [[ -z "${uid}" ]]; then
    echo "ERROR: utente '${username}' non trovato in /etc/passwd dell’immagine ${image}" >&2
    return 1
  fi

  echo "${uid}"
}

# Render semplice con envsubst (se disponibile) o sostituzione bash per placeholder ${VAR}
render_template() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"

  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$src" > "$dst"
  else
    # Fallback: sostituzioni minime (richiede che i placeholder siano ${VAR})
    local tmp
    tmp="$(cat "$src")"
    # sostituisce solo variabili presenti nell'ambiente
    while IFS='=' read -r k _; do
      [[ -z "$k" ]] && continue
      tmp="${tmp//\$\{${k}\}/${!k}}"
    done < <(env | cut -d= -f1 | sort -u | sed 's/$/=/' )
    printf "%s" "$tmp" > "$dst"
  fi
}
