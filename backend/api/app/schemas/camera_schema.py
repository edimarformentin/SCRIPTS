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
    transcode_to_h265: Optional[bool] = False

class CameraUpdate(BaseModel):
    nome: Optional[str] = None
    protocolo: Optional[str] = Field(None, pattern="^(RTSP|RTMP|HLS)$")
    endpoint: Optional[str] = None
    ativo: Optional[bool] = None
    stream_key: Optional[str] = None
    resolucao: Optional[str] = None
    fps: Optional[int] = None
    bitrate_kbps: Optional[int] = None
    transcode_to_h265: Optional[bool] = None

class CameraOut(BaseModel):
    model_config = {"from_attributes": True}

    id: UUID
    cliente_id: UUID
    cliente_slug: Optional[str] = None
    nome: str
    protocolo: str
    endpoint: str
    ativo: bool
    stream_key: Optional[str]
    resolucao: Optional[str]
    fps: Optional[int]
    bitrate_kbps: Optional[int]
    transcode_to_h265: bool
