#!/usr/bin/env bash
set -euo pipefail
MASTER="/home/edimar/SCRIPTS/5_criar_frontend.sh"
LINE='bash /home/edimar/SCRIPTS/5.10_fix_video_bootstrap.sh || true'
[ -f "$MASTER" ] || { echo "[ERRO] $MASTER não existe"; exit 1; }
grep -q "5.10_fix_video_bootstrap.sh" "$MASTER" || {
  cat >> "$MASTER" <<EOC

# --- Patch automático: modal Bootstrap e botão "Ver vídeo" ---
echo "--> Aplicando patch de vídeo (Bootstrap modal + botão)"
$LINE
echo "Patch de vídeo aplicado."
EOC
  echo "[OK] Patch aplicado em $MASTER"
}
