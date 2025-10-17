#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 03-api-04: Endpoints e Main (v3.5 - GET /cameras/)
#
# Adiciona o endpoint GET /api/v1/cameras/ para listar todas
# as câmeras do sistema.
# =================================================================
echo "--> 3.4: Criando endpoints e o arquivo main.py da API (v3.5)..."
ENDPOINTS_DIR="$API_DIR/app/api/endpoints"
mkdir -p "$ENDPOINTS_DIR" && touch "$API_DIR/app/api/__init__.py" && touch "$ENDPOINTS_DIR/__init__.py"

# --- Recria clients.py (sem alterações) ---
echo "    -> Recriando app/api/endpoints/clients.py..."
cat << 'EP_C_EOF' > "$ENDPOINTS_DIR/clients.py"
from fastapi import APIRouter, HTTPException, status, Depends, Response
from typing import List
from uuid import UUID
import psycopg2
from app.schemas.client_schema import ClientInDB, ClientCreate, ClientUpdate
from app.crud import crud_client
from app.database import get_db_connection
router = APIRouter()
@router.post("/", response_model=ClientInDB, status_code=status.HTTP_201_CREATED)
def create_client(client: ClientCreate, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        return crud_client.create(db, client_in=client)
    except psycopg2.errors.UniqueViolation as e:
        db.rollback()
        if 'clientes_email_key' in str(e): raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Este e-mail já está em uso.")
        if 'clientes_cpf_key' in str(e): raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Este CPF já está cadastrado.")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Erro de integridade: {e}")
    finally:
        if db: db.close()
@router.get("/", response_model=List[ClientInDB])
def read_clients(skip: int = 0, limit: int = 100, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try: return crud_client.get_all(db, skip=skip, limit=limit)
    finally:
        if db: db.close()
@router.get("/{client_id}", response_model=ClientInDB)
def read_client(client_id: UUID, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        db_client = crud_client.get(db, client_id=client_id)
        if db_client is None: raise HTTPException(status_code=404, detail="Cliente não encontrado")
        return db_client
    finally:
        if db: db.close()
@router.put("/{client_id}", response_model=ClientInDB)
def update_client(client_id: UUID, client_in: ClientUpdate, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        if not crud_client.get(db, client_id=client_id): raise HTTPException(status_code=404, detail="Cliente não encontrado")
        return crud_client.update(db, client_id=client_id, client_in=client_in)
    except psycopg2.errors.UniqueViolation as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Este e-mail ou CPF já está em uso por outro cliente.")
    finally:
        if db: db.close()
@router.delete("/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_client(client_id: UUID, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        if not crud_client.remove(db, client_id=client_id): raise HTTPException(status_code=404, detail="Cliente não encontrado")
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    finally:
        if db: db.close()
EP_C_EOF

# --- Cria cameras.py com o novo endpoint ---
echo "    -> Criando app/api/endpoints/cameras.py com o novo endpoint GET /..."
cat << 'EP_CAM_EOF' > "$ENDPOINTS_DIR/cameras.py"
from fastapi import APIRouter, HTTPException, status, Depends, Response
from typing import List
from uuid import UUID
import psycopg2
from app.schemas.camera_schema import CameraInDB, CameraCreate, CameraUpdate
from app.crud import crud_camera
from app.database import get_db_connection
router = APIRouter()

@router.get("/", response_model=List[CameraInDB])
def read_all_cameras(skip: int = 0, limit: int = 1000, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    """
    Endpoint para o orquestrador. Retorna todas as câmeras do sistema.
    """
    try:
        return crud_camera.get_all(db, skip=skip, limit=limit)
    finally:
        if db: db.close()

@router.post("/", response_model=CameraInDB, status_code=status.HTTP_201_CREATED)
def create_camera(camera: CameraCreate, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        new_camera = crud_camera.create(db, camera_in=camera)
        if new_camera is None: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="O cliente especificado não foi encontrado.")
        return new_camera
    except psycopg2.errors.UniqueViolation:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Já existe uma câmera com este nome para este cliente.")
    finally:
        if db: db.close()

@router.get("/client/{client_id}", response_model=List[CameraInDB])
def read_cameras_by_client(client_id: UUID, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try: return crud_camera.get_by_client(db, client_id=client_id)
    finally:
        if db: db.close()

@router.put("/{camera_id}", response_model=CameraInDB)
def update_camera(camera_id: UUID, camera_in: CameraUpdate, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        if not crud_camera.get(db, camera_id=camera_id): raise HTTPException(status_code=404, detail="Câmera não encontrada")
        return crud_camera.update(db, camera_id=camera_id, camera_in=camera_in)
    except psycopg2.errors.UniqueViolation:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Já existe uma câmera com este nome para este cliente.")
    finally:
        if db: db.close()

@router.delete("/{camera_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_camera(camera_id: UUID, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    try:
        if not crud_camera.remove(db, camera_id=camera_id): raise HTTPException(status_code=404, detail="Câmera não encontrada")
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    finally:
        if db: db.close()
EP_CAM_EOF

# --- Recria main.py (sem alterações) ---
echo "    -> Recriando app/main.py..."
cat << 'MAIN_EOF' > "$API_DIR/app/main.py"
from fastapi import FastAPI
from app.api.endpoints import clients, cameras
from app.database import wait_for_db
app = FastAPI(title="VaaS API", description="API para o sistema de Video Analytics as a Service.", version="3.5.0")
@app.on_event("startup")
def startup_event(): wait_for_db()
@app.get("/", tags=["Health Check"])
def read_root(): return {"status": "VaaS API is running!"}
app.include_router(clients.router, prefix="/api/v1/clients", tags=["Clients"])
app.include_router(cameras.router, prefix="/api/v1/cameras", tags=["Cameras"])
MAIN_EOF
echo "--- Endpoints e main.py da API (v3.5) criados com sucesso."
