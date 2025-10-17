#!/bin/bash
# =================================================================
# ARQUIVO DE CONFIGURAÇÃO CENTRAL (v1.0)
#
# Define variáveis de ambiente e funções utilitárias que serão
# usadas por todos os outros scripts de instalação.
# =================================================================

# --- Diretórios Base ---
export SCRIPT_DIR="/home/edimar/SCRIPTS"
export SISTEMA_DIR="/home/edimar/SISTEMA"

# --- Diretórios de Serviços ---
export GESTAO_WEB_DIR="$SISTEMA_DIR/GESTAO_WEB"
export API_DIR="$GESTAO_WEB_DIR/backend"
export FRONTEND_DIR="$GESTAO_WEB_DIR/frontend"
export BANCO_DATA_DIR="$SISTEMA_DIR/BANCO/data"
export MEDIAMTX_DIR="$SISTEMA_DIR/MEDIAMTX"

# --- Configurações do Banco de Dados ---
export DB_CONTAINER="vaas-postgres-db"
export DB_NAME="vaas_db"
export DB_USER="vaas_user"

# --- Funções Utilitárias ---

# Função de log com prefixo para melhor visualização
log() {
    echo "=> $1"
}

# Função para verificar e instalar pacotes (idempotente)
install_package() {
    if dpkg -s "$1" &> /dev/null; then
        log "Pacote '$1' já está instalado."
    else
        log "Instalando pacote '$1'..."
        sudo apt-get install -y "$1"
    fi
}
NGINX_CONTAINER_NAME=vaas-frontend-web
MEDIAMTX_CONTAINER_NAME=vaas-mediamtx
MEDIAMTX_INTERNAL_HLS=http://vaas-mediamtx:8888
MEDIAMTX_API_URL=http://localhost:9997/v3
PUBLIC_BASE_URL=http://localhost:8080

# --------------------------------------------------------------------------------
# build_stream_path TENANT CAMERA_NAME
# - Sempre prefixa com 'live/'
# - Se TENANT vier vazio, usa 'live/<camera>'
# - Normaliza CAMERA_NAME para slug seguro (sem espaços)
build_stream_path() {
  local tenant="${1:-}"
  local cam="${2:-}"
  cam="$(echo "$cam" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  if [ -n "$tenant" ]; then
    echo "live/$tenant/$cam"
  else
    echo "live/$cam"
  fi
}
# --------------------------------------------------------------------------------
