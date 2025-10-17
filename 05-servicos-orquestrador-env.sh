#!/usr/bin/env bash
set -euo pipefail

# Carrega variáveis centrais se existirem
[ -f /home/edimar/SCRIPTS/00-configuracao-central.sh ] && source /home/edimar/SCRIPTS/00-configuracao-central.sh || true

ORQ_DIR="${ORQ_DIR:-/home/edimar/SISTEMA/orquestrador}"
CTN_MTX="${CTN_MTX:-vaas-mediamtx}"
CTN_API="${CTN_API:-vaas-gestao-web}"

echo "[orquestrador-env] Gerando .env (sem credenciais) ..."
mkdir -p "${ORQ_DIR}"
cat > "${ORQ_DIR}/.env" <<ENV
MTX_API_BASE=http://${CTN_MTX}:9997
MTX_API_USER=
MTX_API_PASS=
API_GESTAO_BASE=http://${CTN_API}:8000
ENV

echo "[orquestrador-env] OK: ${ORQ_DIR}/.env"
