#!/bin/bash
# Script executado dentro do container gestao-web para sincronizar câmeras RTSP com MediaMTX
set -e

CONFIG_BASE="/app/config/mediamtx/mediamtx.yml"
CONFIG_TEMP="/tmp/mediamtx.yml.tmp"

# Busca câmeras RTSP via API local
export CAMERAS_JSON=$(curl -s "http://localhost:8000/api/cameras" 2>/dev/null || echo "[]")

# Copia config base até paths (inclusive)
if [ -f "$CONFIG_BASE" ]; then
  # Copia tudo até e incluindo o regex path ~^live/(.+)/(.+)$
  # Depois adiciona as câmeras RTSP específicas
  awk '
    /^  ~\^live\/\(.+\)\/\(.+\)\$:/ {
      print
      print "    record: yes"
      print "    recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S"
      print ""
      in_rtsp_section = 1
      next
    }
    !in_rtsp_section {
      print
    }
    /# Câmeras RTSP/ {
      in_rtsp_section = 1
    }
  ' "$CONFIG_BASE" > "$CONFIG_TEMP"
else
  echo "Erro: Arquivo $CONFIG_BASE não encontrado"
  exit 1
fi

# Adiciona câmeras RTSP via Python
python3 -c '
import json, os

cameras_str = os.getenv("CAMERAS_JSON", "[]")
try:
    cameras = json.loads(cameras_str)
except:
    cameras = []

rtsp_cameras = [c for c in cameras if c.get("protocolo", "").upper() == "RTSP"]

if rtsp_cameras:
    print("  # Câmeras RTSP (auto-geradas)")
    for cam in rtsp_cameras:
        client_slug = cam.get("cliente_slug", "")
        nome = cam.get("nome", "")
        endpoint = cam.get("endpoint", "")

        if not all([client_slug, nome, endpoint]):
            continue

        path = f"live/{client_slug}/{nome}"
        print(f"  {path}:")
        print(f"    source: {endpoint}")
        print(f"    rtspTransport: tcp")
        print(f"    sourceOnDemand: no")
        print(f"    record: yes")
        print(f"    recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S")
' >> "$CONFIG_TEMP"

# Substitui arquivo original
mv "$CONFIG_TEMP" "$CONFIG_BASE"

# Reinicia MediaMTX via Docker
docker restart mediamtx 2>/dev/null || echo "[SYNC] Aviso: não foi possível reiniciar mediamtx (requer acesso ao docker socket)"

echo "[SYNC] Configuração atualizada com sucesso"
