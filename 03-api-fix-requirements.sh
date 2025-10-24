#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 03-api-fix-requirements.sh
# Adiciona as libs necessárias para EmailStr (email-validator) e reconstrói a API.
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  mkdir -p "$API_DIR"
  cat > "$API_DIR/requirements.txt" <<'REQ'
# --- Core API ---
fastapi==0.115.0
uvicorn[standard]==0.30.6

# --- Pydantic v2 ---
# 'pydantic[email]' puxa email-validator; incluímos explicitamente também por robustez.
pydantic[email]==2.8.2
email-validator>=2.1.0

# --- DB ---
SQLAlchemy==2.0.32
psycopg2-binary==2.9.9

# --- Util ---
python-dotenv==1.0.1
REQ

  # Garante que o Dockerfile existe (gerado pelo 03-api-estrutura-base.sh)
  if [[ ! -f "$API_DIR/Dockerfile" ]]; then
    cat > "$API_DIR/Dockerfile" <<'DOCKER'
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# deps nativos para psycopg2-binary compilar extensões se necessário
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      build-essential libpq-dev curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
DOCKER
  fi

  echo "[OK] requirements.txt atualizado em $API_DIR/requirements.txt"
}

main "$@"
