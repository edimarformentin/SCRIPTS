#!/usr/bin/env bash
set -euo pipefail

# Carrega variáveis centrais se existirem, mas não falha se não houver
[ -f /home/edimar/SCRIPTS/00-configuracao-central.sh ] && source /home/edimar/SCRIPTS/00-configuracao-central.sh || true

BASE_DIR_DEFAULT="/home/edimar/SISTEMA"
BASE_DIR="${BASE_DIR:-$BASE_DIR_DEFAULT}"

MEDIAMTX_DIR_UPPER="${BASE_DIR}/MEDIAMTX"
CFG_PATH="${MEDIAMTX_DIR_UPPER}/mediamtx.yml"

echo "[mediamtx-config] Gerando arquivo de configuração em: ${CFG_PATH}"

# O diretório de recordings agora será criado pelo docker-compose ao mapear o volume
mkdir -p "${MEDIAMTX_DIR_UPPER}"

cat > "${CFG_PATH}" <<'YAML'
###############################################
# MediaMTX v1.14.x - config compatível
###############################################

# API de controle
api: yes
apiAddress: :9997

# Métricas
metrics: yes
metricsAddress: :9998

# pprof (desativado)
pprof: no
pprofAddress: :9999

# ---- Autenticação interna (schema correto) ----
authMethod: internal
authInternalUsers:
  - user: any
    pass:
    ips: []
    permissions:
      - action: api
        path:
      - action: read
        path:
      - action: playback
        path:
      - action: publish
        path:

# Protocolos
rtsp: yes
rtmp: yes
hls: yes
webrtc: yes

# =================================================
# INÍCIO DA MODIFICAÇÃO: Configurações de Gravação
# =================================================
record: yes
recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S
recordFormat: fmp4
recordSegmentDuration: 1h
# =================================================
# FIM DA MODIFICAÇÃO
# =================================================

# Paths (orquestrador gerencia via Control API)
paths:
  all: {}
YAML

chmod 644 "${CFG_PATH}"
chmod 755 "${MEDIAMTX_DIR_UPPER}"

echo "[mediamtx-config] Arquivo gerado com sucesso."
