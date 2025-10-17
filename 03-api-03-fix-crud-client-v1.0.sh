#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

log "Aplicando correção no CRUD de clientes (gerar UUID no servidor)..."

# Procura os arquivos candidatos (projeto pode ter estrutura levemente diferente)
mapfile -t FILES < <(find "$API_DIR" -type f -name "crud_client.py" 2>/dev/null || true)

if [ "${#FILES[@]}" -eq 0 ]; then
  log "ATENÇÃO: crud_client.py não encontrado dentro de $API_DIR"
  exit 0
fi

for F in "${FILES[@]}"; do
  log "Corrigindo: $F"

  # Garante import do uuid4
  grep -q "from uuid import uuid4" "$F" || sed -i '1s/^/from uuid import uuid4\n/' "$F"

  # Substitui padrões que acessam client_in.id pelo fallback seguro
  sed -i -E 's/client_id\s*=\s*client_in\.id\s*or\s*uuid4\(\)/client_id = getattr(client_in, "id", None) or uuid4()/g' "$F"
  sed -i -E 's/client_id\s*=\s*getattr\(client_in,\s*\"id\",\s*None\)\s*or\s*uuid4\(\)/client_id = getattr(client_in, "id", None) or uuid4()/g' "$F"
  sed -i -E 's/client_id\s*=\s*client_in\.id\s*if\s*client_in\.id\s*else\s*uuid4\(\)/client_id = getattr(client_in, "id", None) or uuid4()/g' "$F"

  # Em muitos códigos o dict/model_dump é usado; não é necessário trocar,
  # mas garantimos compatibilidade com Pydantic v1/v2 em uma linha só (idempotente).
  if grep -q "obj_in.dict(" "$F"; then
    sed -i -E 's/([_a-zA-Z0-9]+)\s*=\s*([_a-zA-Z0-9]+)\.dict\(([^)]*)\)/\1 = \2.model_dump(\3) if hasattr(\2, "model_dump") else \2.dict(\3)/g' "$F"
  fi
done

log "Correção aplicada com sucesso."
