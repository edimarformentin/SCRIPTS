#!/bin/bash
# =================================================================
# Script: Orquestrador - Estrutura Base (v1.7 - No On-Demand)
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
echo "--> 5.2: Criando a estrutura base do Orquestrador (v1.7 - No On-Demand)..."
ORQUESTRADOR_DIR="$SISTEMA_DIR/ORQUESTRADOR"
mkdir -p "$ORQUESTRADOR_DIR"
cat > "$ORQUESTRADOR_DIR/requirements.txt" << REQ_EOF
requests==2.31.0
schedule==1.2.1
python-slugify==8.0.4
REQ_EOF
cat > "$ORQUESTRADOR_DIR/Dockerfile" << DOCKER_EOF
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY orchestrator.py .
CMD ["python", "-u", "orchestrator.py"]
DOCKER_EOF
cat > "$ORQUESTRADOR_DIR/orchestrator.py" << ORCH_EOF
import time, schedule, os, requests
from slugify import slugify
API_URL = os.getenv("API_URL", "http://vaas-gestao-web:8000/api/v1" )
MEDIAMTX_URL = os.getenv("MEDIAMTX_URL", "http://vaas-mediamtx:9997/v3" )
MEDIAMTX_USER = os.getenv("MEDIAMTX_API_USER", "admin")
MEDIAMTX_PASS = os.getenv("MEDIAMTX_API_PASS", "vaas_secret_pass")
def sync_cameras():
    print("="*46)
    print(f"[{time.ctime()}] Iniciando ciclo de sincronização...")
    try:
        response_api = requests.get(f"{API_URL}/cameras/")
        response_api.raise_for_status()
        api_cameras = {slugify(cam['nome_camera']): cam for cam in response_api.json() if cam.get('nome_camera')}
        print(f"API Gestão: Encontrado {len(api_cameras)} câmeras.")
        auth = (MEDIAMTX_USER, MEDIAMTX_PASS)
        response_mtx = requests.get(f"{MEDIAMTX_URL}/paths/list", auth=auth)
        response_mtx.raise_for_status()
        mtx_paths = response_mtx.json().get("items", {})
        print(f"MediaMTX: Encontrado {len(mtx_paths)} paths configurados.")
        cameras_to_add = [cam for name, cam in api_cameras.items() if cam.get('url_rtsp') and cam.get('is_active') and name not in mtx_paths]
        if not cameras_to_add:
            print("Nenhuma nova câmera RTSP para adicionar.")
        else:
            print(f"ADICIONANDO {len(cameras_to_add)} CÂMERAS RTSP...")
            for cam in cameras_to_add:
                path_name = slugify(cam['nome_camera'])
                payload = {"source": cam['url_rtsp'], "sourceOnDemand": False}
                print(f"  -> Adicionando path '{path_name}' com sourceOnDemand: False...")
                add_url = f"{MEDIAMTX_URL}/config/paths/add/{path_name}"
                res = requests.post(add_url, json=payload, auth=auth)
                res.raise_for_status()
                print(f"  -> SUCESSO: Path '{path_name}' adicionado ao MediaMTX.")
    except Exception as e:
        print(f"ERRO INESPERADO: {e}")
    print(f"[{time.ctime()}] Ciclo de sincronização finalizado.")
    print("="*46 + "\n")
if __name__ == "__main__":
    print("Serviço Orquestrador iniciado. Aguardando 15s...")
    time.sleep(15)
    schedule.every(30).seconds.do(sync_cameras)
    sync_cameras()
    while True:
        schedule.run_pending()
        time.sleep(1)
ORCH_EOF
echo "--- Estrutura base do Orquestrador (v1.7) com No On-Demand criada com sucesso."
