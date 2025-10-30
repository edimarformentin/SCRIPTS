from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from uuid import UUID

class ClientCreate(BaseModel):
    nome: str = Field(..., min_length=1, max_length=255)
    documento: str = Field(..., min_length=1, max_length=32)
    email: Optional[EmailStr] = None
    telefone: Optional[str] = None
    status: Optional[str] = "ativo"

class ClientUpdate(BaseModel):
    nome: Optional[str] = Field(None, min_length=1, max_length=255)
    email: Optional[EmailStr] = None
    telefone: Optional[str] = None
    status: Optional[str] = None

class ClientOut(BaseModel):
    model_config = {"from_attributes": True}

    id: UUID
    slug: str
    nome: str
    documento: str
    email: Optional[EmailStr]
    telefone: Optional[str]
    status: str
