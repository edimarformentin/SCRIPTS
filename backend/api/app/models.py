import uuid
from sqlalchemy import Column, String, Boolean, Integer, CheckConstraint, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship, Mapped, mapped_column
from app.database import Base

class Client(Base):
    __tablename__ = "clientes"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    slug: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
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
    transcode_to_h265: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    created_at: Mapped[str] = mapped_column(server_default=text("NOW()"))
    updated_at: Mapped[str] = mapped_column(server_default=text("NOW()"))

    __table_args__ = (
        CheckConstraint("protocolo in ('RTSP','RTMP','HLS')", name="chk_protocolo"),
    )

    cliente: Mapped["Client"] = relationship("Client", back_populates="cameras")
