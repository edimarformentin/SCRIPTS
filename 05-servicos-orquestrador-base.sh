#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 05-servicos-orquestrador-base.sh
# -----------------------------------------------------------------------------
# Estrutura base do Orquestrador (RabbitMQ + Postgres)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  cat > "$SERVICOS_DIR/orquestrador/requirements.txt" <<'REQ'
pika==1.3.2
psycopg2-binary==2.9.9
REQ

  cat > "$SERVICOS_DIR/orquestrador/Dockerfile" <<'DF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY orchestrator.py .
CMD ["python","-u","orchestrator.py"]
DF

  cat > "$SERVICOS_DIR/orquestrador/orchestrator.py" <<'PY'
import os, json, time
import pika
import psycopg2

RABBIT_URL = os.getenv("VAAS_RABBIT_URL", "amqp://guest:guest@rabbitmq:5672/")
DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres-db:5432/vaas_db")

def connect_rabbit():
    params = pika.URLParameters(RABBIT_URL)
    return pika.BlockingConnection(params)

def connect_db():
    return psycopg2.connect(DB_URL)

def ensure_queues(ch):
    ch.queue_declare(queue="vaas.events", durable=True)
    ch.queue_declare(queue="vaas.jobs", durable=True)

def on_event(ch, method, properties, body):
    try:
        evt = json.loads(body)
    except Exception:
        evt = {"raw": body.decode("utf-8","ignore")}
    print("[orquestrador] evento:", evt, flush=True)
    # Exemplo: ao receber camera.registered, poderíamos criar job de análise:
    if isinstance(evt, dict) and evt.get("type") == "camera.registered":
        ch.basic_publish(exchange="", routing_key="vaas.jobs", body=json.dumps({"type":"analyze", "camera_id": evt.get("camera_id")}))
    ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    while True:
        try:
            conn = connect_rabbit()
            ch = conn.channel()
            ensure_queues(ch)
            ch.basic_qos(prefetch_count=1)
            ch.basic_consume(queue="vaas.events", on_message_callback=on_event)
            print("[orquestrador] aguardando eventos...", flush=True)
            ch.start_consuming()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print("[orquestrador] erro:", e, flush=True)
            time.sleep(3)

if __name__ == "__main__":
    main()
PY

  ok "Orquestrador base gerado."
}
main "$@"
