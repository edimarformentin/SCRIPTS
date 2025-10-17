#!/usr/bin/env bash
set -euo pipefail
CONFIG="/home/edimar/SCRIPTS/00-configuracao-central.sh"
[ -f "$CONFIG" ] || { echo "ERRO: $CONFIG não encontrado"; exit 1; }

if ! grep -q "build_stream_path()" "$CONFIG"; then
  cat <<'FUNC' >> "$CONFIG"

# --------------------------------------------------------------------------------
# build_stream_path TENANT CAMERA_NAME
# - Sempre prefixa com 'live/'
# - Se TENANT vier vazio, usa 'live/<camera>'
# - Normaliza CAMERA_NAME para slug seguro (sem espaços)
build_stream_path() {
  local tenant="${1:-}"
  local cam="${2:-}"
  cam="$(echo "$cam" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  if [ -n "$tenant" ]; then
    echo "live/$tenant/$cam"
  else
    echo "live/$cam"
  fi
}
# --------------------------------------------------------------------------------
FUNC
  echo ">> build_stream_path() adicionada ao $CONFIG"
else
  echo ">> build_stream_path() já existe no $CONFIG (OK)"
fi
