"""
Serviço para sincronizar câmeras RTSP do banco de dados com MediaMTX.
Atualiza dinamicamente a configuração do MediaMTX quando câmeras RTSP são cadastradas.
Usa a API dinâmica do MediaMTX para adicionar/editar/remover câmeras SEM reiniciar.
"""
import subprocess
import re
import httpx
from pathlib import Path
from app.database import SessionLocal
from app.crud.crud_camera import list_cameras, get_camera
from app.crud.crud_client import get_client

MEDIAMTX_CONFIG_PATH = Path("/app/config/mediamtx/mediamtx.yml")
MEDIAMTX_API_URL = "http://mediamtx:9997/v3/config"

def sanitize_name(name: str) -> str:
    """Remove caracteres especiais de nomes para uso em paths"""
    return re.sub(r'[^a-zA-Z0-9_-]', '_', name)

def generate_mediamtx_config():
    """
    Gera a configuração completa do MediaMTX com TODAS as câmeras do banco (RTSP + RTMP).
    """
    db = SessionLocal()
    try:
        cameras = list_cameras(db)
        all_cameras = []

        for cam in cameras:
            client = get_client(db, cam.cliente_id)
            if client:
                all_cameras.append({
                    'cliente_slug': client.slug,
                    'nome': sanitize_name(cam.nome),
                    'endpoint': cam.endpoint,
                    'protocolo': cam.protocolo.upper(),
                    'transcode_to_h265': cam.transcode_to_h265
                })

        # Configuração base do MediaMTX
        config_content = """# MediaMTX configuration file
# Arquivo gerado automaticamente

# Server settings
logLevel: info
logDestinations: [stdout]
logFile: /logs/mediamtx.log

# API settings
api: yes
apiAddress: :9997

# Auth settings (allow API access and streaming from any container/client)
authInternalUsers:
  - user: any
    pass:
    ips: []
    permissions:
      - action: api
      - action: metrics
      - action: pprof
      - action: publish
        path:
      - action: read
        path:

# Metrics
metrics: yes
metricsAddress: :9998

# HLS settings
hls: yes
hlsAddress: :8888
hlsAlwaysRemux: no
hlsVariant: mpegts
hlsSegmentCount: 10
hlsSegmentDuration: 1s
hlsPartDuration: 200ms
hlsSegmentMaxSize: 50M

# RTSP settings
rtspAddress: :8554

# Global path defaults
pathDefaults:
  source: publisher
  sourceOnDemand: no
  # NOTE: 'record' removido do pathDefaults para evitar conflito
  # Cada path individual define seu próprio 'record: yes/no'
  recordPath: /recordings/%path/%Y-%m-%d_%H-%M-%S
  recordFormat: fmp4
  recordPartDuration: 1s
  recordSegmentDuration: 120s
  recordDeleteAfter: 48h

# Paths
paths:
  # Health check path
  health:
    source: publisher
    sourceOnDemand: no
    record: no

"""

        # Adiciona todas as câmeras (RTSP e RTMP)
        if all_cameras:
            config_content += "\n  # Câmeras (sincronizadas automaticamente)\n"
            config_content += "  # MediaMTX NUNCA grava (record: no) - FFmpeg grava tudo\n"
            for cam in all_cameras:
                if cam['protocolo'] == 'RTSP':
                    # RTSP: MediaMTX puxa o stream da câmera
                    config_content += f"""  live/{cam['cliente_slug']}/{cam['nome']}:
    source: {cam['endpoint']}
    sourceOnDemand: yes
    record: no

"""
                elif cam['protocolo'] == 'RTMP':
                    # RTMP: MediaMTX aguarda publisher enviar stream
                    config_content += f"""  live/{cam['cliente_slug']}/{cam['nome']}:
    source: publisher
    record: no

"""
                else:
                    # HLS ou outros: usa publisher
                    config_content += f"""  live/{cam['cliente_slug']}/{cam['nome']}:
    source: publisher
    record: no

"""

        # Escreve o arquivo de configuração
        MEDIAMTX_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        MEDIAMTX_CONFIG_PATH.write_text(config_content)

        return len(all_cameras)

    except Exception as e:
        print(f"[MEDIAMTX_SYNC] ❌ Erro ao gerar configuração: {e}")
        raise
    finally:
        db.close()

def add_camera_to_mediamtx(cliente_slug: str, camera_name: str, endpoint: str, protocolo: str) -> bool:
    """
    Adiciona uma câmera ao MediaMTX via API dinâmica (SEM reiniciar).
    Retorna True se sucesso, False caso contrário.
    """
    try:
        path_name = f"live/{cliente_slug}/{sanitize_name(camera_name)}"

        # Configuração baseada no protocolo
        if protocolo.upper() == "RTSP":
            path_config = {
                "source": endpoint,
                "sourceOnDemand": True,
                "record": True
            }
        else:  # RTMP, HLS, etc
            path_config = {
                "source": "publisher",
                "record": True
            }

        # Adiciona via API
        with httpx.Client() as client:
            response = client.post(
                f"{MEDIAMTX_API_URL}/paths/add/{path_name}",
                json=path_config,
                timeout=10.0
            )

        if response.status_code in [200, 201]:
            print(f"[MEDIAMTX_API] ✅ Câmera adicionada: {path_name}")
            return True
        else:
            print(f"[MEDIAMTX_API] ⚠️  Erro ao adicionar {path_name}: {response.status_code} - {response.text}")
            return False

    except Exception as e:
        print(f"[MEDIAMTX_API] ❌ Erro ao adicionar câmera: {e}")
        return False

def update_camera_in_mediamtx(cliente_slug: str, camera_name: str, endpoint: str, protocolo: str) -> bool:
    """
    Atualiza uma câmera no MediaMTX via API dinâmica (SEM reiniciar).
    Retorna True se sucesso, False caso contrário.
    """
    try:
        path_name = f"live/{cliente_slug}/{sanitize_name(camera_name)}"

        # Configuração baseada no protocolo
        if protocolo.upper() == "RTSP":
            path_config = {
                "source": endpoint,
                "sourceOnDemand": True,
                "record": True
            }
        else:  # RTMP, HLS, etc
            path_config = {
                "source": "publisher",
                "record": True
            }

        # Atualiza via API
        with httpx.Client() as client:
            response = client.patch(
                f"{MEDIAMTX_API_URL}/paths/patch/{path_name}",
                json=path_config,
                timeout=10.0
            )

        if response.status_code == 200:
            print(f"[MEDIAMTX_API] ✅ Câmera atualizada: {path_name}")
            return True
        else:
            print(f"[MEDIAMTX_API] ⚠️  Erro ao atualizar {path_name}: {response.status_code} - {response.text}")
            return False

    except Exception as e:
        print(f"[MEDIAMTX_API] ❌ Erro ao atualizar câmera: {e}")
        return False

def remove_camera_from_mediamtx(cliente_slug: str, camera_name: str) -> bool:
    """
    Remove uma câmera do MediaMTX via API dinâmica (SEM reiniciar).
    Retorna True se sucesso, False caso contrário.
    404 é aceito pois path pode não existir (sourceOnDemand não criado ainda).
    """
    try:
        path_name = f"live/{cliente_slug}/{sanitize_name(camera_name)}"

        # Remove via API
        with httpx.Client() as client:
            response = client.post(
                f"{MEDIAMTX_API_URL}/paths/delete/{path_name}",
                timeout=10.0
            )

        if response.status_code == 200:
            print(f"[MEDIAMTX_API] ✅ Câmera removida: {path_name}")
            return True
        elif response.status_code == 404:
            print(f"[MEDIAMTX_API] ℹ️  Path {path_name} não existe (sourceOnDemand não iniciado)")
            return True
        else:
            print(f"[MEDIAMTX_API] ⚠️  Erro ao remover {path_name}: {response.status_code} - {response.text}")
            return False

    except Exception as e:
        print(f"[MEDIAMTX_API] ❌ Erro ao remover câmera: {e}")
        return False

def restart_mediamtx():
    """
    Reinicia o container MediaMTX para aplicar as novas configurações.
    Usa script externo pois o container não tem acesso direto ao Docker.
    """
    try:
        # Chama script do host através do volume compartilhado
        result = subprocess.run(
            ["/bin/bash", "/app/scripts/restart-mediamtx.sh"],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            print("[MEDIAMTX_SYNC] ✅ MediaMTX reiniciado com sucesso")
            return True
        else:
            print(f"[MEDIAMTX_SYNC] ⚠️  Aviso ao reiniciar: {result.stderr}")
            # Tenta alternativa: docker via socket diretamente
            try:
                import docker
                client = docker.from_env()
                container = client.containers.get('mediamtx')
                container.restart()
                print("[MEDIAMTX_SYNC] ✅ MediaMTX reiniciado via Docker API")
                return True
            except:
                print("[MEDIAMTX_SYNC] ⚠️  Use: docker restart mediamtx")
                return False

    except Exception as e:
        print(f"[MEDIAMTX_SYNC] ⚠️  Erro ao reiniciar: {e}")
        return False

def sync_rtsp_cameras():
    """
    Sincroniza TODAS as câmeras (RTSP + RTMP) do banco com MediaMTX.
    Regenera a configuração e reinicia o serviço.
    """
    try:
        print("[MEDIAMTX_SYNC] Iniciando sincronização...")

        # Gera nova configuração
        camera_count = generate_mediamtx_config()
        print(f"[MEDIAMTX_SYNC] Configuração gerada com {camera_count} câmeras")

        # Reinicia MediaMTX
        restart_mediamtx()

        print(f"[MEDIAMTX_SYNC] ✅ Sincronização concluída ({camera_count} câmeras)")

    except Exception as e:
        print(f"[MEDIAMTX_SYNC] ❌ Erro na sincronização: {e}")
        raise

if __name__ == "__main__":
    sync_rtsp_cameras()
