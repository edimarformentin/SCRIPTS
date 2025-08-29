#!/usr/bin/env bash
set -euo pipefail

BASE="/home/edimar/SISTEMA"
cd "$BASE"

echo "==== 8.10: INSTALAR BROKER + WORKERS (no $BASE) ===="

mkdir -p BROKER/data WORKERS SCRIPTS

# --- .env: garante chaves do broker e URLs DB/BROKER ---
touch .env
add_if_absent() {
  local KEY="$1" VAL="$2"
  grep -q "^${KEY}=" .env || echo "${KEY}=${VAL}" >> .env
}
# Broker defaults (idempotente)
add_if_absent BROKER_USER broker
add_if_absent BROKER_PASS broker123
add_if_absent BROKER_HOST broker
add_if_absent BROKER_PORT 5672
add_if_absent BROKER_MAN_PORT 15672

# DB_URL e BROKER_URL (derivados)
POSTGRES_USER="$(grep -oP '^POSTGRES_USER=\K.*' .env || true)"
POSTGRES_PASSWORD="$(grep -oP '^POSTGRES_PASSWORD=\K.*' .env || true)"
POSTGRES_DB="$(grep -oP '^POSTGRES_DB=\K.*' .env || true)"
[ -n "${POSTGRES_USER}" ] && [ -n "${POSTGRES_DB}" ] || {
  echo "WARN: POSTGRES_* não encontrado no .env do SISTEMA. Seus scripts 1..2 devem criar isso."
}

DB_URL="postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@banco:5432/${POSTGRES_DB:-sistema}"
BROKER_URL="amqp://$(grep -oP '^BROKER_USER=\K.*' .env):$(grep -oP '^BROKER_PASS=\K.*' .env)@${BROKER_HOST:-broker}:${BROKER_PORT:-5672}/%2f"

add_if_absent DB_URL "$DB_URL"
add_if_absent BROKER_URL "$BROKER_URL"

# --- docker-compose do broker ---
cat > docker-compose.broker.yml <<'YML'
services:
  broker:
    image: rabbitmq:3.13-management
    container_name: broker
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: ${BROKER_USER}
      RABBITMQ_DEFAULT_PASS: ${BROKER_PASS}
    ports:
      - "${BROKER_PORT:-5672}:5672"
      - "${BROKER_MAN_PORT:-15672}:15672"
    volumes:
      - ./BROKER/data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10
YML

# --- workers (Python) ---
cat > WORKERS/worker_person.py <<'PY'
import json, os, time, socket, traceback, threading
import pika, psycopg2

BROKER_URL = os.environ["BROKER_URL"]
DB_URL     = os.environ["DB_URL"]
WORKER_ID  = os.environ.get("WORKER_ID", f"person-{socket.gethostname()}")

RENEW_EVERY_SEC = int(os.getenv("RENEW_EVERY_SEC", "5"))
LEASE_EXT_SEC   = int(os.getenv("LEASE_EXT_SEC", "20"))

def db_conn():
    return psycopg2.connect(DB_URL)

def get_det_id(cur, det_name:str) -> int:
    cur.execute("INSERT INTO detection_type(name) VALUES (%s) ON CONFLICT (name) DO NOTHING", (det_name,))
    cur.execute("SELECT id FROM detection_type WHERE name=%s", (det_name,))
    return cur.fetchone()[0]

def upsert_assignment_start(cur, camera_id:int, det_name:str, lease_ttl:int):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO assignment(camera_id, detection_type_id, worker_id, lease_until, status)
        VALUES (%s, %s, %s, now() + (%s || ' sec')::interval, 'leased')
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET worker_id=EXCLUDED.worker_id,
              lease_until=EXCLUDED.lease_until,
              status='leased',
              updated_at=now()
    """, (camera_id, det_id, WORKER_ID, lease_ttl))

def upsert_assignment_stop(cur, camera_id:int, det_name:str):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO assignment(camera_id, detection_type_id, worker_id, lease_until, status)
        VALUES (%s, %s, NULL, NULL, 'stopped')
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET worker_id=NULL,
              lease_until=NULL,
              status='stopped',
              updated_at=now()
    """, (camera_id, det_id))

def upsert_subscription_params(cur, camera_id:int, det_name:str, params:dict):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO camera_subscription(camera_id, detection_type_id, params, enabled)
        VALUES (%s, %s, %s::jsonb, TRUE)
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET params = camera_subscription.params || EXCLUDED.params,
              updated_at = now()
    """, (camera_id, det_id, json.dumps(params)))

def renew_loop():
    time.sleep(RENEW_EVERY_SEC)  # atraso inicial
    while True:
        try:
            with db_conn() as dbc, dbc.cursor() as cur:
                cur.execute("""
                    UPDATE assignment a
                    SET lease_until = GREATEST(a.lease_until, now()) + (%s || ' sec')::interval,
                        updated_at = now()
                    FROM detection_type dt
                    WHERE a.detection_type_id = dt.id
                      AND dt.name = %s
                      AND a.worker_id = %s
                      AND a.status = 'leased'
                """, (LEASE_EXT_SEC, "person", WORKER_ID))
        except Exception as e:
            print(f"[worker:{WORKER_ID}] erro no renew: {e}", flush=True)
        time.sleep(RENEW_EVERY_SEC)

def main():
    params = pika.URLParameters(BROKER_URL)
    while True:
        try:
            conn = pika.BlockingConnection(params)
            ch = conn.channel()
            ch.queue_declare(queue="det.start.person", durable=True)
            ch.queue_declare(queue="det.stop", durable=True)
            ch.queue_declare(queue="det.params", durable=True)
            ch.basic_qos(prefetch_count=3)
            print(f"[worker:{WORKER_ID}] aguardando det.start.person / det.stop / det.params", flush=True)

            def on_start(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    cam = int(msg["camera_id"])
                    ttl = int(msg.get("lease_ttl_sec", 60))
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_assignment_start(cur, cam, "person", ttl)
                    print(f"[worker:{WORKER_ID}] START person camera={cam} ttl={ttl}s -> ASSIGN ok", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO START: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            def on_stop(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    det = msg.get("type") or msg.get("detection_type")
                    if det != "person":
                        chx.basic_ack(delivery_tag=method.delivery_tag); return
                    cam = int(msg["camera_id"])
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_assignment_stop(cur, cam, "person")
                    print(f"[worker:{WORKER_ID}] STOP person camera={cam} -> stopped", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO STOP: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            def on_params(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    det = msg.get("type") or msg.get("detection_type")
                    if det != "person":
                        chx.basic_ack(delivery_tag=method.delivery_tag); return
                    cam = int(msg["camera_id"])
                    params = msg.get("params") or {k.replace('-','_'):v for k,v in msg.items() if k in ("threshold","max_fps")}
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_subscription_params(cur, cam, "person", params)
                    print(f"[worker:{WORKER_ID}] PARAMS person camera={cam} -> merged {params}", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO PARAMS: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            threading.Thread(target=renew_loop, daemon=True).start()
            ch.basic_consume(queue="det.start.person", on_message_callback=on_start, auto_ack=False)
            ch.basic_consume(queue="det.stop", on_message_callback=on_stop, auto_ack=False)
            ch.basic_consume(queue="det.params", on_message_callback=on_params, auto_ack=False)
            ch.start_consuming()
        except Exception as e:
            print(f"[worker:{WORKER_ID}] conexão perdida: {e}; retry em 1s", flush=True)
            time.sleep(1)

if __name__ == "__main__":
    main()
PY

cat > WORKERS/worker_car.py <<'PY'
import json, os, time, socket, traceback, threading
import pika, psycopg2

BROKER_URL = os.environ["BROKER_URL"]
DB_URL     = os.environ["DB_URL"]
WORKER_ID  = os.environ.get("WORKER_ID", f"car-{socket.gethostname()}")

RENEW_EVERY_SEC = int(os.getenv("RENEW_EVERY_SEC", "5"))
LEASE_EXT_SEC   = int(os.getenv("LEASE_EXT_SEC", "20"))

def db_conn():
    return psycopg2.connect(DB_URL)

def get_det_id(cur, det_name:str) -> int:
    cur.execute("INSERT INTO detection_type(name) VALUES (%s) ON CONFLICT (name) DO NOTHING", (det_name,))
    cur.execute("SELECT id FROM detection_type WHERE name=%s", (det_name,))
    return cur.fetchone()[0]

def upsert_assignment_start(cur, camera_id:int, det_name:str, lease_ttl:int):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO assignment(camera_id, detection_type_id, worker_id, lease_until, status)
        VALUES (%s, %s, %s, now() + (%s || ' sec')::interval, 'leased')
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET worker_id=EXCLUDED.worker_id,
              lease_until=EXCLUDED.lease_until,
              status='leased',
              updated_at=now()
    """, (camera_id, det_id, WORKER_ID, lease_ttl))

def upsert_assignment_stop(cur, camera_id:int, det_name:str):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO assignment(camera_id, detection_type_id, worker_id, lease_until, status)
        VALUES (%s, %s, NULL, NULL, 'stopped')
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET worker_id=NULL,
              lease_until=NULL,
              status='stopped',
              updated_at=now()
    """, (camera_id, det_id))

def upsert_subscription_params(cur, camera_id:int, det_name:str, params:dict):
    det_id = get_det_id(cur, det_name)
    cur.execute("""
        INSERT INTO camera_subscription(camera_id, detection_type_id, params, enabled)
        VALUES (%s, %s, %s::jsonb, TRUE)
        ON CONFLICT (camera_id, detection_type_id) DO UPDATE
          SET params = camera_subscription.params || EXCLUDED.params,
              updated_at = now()
    """, (camera_id, det_id, json.dumps(params)))

def renew_loop():
    time.sleep(RENEW_EVERY_SEC)
    while True:
        try:
            with db_conn() as dbc, dbc.cursor() as cur:
                cur.execute("""
                    UPDATE assignment a
                    SET lease_until = GREATEST(a.lease_until, now()) + (%s || ' sec')::interval,
                        updated_at = now()
                    FROM detection_type dt
                    WHERE a.detection_type_id = dt.id
                      AND dt.name = %s
                      AND a.worker_id = %s
                      AND a.status = 'leased'
                """, (LEASE_EXT_SEC, "car", WORKER_ID))
        except Exception as e:
            print(f"[worker:{WORKER_ID}] erro no renew: {e}", flush=True)
        time.sleep(RENEW_EVERY_SEC)

def main():
    params = pika.URLParameters(BROKER_URL)
    while True:
        try:
            conn = pika.BlockingConnection(params)
            ch = conn.channel()
            ch.queue_declare(queue="det.start.car", durable=True)
            ch.queue_declare(queue="det.stop", durable=True)
            ch.queue_declare(queue="det.params", durable=True)
            ch.basic_qos(prefetch_count=3)
            print(f"[worker:{WORKER_ID}] aguardando det.start.car / det.stop / det.params", flush=True)

            def on_start(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    cam = int(msg["camera_id"])
                    ttl = int(msg.get("lease_ttl_sec", 60))
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_assignment_start(cur, cam, "car", ttl)
                    print(f"[worker:{WORKER_ID}] START car camera={cam} ttl={ttl}s -> ASSIGN ok", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO START: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            def on_stop(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    det = msg.get("type") or msg.get("detection_type")
                    if det != "car":
                        chx.basic_ack(delivery_tag=method.delivery_tag); return
                    cam = int(msg["camera_id"])
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_assignment_stop(cur, cam, "car")
                    print(f"[worker:{WORKER_ID}] STOP car camera={cam} -> stopped", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO STOP: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            def on_params(chx, method, props, body):
                try:
                    msg = json.loads(body.decode("utf-8"))
                    det = msg.get("type") or msg.get("detection_type")
                    if det != "car":
                        chx.basic_ack(delivery_tag=method.delivery_tag); return
                    cam = int(msg["camera_id"])
                    params = msg.get("params") or {k.replace('-','_'):v for k,v in msg.items() if k in ("threshold","max_fps")}
                    with db_conn() as dbc, dbc.cursor() as cur:
                        upsert_subscription_params(cur, cam, "car", params)
                    print(f"[worker:{WORKER_ID}] PARAMS car camera={cam} -> merged {params}", flush=True)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO PARAMS: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

            threading.Thread(target=renew_loop, daemon=True).start()
            ch.basic_consume(queue="det.start.car", on_message_callback=on_start, auto_ack=False)
            ch.basic_consume(queue="det.stop", on_message_callback=on_stop, auto_ack=False)
            ch.basic_consume(queue="det.params", on_message_callback=on_params, auto_ack=False)
            ch.start_consuming()
        except Exception as e:
            print(f"[worker:{WORKER_ID}] conexão perdida: {e}; retry em 1s", flush=True)
            time.sleep(1)

if __name__ == "__main__":
    main()
PY

cat > WORKERS/events_ingestor.py <<'PY'
import json, os, time, socket, traceback
import pika, psycopg2

BROKER_URL = os.environ["BROKER_URL"]
DB_URL     = os.environ["DB_URL"]
WORKER_ID  = os.environ.get("WORKER_ID", f"ingestor-{socket.gethostname()}")

def db():
    return psycopg2.connect(DB_URL)

def get_det_id(cur, det_name:str) -> int:
    cur.execute("INSERT INTO detection_type(name) VALUES (%s) ON CONFLICT (name) DO NOTHING", (det_name,))
    cur.execute("SELECT id FROM detection_type WHERE name=%s", (det_name,))
    return cur.fetchone()[0]

def insert_event(cur, ev:dict):
    det_id = get_det_id(cur, ev["detection_type"])
    cur.execute("""
        INSERT INTO det_event(event_id, camera_id, detection_type_id, ts, cls, conf)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """, (
        ev.get("event_id"),
        int(ev["camera_id"]),
        det_id,
        ev["ts"],
        ev.get("cls"),
        float(ev.get("conf", 0.0)),
    ))

def main():
    params = pika.URLParameters(BROKER_URL)
    while True:
        try:
            conn = pika.BlockingConnection(params)
            ch = conn.channel()
            ch.queue_declare(queue="det.events", durable=True)
            ch.basic_qos(prefetch_count=50)
            print(f"[{WORKER_ID}] aguardando msgs em det.events", flush=True)
            def on_msg(chx, method, props, body):
                try:
                    ev = json.loads(body.decode("utf-8"))
                    with db() as dbc, dbc.cursor() as cur:
                        insert_event(cur, ev)
                    chx.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"[{WORKER_ID}] ERRO: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
            ch.basic_consume(queue="det.events", on_message_callback=on_msg, auto_ack=False)
            ch.start_consuming()
        except Exception as e:
            print(f"[{WORKER_ID}] conexão perdida: {e}; retry em 1s", flush=True)
            time.sleep(1)

if __name__ == "__main__":
    main()
PY

cat > WORKERS/lease_janitor.py <<'PY'
import os, time, socket, traceback
import psycopg2

DB_URL = os.environ["DB_URL"]
WORKER_ID = os.environ.get("WORKER_ID", f"janitor-{socket.gethostname()}")
INTERVAL = int(os.getenv("JANITOR_INTERVAL", "5"))

def run():
    while True:
        try:
            with psycopg2.connect(DB_URL) as dbc, dbc.cursor() as cur:
                cur.execute("""
                    UPDATE assignment a
                       SET status='expired', worker_id=NULL, lease_until=NULL, updated_at=now()
                     WHERE a.status='leased' AND a.lease_until < now();
                """)
                print(f"[{WORKER_ID}] expired rows={cur.rowcount}", flush=True)
        except Exception as e:
            print(f"[{WORKER_ID}] ERRO JANITOR: {e}\n{traceback.format_exc()}", flush=True)
        time.sleep(INTERVAL)

if __name__ == "__main__":
    run()
PY

# publisher stub
cat > BROKER/publish.py <<'PY'
import os, sys, pika
BROKER_URL=os.environ["BROKER_URL"]
conn=pika.BlockingConnection(pika.URLParameters(BROKER_URL))
ch=conn.channel()
q=sys.argv[1]; msg=sys.argv[2]
ch.queue_declare(queue=q, durable=True)
ch.basic_publish(exchange="", routing_key=q, body=msg)
print(f"OK: publicado em {q}")
conn.close()
PY

# --- compose dos workers (somente rede default; depois conectamos ao DB via 'network connect') ---
cat > docker-compose.workers.yml <<'YML'
services:
  worker-person:
    image: python:3.12-slim
    container_name: worker-person
    restart: unless-stopped
    env_file: .env
    environment:
      WORKER_ID: person-1
      RENEW_EVERY_SEC: "5"
      LEASE_EXT_SEC: "20"
    working_dir: /app
    volumes: [ "./WORKERS:/app" ]
    command: bash -lc "pip -q install pika==1.3.2 psycopg2-binary==2.9.9 && python worker_person.py"
    depends_on: [ broker ]

  worker-car:
    image: python:3.12-slim
    container_name: worker-car
    restart: unless-stopped
    env_file: .env
    environment:
      WORKER_ID: car-1
      RENEW_EVERY_SEC: "5"
      LEASE_EXT_SEC: "20"
    working_dir: /app
    volumes: [ "./WORKERS:/app" ]
    command: bash -lc "pip -q install pika==1.3.2 psycopg2-binary==2.9.9 && python worker_car.py"
    depends_on: [ broker ]

  events-ingestor:
    image: python:3.12-slim
    container_name: events-ingestor
    restart: unless-stopped
    env_file: .env
    environment:
      WORKER_ID: events-1
    working_dir: /app
    volumes: [ "./WORKERS:/app" ]
    command: bash -lc "pip -q install pika==1.3.2 psycopg2-binary==2.9.9 && python events_ingestor.py"
    depends_on: [ broker ]

  lease-janitor:
    image: python:3.12-slim
    container_name: lease-janitor
    restart: unless-stopped
    env_file: .env
    environment:
      WORKER_ID: janitor-1
      JANITOR_INTERVAL: "5"
    working_dir: /app
    volumes: [ "./WORKERS:/app" ]
    command: bash -lc "pip -q install psycopg2-binary==2.9.9 && python lease_janitor.py"
YML

# --- Sobe com overrides (sem depender do 6_subir_docker.sh) ---
echo "-> Subindo broker + workers com overrides..."
docker compose -f docker-compose.yml -f docker-compose.broker.yml -f docker-compose.workers.yml up -d

# --- Conecta workers à rede do banco se necessário ---
DB_CONT="$(docker ps --filter "name=banco" --format '{{.Names}}' | head -n1 || true)"
if [ -n "${DB_CONT}" ]; then
  DB_NET="$(docker inspect "$DB_CONT" -f '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' | head -n1 || true)"
  for SVC in worker-person worker-car events-ingestor lease-janitor; do
    if docker ps --format '{{.Names}}' | grep -qx "$SVC"; then
      if [ -n "${DB_NET}" ] && ! docker inspect "$SVC" -f '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' | grep -qx "$DB_NET"; then
        docker network connect "$DB_NET" "$SVC" || true
      fi
    fi
  done
fi

echo "-> Containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}' | egrep 'broker|worker-(person|car)|events-ingestor|lease-janitor|gestao|banco|mediamtx' || true

echo "==== 8.10 CONCLUÍDO ===="
