#!/usr/bin/env bash
set -euo pipefail

echo "==== SCRIPT 4 (MESTRE): INICIANDO CRIAÇÃO COMPLETA DO BACKEND ===="
echo "----------------------------------------------------------------"

SUBSCRIPTS=(
  "4.1_criar_backend_estrutura.sh"
  "4.2_criar_backend_dockerfile.sh"
  "4.3_criar_backend_requirements.sh"
  "4.4_criar_backend_settings.sh"
  "4.5_criar_backend_models.sh"
  "4.6_criar_backend_main.sh"
  "4.7_criar_backend_gerenciar_frigate.sh"
  "4.8_criar_backend_popular_dados.sh"
  "4.10_criar_backend_gerenciar_yolo.sh"
)

for S in "${SUBSCRIPTS[@]}"; do
  echo "----------------------------------------------------------------"
  echo "--> Executando sub-script: $S"
  echo "----------------------------------------------------------------"
  if [ -x "/home/edimar/SCRIPTS/$S" ]; then
    bash "/home/edimar/SCRIPTS/$S"
  else
    echo "ERRO: O script '$S' não foi encontrado ou não é executável."
    exit 1
  fi
done

# ---- Recursos de VÍDEO POR EVENTO (idempotentes) ----
[ -x /home/edimar/SCRIPTS/4.11_criar_backend_evento_video.sh ] && bash /home/edimar/SCRIPTS/4.11_criar_backend_evento_video.sh || true
[ -x /home/edimar/SCRIPTS/4.11b_configurar_evento_video.sh ] && bash /home/edimar/SCRIPTS/4.11b_configurar_evento_video.sh 10 15 /home/edimar/SISTEMA/FRIGATE || true
[ -x /home/edimar/SCRIPTS/4.12_instalar_merge_eventos.sh ] && bash /home/edimar/SCRIPTS/4.12_instalar_merge_eventos.sh || true
[ -x /home/edimar/SCRIPTS/4.12c_adicionar_healthcheck_eventos.sh ] && bash /home/edimar/SCRIPTS/4.12c_adicionar_healthcheck_eventos.sh || true
[ -x /home/edimar/SCRIPTS/4.12d_add_api_event_video.sh ] && bash /home/edimar/SCRIPTS/4.12d_add_api_event_video.sh || true

echo
echo "✅ SUCESSO: Todos os scripts do backend foram executados."
echo "==== SCRIPT 4 (MESTRE) CONCLUÍDO ===="

# ---- Instalar serviço de limpeza de eventos (idempotente) ----
[ -x /home/edimar/SCRIPTS/4.13_instalar_limpeza_eventos.sh ] && bash /home/edimar/SCRIPTS/4.13_instalar_limpeza_eventos.sh || true

