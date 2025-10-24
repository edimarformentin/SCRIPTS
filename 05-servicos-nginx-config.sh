#!/usr/bin/env bash
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  ensure_dirs "$CONFIG_DIR/nginx"

  cat > "$CONFIG_DIR/nginx/nginx.conf" <<'NGINX'
user  nginx;
worker_processes  auto;

events { worker_connections 1024; }

http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  sendfile        on;
  keepalive_timeout  65;
  server_tokens off;

  # Logs no stdout/stderr (padrão Docker)
  access_log /dev/stdout;
  error_log  /dev/stderr warn;

  # Resolve nomes de serviços Docker em tempo de requisição
  resolver 127.0.0.11 ipv6=off valid=30s;

  server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
      try_files $uri $uri/ /index.html;
    }

    # API (mantém /api/ no path)
    location /api/ {
      set $api http://gestao-web:8000;
      proxy_pass $api;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }

    # HLS (MediaMTX) – não derruba o Nginx se não existir
    location /hls/ {
      set $hls http://mediamtx:8888;
      proxy_pass $hls;
      proxy_http_version 1.1;
      proxy_set_header Connection "";
    }
  }
}
NGINX
  ok "nginx.conf atualizado."
}
main "$@"
