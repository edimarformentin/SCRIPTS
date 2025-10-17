#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Atualizando orquestração v2.7 (ffmpeg no API e BASE_PUBLIC_URL)..."

# Ajuste no Dockerfile da API para incluir ffmpeg/ffprobe
if [ -f "$API_DIR/Dockerfile" ]; then
  if ! grep -q "ffmpeg" "$API_DIR/Dockerfile"; then
    sed -i '/^RUN apt-get update/a RUN apt-get install -y ffmpeg \&\& rm -rf /var/lib/apt/lists/*' "$API_DIR/Dockerfile"
  fi
fi

# Ajusta docker-compose para expor BASE_PUBLIC_URL (usado para montar URL do HLS)
if [ -f "$GESTAO_WEB_DIR/docker-compose.yml" ]; then
  if ! grep -q "BASE_PUBLIC_URL" "$GESTAO_WEB_DIR/docker-compose.yml"; then
    sed -i '/environment:/,/^\s*[^-]/ s/$/\n      - BASE_PUBLIC_URL=${BASE_PUBLIC_URL:-http:\/\/localhost}/' "$GESTAO_WEB_DIR/docker-compose.yml"
  fi
fi

log "Orquestração v2.7 concluída."
