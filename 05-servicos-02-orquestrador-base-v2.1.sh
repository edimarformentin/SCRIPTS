#!/bin/bash
# =================================================================
# Script: Orquestrador - Estrutura Base (v2.1 - Resiliente e Idempotente)
#
# - Usa o endpoint 'patch' do MediaMTX para adicionar/atualizar,
#   o que é idempotente e evita erros de "path já existe".
# - Simplifica drasticamente a lógica de sincronização.
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 5.2: Criando a estrutura base do Orquestrador (v2.1 - Resiliente)..."
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

# --- orchestrator.py (LÓGICA FINAL, SIMPLES E ROBUSTA) ---
cat > "$ORQUESTRADOR_DIR/orchestrator.py" << ORCH_EOF
import time, schedule, os, requests
from slugify import slugify

API_URL = os.getenv("API_URL", "http://vaas-gestao-web:8000/api/v1" )
MEDIAMTX_URL = os.getenv("MEDIAMTX_URL", "http://vaas-mediamtx:9997/v3" )

def sync_cameras():
    print("="*50)
    print(f"[{time.ctime()}] Iniciando ciclo de sincronização v2.1 (Resiliente)...")
    try:
        # 1. Obter dados da API e do MediaMTX
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
        mtx_paths = response_mtx.json().get("items") or {}
        print(f"MediaMTX: {len(mtx_paths)} paths configurados.")

        # 2. SINCRONIZAR ADIÇÕES E ATUALIZAÇÕES
        for name, cam_data in api_rtsp_cameras.items():
            if cam_data.get('is_active'):
                print(f"  [SYNC] Garantindo que o path '{name}' está configurado...")
                payload = {"source": cam_data['url_rtsp'], "sourceOnDemand": False}
                requests.patch(f"{MEDIAMTX_URL}/config/paths/patch/{name}", json=payload).raise_for_status()
        print("  -> Sincronização de paths ativos concluída.")

        # 3. SINCRONIZAR REMOÇÕES
        for name, path_info in mtx_paths.items():
            if path_info.get('source', {}).get('type') != 'rtspSource':
                continue

            cam_in_db = api_rtsp_cameras.get(name)
            if not cam_in_db or not cam_in_db.get('is_active'):
                print(f"  [REMOVE] Path '{name}' obsoleto. Removendo...")
                requests.post(f"{MEDIAMTX_URL}/config/paths/delete/{name}").raise_for_status()
                print(f"  -> SUCESSO: Path '{name}' removido.")

    except Exception as e:
        print(f"ERRO INESPERADO DURANTE A SINCRONIZAÇÃO: {e}")
    finally:
        print(f"[{time.ctime()}] Ciclo de sincronização finalizado.")
        print("="*50 + "\n")

if __name__ == "__main__":
    print("Serviço Orquestrador v2.1 (Resiliente) iniciado.")
    print("Aguardando 15s para a estabilização dos serviços...")
    time.sleep(15)
    schedule.every(30).seconds.do(sync_cameras)
    sync_cameras()
    while True:
        schedule.run_pending()
        time.sleep(1)
ORCH_EOF

echo "--- Estrutura base do Orquestrador (v2.1) com lógica resiliente, criada com sucesso."
