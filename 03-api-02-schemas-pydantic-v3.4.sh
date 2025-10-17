#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 03-api-02: Schemas Pydantic (v3.4 - ID Opcional)
#
# Adiciona um campo 'id' opcional ao schema ClientCreate para
# permitir o cadastro de clientes com UUIDs pré-definidos (seeding).
# =================================================================
echo "--> 3.2: Criando os schemas Pydantic da API (v3.4 - ID Opcional)..."
SCHEMAS_DIR="$API_DIR/app/schemas"
mkdir -p "$SCHEMAS_DIR" && touch "$SCHEMAS_DIR/__init__.py"

# --- client_schema.py (COM ID OPCIONAL) ---
echo "    -> Criando app/schemas/client_schema.py com ID opcional..."
cat << 'CS_EOF' > "$SCHEMAS_DIR/client_schema.py"
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from uuid import UUID
import datetime

class ClientBase(BaseModel):
    nome: str = Field(..., min_length=3, max_length=255)
    email: EmailStr
    cpf: str = Field(..., min_length=11, max_length=14)
    endereco: Optional[str] = None

class ClientCreate(ClientBase):
    # --- AQUI ESTÁ A MODIFICAÇÃO ---
    id: Optional[UUID] = None # Permite que um UUID seja passado no momento da criação

class ClientUpdate(BaseModel):
    nome: Optional[str] = Field(None, min_length=3, max_length=255)
    email: Optional[EmailStr] = None
    cpf: Optional[str] = Field(None, min_length=11, max_length=14)
    endereco: Optional[str] = None

class ClientInDB(ClientBase):
    id: UUID
    id_legivel: str
    data_criacao: datetime.datetime
    data_atualizacao: datetime.datetime
    class Config: from_attributes = True
CS_EOF

# --- camera_schema.py (sem alterações, apenas recriado) ---
echo "    -> Recriando app/schemas/camera_schema.py (v3.3)..."
cat << 'CAM_S_EOF' > "$SCHEMAS_DIR/camera_schema.py"
from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID
import datetime

class CameraBase(BaseModel):
    nome_camera: str = Field(..., min_length=1, max_length=100)
    dias_gravacao: int = Field(1, ge=1, le=7)
    detectar_carros: bool = False
    detectar_pessoas: bool = False

class CameraCreate(CameraBase):
    cliente_id: UUID
    url_rtsp: Optional[str] = Field(None, description="URL da câmera RTSP. Se nulo, será uma câmera RTMP.")

class CameraUpdate(BaseModel):
    nome_camera: Optional[str] = Field(None, min_length=1, max_length=100)
    dias_gravacao: Optional[int] = Field(None, ge=1, le=7)
    detectar_carros: Optional[bool] = None
    detectar_pessoas: Optional[bool] = None
    is_active: Optional[bool] = None

class CameraInDB(CameraBase):
    id: UUID
    cliente_id: UUID
    url_rtmp_path: Optional[str] = None
    url_rtsp: Optional[str] = None
    is_active: bool
    data_criacao: datetime.datetime
    data_atualizacao: datetime.datetime
    class Config:
        from_attributes = True
CAM_S_EOF
echo "--- Schemas Pydantic da API (v3.4) com ID opcional criados com sucesso."
