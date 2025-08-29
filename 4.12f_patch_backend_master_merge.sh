#!/usr/bin/env bash
set -euo pipefail
MASTER="/home/edimar/SCRIPTS/4_criar_backend.sh"

ensure_line() {
  local file="$1" ; shift
  local needle="$1" ; shift
  local block="$1" ; shift
  grep -qF "$needle" "$file" || { echo "$block" >> "$file" ; echo "[OK] injetado: $needle" ; }
}

[ -f "$MASTER" ] || { echo "[ERRO] $MASTER não existe"; exit 1; }

# 4.11 - installer do assembler (se já tiver, fica idempotente)
ensure_line "$MASTER" "4.11_criar_backend_evento_video.sh" '
# --- Habilitar assembler de vídeo (4.11) ---
echo "--> Instalando assembler de vídeo (4.11)"
bash /home/edimar/SCRIPTS/4.11_criar_backend_evento_video.sh || true
'

# 4.12 - installer do merge de eventos
ensure_line "$MASTER" "4.12_instalar_merge_eventos.sh" '
# --- Habilitar merge automático de eventos (4.12) ---
echo "--> Instalando merge de eventos (4.12)"
bash /home/edimar/SCRIPTS/4.12_instalar_merge_eventos.sh || true
'

# Configurar PRE/POST/BASE pós-instalação (drop-in systemd do assembler)
ensure_line "$MASTER" "4.11b_configurar_evento_video.sh" '
# --- Configurar assembler: PRE/POST/BASE ---
echo "--> Configurando assembler (PRE=10, POST=15)"
bash /home/edimar/SCRIPTS/4.11b_configurar_evento_video.sh 10 15 /home/edimar/SISTEMA/FRIGATE || true
'

# Já patchamos a API em 4.12e e o front em 5.7 anteriormente
echo "[OK] Patch aplicado em $MASTER (4.11, 4.12 e config)."
