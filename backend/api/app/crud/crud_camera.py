from sqlalchemy.orm import Session
from sqlalchemy import select
from uuid import UUID
from app.models import Camera
from app.schemas.camera_schema import CameraCreate, CameraUpdate

def list_cameras(db: Session) -> list[Camera]:
  return db.execute(select(Camera).order_by(Camera.nome)).scalars().all()

def list_cameras_by_client(db: Session, client_id: UUID) -> list[Camera]:
  return db.execute(select(Camera).where(Camera.cliente_id==client_id).order_by(Camera.nome)).scalars().all()

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
