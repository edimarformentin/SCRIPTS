#!/usr/bin/env bash
set -euo pipefail
# Carrega config central (seu arquivo original) e, se existir, um extra opcional só do MediaMTX
source /home/edimar/SCRIPTS/00-configuracao-central.sh
[ -f /home/edimar/SCRIPTS/00-config-mediamtx-extra.sh ] && source /home/edimar/SCRIPTS/00-config-mediamtx-extra.sh

gen_paths_block() {
  # Fallback: mantém comportamento atual (dinâmico desligado)
  local fallback="paths:
  all:
    source: publisher"

  # Só tenta gerar dinamicamente se habilitado
  if [ "${MEDIAMTX_DYNAMIC_PATHS:-no}" != "yes" ]; then
    echo "$fallback"
    return 0
  fi

  if [ -z "${MEDIAMTX_PATHS_SQL:-}" ]; then
    log "MEDIAMTX_DYNAMIC_PATHS=yes mas MEDIAMTX_PATHS_SQL está vazio. Usando fallback."
    echo "$fallback"
    return 0
  fi

  local psql_env=( "PGHOST=${VAAS_DB_HOST:-127.0.0.1}" "PGPORT=${VAAS_DB_PORT:-5432}" "PGDATABASE=${VAAS_DB_NAME:-vaas}" "PGUSER=${VAAS_DB_USER:-vaas}" "PGPASSWORD=${VAAS_DB_PASS:-vaas}" )
  local paths
  if ! paths=$(env "${psql_env[@]}" "${PSQL_BIN:-psql}" -qAt -c "${MEDIAMTX_PATHS_SQL}" 2>/dev/null | sed '/^[[:space:]]*$/d'); then
    log "Falha ao executar SQL dos paths. Usando fallback."
    echo "$fallback"
    return 0
  fi
  if [ -z "$paths" ]; then
    log "SQL não retornou paths. Usando fallback."
    echo "$fallback"
    return 0
  fi

  echo "paths:"
  echo "$paths" | while IFS= read -r p; do
    p="$(echo "$p" | sed 's/[[:space:]]\+$//')"
    [ -z "$p" ] && continue
    printf "  %s:\n    source: publisher\n" "$p"
  done
}

log "Gerando configuração do MediaMTX em ${MEDIAMTX_CONFIG}"
PATHS_BLOCK="$(gen_paths_block)"

cat > "${MEDIAMTX_CONFIG}" << MTX
# ===== VAAS / MediaMTX =====
# Control API
api: yes
# apiAddress: 127.0.0.1:9997  # opcional

# Observabilidade
metrics: yes
pprof: yes

# Autenticação interna para Control API
authInternalUsers:
  - user: ${MEDIAMTX_API_USER:-admin}
    pass: ${MEDIAMTX_API_PASS:-supersecreta}
    permissions:
      - action: api
        path: ""

# ===== Paths =====
${PATHS_BLOCK}
MTX

log "Subindo contêiner ${MEDIAMTX_CONTAINER:-vaas-mediamtx} (${MEDIAMTX_IMAGE:-bluenviron/mediamtx:1.14.0})"
docker_rm_if_exists "${MEDIAMTX_CONTAINER:-vaas-mediamtx}"

docker run -d \
  --name "${MEDIAMTX_CONTAINER:-vaas-mediamtx}" \
  --restart unless-stopped \
  -p 0.0.0.0:${MEDIAMTX_PORT_RTMP:-1935}:1935 \
  -p 0.0.0.0:${MEDIAMTX_PORT_RTSP:-8554}:8554 \
  -p 0.0.0.0:${MEDIAMTX_PORT_HLS:-8888}:8888 \
  -p 0.0.0.0:${MEDIAMTX_PORT_API:-9997}:9997 \
  -p 0.0.0.0:${MEDIAMTX_PORT_METRICS:-9998}:9998 \
  -p 0.0.0.0:${MEDIAMTX_PORT_PPROF:-9999}:9999 \
  -p 0.0.0.0:${MEDIAMTX_PORT_SRT:-8890}:8890/udp \
  -v "${MEDIAMTX_CONFIG}:/mediamtx.yml:rw" \
  "${MEDIAMTX_IMAGE:-bluenviron/mediamtx:1.14.0}"

log "Aguardando inicialização (3s)..."
sleep 3

log "Teste de saúde da Control API"
set +e
HTTP_CODE=$(curl -s -u "${MEDIAMTX_API_USER:-admin}:${MEDIAMTX_API_PASS:-supersecreta}" -o /dev/null -w "%{http_code}" "http://127.0.0.1:${MEDIAMTX_PORT_API:-9997}/v3/paths/list")
set -e
if [ "$HTTP_CODE" != "200" ]; then
  log "ERRO: Control API não respondeu 200 (respondeu ${HTTP_CODE}). Verifique logs com: docker logs ${MEDIAMTX_CONTAINER:-vaas-mediamtx}"
  exit 1
fi
log "Control API OK (HTTP 200)."
