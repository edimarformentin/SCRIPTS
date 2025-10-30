from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
import subprocess
import tempfile
from pathlib import Path
from app.database import get_db
from app.schemas.camera_schema import CameraCreate, CameraUpdate, CameraOut
from app.crud.crud_camera import list_cameras, get_camera, create_camera, update_camera, delete_camera
from app.core.storage import cleanup_camera_recordings

router = APIRouter(prefix="/api/cameras", tags=["cameras"])

def populate_cliente_slug(cam, db: Session):
    """Popula o cliente_slug na câmera"""
    from app.crud.crud_client import get_client
    if cam:
        client = get_client(db, cam.cliente_id)
        cam.cliente_slug = client.slug if client else None
    return cam

@router.get("", response_model=List[CameraOut])
def _list(db: Session = Depends(get_db)):
    cameras = list_cameras(db)
    return [populate_cliente_slug(cam, db) for cam in cameras]

@router.post("", response_model=CameraOut, status_code=201)
async def _create(payload: CameraCreate, db: Session = Depends(get_db)):
    from app.crud.crud_client import get_client

    cam = create_camera(db, payload)

    # Busca o cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    if not client:
        raise HTTPException(400, "Cliente não encontrado")

    # Adiciona câmera ao MediaMTX via API dinâmica (SEM reiniciar)
    from app.services.mediamtx_sync import add_camera_to_mediamtx
    try:
        success = add_camera_to_mediamtx(
            client.slug,
            cam.nome,
            cam.endpoint,
            cam.protocolo
        )
        if success:
            print(f"[CAMERA_CREATE] ✅ Câmera {cam.nome} adicionada ao MediaMTX")
        else:
            print(f"[CAMERA_CREATE] ⚠️  Câmera criada no DB mas falhou ao adicionar no MediaMTX")
    except Exception as e:
        print(f"[CAMERA_CREATE] ⚠️  Erro ao adicionar no MediaMTX: {e}")

    # Inicia gravação FFmpeg (SEMPRE, com ou sem H.265)
    from app.services.recording import get_recording_manager

    manager = get_recording_manager()

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
        print(f"[RECORDING] ✅ Gravação iniciada para {cam.nome} ({mode})")
    else:
        print(f"[RECORDING] ⚠️  Falha ao iniciar gravação para {cam.nome}")

    return populate_cliente_slug(cam, db)

@router.get("/{camera_id}", response_model=CameraOut)
def _get(camera_id: UUID, db: Session = Depends(get_db)):
    cam = get_camera(db, camera_id)
    if not cam: raise HTTPException(404, "Câmera não encontrada")
    return populate_cliente_slug(cam, db)

@router.put("/{camera_id}", response_model=CameraOut)
async def _update(camera_id: UUID, payload: CameraUpdate, db: Session = Depends(get_db)):
    from app.crud.crud_client import get_client

    # Busca câmera antes de atualizar para comparar estado
    old_cam = get_camera(db, camera_id)
    if not old_cam: raise HTTPException(404, "Câmera não encontrada")
    old_transcode_state = old_cam.transcode_to_h265

    cam = update_camera(db, camera_id, payload)
    if not cam: raise HTTPException(404, "Câmera não encontrada")

    # Busca o cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    if not client:
        raise HTTPException(400, "Cliente não encontrado")

    # Atualiza câmera no MediaMTX via API dinâmica (SEM reiniciar)
    from app.services.mediamtx_sync import update_camera_in_mediamtx
    try:
        success = update_camera_in_mediamtx(
            client.slug,
            cam.nome,
            cam.endpoint,
            cam.protocolo
        )
        if success:
            print(f"[CAMERA_UPDATE] ✅ Câmera {cam.nome} atualizada no MediaMTX")
        else:
            print(f"[CAMERA_UPDATE] ⚠️  Câmera atualizada no DB mas falhou ao atualizar no MediaMTX")
    except Exception as e:
        print(f"[CAMERA_UPDATE] ⚠️  Erro ao atualizar no MediaMTX: {e}")

    # Gerencia gravação se o modo mudou (sempre para e reinicia)
    if old_transcode_state != cam.transcode_to_h265:
        from app.services.recording import get_recording_manager

        manager = get_recording_manager()

        # Para gravação anterior (se existir)
        await manager.stop_camera_recording(str(cam.id))

        # Reinicia gravação com novo modo (copy ou transcode)
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
            print(f"[RECORDING] ✅ Modo de gravação alterado para {cam.nome} ({mode})")
        else:
            print(f"[RECORDING] ⚠️  Falha ao alterar modo de gravação para {cam.nome}")

    return populate_cliente_slug(cam, db)

@router.delete("/{camera_id}", status_code=204)
async def _delete(camera_id: UUID, db: Session = Depends(get_db)):
    from app.crud.crud_client import get_client

    cam = get_camera(db, camera_id)
    if not cam: raise HTTPException(404, "Câmera não encontrada")

    # Busca cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    client_slug = client.slug if client else str(cam.cliente_id)
    camera_name = cam.nome

    # Para gravação FFmpeg (SEMPRE, copy ou transcode)
    from app.services.recording import get_recording_manager
    manager = get_recording_manager()
    success = await manager.stop_camera_recording(str(cam.id))
    if success:
        print(f"[RECORDING] ✅ Gravação parada para {camera_name}")
    else:
        print(f"[RECORDING] ⚠️  Falha ao parar gravação para {camera_name}")

    ok = delete_camera(db, camera_id)
    if not ok: raise HTTPException(404, "Câmera não encontrada")

    # Remove gravações da câmera
    cleanup_camera_recordings(client_slug, camera_name)

    # Remove câmera do MediaMTX via API dinâmica (SEM reiniciar)
    from app.services.mediamtx_sync import remove_camera_from_mediamtx
    try:
        success = remove_camera_from_mediamtx(client_slug, camera_name)
        if success:
            print(f"[CAMERA_DELETE] ✅ Câmera {camera_name} removida do MediaMTX")
        else:
            print(f"[CAMERA_DELETE] ⚠️  Câmera removida do DB mas falhou ao remover do MediaMTX")
    except Exception as e:
        print(f"[CAMERA_DELETE] ⚠️  Erro ao remover do MediaMTX: {e}")

@router.get("/{camera_id}/snapshot")
async def get_camera_snapshot(camera_id: UUID, db: Session = Depends(get_db)):
    """
    Retorna um snapshot (JPEG) do momento atual da câmera
    """
    from app.crud.crud_client import get_client

    # Buscar câmera no banco
    cam = get_camera(db, camera_id)
    if not cam:
        raise HTTPException(404, "Câmera não encontrada")

    # Buscar cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    if not client:
        raise HTTPException(400, "Cliente não encontrado")

    # Determinar URL do stream baseado no protocolo
    if cam.protocolo == 'RTSP':
        # Para RTSP, usar stream do MediaMTX (re-streaming)
        stream_url = f"http://mediamtx:8888/live/{client.slug}/{cam.nome}/index.m3u8"
    else:
        # Para RTMP/HLS, usar stream do MediaMTX
        stream_url = f"http://mediamtx:8888/live/{client.slug}/{cam.nome}/index.m3u8"

    # Criar arquivo temporário para o snapshot
    with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
        tmp_path = tmp_file.name

    try:
        # Usar FFmpeg para capturar um frame
        cmd = [
            'ffmpeg',
            '-hide_banner',
            '-loglevel', 'error',
            '-y',
            '-i', stream_url,
            '-frames:v', '1',           # Apenas 1 frame
            '-q:v', '2',                # Qualidade JPEG (2 = alta)
            '-update', '1',             # Atualizar o mesmo arquivo
            tmp_path
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=10
        )

        if result.returncode != 0:
            # Se falhar, retornar uma imagem placeholder
            raise HTTPException(503, "Câmera offline ou stream indisponível")

        # Ler o arquivo JPEG gerado
        with open(tmp_path, 'rb') as f:
            image_data = f.read()

        # Limpar arquivo temporário
        Path(tmp_path).unlink(missing_ok=True)

        # Retornar imagem JPEG
        return Response(
            content=image_data,
            media_type="image/jpeg",
            headers={
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0"
            }
        )

    except subprocess.TimeoutExpired:
        Path(tmp_path).unlink(missing_ok=True)
        raise HTTPException(504, "Timeout ao capturar snapshot")
    except Exception as e:
        Path(tmp_path).unlink(missing_ok=True)
        print(f"[SNAPSHOT] Erro ao capturar snapshot: {e}")
        raise HTTPException(500, f"Erro ao capturar snapshot: {str(e)}")
