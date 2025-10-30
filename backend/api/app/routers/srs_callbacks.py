"""
SRS Callbacks Router
Endpoints para callbacks do SRS Server
"""

from fastapi import APIRouter, Request, Depends
from sqlalchemy.orm import Session
from typing import Dict
import logging

from app.database import get_db
from app.models import Camera
from app.services.recording import get_recording_manager

router = APIRouter(prefix="/api/srs", tags=["SRS Callbacks"])
logger = logging.getLogger(__name__)


@router.post("/on_connect")
async def on_connect(request: Request):
    """
    Callback: Quando cliente conecta ao SRS

    Payload SRS:
    {
        "action": "on_connect",
        "client_id": 123,
        "ip": "192.168.1.100",
        "vhost": "__defaultVhost__",
        "app": "live",
        "tcUrl": "rtmp://server/live"
    }

    Retorno:
    - 0: Permite conexão
    - 1: Rejeita conexão
    """
    try:
        data = await request.json()
        client_ip = data.get("ip", "unknown")

        logger.info(f"[SRS] Connection from {client_ip}")

        # TODO: Validação de IP/autenticação se necessário
        # Por enquanto, permite todas as conexões

        return {"code": 0}  # Permite

    except Exception as e:
        logger.error(f"[SRS] Error in on_connect: {e}")
        return {"code": 0}  # Permite mesmo com erro (fallback)


@router.post("/on_publish")
async def on_publish(request: Request, db: Session = Depends(get_db)):
    """
    Callback: Quando câmera começa a publicar stream

    Payload SRS:
    {
        "action": "on_publish",
        "client_id": 123,
        "ip": "192.168.1.100",
        "vhost": "__defaultVhost__",
        "app": "live",
        "stream": "edimar-demo01/cam1"
    }

    Retorno:
    - 0: Permite publicação e inicia gravação
    - 1: Rejeita publicação
    """
    try:
        data = await request.json()
        stream_path = data.get("stream", "")
        client_ip = data.get("ip", "unknown")

        logger.info(f"[SRS] Stream published: {stream_path} from {client_ip}")

        # Parse stream path: "cliente-slug/camera-nome"
        if "/" not in stream_path:
            logger.warning(f"[SRS] Invalid stream path: {stream_path}")
            return {"code": 1, "msg": "Invalid stream path"}

        parts = stream_path.split("/")
        if len(parts) < 2:
            logger.warning(f"[SRS] Invalid stream path format: {stream_path}")
            return {"code": 1, "msg": "Invalid stream path format"}

        client_slug = parts[0]
        camera_name = parts[1]

        # Busca câmera no banco
        from app.crud.crud_client import get_client_by_slug

        client = get_client_by_slug(db, client_slug)
        if not client:
            logger.warning(f"[SRS] Client not found: {client_slug}")
            return {"code": 1, "msg": "Client not found"}

        camera = db.query(Camera).filter(
            Camera.cliente_id == client.id,
            Camera.nome == camera_name
        ).first()

        if not camera:
            logger.warning(f"[SRS] Camera not found: {client_slug}/{camera_name}")
            return {"code": 1, "msg": "Camera not found"}

        if not camera.ativo:
            logger.warning(f"[SRS] Camera inactive: {client_slug}/{camera_name}")
            return {"code": 1, "msg": "Camera inactive"}

        # ✅ Inicia gravação via RecordingManager
        from datetime import datetime
        camera.last_seen = datetime.now()
        db.commit()

        manager = get_recording_manager()
        source_url = f"rtmp://srs:1935/live/{stream_path}"

        success = await manager.start_camera_recording(
            camera_id=str(camera.id),
            client_slug=client_slug,
            camera_name=camera_name,
            source_url=source_url,
            transcode_h265=camera.transcode_to_h265
        )

        if success:
            mode = "H.265" if camera.transcode_to_h265 else "Native"
            logger.info(f"[SRS] ✅ Recording started: {camera_name} ({mode})")
            return {"code": 0}  # Permite e grava
        else:
            logger.error(f"[SRS] ❌ Failed to start recording: {camera_name}")
            return {"code": 0}  # Permite stream mesmo se gravação falhar

    except Exception as e:
        logger.error(f"[SRS] Error in on_publish: {e}", exc_info=True)
        return {"code": 0}  # Permite mesmo com erro (fallback)


@router.post("/on_unpublish")
async def on_unpublish(request: Request, db: Session = Depends(get_db)):
    """
    Callback: Quando câmera para de publicar stream

    Payload SRS:
    {
        "action": "on_unpublish",
        "client_id": 123,
        "ip": "192.168.1.100",
        "vhost": "__defaultVhost__",
        "app": "live",
        "stream": "edimar-demo01/cam1"
    }
    """
    try:
        data = await request.json()
        stream_path = data.get("stream", "")

        logger.info(f"[SRS] Stream unpublished: {stream_path}")

        # Parse stream path
        if "/" not in stream_path:
            return {"code": 0}

        parts = stream_path.split("/")
        if len(parts) < 2:
            return {"code": 0}

        client_slug = parts[0]
        camera_name = parts[1]

        # Busca câmera
        from app.crud.crud_client import get_client_by_slug

        client = get_client_by_slug(db, client_slug)
        if not client:
            return {"code": 0}

        camera = db.query(Camera).filter(
            Camera.cliente_id == client.id,
            Camera.nome == camera_name
        ).first()

        if not camera:
            return {"code": 0}

        # Para gravação
        manager = get_recording_manager()
        success = await manager.stop_camera_recording(str(camera.id))

        if success:
            logger.info(f"[SRS] ✅ Recording stopped: {camera_name}")
        else:
            logger.warning(f"[SRS] ⚠️  Failed to stop recording: {camera_name}")

        return {"code": 0}

    except Exception as e:
        logger.error(f"[SRS] Error in on_unpublish: {e}")
        return {"code": 0}


@router.post("/on_hls")
async def on_hls(request: Request):
    """
    Callback: Atualização de HLS

    Payload SRS:
    {
        "action": "on_hls",
        "stream": "edimar-demo01/cam1",
        "duration": 2.0,
        "cwd": "/usr/local/srs",
        "file": "/hls/edimar-demo01/cam1-001.ts",
        "seq_no": 1
    }

    Pode ser usado para:
    - Monitorar saúde do stream
    - Trigger análises de IA em segmentos
    """
    try:
        data = await request.json()
        stream = data.get("stream", "")

        # TODO (Futuro): Publicar em RabbitMQ para processamento IA
        # - Ler segmento HLS
        # - Enviar para fila de análise
        # - IA detecta objetos/eventos
        # - Gera alertas/notificações

        return {"code": 0}

    except Exception as e:
        logger.error(f"[SRS] Error in on_hls: {e}")
        return {"code": 0}


@router.get("/status")
async def srs_status():
    """
    Status do sistema de gravação

    Endpoint útil para monitoramento
    """
    try:
        manager = get_recording_manager()
        statuses = manager.get_all_cameras_status()

        return {
            "status": "ok",
            "total_recordings": len(statuses),
            "recordings": statuses
        }

    except Exception as e:
        logger.error(f"[SRS] Error getting status: {e}")
        return {
            "status": "error",
            "error": str(e)
        }
