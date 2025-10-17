#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Atualizando endpoints FastAPI v3.8..."

# Rotas de cameras (incluindo validate e playback)
cat > "$API_DIR/app/api/endpoints/cameras.py" <<'PY'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import subprocess, shlex
import os

from app.api.deps import get_db
from app.schemas.camera import CameraCreate, CameraUpdate, CameraDB
from app.crud import camera as crud
from app import models

router = APIRouter()

@router.get("/", response_model=list[CameraDB])
def list_cameras(skip:int=0, limit:int=100, db:Session=Depends(get_db)):
    return crud.get_multi(db, skip=skip, limit=limit)

@router.get("/{camera_id}", response_model=CameraDB)
def get_camera(camera_id:int, db:Session=Depends(get_db)):
    obj = crud.get(db, camera_id)
    if not obj:
        raise HTTPException(404, "Camera não encontrada")
    return obj

@router.post("/", response_model=CameraDB, status_code=201)
def create_camera(payload:CameraCreate, db:Session=Depends(get_db)):
    return crud.create(db, payload)

@router.patch("/{camera_id}", response_model=CameraDB)
def update_camera(camera_id:int, payload:CameraUpdate, db:Session=Depends(get_db)):
    obj = crud.get(db, camera_id)
    if not obj:
        raise HTTPException(404, "Camera não encontrada")
    return crud.update(db, obj, payload)

@router.get("/{camera_id}/playback")
def playback(camera_id:int, db:Session=Depends(get_db)):
    obj = crud.get(db, camera_id)
    if not obj:
        raise HTTPException(404, "Camera não encontrada")
    if not obj.stream_output_slug or obj.playback_protocol != 'hls':
        # fallback simples
        return {"protocol": "none", "url": None}
    # URL HLS publicada pelo MediaMTX (via Nginx se houver)
    # Usa variável de ambiente BASE_PUBLIC_URL, definida no compose/env
    base = os.environ.get("BASE_PUBLIC_URL", "").rstrip("/")
    url = f"{base}/hls/{obj.stream_output_slug}/index.m3u8"
    return {"protocol":"hls","url":url}

@router.post("/{camera_id}/validate")
def validate_stream(camera_id:int, db:Session=Depends(get_db)):
    obj = crud.get(db, camera_id)
    if not obj:
        raise HTTPException(404, "Camera não encontrada")
    if not obj.stream_input_url:
        raise HTTPException(400, "stream_input_url não definido")
    # Usa ffprobe para checar rapidamente a conexão
    cmd = f"ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 {shlex.quote(obj.stream_input_url)}"
    try:
        subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, timeout=15)
        obj.health_status = "ok"
    except subprocess.CalledProcessError as e:
        obj.health_status = "error"
    except subprocess.TimeoutExpired:
        obj.health_status = "warn"
    obj.last_health_check = datetime.now(timezone.utc)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return {"camera_id": obj.id, "health_status": obj.health_status, "last_health_check": obj.last_health_check}
PY

# Main inclui o router acima
sed -i "s#from app.api.api_v1.endpoints import .*#from app.api.endpoints import cameras#g" "$API_DIR/app/main.py" || true

if ! grep -q "include_router(cameras.router" "$API_DIR/app/main.py"; then
cat >> "$API_DIR/app/main.py" <<'PY'

from app.api.endpoints import cameras
app.include_router(cameras.router, prefix="/api/v1/cameras", tags=["Cameras"])
PY
fi

log "Endpoints v3.8 prontos."
