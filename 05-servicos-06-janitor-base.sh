#!/bin/bash
# =================================================================
# Script: 05-servicos-06-janitor-base.sh (v1.3 - Lógica Cíclica Robusta)
#
# Propósito:
# Restaura a lógica de agendamento do serviço 'vaas-janitor' e
# aumenta o atraso inicial para garantir que o script de seed do
# banco de dados tenha tempo de ser executado antes da primeira
# verificação.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 5.6: Criando a estrutura do Serviço Janitor (v1.3 - Lógica Cíclica)..."

JANITOR_DIR="$SISTEMA_DIR/JANITOR"
mkdir -p "$JANITOR_DIR"

echo "    -> Criando requirements.txt para o janitor..."
cat << 'REQ_EOF' > "$JANITOR_DIR/requirements.txt"
requests==2.31.0
schedule==1.2.1
python-slugify==8.0.4
REQ_EOF

echo "    -> Criando Dockerfile para o janitor..."
cat << 'DOCKER_EOF' > "$JANITOR_DIR/Dockerfile"
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY janitor.py .
CMD ["python", "-u", "janitor.py"]
DOCKER_EOF

echo "    -> Criando janitor.py com lógica cíclica robusta..."
cat << 'JANITOR_PY_EOF' > "$JANITOR_DIR/janitor.py"
import os
import schedule
import time
import requests
from datetime import datetime
from slugify import slugify

API_URL = os.getenv("API_URL", "http://vaas-gestao-web:8000/api/v1" )
RECORDINGS_BASE_PATH = "/recordings"

def cleanup_recordings():
    print(f"[{datetime.now()}] Iniciando ciclo de limpeza de gravações...")
    try:
        response = requests.get(f"{API_URL}/cameras/")
        response.raise_for_status()
        all_cameras = response.json()

        if not all_cameras:
            print("API não retornou câmeras. O banco pode estar vazio. Aguardando próximo ciclo.")
            return

        rtsp_cameras_to_clean = [
            cam for cam in all_cameras
            if cam.get("url_rtsp") is not None and cam.get("dias_gravacao", 0) > 0
        ]

        if not rtsp_cameras_to_clean:
            print("Nenhuma câmera RTSP com gravação configurada para limpar.")
            return

        print(f"Encontradas {len(rtsp_cameras_to_clean)} câmera(s) RTSP para verificar a limpeza.")

        for cam in rtsp_cameras_to_clean:
            camera_name = cam.get('nome_camera')
            retention_days = cam.get('dias_gravacao')

            path_name = slugify(camera_name)
            camera_rec_path = os.path.join(RECORDINGS_BASE_PATH, path_name)

            if not os.path.isdir(camera_rec_path):
                continue

            print(f"  -> Verificando '{camera_name}' (path: {path_name}). Retenção: {retention_days} dia(s).")

            cutoff_time = time.time() - (retention_days * 86400)

            for filename in os.listdir(camera_rec_path):
                file_path = os.path.join(camera_rec_path, filename)
                if os.path.isfile(file_path):
                    file_mod_time = os.path.getmtime(file_path)
                    if file_mod_time < cutoff_time:
                        try:
                            os.remove(file_path)
                            print(f"    - DELETADO: {filename}")
                        except OSError as e:
                            print(f"    - ERRO ao deletar {filename}: {e}")

    except requests.exceptions.RequestException as e:
        print(f"ERRO: Não foi possível conectar à API de gestão: {e}")
    except Exception as e:
        print(f"ERRO INESPERADO durante a limpeza: {e}")
    finally:
        print(f"[{datetime.now()}] Ciclo de limpeza finalizado.")


if __name__ == "__main__":
    print("Serviço Janitor (Limpador de Gravações) v1.3 iniciado.")

    # Atraso inicial generoso para garantir que todo o sistema, incluindo o seed, esteja pronto.
    initial_delay = 60
    print(f"Aguardando {initial_delay} segundos para a estabilização completa do sistema...")
    time.sleep(initial_delay)

    # Agenda a limpeza para rodar a cada 24 horas.
    schedule.every(24).hours.do(cleanup_recordings)

    # Loop infinito para manter o serviço rodando
    while True:
        print("\nPróxima verificação de limpeza agendada para daqui a 24 horas.")
        cleanup_recordings() # Roda uma vez e depois entra no agendamento
        schedule.run_pending()
        time.sleep(schedule.idle_seconds()) # Dorme até a próxima tarefa agendada

JANITOR_PY_EOF

echo "--- Estrutura do Serviço Janitor (v1.3) criada com sucesso."
