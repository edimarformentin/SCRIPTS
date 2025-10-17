#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-04: Worker de IA - Estrutura Base (v1.1 - Dep Fix)
#
# Corrige a dependência do OpenCV no Dockerfile, trocando
# 'libgl1-mesa-glx' por 'libgl1'.
# =================================================================

echo "--> 5.4: Criando a estrutura base do Worker de IA (v1.1 - Dep Fix)..."

WORKER_IA_DIR="$SISTEMA_DIR/WORKER_IA"
mkdir -p "$WORKER_IA_DIR"

# --- Cria o arquivo requirements.txt (sem alterações) ---
echo "    -> Recriando requirements.txt para o worker..."
cat << 'REQ_EOF' > "$WORKER_IA_DIR/requirements.txt"
pika==1.3.2
requests==2.31.0
opencv-python==4.9.0.80
ultralytics==8.2.2
Pillow==10.3.0
REQ_EOF

# --- Cria o Dockerfile para o worker (COM A CORREÇÃO) ---
echo "    -> Criando Dockerfile para o worker com dependência corrigida..."
cat << 'DOCKER_EOF' > "$WORKER_IA_DIR/Dockerfile"
FROM python:3.11-slim

WORKDIR /app

# Instala dependências do sistema para OpenCV
# --- AQUI ESTÁ A CORREÇÃO ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY worker.py .

CMD ["python", "-u", "worker.py"]
DOCKER_EOF

# --- Cria o script worker.py (sem alterações) ---
echo "    -> Recriando worker.py..."
cat << 'WORKER_EOF' > "$WORKER_IA_DIR/worker.py"
import pika
import time
import os
import sys

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "vaas-rabbitmq")
QUEUE_NAME = "camera_processing_queue"

def main():
    connection = None
    while not connection:
        try:
            print(f"[*] Tentando conectar ao RabbitMQ em '{RABBITMQ_HOST}'...")
            connection = pika.BlockingConnection(pika.ConnectionParameters(host=RABBITMQ_HOST))
            print("[+] Conexão com RabbitMQ estabelecida com sucesso.")
        except pika.exceptions.AMQPConnectionError:
            print(f"[!] Falha ao conectar ao RabbitMQ em '{RABBITMQ_HOST}'. Tentando novamente em 5 segundos...")
            time.sleep(5)

    channel = connection.channel()
    channel.queue_declare(queue=QUEUE_NAME, durable=True)

    def callback(ch, method, properties, body):
        print(f"[*] Mensagem recebida: {body.decode()}")
        time.sleep(2)
        print(f"[+] Mensagem processada.")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue=QUEUE_NAME, on_message_callback=callback)

    print(f"[*] Aguardando por mensagens na fila '{QUEUE_NAME}'. Para sair, pressione CTRL+C")
    channel.start_consuming()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('Interrompido')
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)
WORKER_EOF

echo "--- Estrutura base do Worker de IA (v1.1) criada com sucesso."
