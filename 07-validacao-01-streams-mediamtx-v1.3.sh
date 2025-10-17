#!/bin/bash
# =================================================================
# Script de Validação 01: Status das Streams no MediaMTX (v1.3)
#
# - Corrige o erro de tipo do jq ao concatenar o campo booleano 'ready'.
# =================================================================
set -e
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

# Instala o slugify via apt se não estiver disponível
if ! command -v slugify &> /dev/null; then
    echo "Comando 'slugify' não encontrado. Tentando instalar via apt..."
    sudo apt-get update && sudo apt-get install -y slugify
fi

API_GESTAO_URL="http://localhost/api/v1/cameras/"
API_MEDIAMTX_URL="http://localhost:9997/v3/paths/list"

log( ) {
    echo "=> $1"
}

log "Iniciando validação de streams entre a API de Gestão e o MediaMTX (v1.3)..."
echo

# --- Etapa 1: Obter câmeras da API de Gestão ---
log "1. Buscando câmeras na API de Gestão..."
api_cameras_json=$(curl -s "$API_GESTAO_URL")
if ! echo "$api_cameras_json" | jq . > /dev/null 2>&1; then
    echo "   ERRO: Não foi possível obter um JSON válido da API de Gestão. Verifique se o sistema está no ar."
    exit 1
fi
log "   -> Encontradas $(echo "$api_cameras_json" | jq '. | length') câmeras no banco de dados."
echo

# --- Etapa 2: Obter paths do MediaMTX ---
log "2. Buscando paths no MediaMTX..."
mtx_paths_json=$(curl -s "$API_MEDIAMTX_URL")
mtx_paths=""
if echo "$mtx_paths_json" | jq -e '.items | if . == null then false else true end' > /dev/null 2>&1; then
    mtx_paths=$(echo "$mtx_paths_json" | jq -r '.items | .[] | .name + " " + .source.type + " " + (.ready|tostring)')
    log "   -> Encontrados $(echo "$mtx_paths" | wc -l) paths configurados no MediaMTX."
else
    log "   -> Nenhum path configurado no MediaMTX ou resposta inválida."
fi
echo

# --- Etapa 3: Validar e Exibir Relatório ---
log "3. Gerando relatório de status:"
echo "--------------------------------------------------------------------------------------------"
printf "%-30s | %-10s | %-12s | %s\n" "NOME DA CÂMERA (CLIENTE)" "TIPO" "STATUS DB" "STATUS MEDIAMTX"
echo "--------------------------------------------------------------------------------------------"

echo "$api_cameras_json" | jq -c '.[]' | while read -r camera_json; do
    nome=$(echo "$camera_json" | jq -r '.nome_camera')
    cliente_id_short=$(echo "$camera_json" | jq -r '.cliente_id' | cut -c1-8)
    url_rtmp_path=$(echo "$camera_json" | jq -r '.url_rtmp_path')
    url_rtsp=$(echo "$camera_json" | jq -r '.url_rtsp')
    is_active=$(echo "$camera_json" | jq -r '.is_active')

    status_db="INATIVA"
    [ "$is_active" == "true" ] && status_db="ATIVA"

    if [ "$url_rtsp" != "null" ]; then
        tipo="RTSP"
        path_esperado=$(slugify "$nome")
    else
        tipo="RTMP"
        path_esperado=$(basename "$url_rtmp_path")
    fi

    status_mtx="NÃO ENCONTRADO"
    if [ -n "$mtx_paths" ] && echo "$mtx_paths" | grep -q "^${path_esperado} "; then
        path_details=$(echo "$mtx_paths" | grep "^${path_esperado} ")
        source_type=$(echo "$path_details" | awk '{print $2}')
        is_ready=$(echo "$path_details" | awk '{print $3}')

        if [ "$is_ready" == "true" ]; then
            status_mtx="OK (ATIVA/PULLING)"
        else
            status_mtx="OK (CONFIGURADA)"
        fi
    fi

    final_status_color="\033[0m"
    if [ "$is_active" == "true" ] && [[ "$status_mtx" == "NÃO ENCONTRADO" ]]; then
        final_status_color="\033[0;31m"
    elif [ "$is_active" == "true" ] && [[ "$status_mtx" != "NÃO ENCONTRADO" ]]; then
        final_status_color="\033[0;32m"
    elif [ "$is_active" == "false" ] && [[ "$status_mtx" != "NÃO ENCONTRADO" ]]; then
        final_status_color="\033[0;33m"
    fi

    printf "%-30s | %-10s | %-12s | ${final_status_color}%s\033[0m\n" "$nome ($cliente_id_short...)" "$tipo" "$status_db" "$status_mtx"
done

echo "--------------------------------------------------------------------------------------------"
echo -e "\nLegenda de Status MediaMTX:"
echo "  - NÃO ENCONTRADO: O path não existe no MediaMTX."
echo "  - OK (CONFIGURADA): O path existe, mas não há uma stream ativa."
echo "  - OK (ATIVA/PULLING): O path existe e o MediaMTX está recebendo a stream."
