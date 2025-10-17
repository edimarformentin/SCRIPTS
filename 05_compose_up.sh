#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'
log(){ printf "\033[1;36m[05]\033[0m %s\n" "$*"; }

# Fallback: se SISTEMA_DIR não vier do instalador, resolve por caminho do script
if [ -z "${SISTEMA_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
  SISTEMA_DIR="${PROJECT_ROOT}/SISTEMA"
fi

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

if [ "${#FOUND[@]}" -eq 0 ]; then
  log "Nenhum compose encontrado em ${PWD}"
  exit 0
fi

log "Composes detectados:"
for f in "${FOUND[@]}"; do log " - ${f}"; done

ARGS=""
for f in "${FOUND[@]}"; do ARGS="$ARGS -f '$f'"; done

log "docker compose up -d --build ($ARGS)"
# shellcheck disable=SC2086
eval docker compose $ARGS up -d --build
