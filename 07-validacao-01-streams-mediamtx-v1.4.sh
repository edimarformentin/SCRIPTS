#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

log "Validador simples de streams (ffprobe) v1.4 instalado."
# Mantido para uso futuro como CLI, se necessário.
# Exemplo: ./07-validacao-01-streams-mediamtx-v1.4.sh "rtsp://user:pass@host:554/..."
if [[ "${1:-}" != "" ]]; then
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$1"
fi
