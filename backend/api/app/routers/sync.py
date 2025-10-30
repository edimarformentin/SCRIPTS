from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.services.mediamtx_sync import sync_rtsp_cameras
import subprocess

router = APIRouter(prefix="/api/sync", tags=["sync"])

@router.post("/mediamtx")
def sync_mediamtx_config(db: Session = Depends(get_db)):
    """
    Sincroniza câmeras RTSP do banco com a configuração do MediaMTX.
    Atualiza /mediamtx.yml e reinicia o MediaMTX se necessário.
    """
    try:
        sync_rtsp_cameras()
        
        # Envia sinal HUP para MediaMTX recarregar config (sem derrubar conexões)
        try:
            subprocess.run(["pkill", "-HUP", "mediamtx"], check=False, timeout=2)
        except Exception as e:
            print(f"[SYNC] Aviso: não foi possível enviar HUP ao MediaMTX: {e}")
        
        return {
            "status": "success",
            "message": "Configuração do MediaMTX sincronizada com sucesso"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
