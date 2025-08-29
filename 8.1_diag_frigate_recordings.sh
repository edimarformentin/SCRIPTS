#!/usr/bin/env bash
set -euo pipefail

FRIGATE_NAME="${FRIGATE_NAME:-frigate-edimar-rdk18}"
BASE="/home/edimar/SISTEMA/FRIGATE/edimar-rdk18"
CFG="$BASE/config"
MEDIA="$BASE/media"

echo "===== DIAG FRIGATE RECORDINGS ====="
date
echo "Container: $FRIGATE_NAME"
echo "BASE: $BASE"
echo

echo "== 1) Host: estrutura e permissões =="
echo "[host] ls -ld $BASE $CFG $MEDIA"
ls -ld "$BASE" "$CFG" "$MEDIA" || true
echo "[host] ls -ld $MEDIA/recordings || (ainda não existe)"
ls -ld "$MEDIA/recordings" || true
echo

echo "== 2) Compose e volumes =="
if [ -f "$BASE/docker-compose.yml" ]; then
  echo "[host] volumes no compose:"
  awk 'NR>=1 && NR<=200 {print NR": "$0}' "$BASE/docker-compose.yml" | sed -n '1,200p' | grep -nE 'volumes:|/config|/media/frigate|bind|source:|target:' -n || true
else
  echo "[host] compose não encontrado em $BASE/docker-compose.yml"
fi
echo

echo "== 3) Dentro do container: ver /config e /media/frigate =="
docker exec -i "$FRIGATE_NAME" bash -lc '
set -e
echo "[ctn] id:"; hostname
echo "[ctn] ls -l /config (topo):"; ls -l /config | head -n 20 || true
echo "[ctn] grep record em /config/config.*:"
( grep -n "^[[:space:]]*record:" -n /config/config* 2>/dev/null || true; grep -n "enabled:" -n /config/config* 2>/dev/null || true )
echo
echo "[ctn] ls -ld /media/frigate:"; ls -ld /media/frigate || true
echo "[ctn] tree recordings (amostra):"
( command -v tree >/dev/null && tree -L 3 /media/frigate/recordings 2>/dev/null ) || ( ls -R /media/frigate/recordings 2>/dev/null | head -n 200 || true )
echo
echo "[ctn] teste de escrita em /media/frigate/_probe:"
mkdir -p /media/frigate/_probe && date > /media/frigate/_probe/inside_container.txt && ls -l /media/frigate/_probe
' || true
echo

echo "== 4) Host enxerga o probe? =="
ls -l "$MEDIA/_probe" || true
echo

echo "== 5) Logs recentes do Frigate (200 linhas) =="
docker logs --tail=200 "$FRIGATE_NAME" || true
echo

echo "== 6) Inspecionar mounts do Frigate =="
docker inspect "$FRIGATE_NAME" --format '{{json .Mounts}}' | jq . || docker inspect "$FRIGATE_NAME" --format '{{json .Mounts}}' || true
echo

echo "===== FIM DO DIAG ====="
