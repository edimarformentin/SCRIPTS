#!/usr/bin/env bash
set -euo pipefail
log(){ printf "\033[1;36m[04]\033[0m %s\n" "$*"; }
: "${SISTEMA_DIR:?SISTEMA_DIR não definido}"

if [ -f "${SISTEMA_DIR}/docker-compose.yml" ]; then
  log "Down + prune (compose raiz)"
  (cd "${SISTEMA_DIR}" && docker compose down -v || true)
fi
if [ -f "${SISTEMA_DIR}/docker-compose.vaas.yml" ]; then
  log "Down + prune (compose vaas)"
  (cd "${SISTEMA_DIR}" && docker compose -f docker-compose.vaas.yml down -v || true)
fi
docker image prune -f || true
