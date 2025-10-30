from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Dict
from uuid import UUID
import os
from app.database import get_db
from app.crud.crud_camera import get_camera
from app.crud.crud_client import get_client
from app.core.storage import list_camera_recordings, get_recording_path

router = APIRouter(prefix="/api/recordings", tags=["recordings"])

@router.get("/{camera_id}")
def list_recordings(camera_id: UUID, db: Session = Depends(get_db)):
    """Lista todas as gravações de uma câmera com metadados completos."""
    cam = get_camera(db, camera_id)
    if not cam:
        raise HTTPException(404, "Câmera não encontrada")

    # Busca cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    if not client:
        raise HTTPException(404, "Cliente não encontrado")

    client_slug = client.slug
    camera_name = cam.nome

    recordings_data = list_camera_recordings(client_slug, camera_name)
    return recordings_data

@router.get("/stream/{camera_id}/{filename}")
def stream_recording(
    camera_id: UUID,
    filename: str,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Serve uma gravação específica para streaming com suporte a HTTP Range (seek).
    Implementa 206 Partial Content para permitir navegação precisa no player.
    """
    cam = get_camera(db, camera_id)
    if not cam:
        raise HTTPException(404, "Câmera não encontrada")

    # Busca cliente para pegar o slug
    client = get_client(db, cam.cliente_id)
    if not client:
        raise HTTPException(404, "Cliente não encontrado")

    client_slug = client.slug
    camera_name = cam.nome

    recording_path = get_recording_path(client_slug, camera_name, filename)
    if not recording_path:
        raise HTTPException(404, "Gravação não encontrada")

    # Obtém tamanho total do arquivo
    file_size = recording_path.stat().st_size

    # Verifica se há cabeçalho Range na requisição
    range_header = request.headers.get("range")

    if not range_header:
        # Sem Range: retorna arquivo completo (200 OK)
        def iterfile():
            with open(recording_path, mode="rb") as file_like:
                while chunk := file_like.read(65536):  # 64KB chunks
                    yield chunk

        return StreamingResponse(
            iterfile(),
            media_type="video/mp4",
            headers={
                "Content-Disposition": f'inline; filename="{filename}"',
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Cache-Control": "no-cache"
            }
        )

    # Com Range: retorna trecho solicitado (206 Partial Content)
    # Parse do Range header (formato: "bytes=start-end")
    try:
        range_match = range_header.replace("bytes=", "").split("-")
        start = int(range_match[0]) if range_match[0] else 0
        end = int(range_match[1]) if len(range_match) > 1 and range_match[1] else file_size - 1

        # Validação
        if start >= file_size or start < 0:
            raise HTTPException(416, "Range Not Satisfiable")

        # Ajusta end se necessário
        end = min(end, file_size - 1)
        content_length = end - start + 1

        # Função geradora para ler apenas o trecho solicitado
        def iterfile_range():
            with open(recording_path, mode="rb") as file_like:
                file_like.seek(start)
                remaining = content_length

                while remaining > 0:
                    chunk_size = min(65536, remaining)  # 64KB ou o que falta
                    chunk = file_like.read(chunk_size)
                    if not chunk:
                        break
                    remaining -= len(chunk)
                    yield chunk

        return StreamingResponse(
            iterfile_range(),
            status_code=206,  # Partial Content
            media_type="video/mp4",
            headers={
                "Content-Disposition": f'inline; filename="{filename}"',
                "Accept-Ranges": "bytes",
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Content-Length": str(content_length),
                "Cache-Control": "no-cache"
            }
        )

    except (ValueError, IndexError):
        raise HTTPException(400, "Invalid Range header")
