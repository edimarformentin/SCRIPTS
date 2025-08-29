#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/edimar/SISTEMA"
mkdir -p "$ROOT"/{WORKERS,BROKER,GESTAO_WEB,DB/data,SCRIPTS}
cd "$ROOT"

# --- 1) .env: injeta blocos do broker e variáveis DB/BROKER URL (idempotente) ---
touch .env
grep -q '^# --- Broker (RabbitMQ) ---' .env 2>/dev/null || cat >> .env <<'EOF'
# --- Broker (RabbitMQ) ---
BROKER_USER=broker
BROKER_PASS=broker123
BROKER_HOST=broker
BROKER_PORT=5672
BROKER_MAN_PORT=15672
EOF

grep -q '^# --- Postgres ---' .env 2>/dev/null || cat >> .env <<'EOF'
# --- Postgres ---
POSTGRES_USER=monitoramento
POSTGRES_PASSWORD=senha_super_segura
POSTGRES_DB=monitoramento
EOF

# LINHAS DB_URL / BROKER_URL (idempotentes)
export $(grep -E '^(POSTGRES_USER|POSTGRES_PASSWORD|POSTGRES_DB)=' .env | xargs)
awk -v line="DB_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@banco:5432/${POSTGRES_DB}" '
BEGIN{f=0} $1=="DB_URL"{print line; f=1; next} {print} END{if(!f) print line}' .env > .env.new && mv .env.new .env

export $(grep -E '^(BROKER_USER|BROKER_PASS|BROKER_HOST|BROKER_PORT)=' .env | xargs)
awk -v line="BROKER_URL=amqp://${BROKER_USER}:${BROKER_PASS}@${BROKER_HOST}:${BROKER_PORT}/" '
BEGIN{f=0} $1=="BROKER_URL"{print line; f=1; next} {print} END{if(!f) print line}' .env > .env.new && mv .env.new .env

# --- 2) compose overrides (não mexem na sua GUI) ---
cat > docker-compose.broker.yml <<'YML'
services:
  broker:
    image: rabbitmq:3.13-management
    container_name: broker
    restart: unless-stopped
    env_file: .env
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
      retries: 20
YML

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
    depends_on:
      broker: { condition: service_healthy }
      banco:  { condition: service_healthy }

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
    depends_on:
      broker: { condition: service_healthy }
      banco:  { condition: service_healthy }

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
    depends_on:
      broker: { condition: service_healthy }
      banco:  { condition: service_healthy }

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
    depends_on:
      banco: { condition: service_healthy }
YML

# --- 3) schema de detecção (não conflita com suas tabelas) ---
cat > SCRIPTS/2.1_db_detect_schema.sh <<'SCHEMA'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f docker-compose.yml up -d banco >/dev/null

DB_CONT=$(docker ps --filter "name=sistema-banco" --format '{{.Names}}' | head -n1)
DB_USER=$(grep -m1 '^POSTGRES_USER=' .env | cut -d= -f2)
DB_PASS=$(grep -m1 '^POSTGRES_PASSWORD=' .env | cut -d= -f2)
DB_NAME=$(grep -m1 '^POSTGRES_DB=' .env | cut -d= -f2)

until docker exec -e PGPASSWORD="$DB_PASS" "$DB_CONT" pg_isready -U "$DB_USER" -d "$DB_NAME" -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done

docker exec -i -e PGPASSWORD="$DB_PASS" "$DB_CONT" psql -U "$DB_USER" -d "$DB_NAME" -h 127.0.0.1 <<'SQL'
BEGIN;
CREATE TABLE IF NOT EXISTS detection_type(
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  model TEXT,
  default_params JSONB NOT NULL DEFAULT '{}'::jsonb,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS camera_subscription(
  id BIGSERIAL PRIMARY KEY,
  camera_id BIGINT NOT NULL,
  detection_type_id BIGINT NOT NULL REFERENCES detection_type(id),
  params JSONB NOT NULL DEFAULT '{}'::jsonb,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(camera_id, detection_type_id)
);
CREATE INDEX IF NOT EXISTS idx_camera_subscription_camera ON camera_subscription(camera_id);
CREATE INDEX IF NOT EXISTS idx_camera_subscription_dt ON camera_subscription(detection_type_id);

CREATE TABLE IF NOT EXISTS assignment(
  camera_id BIGINT NOT NULL,
  detection_type_id BIGINT NOT NULL REFERENCES detection_type(id),
  worker_id TEXT,
  lease_until TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (camera_id, detection_type_id)
);
CREATE INDEX IF NOT EXISTS idx_assignment_lease_until ON assignment(lease_until);

CREATE TABLE IF NOT EXISTS det_event(
  event_id TEXT PRIMARY KEY,
  camera_id BIGINT NOT NULL,
  detection_type_id BIGINT NOT NULL REFERENCES detection_type(id),
  ts TIMESTAMPTZ NOT NULL,
  cls TEXT,
  conf DOUBLE PRECISION
);
CREATE INDEX IF NOT EXISTS idx_det_event_cam_ts ON det_event(camera_id, ts DESC);

INSERT INTO detection_type(name, model) VALUES ('car','yolo')    ON CONFLICT DO NOTHING;
INSERT INTO detection_type(name, model) VALUES ('person','yolo') ON CONFLICT DO NOTHING;
COMMIT;
SQL
echo "Schema de detecção aplicado."
SCHEMA
chmod +x SCRIPTS/2.1_db_detect_schema.sh

# --- 4) Workers (person/car/ingestor/janitor) + util publish ---
cat > WORKERS/_base_worker.py <<'PY'
import json, os, time, socket, traceback, threading
import pika, psycopg2
BROKER_URL=os.environ["BROKER_URL"]; DB_URL=os.environ["DB_URL"]
WORKER_ID=os.environ.get("WORKER_ID",f"wk-{socket.gethostname()}")
RENEW_EVERY_SEC=int(os.getenv("RENEW_EVERY_SEC","5")); LEASE_EXT_SEC=int(os.getenv("LEASE_EXT_SEC","20"))
def db_conn(): return psycopg2.connect(DB_URL)
def get_det_id(cur, n): cur.execute("INSERT INTO detection_type(name) VALUES (%s) ON CONFLICT (name) DO NOTHING",(n,)); cur.execute("SELECT id FROM detection_type WHERE name=%s",(n,)); return cur.fetchone()[0]
def upsert_assignment_start(cur, cam, det, ttl):
    det_id = get_det_id(cur, det)
    cur.execute("""INSERT INTO assignment(camera_id,detection_type_id,worker_id,lease_until,status)
                   VALUES (%s,%s,%s,now()+(%s||' sec')::interval,'leased')
                   ON CONFLICT (camera_id,detection_type_id) DO UPDATE
                     SET worker_id=EXCLUDED.worker_id, lease_until=EXCLUDED.lease_until,
                         status='leased', updated_at=now()""",(cam,det_id,WORKER_ID,ttl))
def upsert_assignment_stop(cur, cam, det):
    det_id=get_det_id(cur,det)
    cur.execute("""INSERT INTO assignment(camera_id,detection_type_id,worker_id,lease_until,status)
                   VALUES (%s,%s,NULL,NULL,'stopped')
                   ON CONFLICT (camera_id,detection_type_id) DO UPDATE
                     SET worker_id=NULL, lease_until=NULL, status='stopped', updated_at=now()""",(cam,det_id))
def upsert_subscription_params(cur, cam, det, params):
    det_id=get_det_id(cur,det)
    cur.execute("""INSERT INTO camera_subscription(camera_id,detection_type_id,params,enabled)
                   VALUES (%s,%s,%s::jsonb,TRUE)
                   ON CONFLICT (camera_id,detection_type_id) DO UPDATE
                     SET params=camera_subscription.params||EXCLUDED.params, updated_at=now()""",(cam,det_id,json.dumps(params)))
def renew_loop(det):
    time.sleep(RENEW_EVERY_SEC)
    while True:
        try:
            with db_conn() as dbc, dbc.cursor() as cur:
                cur.execute("""UPDATE assignment a
                               SET lease_until=GREATEST(a.lease_until,now())+(%s||' sec')::interval,
                                   updated_at=now()
                               FROM detection_type dt
                               WHERE a.detection_type_id=dt.id AND dt.name=%s
                                 AND a.worker_id=%s AND a.status='leased'""",(LEASE_EXT_SEC,det,WORKER_ID))
        except Exception as e:
            print(f"[worker:{WORKER_ID}] erro no renew: {e}", flush=True)
        time.sleep(RENEW_EVERY_SEC)
def run_consumer(det):
    params=pika.URLParameters(BROKER_URL)
    while True:
        try:
            conn=pika.BlockingConnection(params); ch=conn.channel()
            ch.queue_declare(queue=f"det.start.{det}", durable=True)
            ch.queue_declare(queue="det.stop", durable=True)
            ch.queue_declare(queue="det.params", durable=True)
            ch.basic_qos(prefetch_count=5)
            threading.Thread(target=renew_loop, args=(det,), daemon=True).start()
            print(f"[worker:{WORKER_ID}] aguardando em det.start.{det} / det.stop / det.params", flush=True)
            def on_start(chx,m,p,b):
                try:
                    msg=json.loads(b.decode()); cam=int(msg["camera_id"]); ttl=int(msg.get("lease_ttl_sec",60))
                    with db_conn() as dbc, dbc.cursor() as cur: upsert_assignment_start(cur,cam,det,ttl)
                    print(f"[worker:{WORKER_ID}] START {det} camera={cam} ttl={ttl}s -> ASSIGN ok", flush=True)
                    chx.basic_ack(delivery_tag=m.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO START: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=m.delivery_tag, requeue=True)
            def on_stop(chx,m,p,b):
                try:
                    msg=json.loads(b.decode()); cam=int(msg["camera_id"]); d=msg.get("type") or msg.get("detection_type") or det
                    with db_conn() as dbc, dbc.cursor() as cur: upsert_assignment_stop(cur,cam,d)
                    print(f"[worker:{WORKER_ID}] STOP {d} camera={cam} -> ASSIGN stopped", flush=True)
                    chx.basic_ack(delivery_tag=m.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO STOP: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=m.delivery_tag, requeue=True)
            def on_params(chx,m,p,b):
                try:
                    msg=json.loads(b.decode()); cam=int(msg["camera_id"]); d=msg.get("type") or det
                    params=msg.get("params") or {k:v for k,v in msg.items() if k in ("threshold","max_fps")}
                    with db_conn() as dbc, dbc.cursor() as cur: upsert_subscription_params(cur,cam,d,params)
                    print(f"[worker:{WORKER_ID}] PARAMS merged cam={cam} det={d} -> {params}", flush=True)
                    chx.basic_ack(delivery_tag=m.delivery_tag)
                except Exception as e:
                    print(f"[worker:{WORKER_ID}] ERRO PARAMS: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=m.delivery_tag, requeue=True)
            ch.basic_consume(queue=f"det.start.{det}", on_message_callback=on_start, auto_ack=False)
            ch.basic_consume(queue="det.stop",      on_message_callback=on_stop,  auto_ack=False)
            ch.basic_consume(queue="det.params",    on_message_callback=on_params,auto_ack=False)
            ch.start_consuming()
        except Exception as e:
            print(f"[worker:{WORKER_ID}] conexão perdida: {e}; retry em 1s", flush=True); time.sleep(1)
PY

cat > WORKERS/worker_person.py <<'PY'
from _base_worker import run_consumer
if __name__ == "__main__":
    run_consumer("person")
PY

cat > WORKERS/worker_car.py <<'PY'
from _base_worker import run_consumer
if __name__ == "__main__":
    run_consumer("car")
PY

cat > WORKERS/events_ingestor.py <<'PY'
import json, os, socket, time, traceback, pika, psycopg2
BROKER_URL=os.environ["BROKER_URL"]; DB_URL=os.environ["DB_URL"]
WORKER_ID=os.environ.get("WORKER_ID", f"ingestor-{socket.gethostname()}")
def db(): return psycopg2.connect(DB_URL)
def get_det_id(cur, n): cur.execute("INSERT INTO detection_type(name) VALUES (%s) ON CONFLICT (name) DO NOTHING",(n,)); cur.execute("SELECT id FROM detection_type WHERE name=%s",(n,)); return cur.fetchone()[0]
def insert_event(cur, ev):
    det_id=get_det_id(cur,ev["detection_type"])
    cur.execute("""INSERT INTO det_event(event_id,camera_id,detection_type_id,ts,cls,conf)
                   VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING""",
                (ev.get("event_id"), int(ev["camera_id"]), det_id, ev["ts"], ev.get("cls"), float(ev.get("conf",0.0))))
def main():
    params=pika.URLParameters(BROKER_URL)
    while True:
        try:
            conn=pika.BlockingConnection(params); ch=conn.channel()
            ch.queue_declare(queue="det.events", durable=True); ch.basic_qos(prefetch_count=50)
            print(f"[{WORKER_ID}] aguardando msgs em det.events", flush=True)
            def on_msg(chx,m,p,b):
                try:
                    ev=json.loads(b.decode());
                    with db() as dbc, dbc.cursor() as cur: insert_event(cur, ev)
                    chx.basic_ack(delivery_tag=m.delivery_tag)
                except Exception as e:
                    print(f"[{WORKER_ID}] ERRO: {e}\n{traceback.format_exc()}", flush=True)
                    chx.basic_nack(delivery_tag=m.delivery_tag, requeue=True)
            ch.basic_consume(queue="det.events", on_message_callback=on_msg, auto_ack=False)
            ch.start_consuming()
        except Exception as e:
            print(f"[{WORKER_ID}] conexão perdida: {e}; retry em 1s", flush=True); time.sleep(1)
if __name__ == "__main__": main()
PY

cat > WORKERS/lease_janitor.py <<'PY'
import os, time, socket, traceback, psycopg2
DB_URL=os.environ["DB_URL"]; WORKER_ID=os.environ.get("WORKER_ID",f"janitor-{socket.gethostname()}"); INTERVAL=int(os.getenv("JANITOR_INTERVAL","5"))
def run():
    while True:
        try:
            with psycopg2.connect(DB_URL) as dbc, dbc.cursor() as cur:
                cur.execute("""UPDATE assignment a
                               SET status='expired', worker_id=NULL, lease_until=NULL, updated_at=now()
                               WHERE a.status='leased' AND a.lease_until < now();""")
                print(f"[{WORKER_ID}] expired rows={cur.rowcount}", flush=True)
        except Exception as e:
            print(f"[{WORKER_ID}] ERRO JANITOR: {e}\n{traceback.format_exc()}", flush=True)
        time.sleep(INTERVAL)
if __name__ == "__main__": run()
PY

# util para publicar direto em fila (opcional)
mkdir -p BROKER
cat > BROKER/publish.py <<'PY'
import os, sys, pika
q=sys.argv[1]; body=sys.argv[2]
params=pika.URLParameters(os.environ["BROKER_URL"])
conn=pika.BlockingConnection(params); ch=conn.channel()
ch.queue_declare(queue=q, durable=True); ch.basic_publish("", q, body); conn.close()
print(f"OK: publicado em {q}")
PY

# --- 5) CLI de emissão (sem mexer na sua GUI) ---
mkdir -p GESTAO_WEB/app
cat > GESTAO_WEB/app/emit_cli.py <<'PY'
import os, argparse, json, pika, datetime as dt
BROKER_URL=os.environ["BROKER_URL"]
def publish(q,payload):
    params=pika.URLParameters(BROKER_URL); c=pika.BlockingConnection(params); ch=c.channel()
    ch.queue_declare(queue=q, durable=True); ch.basic_publish("", q, json.dumps(payload).encode()); c.close()
    print(f"OK {payload.get('msg_type')} -> {q}")
def main():
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest="cmd",required=True)
    s=sub.add_parser("start"); s.add_argument("--camera-id",type=int,required=True); s.add_argument("--type",choices=["person","car"],required=True); s.add_argument("--read-url",required=True); s.add_argument("--lease-ttl",type=int,default=60)
    u=sub.add_parser("update"); u.add_argument("--camera-id",type=int,required=True); u.add_argument("--type",choices=["person","car"],required=True); u.add_argument("--threshold",type=float); u.add_argument("--max-fps",type=int)
    t=sub.add_parser("stop"); t.add_argument("--camera-id",type=int,required=True); t.add_argument("--type",choices=["person","car"],required=True)
    a=p.parse_args(); now=dt.datetime.utcnow().isoformat()+"Z"
    if a.cmd=="start":
        publish(f"det.start.{a.type}", {"msg_type":"START","camera_id":a.camera_id,"detection_type":a.type,"read_url":a.read_url,"params":{},"lease_ttl_sec":a.lease_ttl,"issued_at":now})
    elif a.cmd=="update":
        params={};
        if a.threshold is not None: params["threshold"]=a.threshold
        if a.max_fps is not None: params["max_fps"]=a.max_fps
        publish("det.params", {"msg_type":"UPDATE_PARAMS","camera_id":a.camera_id,"type":a.type,"params":params,"issued_at":now})
    elif a.cmd=="stop":
        publish("det.stop", {"msg_type":"STOP","camera_id":a.camera_id,"type":a.type,"issued_at":now})
if __name__=="__main__": main()
PY

# --- 6) Patch no 6_subir_docker.sh para usar overrides (idempotente) ---
if [ -f SCRIPTS/6_subir_docker.sh ]; then
  cp -n SCRIPTS/6_subir_docker.sh SCRIPTS/6_subir_docker.sh.bak 2>/dev/null || true
  if ! grep -q 'docker-compose\.broker\.yml' SCRIPTS/6_subir_docker.sh; then
    sed -i -E \
     's|docker[[:space:]]+compose[[:space:]]+up[[:space:]]+-d|COMPOSE_ARGS="-f docker-compose.yml"; [ -f docker-compose.broker.yml ] \&\& COMPOSE_ARGS="$COMPOSE_ARGS -f docker-compose.broker.yml"; [ -f docker-compose.workers.yml ] \&\& COMPOSE_ARGS="$COMPOSE_ARGS -f docker-compose.workers.yml"; docker compose $COMPOSE_ARGS up -d|' \
     SCRIPTS/6_subir_docker.sh
  fi
else
  cat > SCRIPTS/6_subir_docker.sh <<'UP'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "==== SCRIPT 6: SUBIR DOCKER (COM OVERRIDES) ===="
COMPOSE_ARGS="-f docker-compose.yml"
[ -f docker-compose.broker.yml ]  && COMPOSE_ARGS="$COMPOSE_ARGS -f docker-compose.broker.yml"
[ -f docker-compose.workers.yml ] && COMPOSE_ARGS="$COMPOSE_ARGS -f docker-compose.workers.yml"
docker compose $COMPOSE_ARGS up -d
echo "==== SCRIPT 6 CONCLUÍDO ===="
UP
  chmod +x SCRIPTS/6_subir_docker.sh
fi

# --- 7) Patch no reinstalar_sistema.sh para incluir schema e subir ---
if [ -f SCRIPTS/reinstalar_sistema.sh ]; then
  cp -n SCRIPTS/reinstalar_sistema.sh SCRIPTS/reinstalar_sistema.sh.bak 2>/dev/null || true
  grep -q 'SCRIPTS/2.1_db_detect_schema.sh' SCRIPTS/reinstalar_sistema.sh || \
    sed -i -e '$a\' -e 'bash SCRIPTS/2.1_db_detect_schema.sh' SCRIPTS/reinstalar_sistema.sh
  grep -q 'SCRIPTS/6_subir_docker.sh' SCRIPTS/reinstalar_sistema.sh || \
    sed -i -e '$a\' -e 'bash SCRIPTS/6_subir_docker.sh' SCRIPTS/reinstalar_sistema.sh
fi

echo "✅ Integração feita: overrides + workers + schema + patches aplicados."
echo "Use seus scripts normalmente. Para subir agora:  bash SCRIPTS/6_subir_docker.sh"
echo "Para reinstalar do zero (mantendo sua GUI):   bash SCRIPTS/reinstalar_sistema.sh"
