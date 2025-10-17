#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-05: Configuração do Nginx (v1.1 - Sintaxe Corrigida)
#
# Corrige a sintaxe da diretiva 'location' para o proxy reverso
# dos streams HLS, resolvendo o crash do contêiner Nginx.
# =================================================================

echo "--> 5.5: Configurando o Nginx (v1.1 - Sintaxe Corrigida)..."

echo "    -> Criando nginx.conf com sintaxe de proxy corrigida..."
cat << 'NGINX_EOF' > "$GESTAO_WEB_DIR/nginx.conf"
server {
    listen 80;
    server_name localhost;

    # Regra para a API Backend
    location /api/ {
        proxy_pass http://vaas-gestao-web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # --- REGRA CORRIGIDA PARA OS STREAMS DE VÍDEO HLS ---
    # Qualquer requisição que comece com /live/ será enviada para o MediaMTX
    location /live/ {
        proxy_pass http://vaas-mediamtx:8888;

        # Cabeçalhos para streaming
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Regra para o Frontend (deve ser a última )
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF
echo "--- Configuração do Nginx (v1.1) concluída."
