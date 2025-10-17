#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Atualizando CRUD da API v3.8..."

cat > "$API_DIR/app/crud/crud_camera.py" <<'PY'
from sqlalchemy.orm import Session
from typing import Optional
from app import models
from app.schemas.camera import CameraCreate, CameraUpdate

def get(db: Session, camera_id: int) -> Optional[models.Camera]:
    return db.query(models.Camera).filter(models.Camera.id == camera_id).first()

def get_multi(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Camera).offset(skip).limit(limit).all()

def create(db: Session, obj_in: CameraCreate) -> models.Camera:
    data = obj_in.model_dump(exclude_unset=True)
    db_obj = models.Camera(**data)
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def update(db: Session, db_obj: models.Camera, obj_in: CameraUpdate) -> models.Camera:
    data = obj_in.model_dump(exclude_unset=True)
    for f, v in data.items():
        setattr(db_obj, f, v)
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj
PY

log "CRUD v3.8 pronto."
