#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Ajustando Nginx v1.2 para servir HLS..."

NGINX_CONF="$GESTAO_WEB_DIR/nginx/conf.d/vaas.conf"
mkdir -p "$(dirname "$NGINX_CONF")"

if [ -f "$NGINX_CONF" ] && grep -q "/hls/" "$NGINX_CONF"; then
  log "Bloco /hls/ já presente. Nada a fazer."
else
  cat >> "$NGINX_CONF" <<'NGX'

# Proxy de HLS do MediaMTX
location /hls/ {
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_read_timeout 3600;
    proxy_pass http://mediamtx:8888/hls/;  # porta HTTP do MediaMTX
}
NGX
fi

log "Nginx v1.2 ajustado."
