#!/bin/bash
# =================================================================
# Script: 03-api-05-endpoint-gravacoes.sh (v1.1 - Correção de Import)
#
# Propósito:
# Adiciona o endpoint para listar gravações e corrige a falha de
# inicialização da API causada pela falta de importação dos schemas.
#
# O que ele faz:
# 1. Adiciona o schema 'RecordingSegment' em 'camera_schema.py'.
# 2. Adiciona a rota GET /{camera_id}/recordings em 'cameras.py'.
# 3. **CORREÇÃO:** Adiciona as importações necessárias (List, RecordingSegment)
#    no topo do arquivo 'cameras.py' para resolver o NameError.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 3.5: Adicionando endpoint para listar gravações (v1.1)..."

# --- 1. Adicionar o novo Schema de Resposta ---
# Verifica se o schema já não foi adicionado para tornar o script idempotente
if ! grep -q "class RecordingSegment" "$API_DIR/app/schemas/camera_schema.py"; then
    echo "    -> Adicionando schema 'RecordingSegment' em camera_schema.py..."
    cat << 'SCHEMA_APPEND_EOF' >> "$API_DIR/app/schemas/camera_schema.py"

class RecordingSegment(BaseModel):
    start_time: datetime.datetime
    end_time: datetime.datetime
    url: str
SCHEMA_APPEND_EOF
fi

# --- 2. Adicionar as importações e a lógica do endpoint em cameras.py ---
echo "    -> Adicionando importações e rota GET /{camera_id}/recordings em cameras.py..."

# Adiciona as importações que faltam no topo do arquivo de endpoints de câmera
# Usamos um bloco para garantir que a inserção aconteça apenas uma vez
if ! grep -q "RecordingSegment" "$API_DIR/app/api/endpoints/cameras.py"; then
    sed -i '
    /from typing import List/a \
from app.schemas.camera_schema import RecordingSegment
    ' "$API_DIR/app/api/endpoints/cameras.py"

    sed -i '
    /from app.database import get_db_connection/a \
import os\
from slugify import slugify\
from datetime import timedelta
    ' "$API_DIR/app/api/endpoints/cameras.py"
fi

# Adiciona o novo endpoint no final do arquivo, se ele não existir
if ! grep -q "def list_camera_recordings" "$API_DIR/app/api/endpoints/cameras.py"; then
    cat << 'ENDPOINT_APPEND_EOF' >> "$API_DIR/app/api/endpoints/cameras.py"

RECORDINGS_BASE_DIR = "/recordings"

@router.get("/{camera_id}/recordings", response_model=List[RecordingSegment])
def list_camera_recordings(camera_id: UUID, db: psycopg2.extensions.connection = Depends(get_db_connection)):
    """
    Lista os segmentos de gravação disponíveis para uma câmera.
    """
    try:
        cam = crud_camera.get(db, camera_id=camera_id)
        if not cam:
            raise HTTPException(status_code=404, detail="Câmera não encontrada")

        # Determina o nome do path da câmera
        if cam.get("url_rtsp"):
            path_name = slugify(cam["nome_camera"])
        elif cam.get("url_rtmp_path"):
            path_name = cam["url_rtmp_path"]
        else:
            return []

        cam_record_dir = os.path.join(RECORDINGS_BASE_DIR, path_name)

        if not os.path.isdir(cam_record_dir):
            return []

        segments = []
        for filename in sorted(os.listdir(cam_record_dir)):
            if filename.endswith(".mp4"):
                try:
                    timestamp_str = filename.replace(".mp4", "")
                    start_time = datetime.strptime(timestamp_str, "%Y-%m-%d_%H-%M-%S")
                    end_time = start_time + timedelta(hours=1)
                    public_url = f"/recordings/{path_name}/{filename}"

                    segments.append(
                        RecordingSegment(
                            start_time=start_time,
                            end_time=end_time,
                            url=public_url
                        )
                    )
                except (ValueError, IndexError):
                    continue

        return segments
    finally:
        if db: db.close()
ENDPOINT_APPEND_EOF
fi

echo "--- Endpoint de gravações adicionado e corrigido com sucesso."
