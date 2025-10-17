#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Gerando schemas Pydantic v3.8..."

cat > "$API_DIR/app/schemas/camera_schema.py" <<'PY'
from pydantic import BaseModel, HttpUrl, field_validator
from typing import Optional, Literal
from datetime import datetime

PlaybackProtocol = Literal['hls','webrtc','dash','none']

class CameraBase(BaseModel):
    client_id: int
    nome: str
    descricao: Optional[str] = None
    stream_input_url: Optional[str] = None
    stream_output_slug: Optional[str] = None
    playback_protocol: PlaybackProtocol = 'hls'
    is_active: bool = True
    recording_days: int = 0

    @field_validator('recording_days')
    @classmethod
    def _rec_days(cls, v):
        if v is None: return 0
        if v < 0 or v > 7:
            raise ValueError("recording_days deve estar entre 0 e 7")
        return v

class CameraCreate(CameraBase):
    pass

class CameraUpdate(BaseModel):
    nome: Optional[str] = None
    descricao: Optional[str] = None
    stream_input_url: Optional[str] = None
    stream_output_slug: Optional[str] = None
    playback_protocol: Optional[PlaybackProtocol] = None
    is_active: Optional[bool] = None
    recording_days: Optional[int] = None

class CameraDB(CameraBase):
    id: int
    health_status: Optional[Literal['unknown','ok','warn','error']] = 'unknown'
    last_health_check: Optional[datetime] = None
    snapshot_url: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
PY

log "Schemas v3.8 prontos."
