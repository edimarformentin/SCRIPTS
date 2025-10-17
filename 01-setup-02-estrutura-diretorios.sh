#!/bin/bash
# =================================================================
# Script: Setup - Estrutura de Diretórios (v1.0)
#
# Cria a árvore de diretórios base para todos os serviços do
# sistema VaaS. Garante que os caminhos existam antes que
# outros scripts tentem escrever neles.
# =================================================================
set -e
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> Preparando estrutura de diretórios do sistema..."

log "Criando diretório para a Gestão Web: $GESTAO_WEB_DIR"
mkdir -p "$GESTAO_WEB_DIR"

log "Criando diretório para a API Backend: $API_DIR"
mkdir -p "$API_DIR"

log "Criando diretório para o Frontend UI: $FRONTEND_DIR"
mkdir -p "$FRONTEND_DIR"

log "Criando diretório para os dados do Banco: $BANCO_DATA_DIR"
mkdir -p "$BANCO_DATA_DIR"

log "Criando diretório para o MediaMTX: $MEDIAMTX_DIR"
mkdir -p "$MEDIAMTX_DIR"

# --- INÍCIO DA MODIFICAÇÃO ---
log "Criando diretório para as Gravações: $SISTEMA_DIR/GRAVACOES"
mkdir -p "$SISTEMA_DIR/GRAVACOES"
# --- FIM DA MODIFICAÇÃO ---

echo "--- Estrutura de diretórios criada com sucesso."
