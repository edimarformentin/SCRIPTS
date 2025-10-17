#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-05: Configuração do Nginx (v1.0 - HLS Proxy)
#
# Configura o Nginx para atuar como proxy reverso para os streams HLS
# do MediaMTX, além de servir a API e o frontend.
# =================================================================

echo "--> 5.5: Configurando o Nginx (v1.0 - HLS Proxy)..."

echo "    -> Criando nginx.conf com proxy para HLS..."
cat << 'NGINX_EOF' > "$GESTAO_WEB_DIR/nginx.conf"
server {
    listen 80;
    server_name localhost;

    location /api/ {
        proxy_pass http://vaas-gestao-web:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location ~ ^/(live|cam ) {
        proxy_pass http://vaas-mediamtx:8888;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF
echo "--- Configuração do Nginx (v1.0 ) concluída."
