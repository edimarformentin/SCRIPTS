# Conteúdo do 4.10_criar_backend_gerenciar_yolo.sh (v12 - com atraso)
set -Eeuo pipefail
echo "==== SCRIPT 4.10 (v12): GERANDO GERENCIADOR YOLO COM RASTREAMENTO E ATRASO INICIAL ===="
BASE_DIR="/home/edimar/SISTEMA"
APP_DIR="$BASE_DIR/GESTAO_WEB"
IMAGE_TAG="yolo-detector-local:8.1.0"
DOCKERFILE_PATH="$APP_DIR/detector.Dockerfile"
mkdir -p "$APP_DIR"
cd "$BASE_DIR"

echo "--> Gerando $APP_DIR/detector_yolo.py (v7.1 - com atraso inicial)..."
cat <<'DETECTOR_PY' > "$APP_DIR/detector_yolo.py"
import os, cv2, time, logging
from datetime import datetime, timedelta
from ultralytics import YOLO

logging.getLogger("ultralytics").setLevel(logging.ERROR)

def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [DETECTOR] {msg}", flush=True)

def main():
    # --- ADICIONADO ATRASO INICIAL ---
    log("Aguardando 10 segundos para o stream de vídeo ficar disponível...")
    time.sleep(10)

    RTSP_URL = os.getenv("RTSP_URL")
    VID_STRIDE = int(os.getenv("VID_STRIDE", "2"))
    OBJECTS_TO_TRACK = [s.strip() for s in os.getenv("OBJECTS_TO_TRACK", "person,car").split(",") if s.strip()]
    SAVE_DIR = os.getenv("SAVE_DIR", "/snapshots")
    CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.5"))
    DISAPPEARED_TIMEOUT = int(os.getenv("DISAPPEARED_TIMEOUT", "30"))

    os.makedirs(SAVE_DIR, exist_ok=True)
    log(f"INICIANDO DETECTOR YOLO COM RASTREAMENTO E EVENTOS DE SAÍDA (v7.1)")
    log(f"Timeout de desaparecimento configurado para: {DISAPPEARED_TIMEOUT} segundos.")

    model = YOLO('yolov8n.pt')
    tracked_objects = {}

    log("Iniciando o processamento do stream de vídeo com rastreamento...")
    try:
        results_iterator = model.track(RTSP_URL, stream=True, verbose=False, persist=True, vid_stride=VID_STRIDE)
        while True:
            try:
                result = next(results_iterator)
                now = datetime.now()
                disappeared_ids = []
                for tid, data in tracked_objects.items():
                    if (now - data['last_seen']).total_seconds() > DISAPPEARED_TIMEOUT:
                        disappeared_ids.append(tid)
                        permanence_duration = data['last_seen'] - data['arrival_time']
                        log(
                            f"EVENTO DE SAÍDA: Objeto '{data['class_name']}' (ID: {tid}) "
                            f"saiu após {permanence_duration.total_seconds():.0f} segundos. "
                            f"(Chegada: {data['arrival_time'].strftime('%H:%M:%S')}, "
                            f"Saída: {data['last_seen'].strftime('%H:%M:%S')})"
                        )
                for tid in disappeared_ids: del tracked_objects[tid]
                if result.boxes.id is None: continue
                track_ids = result.boxes.id.int().cpu().tolist()
                for i, track_id in enumerate(track_ids):
                    box = result.boxes[i]
                    confidence = float(box.conf[0])
                    if confidence < CONFIDENCE_THRESHOLD: continue
                    class_name = model.names[int(box.cls[0])]
                    if class_name not in OBJECTS_TO_TRACK: continue
                    if track_id not in tracked_objects:
                        tracked_objects[track_id] = {"class_name": class_name, "arrival_time": now, "last_seen": now, "event_logged": False}
                    tracked_objects[track_id]['last_seen'] = now
                    if not tracked_objects[track_id]['event_logged']:
                        tracked_objects[track_id]['event_logged'] = True
                        timestamp_str = now.strftime('%Y%m%d_%H%M%S')
                        filename = f"{timestamp_str}_{class_name}_id{track_id}_chegada.jpg"
                        save_path = os.path.join(SAVE_DIR, filename)
                        frame_with_boxes = result.plot()
                        cv2.imwrite(save_path, frame_with_boxes)
                        log(f"EVENTO DE CHEGADA: Snapshot para '{class_name}' (ID: {track_id}) salvo. Chegada às {now.strftime('%H:%M:%S')}")
            except StopIteration:
                log("AVISO: Stream de vídeo não disponível. Tentando reconectar em 5s...")
                time.sleep(5)
                results_iterator = model.track(RTSP_URL, stream=True, verbose=False, persist=True, vid_stride=VID_STRIDE)
                continue
            except Exception as e:
                log(f"ERRO no loop: {e!r}. Reconectando em 10s...")
                time.sleep(10)
    except Exception as e:
        log(f"ERRO CRÍTICO: {e!r}. Contêiner pode precisar ser reiniciado.")
        time.sleep(60)

if __name__ == "__main__":
    main()
DETECTOR_PY

# O resto do script permanece igual
echo "--> Gerando $DOCKERFILE_PATH..."
cat <<'DOCKERFILE' > "$DOCKERFILE_PATH"
FROM ultralytics/ultralytics:8.1.0
WORKDIR /app
COPY detector_yolo.py .
DOCKERFILE
echo "--> Construindo imagem local '$IMAGE_TAG'..."
docker build -t "$IMAGE_TAG" -f "$DOCKERFILE_PATH" "$APP_DIR"
echo "--> Gerando $APP_DIR/gerenciar_yolo.py..."
cat <<'MANAGER_PY' > "$APP_DIR/gerenciar_yolo.py"
import os, re, sys, docker
from docker.types import DeviceRequest
from sqlalchemy import create_engine, Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import sessionmaker, relationship, declarative_base, joinedload
FRIGATE_HOST_BASE_PATH = os.getenv("FRIGATE_HOST_PATH", "/home/edimar/SISTEMA/FRIGATE")
DATABASE_URL = "postgresql://monitoramento:senha_super_segura@banco:5432/monitoramento"
LOCAL_IMAGE_NAME = "yolo-detector-local:8.1.0"
BASE_STREAM_FPS = 30
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
class Cliente(Base):
    __tablename__ = 'clientes'
    id = Column(Integer, primary_key=True)
    unique_id = Column(String, nullable=False, unique=True)
    cameras = relationship("Camera", back_populates="cliente", cascade="all, delete-orphan")
class Camera(Base):
    __tablename__ = 'cameras'
    id = Column(Integer, primary_key=True)
    nome = Column(String, nullable=False)
    cliente_id = Column(Integer, ForeignKey('clientes.id'))
    detect_enabled = Column(Boolean, default=False)
    objects_to_track = Column(String, default='person')
    ia_fps = Column(Integer, default=15)
    cliente = relationship("Cliente", back_populates="cameras")
def sanitize_name(name: str) -> str: return re.sub(r'[^a-zA-Z0-9_]', '', name.replace(' ', '_'))
def get_container_name(uid: str, cam: str) -> str: return f"yolo-{uid}-{sanitize_name(cam)}"
def criar_ou_atualizar_detector(camera_id: int):
    db = SessionLocal()
    docker_client = docker.from_env()
    try:
        camera = db.query(Camera).options(joinedload(Camera.cliente)).filter(Camera.id == camera_id).one()
        cliente = camera.cliente
        container_name = get_container_name(cliente.unique_id, camera.nome)
        try:
            old = docker_client.containers.get(container_name)
            old.remove(force=True)
        except docker.errors.NotFound: pass
        if not camera.detect_enabled:
            print(f"[GERENCIADOR] Detecção DESATIVADA para '{camera.nome}'.")
            return
        target_fps = max(1, camera.ia_fps)
        vid_stride = max(1, round(BASE_STREAM_FPS / target_fps))
        print(f"[GERENCIADOR] Câmera '{camera.nome}' configurada para ~{target_fps} FPS (Video Stride: {vid_stride})")
        cam_nome_sanitizado = sanitize_name(camera.nome)
        rtsp_url = f"rtsp://sistema-mediamtx:8554/live/{cliente.unique_id}/{cam_nome_sanitizado}"
        host_save_dir = os.path.join(FRIGATE_HOST_BASE_PATH, cliente.unique_id, "events", cam_nome_sanitizado)
        os.makedirs(host_save_dir, exist_ok=True)
        base_env = {
            "RTSP_URL": rtsp_url,
            "OBJECTS_TO_TRACK": camera.objects_to_track if camera.objects_to_track != 'padrao' else 'person,car',
            "SAVE_DIR": "/snapshots",
            "VID_STRIDE": str(vid_stride),
            "DISAPPEARED_TIMEOUT": "30"
        }
        docker_client.containers.run(
            image=LOCAL_IMAGE_NAME, name=container_name, command=["python", "-u", "detector_yolo.py"],
            environment=base_env, volumes={host_save_dir: {'bind': '/snapshots', 'mode': 'rw'}},
            network="sistema_sistema_network", restart_policy={"Name": "unless-stopped"}, detach=True,
            device_requests=[DeviceRequest(count=-1, capabilities=[["gpu"]])]
        )
        print(f"[GERENCIADOR] Contêiner '{container_name}' iniciado com GPU.")
    except Exception as e: print(f"[GERENCIADOR][ERRO CRÍTICO] {e}")
    finally: db.close()
def remover_detector_por_camera(camera_id: int):
    db = SessionLocal()
    docker_client = docker.from_env()
    try:
        camera = db.query(Camera).options(joinedload(Camera.cliente)).filter(Camera.id == camera_id).one()
        container_name = get_container_name(camera.cliente.unique_id, camera.nome)
        try:
            c = docker_client.containers.get(container_name)
            c.remove(force=True)
        except docker.errors.NotFound: pass
    finally: db.close()
def remover_detectores_por_cliente(cliente_id: int):
    db = SessionLocal()
    docker_client = docker.from_env()
    try:
        cliente = db.query(Cliente).filter(Cliente.id == cliente_id).one()
        prefix = f"yolo-{cliente.unique_id}-"
        for cont in docker_client.containers.list(all=True):
            if cont.name.startswith(prefix):
                try: cont.remove(force=True)
                except Exception: pass
    finally: db.close()
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python gerenciar_yolo.py [criar-atualizar|remover-camera|remover-cliente] [id]")
        sys.exit(1)
    acao, entity_id = sys.argv[1], int(sys.argv[2])
    if acao == "criar-atualizar": criar_ou_atualizar_detector(entity_id)
    elif acao == "remover-camera": remover_detector_por_camera(entity_id)
    elif acao == "remover-cliente": remover_detectores_por_cliente(entity_id)
MANAGER_PY
echo "--> Script 4.10 (v12) finalizado."
echo "==== SCRIPT 4.10 (v12) CONCLUÍDO ===="
