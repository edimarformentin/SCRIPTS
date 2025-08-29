#!/usr/bin/env bash
set -euo pipefail

BASE="${FRIGATE_BASE:-/home/edimar/SISTEMA/FRIGATE}"
LIMIT="${LIMIT:-0}"   # 0 = processar todos; >0 = limita a N
PRE="${EVENT_PRESECONDS:-12}"
POST="${EVENT_POSTSECONDS:-12}"

echo "== Verificador de eventos sem vídeo =="
echo "BASE=$BASE  PRE=${PRE}s  POST=${POST}s  LIMIT=$LIMIT"
echo

# 1) listar .jpg sem .mp4
MISSING_LIST="/tmp/_missing_event_videos.txt"
> "$MISSING_LIST"

COUNT_TOTAL=0
COUNT_MISSING=0

while IFS= read -r JPG; do
  COUNT_TOTAL=$((COUNT_TOTAL+1))
  MP4="${JPG%.jpg}.mp4"
  if [ ! -f "$MP4" ]; then
    echo "$JPG" >> "$MISSING_LIST"
    COUNT_MISSING=$((COUNT_MISSING+1))
  fi
done < <(find "$BASE" -type f -path "*/events/*/*.jpg" | sort)

echo "[sumário] snapshots totais: $COUNT_TOTAL"
echo "[sumário] sem vídeo:        $COUNT_MISSING"
[ "$COUNT_MISSING" -eq 0 ] && { echo "[ok] Nada a corrigir."; exit 0; }

echo
echo "[lista] primeiros 20 sem vídeo:"
head -n 20 "$MISSING_LIST" || true

# 2) Quer corrigir agora?
if [ "${FIX_NOW:-1}" = "1" ]; then
  echo
  echo "[ação] Rodando assembler para corrigir (LIMIT=$LIMIT)..."
  FRIGATE_BASE="$BASE" \
  EVENT_PRESECONDS="$PRE" \
  EVENT_POSTSECONDS="$POST" \
  python3 /home/edimar/SCRIPTS/event_assembler_host.py --limit "$LIMIT" --verbose 1
  echo
  echo "[ação] Recontando após correção..."
  NEW_MISSING=$(awk '{mp4=$0; sub(/\.jpg$/, ".mp4", mp4); if (system("[ -f \"" mp4 "\" ]")==256) print $0 }' "$MISSING_LIST" | wc -l)
  echo "[sumário] ainda sem vídeo: $NEW_MISSING (antes: $COUNT_MISSING)"
fi
