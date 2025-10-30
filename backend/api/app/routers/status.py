from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import Dict, List
import httpx
from app.database import get_db
from app.crud.crud_camera import list_cameras
from app.crud.crud_client import get_client

router = APIRouter(prefix="/api/status", tags=["status"])

MEDIAMTX_HLS_BASE = "http://mediamtx:8888"

@router.get("/cameras")
async def get_cameras_status(db: Session = Depends(get_db), debug: bool = False):
    """
    Retorna status (online/offline) de todas as câmeras.
    Testa se o stream HLS está disponível para cada câmera.
    """
    # Lista todas as câmeras do banco
    cameras = list_cameras(db)

    # Testa cada stream individualmente
    active_paths = set()
    mediamtx_error = None
    mediamtx_paths_found = []

    try:
        async with httpx.AsyncClient(timeout=2.0) as http_client:
            for cam in cameras:
                # Busca slug do cliente
                client_obj = get_client(db, cam.cliente_id)
                client_slug = client_obj.slug if client_obj else None

                if client_slug:
                    path = f"live/{client_slug}/{cam.nome}"
                    # Testa se o arquivo index.m3u8 existe (mais confiável que HEAD)
                    hls_url = f"{MEDIAMTX_HLS_BASE}/{path}/index.m3u8"

                    try:
                        response = await http_client.get(hls_url, timeout=2.0)
                        status_code = response.status_code

                        # 200 = stream ativo, 404 = sem stream
                        if status_code == 200:
                            active_paths.add(path)
                            mediamtx_paths_found.append({"path": path, "online": True})
                        else:
                            mediamtx_paths_found.append({"path": path, "online": False, "code": status_code})
                    except httpx.TimeoutException:
                        # Timeout pode significar que está tentando conectar à fonte
                        mediamtx_paths_found.append({"path": path, "online": False, "error": "timeout"})
                    except Exception as e:
                        mediamtx_paths_found.append({"path": path, "online": False, "error": str(e)[:50]})

    except Exception as e:
        mediamtx_error = str(e)
        print(f"[STATUS] Erro geral ao consultar MediaMTX: {e}")

    # Monta resposta com status de cada câmera
    result = []
    for cam in cameras:
        # Busca slug do cliente
        client = get_client(db, cam.cliente_id)
        client_slug = client.slug if client else None

        # Path esperado no MediaMTX
        expected_path = f"live/{client_slug}/{cam.nome}"

        # Determina status baseado no protocolo e stream ativo
        is_streaming = expected_path in active_paths
        protocolo = cam.protocolo.upper()

        # Para RTSP: verificar se está gravando (processo FFmpeg ativo)
        is_recording = False
        if protocolo == "RTSP":
            try:
                from app.services.recording import get_recording_manager
                manager = get_recording_manager()
                is_recording = str(cam.id) in manager.worker.jobs
                if is_recording:
                    job = manager.worker.jobs[str(cam.id)]
                    is_recording = job.status == "running"
            except:
                pass

        if is_streaming:
            # Stream ativo (transmitindo)
            status = "online"
            status_label = "ONLINE"
        elif protocolo == "RTSP" and is_recording:
            # RTSP gravando (online)
            status = "online"
            status_label = "ONLINE"
        elif protocolo == "RTMP":
            # RTMP configurado, aguardando publisher
            status = "ready"
            status_label = "READY"
        elif protocolo == "RTSP":
            # RTSP sem gravação ativa
            status = "off"
            status_label = "OFF"
        else:
            # Outros protocolos sem stream
            status = "off"
            status_label = "OFF"

        result.append({
            "id": str(cam.id),
            "nome": cam.nome,
            "cliente_slug": client_slug,
            "status": status,
            "status_label": status_label,
            "online": is_streaming,  # Mantém compatibilidade
            "path": expected_path,
            "protocolo": protocolo
        })

    response_data = {
        "cameras": result,
        "total": len(result),
        "online_count": sum(1 for c in result if c["status"] == "online"),
        "ready_count": sum(1 for c in result if c["status"] == "ready"),
        "off_count": sum(1 for c in result if c["status"] == "off")
    }

    # Adiciona debug info se solicitado
    if debug:
        response_data["debug"] = {
            "mediamtx_error": mediamtx_error,
            "mediamtx_paths": mediamtx_paths_found,
            "active_paths": list(active_paths)
        }

    return response_data
