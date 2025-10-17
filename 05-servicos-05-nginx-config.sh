#!/bin/bash
# =================================================================
# Script: 05-servicos-05-nginx-config.sh
#
# Propósito:
# Gera o arquivo de configuração principal para o Nginx.
#
# O que ele faz:
# 1. Cria o arquivo 'nginx.conf' no diretório GESTAO_WEB.
# 2. Configura o Nginx para atuar como um proxy reverso:
#    - Requisições para '/api/' são encaminhadas para o backend (vaas-gestao-web).
#    - Requisições para '/live/' (streams HLS) são encaminhadas para o MediaMTX.
#    - Todas as outras requisições servem os arquivos do frontend (HTML/CSS/JS).
# 3. Adiciona uma nova regra para servir as gravações de vídeo
#    diretamente da pasta '/recordings/'.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 5.5: Gerando configuração do Nginx..."

cat > "$GESTAO_WEB_DIR/nginx.conf" << 'NGINX_EOF'
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

    # Regra para os streams de vídeo HLS ao vivo
    location /live/ {
        proxy_pass http://vaas-mediamtx:8888;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # --- NOVA REGRA PARA ASSISTIR ÀS GRAVAÇÕES ---
    # Serve os arquivos .mp4 diretamente da pasta de gravações
    location /recordings/ {
        # O alias mapeia a URL para um diretório no sistema de arquivos do contêiner
        # O Nginx precisa ter acesso a esta pasta!
        alias /var/www/recordings/;
        # Adiciona cabeçalhos para permitir busca (seeking ) no vídeo
        add_header Content-Type video/mp4;
        mp4; # Habilita o módulo de streaming de MP4 do Nginx
    }

    # Regra para o Frontend (deve ser a última)
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
NGINX_EOF

echo "--- Configuração do Nginx gerada com sucesso."
