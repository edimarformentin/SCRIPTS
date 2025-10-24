#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 05-servicos-worker-ia-base.sh
# -----------------------------------------------------------------------------
# Worker de IA (base) que consome fila 'vaas.jobs' e apenas loga ações
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  cat > "$SERVICOS_DIR/worker-ia/requirements.txt" <<'REQ'
pika==1.3.2
REQ

  cat > "$SERVICOS_DIR/worker-ia/Dockerfile" <<'DF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY worker.py .
CMD ["python","-u","worker.py"]
DF

  cat > "$SERVICOS_DIR/worker-ia/worker.py" <<'PY'
import os, json, time
import pika

RABBIT_URL = os.getenv("VAAS_RABBIT_URL", "amqp://guest:guest@rabbitmq:5672/")

def connect():
    return pika.BlockingConnection(pika.URLParameters(RABBIT_URL))

def ensure(ch):
    ch.queue_declare(queue="vaas.jobs", durable=True)

def on_job(ch, method, properties, body):
    try:
        job = json.loads(body)
    except Exception:
        job = {"raw": body.decode("utf-8","ignore")}
    print("[worker-ia] job recebido:", job, flush=True)
    # TODO: IA real aqui (ex.: inferência). Por ora, simulamos:
    time.sleep(1)
    ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    while True:
        try:
            conn = connect()
            ch = conn.channel()
            ensure(ch)
            ch.basic_qos(prefetch_count=1)
            ch.basic_consume(queue="vaas.jobs", on_message_callback=on_job)
            print("[worker-ia] aguardando jobs...", flush=True)
            ch.start_consuming()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print("[worker-ia] erro:", e, flush=True)
            time.sleep(3)

if __name__ == "__main__":
    main()
PY

  ok "Worker IA base gerado."
}
main "$@"
