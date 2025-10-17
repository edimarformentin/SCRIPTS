#!/bin/bash
# =================================================================
# Script: 03-api-02-schemas-pydantic.sh
#
# Propósito:
# Este script gera os schemas Pydantic para a API. Schemas são
# modelos de dados que definem a estrutura, os tipos e as regras
# de validação para os dados que entram e saem da API.
#
# O que ele faz:
# 1. Cria o arquivo 'client_schema.py' para os dados do cliente.
# 2. Cria o arquivo 'camera_schema.py' para os dados da câmera.
# 3. Define classes como 'ClientCreate', 'ClientUpdate', 'ClientInDB',
#    'CameraCreate', etc., para diferentes operações (criação,
#    leitura, atualização).
#
# Correção nesta versão:
# Garante que o schema 'CameraInDB' (usado nas respostas da API)
# inclua o campo 'url_rtsp', para que serviços como o Janitor
# possam saber qual é a URL da câmera.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
echo "--> 3.2: Criando os schemas Pydantic da API (v-unificada)..."
SCHEMAS_DIR="$API_DIR/app/schemas"
mkdir -p "$SCHEMAS_DIR" && touch "$SCHEMAS_DIR/__init__.py"

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
    id: Optional[UUID] = None
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
    # --- AQUI ESTÁ A CORREÇÃO ---
    url_rtsp: Optional[str] = None
    is_active: bool
    data_criacao: datetime.datetime
    data_atualizacao: datetime.datetime
    class Config:
        from_attributes = True
CAM_S_EOF
echo "--- Schemas Pydantic da API unificados e corrigidos."
