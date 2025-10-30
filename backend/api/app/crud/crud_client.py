from sqlalchemy.orm import Session
from sqlalchemy import select
from uuid import UUID
import string
import random
import unicodedata
from app.models import Client
from app.schemas.client_schema import ClientCreate, ClientUpdate

def generate_slug(nome: str, db: Session) -> str:
    """
    Gera slug único: primeiro-nome + 7 caracteres aleatórios
    Exemplo: edimar-131fG12
    """
    # Pega primeira palavra do nome, remove acentos, lowercase
    first_name = nome.strip().split()[0] if nome.strip() else "user"
    first_name = unicodedata.normalize('NFKD', first_name).encode('ASCII', 'ignore').decode('utf-8')
    first_name = first_name.lower()

    # Gera 7 caracteres aleatórios (letras + números)
    chars = string.ascii_letters + string.digits

    # Tenta até achar um slug único
    for _ in range(100):
        random_suffix = ''.join(random.choices(chars, k=7))
        slug = f"{first_name}-{random_suffix}"

        # Verifica se já existe
        existing = db.execute(select(Client).where(Client.slug == slug)).scalar_one_or_none()
        if not existing:
            return slug

    # Fallback: adiciona timestamp
    import time
    return f"{first_name}-{int(time.time()) % 10000000}"

def list_clients(db: Session) -> list[Client]:
  return db.execute(select(Client).order_by(Client.created_at.desc())).scalars().all()

def get_client(db: Session, client_id: UUID) -> Client | None:
  return db.get(Client, client_id)

def get_client_by_documento(db: Session, documento: str) -> Client | None:
  return db.execute(select(Client).where(Client.documento==documento)).scalar_one_or_none()

def get_client_by_slug(db: Session, slug: str) -> Client | None:
  return db.execute(select(Client).where(Client.slug==slug)).scalar_one_or_none()

def create_client(db: Session, payload: ClientCreate) -> Client:
  data = payload.model_dump()
  # Gera slug automaticamente
  data['slug'] = generate_slug(payload.nome, db)
  cli = Client(**data)
  db.add(cli)
  db.commit()
  db.refresh(cli)
  return cli

def update_client(db: Session, client_id: UUID, payload: ClientUpdate) -> Client | None:
  cli = get_client(db, client_id)
  if not cli: return None
  for k, v in payload.model_dump(exclude_unset=True).items():
    setattr(cli, k, v)
  db.commit(); db.refresh(cli)
  return cli

def delete_client(db: Session, client_id: UUID) -> bool:
  cli = get_client(db, client_id)
  if not cli: return False
  db.delete(cli); db.commit()
  return True
