#!/usr/bin/env bash
set -euo pipefail
echo "[mediamtx-fix] Saneando configuração do MediaMTX para ACESSO SEM AUTENTICAÇÃO (apenas 'any')..."

MTX="/home/edimar/SISTEMA/MEDIAMTX/mediamtx.yml"
[ -f "$MTX" ] || MTX="/home/edimar/SISTEMA/mediamtx/mediamtx.yml"
[ -f "$MTX" ] || { echo "[mediamtx-fix] Aviso: mediamtx.yml não encontrado. Nada a fazer."; exit 0; }

cp -a "$MTX" "${MTX}.bkp.$(date +%Y%m%d%H%M%S)"

# Remove QUALQUER seção de auth existente
sed -i '/^authMethod:/,/^\(rtsp\|rtmp\|hls\|webrtc\|srt\|playback\):/d' "$MTX"
sed -i '/^[[:space:]]*apiUsers:/d' "$MTX"
sed -i '/- action:[[:space:]]*hls/d' "$MTX"
# Remove bloco do 'orq' se sobrou em algum lugar
awk '
  BEGIN{skip=0}
  /^ *- +user: +orq/ {skip=1; next}
  skip==1 && /^ *- +user: +/ {skip=0}
  skip==0 {print}
' "$MTX" > "${MTX}.tmp" && mv "${MTX}.tmp" "$MTX"

# Injeta bloco ONLY 'any' antes do primeiro protocolo
awk '
BEGIN{inserted=0}
# Ao encontrar o primeiro protocolo, injeta e segue
/^(rtsp|rtmp|hls|webrtc|srt|playback):/ && !inserted{
  print "authMethod: internal"
  print "authInternalUsers:"
  print "  - user: any"
  print "    pass:"
  print "    ips: []"
  print "    permissions:"
  print "      - action: api"
  print "        path:"
  print "      - action: read"
  print "        path:"
  print "      - action: playback"
  print "        path:"
  inserted=1
}
{ print }
END{
  if(!inserted){
    print "authMethod: internal"
    print "authInternalUsers:"
    print "  - user: any"
    print "    pass:"
    print "    ips: []"
    print "    permissions:"
    print "      - action: api"
    print "        path:"
    print "      - action: read"
    print "        path:"
    print "      - action: playback"
    print "        path:"
  }
}
' "$MTX" > "${MTX}.tmp" && mv "${MTX}.tmp" "$MTX"

echo "[mediamtx-fix] OK: config SEM credenciais (apenas 'any') em: $MTX"
