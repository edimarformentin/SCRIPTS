#!/usr/bin/env bash
set -euo pipefail

BASE="${FRIGATE_BASE:-/home/edimar/SISTEMA/FRIGATE}"
UID_DIR="${BASE}/edimar-rdk18"         # único id atual
CAM="${1:-cam1}"                       # passe cam1/cam2/cam3/cam4 se quiser
EVENTS="${UID_DIR}/events/${CAM}"
RECS="${UID_DIR}/media/recordings"

if [ ! -d "$RECS" ]; then
  echo "[ERRO] Não achei recordings em $RECS"
  exit 1
fi

mkdir -p "$EVENTS"

# pega o segmento mais recente desta câmera (última hora do dia atual)
LAST_SEG=$(find "$RECS" -type f -path "*/$(date -u +%Y-%m-%d)/*/${CAM}/*.mp4" | sort | tail -n 1 || true)
if [ -z "${LAST_SEG:-}" ]; then
  # se não achou no dia UTC atual, pega qualquer um
  LAST_SEG=$(find "$RECS" -type f -path "*/${CAM}/*.mp4" | sort | tail -n 1 || true)
fi

if [ -z "${LAST_SEG:-}" ]; then
  echo "[ERRO] Não encontrei nenhum segmento mp4 para ${CAM} em ${RECS}"
  exit 1
fi

# timestamp UTC "agora" para nome do arquivo
TS=$(date -u +%Y%m%d_%H%M%S)
SNAP="${EVENTS}/${TS}_teste.jpg"

echo "[INFO] Extraindo frame de ${LAST_SEG} -> ${SNAP}"
ffmpeg -hide_banner -nostdin -y -i "${LAST_SEG}" -frames:v 1 -q:v 2 "${SNAP}" >/dev/null 2>&1 || {
  echo "[ERRO] ffmpeg falhou pra extrair frame."
  exit 1
}

echo "[OK] Snapshot criado: ${SNAP}"
