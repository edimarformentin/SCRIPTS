#!/usr/bin/env bash
set -euo pipefail

echo "===== DIAGNÓSTICO EVENTO→VÍDEO ====="
date

BASES=(
  "/home/edimar/SISTEMA/FRIGATE"
  "/home/edimar/FRIGATE"
  "/FRIGATE"
)

echo
echo "== 1) Verificando bases FRIGATE conhecidas =="
for B in "${BASES[@]}"; do
  echo
  echo "-- BASE: $B"
  if [ ! -d "$B" ]; then
    echo "   (não existe)"
    continue
  fi

  echo "   [a] unique_ids disponíveis (nível 1):"
  find "$B" -maxdepth 1 -mindepth 1 -type d -printf "      %f\n" | head -n 20 || true

  echo "   [b] pastas de events por câmera (2 níveis):"
  find "$B" -maxdepth 3 -type d -path "*/events/*" | head -n 20 || true

  echo "   [c] snapshots .jpg recentes (últimos 7 dias) dentro de events:"
  find "$B" -type f -path "*/events/*" -name "*.jpg" -mtime -7 | head -n 20 || true

  echo "   [d] gravações (recordings) mp4 (amostra):"
  find "$B" -type f -path "*/media/frigate/recordings/*" -name "*.mp4" | head -n 20 || true

  echo "   [e] contagens rápidas:"
  JPG_CNT=$(find "$B" -type f -path "*/events/*" -name "*.jpg" | wc -l || true)
  MP4_CNT=$(find "$B" -type f -path "*/media/frigate/recordings/*" -name "*.mp4" | wc -l || true)
  echo "       jpg_em_events=$JPG_CNT  mp4_em_recordings=$MP4_CNT"
done

echo
echo "== 2) Varredura global por snapshots em /home/edimar (limitado) =="
find /home/edimar -type f -path "*/events/*" -name "*.jpg" | head -n 50 || true

echo
echo "== 3) Containers em execução relevantes =="
docker ps --format '  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'frigate|yolo|mtx|media|rtmp|gest|web' || true

echo
echo "== 4) Containers parados (para ver se o Frigate existe mas está down) =="
docker ps -a --format '  {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -Ei 'frigate|yolo|gest|web' || true

echo
echo "== 5) Se existir compose do Frigate, mostre volumes (tentativa) =="
# procura possíveis docker-compose com 'frigate' no conteúdo
COMPOSES=$(grep -RIl --include="docker-compose*.yml" -e 'frigate' /home/edimar 2>/dev/null || true)
if [ -n "${COMPOSES:-}" ]; then
  echo "Arquivos docker-compose que citam 'frigate':"
  echo "$COMPOSES"
  # só imprime as linhas de volumes/pastas pra ajudar
  echo
  for f in $COMPOSES; do
    echo "---- $f (volumes/paths) ----"
    awk '/volumes:|bind|source:|target:|paths:|media\/frigate|FRIGATE/ {print NR": "$0}' "$f" || true
  done
else
  echo "Nenhum docker-compose com 'frigate' encontrado em /home/edimar"
fi

echo
echo "===== FIM DO DIAGNÓSTICO ====="
