#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'
log(){ printf "\033[1;36m[01]\033[0m %s\n" "$*"; }

# Fallback: se SISTEMA_DIR não vier do instalador, resolve por caminho do script
if [ -z "${SISTEMA_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
  SISTEMA_DIR="${PROJECT_ROOT}/SISTEMA"
fi

# 0) se existir, derruba TODOS os composes (até 3 níveis), incluindo override
if [ -d "${SISTEMA_DIR}" ]; then
  log "SISTEMA existe; iniciando teardown + backup"
  cd "${SISTEMA_DIR}"
  mapfile -t FOUND < <(find . -maxdepth 3 -type f \( \
    -iname 'docker-compose.yml' -o -iname 'docker-compose.yaml' -o \
    -iname 'compose.yml'        -o -iname 'compose.yaml'        -o \
    -iname 'docker-compose.*.yml' -o -iname 'docker-compose.*.yaml' \
  \) | sort)
  OVR="./docker-compose.override.yml"
  if [ -f "${OVR}" ]; then
    FOUND=( $(printf "%s\n" "${FOUND[@]}" | grep -v -x "${OVR}" || true) )
    FOUND+=("${OVR}")
  fi
  FOUND=( $(printf "%s\n" "${FOUND[@]}" | awk '!seen[$0]++') )

  if [ "${#FOUND[@]}" -gt 0 ]; then
    ARGS=""
    for f in "${FOUND[@]}"; do ARGS="$ARGS -f '$f'"; done
    log "Derrubando stack(s): docker compose down -v ($ARGS)"
    # shellcheck disable=SC2086
    eval docker compose $ARGS down -v || true
  else
    log "Nenhum compose para derrubar (ok)."
  fi
else
  log "SISTEMA não existe; será clonado limpo"
fi

# 1) Backup do que precisa preservar
TS="$(date +%Y%m%d-%H%M%S)"
BKP_PARENT="$(dirname "${SISTEMA_DIR}")"
BKP_DIR="${BKP_PARENT}/SISTEMA_BKP_${TS}"
mkdir -p "${BKP_DIR}"

if [ -d "${SISTEMA_DIR}/GRAVACOES" ]; then
  log "Preservando GRAVACOES -> ${BKP_DIR}/GRAVACOES"
  mv "${SISTEMA_DIR}/GRAVACOES" "${BKP_DIR}/GRAVACOES"
fi

# Preserva também BANCO (especialmente BANCO/data)
if [ -d "${SISTEMA_DIR}/BANCO" ]; then
  log "Preservando BANCO -> ${BKP_DIR}/BANCO"
  mv "${SISTEMA_DIR}/BANCO" "${BKP_DIR}/BANCO"
fi

# 2) Remove diretório SISTEMA e clona limpo
if [ -d "${SISTEMA_DIR}" ]; then
  log "Removendo ${SISTEMA_DIR}"
  rm -rf "${SISTEMA_DIR}"
fi

REPO_URL="https://github.com/edimarformentin/SISTEMA"
log "Clonando para ${SISTEMA_DIR}"
git clone "${REPO_URL}" "${SISTEMA_DIR}"
log "Clone OK"

# 3) Restaura itens preservados
# GRAVACOES
if [ -d "${BKP_DIR}/GRAVACOES" ]; then
  log "Restaurando GRAVACOES"
  mv "${BKP_DIR}/GRAVACOES" "${SISTEMA_DIR}/GRAVACOES"
else
  mkdir -p "${SISTEMA_DIR}/GRAVACOES"
fi

# BANCO/data (se você NÃO quiser restaurar o banco, comente este bloco)
if [ -d "${BKP_DIR}/BANCO" ]; then
  log "Restaurando BANCO (inclui data)"
  # cria BANCO se não existir
  mkdir -p "${SISTEMA_DIR}/BANCO"
  # move tudo de volta (normalmente data/)
  shopt -s dotglob
  mv "${BKP_DIR}/BANCO"/* "${SISTEMA_DIR}/BANCO/" || true
  shopt -u dotglob
fi

log "Fetch OK"
