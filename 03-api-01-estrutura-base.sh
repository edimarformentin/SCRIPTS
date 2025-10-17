#!/bin/bash
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
echo "--> 1.2.1: Criando a estrutura base da API (v-unificada)..."
APP_DIR="$API_DIR/app"
CORE_DIR="$APP_DIR/core"
mkdir -p "$CORE_DIR"
touch "$APP_DIR/__init__.py" "$CORE_DIR/__init__.py"

echo "    -> Criando requirements.txt com email-validator..."
cat << 'REQ_EOF' > "$API_DIR/requirements.txt"
fastapi==0.111.0
uvicorn[standard]==0.29.0
psycopg2-binary==2.9.9
pydantic==2.7.1
pydantic-settings==2.2.1
python-slugify==8.0.4
passlib[bcrypt]==1.7.4
python-jose[cryptography]==3.3.0
email-validator==2.1.1
REQ_EOF

cat << 'DOCKER_EOF' > "$API_DIR/Dockerfile"
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./app /app/app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
DOCKER_EOF

cat << 'CONF_EOF' > "$CORE_DIR/config.py"
import os
from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    DB_NAME: str = os.getenv("POSTGRES_DB", "vaas_db")
    DB_USER: str = os.getenv("POSTGRES_USER", "vaas_user")
    DB_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "vaas_strong_password")
    DB_HOST: str = os.getenv("POSTGRES_HOST", "vaas-postgres-db")
    DB_PORT: str = os.getenv("POSTGRES_PORT", "5432")
    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
settings = Settings()
CONF_EOF

cat << 'DB_EOF' > "$APP_DIR/database.py"
import psycopg2
from psycopg2.extras import RealDictCursor
from app.core.config import settings
import time
def get_db_connection():
    conn = psycopg2.connect(
        dbname=settings.DB_NAME, user=settings.DB_USER,
        password=settings.DB_PASSWORD, host=settings.DB_HOST, port=settings.DB_PORT
    )
    return conn
def wait_for_db():
    retries = 10
    while retries > 0:
        try:
            conn = get_db_connection()
            conn.close()
            print("Conexão com o banco de dados bem-sucedida!")
            return
        except psycopg2.OperationalError:
            print(f"Banco de dados indisponível. Tentando novamente em 5 segundos...")
            retries -= 1
            time.sleep(5)
    print("ERRO: Não foi possível conectar ao banco de dados.")
DB_EOF
echo "--- Estrutura base da API unificada."
