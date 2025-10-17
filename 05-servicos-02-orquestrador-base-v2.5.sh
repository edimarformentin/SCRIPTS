#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-02: Orquestrador (v2.5 - Atraso de Inicialização)
#
# Aumenta o atraso inicial para 45 segundos para garantir que o
# seed do banco de dados seja concluído antes do primeiro ciclo.
# =================================================================

echo "--> 5.2: Criando a estrutura do Orquestrador (v2.5 - Atraso de Inicialização)..."
ORQUESTRADOR_DIR="$SISTEMA_DIR/ORQUESTRADOR"
mkdir -p "$ORQUESTRADOR_DIR"

cat > "$ORQUESTRADOR_DIR/requirements.txt" << REQ_EOF
requests==2.31.0
schedule==1.2.1
python-slugify==8.0.4
pika==1.3.2
REQ_EOF

cat > "$ORQUESTRADOR_DIR/Dockerfile" << DOCKER_EOF
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY orchestrator.py .
CMD ["python", "-u", "orchestrator.py"]
DOCKER_EOF

echo "    -> Criando orchestrator.py com atraso de inicialização aumentado..."
cat > "$ORQUESTRADOR_DIR/orchestrator.py" << ORCH_EOF
import time
import schedule
import os
import requests
from slugify import slugify
import pika
import json

API_URL = os.getenv("API_URL", "http://vaas-gestao-web:8000/api/v1" )
MEDIAMTX_URL = os.getenv("MEDIAMTX_URL", "http://vaas-mediamtx:9997/v3" )
RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "vaas-rabbitmq")
QUEUE_NAME = "camera_processing_queue"
rabbit_connection = None
rabbit_channel = None

def connect_to_rabbitmq():
    global rabbit_connection, rabbit_channel
    while not rabbit_channel or rabbit_channel.is_closed:
        try:
            print("[RabbitMQ] Tentando conectar...")
            rabbit_connection = pika.BlockingConnection(pika.ConnectionParameters(host=RABBITMQ_HOST))
            rabbit_channel = rabbit_connection.channel()
            rabbit_channel.queue_declare(queue=QUEUE_NAME, durable=True)
            print("[RabbitMQ] Conexão e fila garantidas com sucesso.")
        except pika.exceptions.AMQPConnectionError as e:
            print(f"[RabbitMQ] Falha ao conectar: {e}. Tentando novamente em 10s...")
            time.sleep(10)

def publish_task(camera):
    global rabbit_channel
    try:
        if not rabbit_channel or rabbit_channel.is_closed:
            print("[RabbitMQ] Conexão perdida. Tentando reconectar...")
            connect_to_rabbitmq()
        if not camera.get('detectar_pessoas') and not camera.get('detectar_carros'):
            return
        message = {"camera_id": camera.get('id'), "camera_name": camera.get('nome_camera'), "rtsp_url": camera.get('url_rtsp'), "rtmp_path": camera.get('url_rtmp_path')}
        rabbit_channel.basic_publish(exchange='', routing_key=QUEUE_NAME, body=json.dumps(message), properties=pika.BasicProperties(delivery_mode=2))
        print(f"  [MSG_SENT] Tarefa para '{camera.get('nome_camera')}' publicada na fila.")
    except Exception as e:
        print(f"ERRO ao publicar tarefa para a câmera {camera.get('id')}: {e}")

def sync_mediamtx(api_rtsp_cameras, mtx_paths):
    print("\n--- Sincronizando MediaMTX ---")
    all_managed_names = set(api_rtsp_cameras.keys()) | set(mtx_paths.keys())
    for name in all_managed_names:
        cam_in_db = api_rtsp_cameras.get(name)
        path_in_mtx = mtx_paths.get(name)
        if cam_in_db and cam_in_db.get('is_active'):
            payload = {"source": cam_in_db['url_rtsp'], "sourceOnDemand": False}
            requests.patch(f"{MEDIAMTX_URL}/config/paths/patch/{name}", json=payload).raise_for_status()
        elif (not cam_in_db or not cam_in_db.get('is_active')) and path_in_mtx:
            if path_in_mtx.get('source', {}).get('type') == 'rtspSource':
                requests.post(f"{MEDIAMTX_URL}/config/paths/delete/{name}").raise_for_status()
    print("--- Sincronização MediaMTX concluída ---\n")

def main_cycle():
    print("="*60)
    print(f"[{time.ctime()}] Iniciando ciclo de orquestração v2.5...")
    try:
        response_api = requests.get(f"{API_URL}/cameras/")
        response_api.raise_for_status()
        all_cameras = response_api.json()
        print(f"API Gestão: {len(all_cameras)} câmeras encontradas no total.")
        api_rtsp_cameras = {slugify(c['nome_camera']): c for c in all_cameras if c.get('url_rtsp')}
        response_mtx = requests.get(f"{MEDIAMTX_URL}/paths/list")
        response_mtx.raise_for_status()
        mtx_paths_data = response_mtx.json().get("items")
        mtx_paths = mtx_paths_data if isinstance(mtx_paths_data, dict) else {}
        sync_mediamtx(api_rtsp_cameras, mtx_paths)
        print("--- Publicando Tarefas de IA ---")
        active_cameras = [cam for cam in all_cameras if cam.get('is_active')]
        print(f"{len(active_cameras)} câmeras ativas para potencial processamento.")
        for cam in active_cameras:
            publish_task(cam)
        print("--- Publicação de tarefas concluída ---")
    except Exception as e:
        print(f"ERRO INESPERADO DURANTE O CICLO PRINCIPAL: {e}")
    finally:
        print(f"[{time.ctime()}] Ciclo de orquestração finalizado.")
        print("="*60 + "\n")

if __name__ == "__main__":
    print("Serviço Orquestrador v2.5 (Atraso de Inicialização) iniciado.")
    print("Aguardando 45s para a estabilização completa do sistema e seed do banco...")
    time.sleep(45)

    connect_to_rabbitmq()
    schedule.every(60).seconds.do(main_cycle)
    main_cycle()

    while True:
        schedule.run_pending()
        time.sleep(1)
ORCH_EOF

echo "--- Estrutura do Orquestrador (v2.5) criada com sucesso."
