#!/usr/bin/env bash
set -euo pipefail
log(){ printf "\033[1;36m[90]\033[0m %s\n" "$*"; }
CLIENTE="${CLIENTE:-TESTECLIENTE}"
CAMERA="${CAMERA:-cam01}"

if docker ps --format '{{.Names}}' | grep -q 'gestao_web'; then
  log "Testando Playback /list via gestao_web -> mediamtx:9996"
  docker exec "$(docker ps --format '{{.Names}}' | grep -m1 gestao_web)" \
    curl -fsS "http://mediamtx:9996/list?path=live/${CLIENTE}/${CAMERA}&start=2025-01-01T00:00:00Z&end=2030-01-01T00:00:00Z" >/dev/null || true
fi
log "Smoke-test básico executado"
