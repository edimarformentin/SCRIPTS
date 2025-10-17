#!/usr/bin/env bash
set -euo pipefail
NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-vaas-frontend-web}"
MEDIAMTX_HOSTPORT="${MEDIAMTX_INTERNAL_HLS:-http://vaas-mediamtx:8888}"
TARGET_CONF_IN_CONTAINER="${TARGET_CONF_IN_CONTAINER:-/etc/nginx/conf.d/default.conf}"

echo ">> NGINX container: $NGINX_CONTAINER_NAME"
echo ">> Origem HLS:      $MEDIAMTX_HOSTPORT"
echo ">> Conf alvo:       $TARGET_CONF_IN_CONTAINER"

TS="$(date +%Y%m%d-%H%M%S)"
CONF_HOST="/tmp/nginx-target-${TS}.conf"
INJ_HOST="/tmp/vaas_live_fallback.${TS}.inj"

# bloco canônico (mantém $ do Nginx)
cat > "$INJ_HOST" <<INJ
    # --- VaaS HOTFIX: Proxy HLS com fallback para paths sem 'live/' ---
    location ^~ /live/ {
        proxy_pass ${MEDIAMTX_HOSTPORT};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_intercept_errors on;
        error_page 404 = @hls_fallback;
    }

    location @hls_fallback {
        rewrite ^/live/(.*)$ /\$1 break;
        proxy_pass ${MEDIAMTX_HOSTPORT};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    # --- FIM HOTFIX ---
INJ

docker cp "${NGINX_CONTAINER_NAME}:${TARGET_CONF_IN_CONTAINER}" "$CONF_HOST"

# remove QUALQUER /live e @hls_fallback e injeta nossa versão dentro do primeiro server 80/8080
awk -v inj="$INJ_HOST" '
  BEGIN{
    while ((getline l < inj) > 0) injbuf = injbuf l "\n"; close(inj)
    inserver=0; depth=0; haslisten=0; injected=0; skipblock=0
  }
  function starts_live(loc){ return (loc ~ /^[ \t]*location[ \t]+(\^~[ \t]+)?\/live\/[ \t]*\{/) }
  function starts_fallback(loc){ return (loc ~ /^[ \t]*location[ \t]+@hls_fallback[ \t]*\{/) }
  {
    line=$0
    if (match(line,/^[ \t]*server[ \t]*\{/)) { inserver=1; depth=1; haslisten=0; print line; next }

    if (inserver) {
      open_n=gsub(/\{/,"{",line)
      close_n=gsub(/\}/,"}",line)
      if (match(line,/listen[ \t]+(80|8080)([ \t;]|$)/)) haslisten=1

      if (skipblock==0 && (starts_live(line) || starts_fallback(line))) {
        skipblock=1; blkdepth=1; next
      }
      if (skipblock==1) {
        blk_open=gsub(/\{/,"{",line); blk_close=gsub(/\}/,"}",line)
        blkdepth += blk_open - blk_close
        if (blkdepth<=0) skipblock=0
        next
      }

      if (depth==1 && close_n>0) {
        if (haslisten==1 && injected==0) { printf("%s", injbuf); injected=1 }
        inserver=0
      }
      print $0
      depth += open_n - close_n
      next
    }
    print $0
  }
' "$CONF_HOST" > "${CONF_HOST}.new"

TMP_IN_CONTAINER="/tmp/default.conf.new.${TS}"
docker cp "${CONF_HOST}.new" "${NGINX_CONTAINER_NAME}:${TMP_IN_CONTAINER}"
docker exec "$NGINX_CONTAINER_NAME" sh -lc "
  cp -f '$TARGET_CONF_IN_CONTAINER' '${TARGET_CONF_IN_CONTAINER}.bak.${TS}';
  cat '$TMP_IN_CONTAINER' > '$TARGET_CONF_IN_CONTAINER';
  nginx -t && nginx -s reload
"
echo ">> Normalização aplicada e Nginx recarregado."
