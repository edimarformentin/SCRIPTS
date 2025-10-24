#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 05-servicos-mediamtx-config.sh
# -----------------------------------------------------------------------------
# Gera config do MediaMTX com HLS habilitado e caminhos básicos
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  cat > "$CONFIG_DIR/mediamtx/mediamtx.yml" <<'YML'
logLevel: info
rtspAddress: :8554
rtmpAddress: :1935
hls: yes
hlsAddress: :8888
hlsVariant: lowLatency
paths:
  all:
    # Publish de qualquer fonte RTSP/RTMP
    # Ex: rtmp://<host>:1935/camera1 ou rtsp://<host>:8554/camera1
    publishUser:
    publishPass:
    hlsSegmentDuration: 1s
    hlsPartDuration: 200ms
    hlsPlaylistType: event
YML
  ok "Config do MediaMTX gerada."
}
main "$@"
