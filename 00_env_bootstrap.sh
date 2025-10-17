#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'
log(){ printf "\033[1;36m[00-env]\033[0m %s\n" "$*"; }

# Fallback: se SISTEMA_DIR não vier do instalador
if [ -z "${SISTEMA_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
  SISTEMA_DIR="${PROJECT_ROOT}/SISTEMA"
fi

cd "${SISTEMA_DIR}"
ENV_FILE="${SISTEMA_DIR}/.env"

# 1) cria .env se não existir (defaults seguros)
if [ ! -f "${ENV_FILE}" ]; then
  cat > "${ENV_FILE}" <<'EODEF'
# --- Auto-gerado por 00_env_bootstrap.sh ---
COMPOSE_PROJECT_NAME=vaas
TZ=America/Sao_Paulo
# Playback interno usado pela UI de Gravações
MEDIAMTX_PLAYBACK_URL=http://mediamtx:9996
EODEF
  log "Criado .env básico em ${ENV_FILE}"
else
  log ".env já existe (mantido)"
fi

# 2) coleta variáveis referenciadas nos composes até 3 níveis
mapfile -t COMPOSES < <(find . -maxdepth 3 -type f \( \
  -iname 'docker-compose.yml' -o -iname 'docker-compose.yaml' -o \
  -iname 'compose.yml'        -o -iname 'compose.yaml'        -o \
  -iname 'docker-compose.*.yml' -o -iname 'docker-compose.*.yaml' \
\) | sort)
[ -f "./docker-compose.override.yml" ] && COMPOSES+=("./docker-compose.override.yml")

if [ "${#COMPOSES[@]}" -eq 0 ]; then
  log "Nenhum compose para analisar variáveis (ok)."
  exit 0
fi

TMPVARS="$(grep -rhoE '\$\{[A-Za-z_][A-Za-z0-9_:-?]*\}' "${COMPOSES[@]}" | sed -E 's/^\$\{([A-Za-z_][A-Za-z0-9_]*).*/\1/' | sort -u || true)"

# 3) acrescenta placeholders para variáveis ausentes
for v in ${TMPVARS}; do
  grep -qE "^${v}=" "${ENV_FILE}" 2>/dev/null && continue
  {
    echo "# auto: detectado no compose"
    echo "${v}="
  } >> "${ENV_FILE}"
done

log "Bootstrap do .env finalizado."
