#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 03-api-schemas-pydantic.sh  (FIX paths)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  ensure_dirs "$API_DIR/app/schemas"
  : > "$API_DIR/app/schemas/__init__.py"

  # Client schema
  cat > "$API_DIR/app/schemas/client_schema.py" <<'PY'
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from uuid import UUID

class ClientCreate(BaseModel):
    nome: str = Field(..., min_length=1, max_length=255)
    documento: str = Field(..., min_length=3, max_length=32)
    email: Optional[EmailStr] = None
    telefone: Optional[str] = None
    status: Optional[str] = "ativo"

class ClientUpdate(BaseModel):
    nome: Optional[str] = Field(None, min_length=1, max_length=255)
    email: Optional[EmailStr] = None
    telefone: Optional[str] = None
    status: Optional[str] = None

class ClientOut(BaseModel):
    id: UUID
    nome: str
    documento: str
    email: Optional[EmailStr]
    telefone: Optional[str]
    status: str
PY

  # Camera schema
  cat > "$API_DIR/app/schemas/camera_schema.py" <<'PY'
from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID

class CameraCreate(BaseModel):
    cliente_id: UUID
    nome: str = Field(..., min_length=1, max_length=255)
    protocolo: str = Field(..., pattern="^(RTSP|RTMP|HLS)$")
    endpoint: str = Field(..., min_length=3, max_length=1024)
    ativo: Optional[bool] = True
    stream_key: Optional[str] = None
    resolucao: Optional[str] = None
    fps: Optional[int] = None
    bitrate_kbps: Optional[int] = None

class CameraUpdate(BaseModel):
    nome: Optional[str] = None
    protocolo: Optional[str] = Field(None, pattern="^(RTSP|RTMP|HLS)$")
    endpoint: Optional[str] = None
    ativo: Optional[bool] = None
    stream_key: Optional[str] = None
    resolucao: Optional[str] = None
    fps: Optional[int] = None
    bitrate_kbps: Optional[int] = None

class CameraOut(BaseModel):
    id: UUID
    cliente_id: UUID
    nome: str
    protocolo: str
    endpoint: str
    ativo: bool
    stream_key: Optional[str]
    resolucao: Optional[str]
    fps: Optional[int]
    bitrate_kbps: Optional[int]
PY
  ok "Schemas Pydantic gerados em app/schemas."
}
main "$@"
