#!/usr/bin/env bash
set -euo pipefail
MASTER="/home/edimar/SCRIPTS/5_criar_frontend.sh"
LINE='bash /home/edimar/SCRIPTS/5.6_frontend_evento_busca_api.sh || true'

[ -f "$MASTER" ] || { echo "[ERRO] $MASTER não existe"; exit 1; }
grep -q "5.6_frontend_evento_busca_api.sh" "$MASTER" || {
  cat >> "$MASTER" <<EOC

# --- Patch automático: front usa /api/event-video com fallback ---
echo "--> Atualizando front para usar /api/event-video (com fallback)"
$LINE
echo "Front atualizado (busca de vídeo por API)."
EOC
  echo "[OK] Patch aplicado em $MASTER"
}
