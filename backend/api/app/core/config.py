from pydantic import BaseModel
import os

class Settings(BaseModel):
    app_name: str = "VaaS API"
    env: str = os.getenv("ENV", "dev")
    database_url: str = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres-db:5432/vaas_db")
    cors_origins: str = os.getenv("CORS_ORIGINS", "*")

settings = Settings()
