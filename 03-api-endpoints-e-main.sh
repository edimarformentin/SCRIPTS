#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 03-api-endpoints-e-main.sh  (FIX paths + imports app.*)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  ensure_dirs "$API_DIR/app/routers"
  : > "$API_DIR/app/routers/__init__.py"

  # routers/clients.py
  cat > "$API_DIR/app/routers/clients.py" <<'PY'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from app.database import get_db
from app.schemas.client_schema import ClientCreate, ClientUpdate, ClientOut
from app.crud.crud_client import list_clients, get_client, create_client, update_client, delete_client
from app.crud.crud_camera import list_cameras_by_client
from app.schemas.camera_schema import CameraOut

router = APIRouter(prefix="/api/clients", tags=["clients"])

@router.get("", response_model=List[ClientOut])
def _list(db: Session = Depends(get_db)):
    return list_clients(db)

@router.post("", response_model=ClientOut, status_code=201)
def _create(payload: ClientCreate, db: Session = Depends(get_db)):
    return create_client(db, payload)

@router.get("/{client_id}", response_model=ClientOut)
def _get(client_id: UUID, db: Session = Depends(get_db)):
    cli = get_client(db, client_id)
    if not cli: raise HTTPException(404, "Cliente não encontrado")
    return cli

@router.put("/{client_id}", response_model=ClientOut)
def _update(client_id: UUID, payload: ClientUpdate, db: Session = Depends(get_db)):
    cli = update_client(db, client_id, payload)
    if not cli: raise HTTPException(404, "Cliente não encontrado")
    return cli

@router.delete("/{client_id}", status_code=204)
def _delete(client_id: UUID, db: Session = Depends(get_db)):
    ok = delete_client(db, client_id)
    if not ok: raise HTTPException(404, "Cliente não encontrado")

@router.get("/{client_id}/cameras", response_model=List[CameraOut])
def _list_cameras(client_id: UUID, db: Session = Depends(get_db)):
    return list_cameras_by_client(db, client_id)
PY

  # routers/cameras.py
  cat > "$API_DIR/app/routers/cameras.py" <<'PY'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from app.database import get_db
from app.schemas.camera_schema import CameraCreate, CameraUpdate, CameraOut
from app.crud.crud_camera import list_cameras, get_camera, create_camera, update_camera, delete_camera

router = APIRouter(prefix="/api/cameras", tags=["cameras"])

@router.get("", response_model=List[CameraOut])
def _list(db: Session = Depends(get_db)):
    return list_cameras(db)

@router.post("", response_model=CameraOut, status_code=201)
def _create(payload: CameraCreate, db: Session = Depends(get_db)):
    return create_camera(db, payload)

@router.get("/{camera_id}", response_model=CameraOut)
def _get(camera_id: UUID, db: Session = Depends(get_db)):
    cam = get_camera(db, camera_id)
    if not cam: raise HTTPException(404, "Câmera não encontrada")
    return cam

@router.put("/{camera_id}", response_model=CameraOut)
def _update(camera_id: UUID, payload: CameraUpdate, db: Session = Depends(get_db)):
    cam = update_camera(db, camera_id, payload)
    if not cam: raise HTTPException(404, "Câmera não encontrada")
    return cam

@router.delete("/{camera_id}", status_code=204)
def _delete(camera_id: UUID, db: Session = Depends(get_db)):
    ok = delete_camera(db, camera_id)
    if not ok: raise HTTPException(404, "Câmera não encontrada")
PY

  # app/main.py
  cat > "$API_DIR/app/main.py" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers import clients, cameras

app = FastAPI(title=settings.app_name)

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
PY

  ok "Endpoints e main gerados em app/routers e app/main.py."
}
main "$@"
