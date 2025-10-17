#!/bin/bash
# =================================================================
# Script: Orquestrador - Estrutura Base (v1.9 - Sincronização Inteligente)
#
# Aprimora a sincronização para verificar e corrigir URLs de origem
# inconsistentes entre o banco de dados e o MediaMTX.
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 5.2: Criando a estrutura base do Orquestrador (v1.9 - Sincronização Inteligente)..."
ORQUESTRADOR_DIR="$SISTEMA_DIR/ORQUESTRADOR"
mkdir -p "$ORQUESTRADOR_DIR"

# Recria arquivos que não mudam
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

# --- orchestrator.py (LÓGICA DE REFINAMENTO) ---
cat > "$ORQUESTRADOR_DIR/orchestrator.py" << ORCH_EOF
import time, schedule, os, requests
from slugify import slugify

API_URL = os.getenv("API_URL", "http://vaas-gestao-web:8000/api/v1" )
MEDIAMTX_URL = os.getenv("MEDIAMTX_URL", "http://vaas-mediamtx:9997/v3" )

def sync_cameras():
    print("="*50)
    print(f"[{time.ctime()}] Iniciando ciclo de sincronização inteligente...")
    try:
        # 1. Obter câmeras e paths
        response_api = requests.get(f"{API_URL}/cameras/")
        response_api.raise_for_status()
        all_cameras = response_api.json()

        api_rtsp_cameras = {
            slugify(cam['nome_camera']): cam
            for cam in all_cameras
            if cam.get('url_rtsp')
        }
        print(f"API Gestão: {len(api_rtsp_cameras)} câmeras RTSP para gerenciar.")

        response_mtx = requests.get(f"{MEDIAMTX_URL}/paths/list")
        response_mtx.raise_for_status()
        mtx_paths_data = response_mtx.json().get("items", {})
        mtx_paths = mtx_paths_data if mtx_paths_data is not None else {}
        print(f"MediaMTX: {len(mtx_paths)} paths configurados.")

        # 2. Sincronizar Câmeras (Adicionar, Atualizar, Remover)
        all_managed_names = set(api_rtsp_cameras.keys()) | set(mtx_paths.keys())

        for name in all_managed_names:
            cam_in_db = api_rtsp_cameras.get(name)
            path_in_mtx = mtx_paths.get(name)

            if cam_in_db and cam_in_db.get('is_active') and not path_in_mtx:
                print(f"  [ADD] Path '{name}' não existe. Adicionando...")
                payload = {"source": cam_in_db['url_rtsp'], "sourceOnDemand": False}
                requests.post(f"{MEDIAMTX_URL}/config/paths/add/{name}", json=payload).raise_for_status()
                print(f"  -> SUCESSO: Path '{name}' adicionado.")

            elif cam_in_db and cam_in_db.get('is_active') and path_in_mtx:
                current_source = path_in_mtx.get('source', {}).get('url', '')
                expected_source = cam_in_db['url_rtsp']
                if current_source != expected_source:
                    print(f"  [UPDATE] Path '{name}' com URL de origem incorreta. Corrigindo...")
                    requests.post(f"{MEDIAMTX_URL}/config/paths/delete/{name}").raise_for_status()
                    payload = {"source": expected_source, "sourceOnDemand": False}
                    requests.post(f"{MEDIAMTX_URL}/config/paths/add/{name}", json=payload).raise_for_status()
                    print(f"  -> SUCESSO: Path '{name}' corrigido.")

            elif (not cam_in_db or not cam_in_db.get('is_active')) and path_in_mtx:
                if path_in_mtx.get('source', {}).get('type') == 'rtspSource':
                    print(f"  [REMOVE] Path '{name}' obsoleto. Removendo...")
                    requests.post(f"{MEDIAMTX_URL}/config/paths/delete/{name}").raise_for_status()
                    print(f"  -> SUCESSO: Path '{name}' removido.")

    except Exception as e:
        print(f"ERRO INESPERADO DURANTE A SINCRONIZAÇÃO: {e}")
    finally:
        print(f"[{time.ctime()}] Ciclo de sincronização finalizado.")
        print("="*50 + "\n")

if __name__ == "__main__":
    print("Serviço Orquestrador v1.9 (Sincronização Inteligente) iniciado.")
    print("Aguardando 15s para a estabilização dos serviços...")
    time.sleep(15)
    schedule.every(30).seconds.do(sync_cameras)
    sync_cameras()
    while True:
        schedule.run_pending()
        time.sleep(1)
ORCH_EOF

echo "--- Estrutura base do Orquestrador (v1.9) com sincronização inteligente, criada com sucesso."
