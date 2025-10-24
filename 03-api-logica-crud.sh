#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 03-api-logica-crud.sh  (FIX paths + imports app.*)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  ensure_dirs "$API_DIR/app/crud"
  : > "$API_DIR/app/crud/__init__.py"

  # CRUD de clientes
  cat > "$API_DIR/app/crud/crud_client.py" <<'PY'
from sqlalchemy.orm import Session
from sqlalchemy import select
from uuid import UUID
from app.models import Client
from app.schemas.client_schema import ClientCreate, ClientUpdate

def list_clients(db: Session) -> list[Client]:
  return db.execute(select(Client).order_by(Client.created_at.desc())).scalars().all()

def get_client(db: Session, client_id: UUID) -> Client | None:
  return db.get(Client, client_id)

def get_client_by_documento(db: Session, documento: str) -> Client | None:
  return db.execute(select(Client).where(Client.documento==documento)).scalar_one_or_none()

def create_client(db: Session, payload: ClientCreate) -> Client:
  cli = Client(**payload.model_dump())
  db.add(cli)
  db.commit()
  db.refresh(cli)
  return cli

def update_client(db: Session, client_id: UUID, payload: ClientUpdate) -> Client | None:
  cli = get_client(db, client_id)
  if not cli: return None
  for k, v in payload.model_dump(exclude_unset=True).items():
    setattr(cli, k, v)
  db.commit(); db.refresh(cli)
  return cli

def delete_client(db: Session, client_id: UUID) -> bool:
  cli = get_client(db, client_id)
  if not cli: return False
  db.delete(cli); db.commit()
  return True
PY

  # CRUD de câmeras
  cat > "$API_DIR/app/crud/crud_camera.py" <<'PY'
from sqlalchemy.orm import Session
from sqlalchemy import select
from uuid import UUID
from app.models import Camera
from app.schemas.camera_schema import CameraCreate, CameraUpdate

def list_cameras(db: Session) -> list[Camera]:
  return db.execute(select(Camera).order_by(Camera.created_at.desc())).scalars().all()

def list_cameras_by_client(db: Session, client_id: UUID) -> list[Camera]:
  return db.execute(select(Camera).where(Camera.cliente_id==client_id).order_by(Camera.created_at.desc())).scalars().all()

def get_camera(db: Session, camera_id: UUID) -> Camera | None:
  return db.get(Camera, camera_id)

def create_camera(db: Session, payload: CameraCreate) -> Camera:
  cam = Camera(**payload.model_dump())
  db.add(cam)
  db.commit()
  db.refresh(cam)
  return cam

def update_camera(db: Session, camera_id: UUID, payload: CameraUpdate) -> Camera | None:
  cam = get_camera(db, camera_id)
  if not cam: return None
  for k, v in payload.model_dump(exclude_unset=True).items():
    setattr(cam, k, v)
  db.commit(); db.refresh(cam)
  return cam

def delete_camera(db: Session, camera_id: UUID) -> bool:
  cam = get_camera(db, camera_id)
  if not cam: return False
  db.delete(cam); db.commit()
  return True
PY

  ok "CRUDs gerados em app/crud."
}
main "$@"
