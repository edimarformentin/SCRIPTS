#!/bin/bash
# Nome do arquivo: 5_criar_frontend.sh (MESTRE)
set -e
echo "==== SCRIPT 5 (MESTRE): EXECUTANDO SCRIPTS DO FRONTEND ===="
cd /home/edimar/SCRIPTS
bash ./5.1_criar_frontend_essenciais.sh
bash ./5.2_criar_frontend_cliente_camera.sh
bash ./5.3_criar_frontend_eventos_erro.sh
echo "✅ SUCESSO: Todos os scripts do frontend foram executados."
echo "==== SCRIPT 5 (MESTRE) CONCLUÍDO ===="

# --- Patch automático: habilitar botão "Ver vídeo" em Eventos (idempotente) ---
echo "--> Executando patch 5.4 (botão Ver vídeo)"
bash /home/edimar/SCRIPTS/5.4_frontend_evento_video.sh || true
echo "Patch 5.4 aplicado."

# --- Patch automático: front usa /api/event-video com fallback ---
echo "--> Atualizando front para usar /api/event-video (com fallback)"
bash /home/edimar/SCRIPTS/5.6_frontend_evento_busca_api.sh || true
echo "Front atualizado (busca de vídeo por API)."

# --- Patch automático: modal Bootstrap e botão "Ver vídeo" ---
echo "--> Aplicando patch de vídeo (Bootstrap modal + botão)"
bash /home/edimar/SCRIPTS/5.10_fix_video_bootstrap.sh || true
echo "Patch de vídeo aplicado."
