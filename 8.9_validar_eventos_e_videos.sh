#!/usr/bin/env bash
set -euo pipefail

echo "== Health dos vídeos de evento =="
curl -s http://127.0.0.1:8000/health/event-videos || true
echo -e "\n"

BASE_HOST="/home/edimar/SISTEMA/FRIGATE"
UID="edimar-rdk18"
EVBASE="$BASE_HOST/$UID/events"

JPG=$(find "$EVBASE" -type f -name "*.jpg" | sort | tail -n 1 || true)
if [ -z "${JPG:-}" ]; then
  echo "[AVISO] Nenhum snapshot encontrado em $EVBASE ainda."
  exit 0
fi

REL="${JPG#${BASE_HOST}/}"                         # edimar-rdk18/...
JPG_URL="/media_files/FRIGATE/${REL}"              # caminho servido pelo web
echo "[info] JPG escolhido: $JPG_URL"

echo "== /api/event-video =="
RESP=$(curl -s --get --data-urlencode "jpg=${JPG_URL}" http://127.0.0.1:8000/api/event-video || true)
echo "$RESP"

VID=$(echo "$RESP" | sed -n 's/.*"url"[ ]*:[ ]*"\([^"]*\)".*/\1/p')
if [ -z "${VID:-}" ]; then
  echo "[ERRO] API não retornou URL de vídeo."
  exit 1
fi

echo -e "\n== HEAD no MP4 =="
curl -I "http://127.0.0.1:8000${VID}" || true
