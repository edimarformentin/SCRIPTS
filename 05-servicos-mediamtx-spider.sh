#!/usr/bin/env bash
set -euo pipefail
MEDIAMTX_CONTAINER="${MEDIAMTX_CONTAINER_NAME:-vaas-mediamtx}"
echo ">> MediaMTX container: $MEDIAMTX_CONTAINER"
docker exec -it "$MEDIAMTX_CONTAINER" sh -lc '
  if command -v wget >/dev/null 2>&1; then
    for P in "cam1" "live/edimar-mluswn/cam2"; do
      echo "==> HEAD /$P/index.m3u8"
      wget -S --spider "http://localhost:8888/$P/index.m3u8" 2>&1 | egrep "HTTP/|Location:|Connecting|Connected" || true
    done
  elif command -v busybox >/dev/null 2>&1; then
    for P in "cam1" "live/edimar-mluswn/cam2"; do
      echo "==> GET /$P/index.m3u8 (head)"
      busybox wget -q -O - "http://localhost:8888/$P/index.m3u8" | head -n 5 || echo "ERRO"
    done
  else
    echo "AVISO: container sem wget/busybox; pulei."
  fi
'
