#!/usr/bin/env bash
set -euo pipefail
log(){ printf "\033[1;36m[00]\033[0m %s\n" "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
    echo "[00] sudo não encontrado e você não é root."; exit 1; fi
fi

if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y curl ca-certificates git jq
elif command -v dnf >/dev/null 2>&1; then
  $SUDO dnf install -y curl ca-certificates git jq
elif command -v pacman >/dev/null 2>&1; then
  $SUDO pacman -Sy --noconfirm curl ca-certificates git jq
elif command -v zypper >/dev/null 2>&1; then
  $SUDO zypper install -y curl ca-certificates git jq
else
  log "Gerenciador de pacotes não detectado (prosseguindo)."
fi

if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker || true
  if getent group docker >/dev/null 2>&1; then
    $SUDO usermod -aG docker "$USER" || true
    log "Talvez precise relogar para grupo docker."
  fi
else
  log "Docker OK"
fi

if docker compose version >/dev/null 2>&1; then
  log "'docker compose' OK"
elif command -v docker-compose >/dev/null 2>&1; then
  log "Usando docker-compose legado"
else
  log "AVISO: plugin docker compose não detectado."
fi
