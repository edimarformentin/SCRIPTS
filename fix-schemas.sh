#!/bin/bash
# =============================================================================
# fix-schemas.sh - Correção dos schemas Pydantic após restaurar backup
# =============================================================================
# Execute este script após restaurar um backup antigo para garantir que
# os schemas estejam configurados corretamente para Pydantic v2
# =============================================================================

set -e

SISTEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SISTEMA_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}[INFO]${NC} Verificando schemas Pydantic..."

# Arquivo 1: client_schema.py
CLIENT_SCHEMA="backend/api/app/schemas/client_schema.py"
if grep -q 'model_config = {"from_attributes": True}' "$CLIENT_SCHEMA"; then
    echo -e "${GREEN}[OK]${NC} client_schema.py já está corrigido"
else
    echo -e "${YELLOW}[FIXING]${NC} Corrigindo client_schema.py..."

    # Backup do arquivo original
    cp "$CLIENT_SCHEMA" "$CLIENT_SCHEMA.bak"

    # Aplicar correção
    sed -i '/^class ClientOut(BaseModel):$/a\    model_config = {"from_attributes": True}\n' "$CLIENT_SCHEMA"

    echo -e "${GREEN}[OK]${NC} client_schema.py corrigido"
fi

# Arquivo 2: camera_schema.py
CAMERA_SCHEMA="backend/api/app/schemas/camera_schema.py"
if grep -q 'model_config = {"from_attributes": True}' "$CAMERA_SCHEMA"; then
    echo -e "${GREEN}[OK]${NC} camera_schema.py já está corrigido"
else
    echo -e "${YELLOW}[FIXING]${NC} Corrigindo camera_schema.py..."

    # Backup do arquivo original
    cp "$CAMERA_SCHEMA" "$CAMERA_SCHEMA.bak"

    # Aplicar correção
    sed -i '/^class CameraOut(BaseModel):$/a\    model_config = {"from_attributes": True}\n' "$CAMERA_SCHEMA"

    echo -e "${GREEN}[OK]${NC} camera_schema.py corrigido"
fi

echo ""
echo -e "${GREEN}[CONCLUÍDO]${NC} Schemas verificados e corrigidos!"
echo -e "${BLUE}[INFO]${NC} Se o sistema estiver rodando, reinicie o backend:"
echo -e "        ${YELLOW}docker restart gestao-web${NC}"
echo ""
