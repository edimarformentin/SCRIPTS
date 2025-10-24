#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 03-api-estrutura-base.sh  (FIX)
# -----------------------------------------------------------------------------
# - Gera base da API FastAPI.
# - Corrigido: garante dirs dentro de app/ (core, routers, schemas, crud).
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  # Garante toda a árvore correta sob app/
  ensure_dirs "$API_DIR/app" \
              "$API_DIR/app/core" \
              "$API_DIR/app/routers" \
              "$API_DIR/app/schemas" \
              "$API_DIR/app/crud"

  # requirements.txt
  cat > "$API_DIR/requirements.txt" <<'REQ'
fastapi==0.114.2
uvicorn[standard]==0.30.6
SQLAlchemy==2.0.34
psycopg2-binary==2.9.9
python-dotenv==1.0.1
pydantic==2.9.2
REQ

  # Dockerfile
  cat > "$API_DIR/Dockerfile" <<'DF'
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host","0.0.0.0","--port","8000","--workers","2"]
DF

  # Pacotes Python (__init__)
  : > "$API_DIR/app/__init__.py"
  : > "$API_DIR/app/core/__init__.py"
  : > "$API_DIR/app/routers/__init__.py"
  : > "$API_DIR/app/schemas/__init__.py"
  : > "$API_DIR/app/crud/__init__.py"

  # core/config.py
  cat > "$API_DIR/app/core/config.py" <<'PY'
from pydantic import BaseModel
import os

class Settings(BaseModel):
    app_name: str = "VaaS API"
    env: str = os.getenv("ENV", "dev")
    database_url: str = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres-db:5432/vaas_db")
    cors_origins: str = os.getenv("CORS_ORIGINS", "*")

settings = Settings()
PY

  # app/database.py
  cat > "$API_DIR/app/database.py" <<'PY'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

class Base(DeclarativeBase):
    pass

engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=1800, echo=False, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
PY

  # app/models.py
  cat > "$API_DIR/app/models.py" <<'PY'
import uuid
from sqlalchemy import Column, String, Boolean, Integer, CheckConstraint, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship, Mapped, mapped_column
from app.database import Base

class Client(Base):
    __tablename__ = "clientes"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    nome: Mapped[str] = mapped_column(String(255), nullable=False)
    documento: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), unique=True)
    telefone: Mapped[str | None] = mapped_column(String(32))
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default=text("'ativo'"))
    created_at: Mapped[str] = mapped_column(server_default=text("NOW()"))
    updated_at: Mapped[str] = mapped_column(server_default=text("NOW()"))
    cameras: Mapped[list["Camera"]] = relationship("Camera", back_populates="cliente", cascade="all, delete-orphan")

class Camera(Base):
    __tablename__ = "cameras"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    cliente_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("clientes.id", ondelete="CASCADE"), nullable=False)
    nome: Mapped[str] = mapped_column(String(255), nullable=False)
    protocolo: Mapped[str] = mapped_column(String(8), nullable=False)
    endpoint: Mapped[str] = mapped_column(String(1024), nullable=False)
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    stream_key: Mapped[str | None] = mapped_column(String(128))
    resolucao: Mapped[str | None] = mapped_column(String(32))
    fps: Mapped[int | None] = mapped_column(Integer)
    bitrate_kbps: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[str] = mapped_column(server_default=text("NOW()"))
    updated_at: Mapped[str] = mapped_column(server_default=text("NOW()"))

    __table_args__ = (
        CheckConstraint("protocolo in ('RTSP','RTMP','HLS')", name="chk_protocolo"),
    )

    cliente: Mapped["Client"] = relationship("Client", back_populates="cameras")
PY

  ok "API base (com estrutura app/*) gerada."
}
main "$@"
