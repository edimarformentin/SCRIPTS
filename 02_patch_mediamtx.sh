#!/usr/bin/env bash
set -euo pipefail
log(){ printf "\033[1;36m[02]\033[0m %s\n" "$*"; }

# Fallback: se SISTEMA_DIR não vier do instalador, resolve por caminho do script
if [ -z "${SISTEMA_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
  SISTEMA_DIR="${PROJECT_ROOT}/SISTEMA"
fi

MM_CFG="${SISTEMA_DIR}/MEDIAMTX/mediamtx.yml"
[ -f "${MM_CFG}" ] || { log "mediamtx.yml não encontrado em ${MM_CFG}"; exit 1; }

# 1) Habilitar Playback e garantir gravação em 2m
if ! grep -qE '^[[:space:]]*playback:[[:space:]]*yes' "${MM_CFG}"; then
  cat <<'EOCONF' >> "${MM_CFG}"

###############################################
# Playback server
playback: yes
playbackAddress: :9996
EOCONF
  log "Playback habilitado"
else
  log "Playback já habilitado"
fi

if ! grep -qE '^recordSegmentDuration:' "${MM_CFG}"; then
  cat <<'EOPATCH' >> "${MM_CFG}"

# --- Parâmetros de gravação ---
record: yes
recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S
recordFormat: fmp4
recordPartDuration: 1s
recordSegmentDuration: 2m
recordDeleteAfter: 0s
EOPATCH
  log "Parâmetros de gravação aplicados"
else
  log "Parâmetros de gravação já presentes"
fi

# 2) Sincronizar para o caminho que o compose do GESTAO_WEB monta
GW_MEDIAMTX_DIR="${SISTEMA_DIR}/GESTAO_WEB/MEDIAMTX"
mkdir -p "${GW_MEDIAMTX_DIR}"
cp -f "${MM_CFG}" "${GW_MEDIAMTX_DIR}/mediamtx.yml"
log "Sincronizado: ${GW_MEDIAMTX_DIR}/mediamtx.yml"

# 3) Garantir pasta de gravações no host
mkdir -p "${SISTEMA_DIR}/GRAVACOES"

# 4) Override só com porta 9996 + volume GRAVACOES (sem mapear mediamtx.yml)
cat > "${SISTEMA_DIR}/docker-compose.override.yml" <<'EOOVR'
services:
  mediamtx:
    ports:
      - "9996:9996"
    volumes:
      - ./GRAVACOES:/recordings/live
EOOVR
log "Override criado/atualizado (9996 e volume GRAVACOES)"
