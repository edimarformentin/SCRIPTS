#!/usr/bin/env bash
set -euo pipefail
CONFIG="/home/edimar/SCRIPTS/00-configuracao-central.sh"; [ -f "$CONFIG" ] && source "$CONFIG" || true

MEDIAMTX_API_URL="${MEDIAMTX_API_URL:-http://localhost:9997/v3}"
MEDIAMTX_HLS_HTTP="${MEDIAMTX_INTERNAL_HLS:-http://vaas-mediamtx:8888}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-http://localhost:8080}"
LIVE_PREFIX="${LIVE_PREFIX:-live}"
CURL_BIN="${CURL_BIN:-curl}"

http_code() { ${CURL_BIN} -s -o /dev/null -w "%{http_code}" "$1" 2>/dev/null || echo "000"; }

echo ">> Consultando paths em: ${MEDIAMTX_API_URL}/paths/list"
JSON="$(${CURL_BIN} -s "${MEDIAMTX_API_URL}/paths/list" || true)"
[ -n "$JSON" ] || { echo "ERRO: não foi possível obter paths/list"; exit 1; }

NAMES=()
if command -v jq >/dev/null 2>&1; then
  mapfile -t NAMES < <(echo "$JSON" | jq -r '.items[]?.name // .[]?.name' 2>/dev/null | sed '/^null$/d')
else
  mapfile -t NAMES < <(echo "$JSON" | sed -n 's/.*"name":"\([^"]\+\)".*/\1/p')
fi
[ "${#NAMES[@]}" -gt 0 ] || { echo "Nenhum path encontrado."; exit 0; }

printf "\n%-35s %-9s %-9s %-10s %-s\n" "PATH" "prefixOK" "HLS-UP" "NGINX" "SUGESTAO"
printf "%0.s-" {1..100}; echo

for NAME in "${NAMES[@]}"; do
  NORM="${NAME#${LIVE_PREFIX}/}"
  HAS_PREFIX="NO"; [ "$NAME" != "$NORM" ] && HAS_PREFIX="YES"
  URL_MTX="${MEDIAMTX_HLS_HTTP%/}/${NAME}/index.m3u8"
  URL_NGX="${PUBLIC_BASE_URL%/}/${LIVE_PREFIX}/${NORM}/index.m3u8"
  CODE_MTX="$(http_code "$URL_MTX")"
  CODE_NGX="$(http_code "$URL_NGX")"
  printf "%-35s %-9s %-9s %-10s %-s\n" "$NAME" "$HAS_PREFIX" "$CODE_MTX" "$CODE_NGX" "padronizar '${LIVE_PREFIX}/${NORM}'"
done

echo
echo "Legenda: HLS-UP = NGINX->MediaMTX (internal) / NGINX = público."
