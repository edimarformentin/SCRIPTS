from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import sys

from app.core.config import settings
from app.routers import clients, cameras, recordings, status, sync, srs_callbacks, hardware, admin

# Configurar logging para garantir que mensagens apareçam
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerencia ciclo de vida da aplicação (startup/shutdown)"""
    # Startup: inicia gravação FFmpeg para TODAS câmeras ativas
    print("🚀 [STARTUP] Initializing recording for all active cameras...", flush=True)
    logger.info("🚀 [STARTUP] Initializing recording for all active cameras...")

    # Aguardar MediaMTX estar pronto
    import time
    print("[STARTUP] Waiting for MediaMTX to be ready...", flush=True)
    time.sleep(8)  # Aguarda MediaMTX estar totalmente pronto

    try:
        from app.database import SessionLocal
        from app.models import Camera
        from app.services.recording import get_recording_manager
        from app.crud.crud_client import get_client

        db = SessionLocal()
        try:
            # Busca TODAS as câmeras ativas (não só as com H.265)
            cameras = db.query(Camera).filter(Camera.ativo == True).all()

            if cameras:
                print(f"[STARTUP] Found {len(cameras)} active camera(s)")
                logger.info(f"[STARTUP] Found {len(cameras)} active camera(s)")
                manager = get_recording_manager()

                for cam in cameras:
                    client = get_client(db, cam.cliente_id)
                    if not client:
                        print(f"[STARTUP] Client not found for camera {cam.nome} ({cam.id})")
                        logger.warning(f"[STARTUP] Client not found for camera {cam.nome} ({cam.id})")
                        continue

                    # Determinar source_url baseado no protocolo
                    if cam.protocolo == 'RTSP':
                        # RTSP externo: usar endpoint direto da câmera
                        source_url = cam.endpoint
                    else:
                        # RTMP/HLS: esperar stream chegar no MediaMTX
                        source_url = f"rtsp://mediamtx:8554/live/{client.slug}/{cam.nome}"

                    success = await manager.start_camera_recording(
                        camera_id=str(cam.id),
                        client_slug=client.slug,
                        camera_name=cam.nome,
                        source_url=source_url,
                        transcode_h265=cam.transcode_to_h265
                    )

                    if success:
                        mode = "H.265 transcode" if cam.transcode_to_h265 else "H.264 copy"
                        print(f"[STARTUP] ✅ Recording started: {cam.nome} ({mode})")
                        logger.info(f"[STARTUP] ✅ Recording started: {cam.nome} ({mode})")
                    else:
                        print(f"[STARTUP] ❌ Failed to start recording: {cam.nome}")
                        logger.error(f"[STARTUP] ❌ Failed to start recording: {cam.nome}")

                print("🎉 [STARTUP] Recording initialization complete")
                logger.info("🎉 [STARTUP] Recording initialization complete")
            else:
                print("[STARTUP] No active cameras found")
                logger.info("[STARTUP] No active cameras found")
        finally:
            db.close()
    except Exception as e:
        print(f"[STARTUP] Error during recording initialization: {e}")
        logger.error(f"[STARTUP] Error during recording initialization: {e}", exc_info=True)

    yield  # Aplicação roda aqui

    # Shutdown: para todos os processos
    print("[SHUTDOWN] Stopping all recording processes...")
    logger.info("[SHUTDOWN] Stopping all recording processes...")
    try:
        from app.services.recording import get_recording_manager
        manager = get_recording_manager()
        await manager.stop_all_recordings()
        print("[SHUTDOWN] All recording processes stopped")
        logger.info("[SHUTDOWN] All recording processes stopped")
    except Exception as e:
        print(f"[SHUTDOWN] Error stopping recordings: {e}")
        logger.error(f"[SHUTDOWN] Error stopping recordings: {e}")


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")] if settings.cors_origins else ["*"],
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status":"ok"}

app.include_router(clients.router)
app.include_router(cameras.router)
app.include_router(recordings.router)
app.include_router(status.router)
app.include_router(sync.router)
app.include_router(srs_callbacks.router)
app.include_router(hardware.router)
app.include_router(admin.router)
