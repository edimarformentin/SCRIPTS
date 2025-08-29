#!/usr/bin/env bash
set -euo pipefail
MASTER="/home/edimar/SCRIPTS/5_criar_frontend.sh"
CALL='bash /home/edimar/SCRIPTS/5.4_frontend_evento_video.sh'

[ -f "$MASTER" ] || { echo "[ERRO] $MASTER não existe"; exit 1; }

if grep -q "5.4_frontend_evento_video.sh" "$MASTER"; then
  echo "[INFO] $MASTER já chama 5.4_frontend_evento_video.sh. Nada a fazer."
  exit 0
fi

echo "[INFO] Patching $MASTER para chamar 5.4..."
cat >> "$MASTER" <<'EOC'

# --- Patch automático: habilitar botão "Ver vídeo" em Eventos (idempotente) ---
echo "--> Executando patch 5.4 (botão Ver vídeo)"
bash /home/edimar/SCRIPTS/5.4_frontend_evento_video.sh || true
echo "Patch 5.4 aplicado."
EOC

echo "[OK] Patch aplicado em $MASTER"
