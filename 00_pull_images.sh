#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'
log(){ printf "\033[1;36m[00-pull]\033[0m %s\n" "$*"; }
: "${SISTEMA_DIR:?SISTEMA_DIR não definido}"
cd "${SISTEMA_DIR}"

mapfile -t FOUND < <(find . -maxdepth 3 -type f \( \
  -iname 'docker-compose.yml' -o -iname 'docker-compose.yaml' -o \
  -iname 'compose.yml'        -o -iname 'compose.yaml'        -o \
  -iname 'docker-compose.*.yml' -o -iname 'docker-compose.*.yaml' \
\) | sort)

OVR="./docker-compose.override.yml"
if [ -f "${OVR}" ]; then
  # remove se já estiver na lista para evitar duplicata e adiciona por último
  FOUND=( $(printf "%s\n" "${FOUND[@]}" | grep -v -x "${OVR}" || true) )
  FOUND+=("${OVR}")
fi

# dedup final
FOUND=( $(printf "%s\n" "${FOUND[@]}" | awk '!seen[$0]++') )

if [ "${#FOUND[@]}" -eq 0 ]; then
  log "Nenhum compose encontrado em ${PWD}"
  log "Dica: find ${SISTEMA_DIR} -maxdepth 3 -name '*compose*.y*ml' -print"
  exit 0
fi

log "Composes detectados:"
for f in "${FOUND[@]}"; do log " - ${f}"; done

ARGS=""
for f in "${FOUND[@]}"; do ARGS="$ARGS -f '$f'"; done

log "docker compose pull ($ARGS)"
# shellcheck disable=SC2086
eval docker compose $ARGS pull || true
