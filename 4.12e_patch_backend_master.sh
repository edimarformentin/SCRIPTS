#!/usr/bin/env bash
set -euo pipefail
MASTER="/home/edimar/SCRIPTS/4_criar_backend.sh"
LINE='bash /home/edimar/SCRIPTS/4.12d_add_api_event_video.sh || true'

[ -f "$MASTER" ] || { echo "[ERRO] $MASTER não existe"; exit 1; }
grep -q "4.12d_add_api_event_video.sh" "$MASTER" || {
  cat >> "$MASTER" <<EOC

# --- Patch automático: API de descoberta de vídeo de evento ---
echo "--> Habilitando endpoint /api/event-video"
$LINE
echo "Endpoint /api/event-video ok."
EOC
  echo "[OK] Patch aplicado em $MASTER"
}
