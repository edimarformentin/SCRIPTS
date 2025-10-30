from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from app.database import get_db
from app.schemas.client_schema import ClientCreate, ClientUpdate, ClientOut
from app.crud.crud_client import list_clients, get_client, create_client, update_client, delete_client
from app.crud.crud_camera import list_cameras_by_client
from app.schemas.camera_schema import CameraOut
from app.core.storage import cleanup_client_recordings

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
    # Busca cliente para pegar o slug antes de deletar
    cli = get_client(db, client_id)
    if not cli: raise HTTPException(404, "Cliente não encontrado")
    client_slug = cli.slug

    ok = delete_client(db, client_id)
    if not ok: raise HTTPException(404, "Cliente não encontrado")

    # Remove gravações do cliente (usando slug)
    cleanup_client_recordings(client_slug)

@router.get("/{client_id}/cameras", response_model=List[CameraOut])
def _list_cameras(client_id: UUID, db: Session = Depends(get_db)):
    return list_cameras_by_client(db, client_id)
