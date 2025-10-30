import os
import shutil
import logging
import subprocess
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

RECORDINGS_BASE = os.getenv("RECORDINGS_PATH", "/recordings")
SEGMENT_SECONDS = 120


def detect_video_codec(file_path: Path) -> Optional[str]:
    """
    Detecta o codec de vídeo de um arquivo MP4.

    Returns:
        "h264", "hevc" (H.265), ou None se erro
    """
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=codec_name",
                "-of", "default=noprint_wrappers=1:nokey=1",
                str(file_path)
            ],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            codec = result.stdout.strip().lower()
            return codec if codec in ["h264", "hevc"] else None

        return None
    except Exception as e:
        logger.warning(f"Error detecting codec for {file_path}: {e}")
        return None

def _parse_start_from_filename(filename: str):
    """
    Extrai o timestamp de início do nome do arquivo.
    Formato esperado: 2025-10-27_19-41-28.mp4
    Retorna timestamp em milissegundos ou None se inválido.
    """
    stem = Path(filename).stem
    try:
        dt = datetime.strptime(stem, "%Y-%m-%d_%H-%M-%S")
        dt = dt.replace(tzinfo=timezone.utc)
        return int(dt.timestamp() * 1000)
    except Exception:
        return None

def cleanup_camera_recordings(client_id: str, camera_name: str):
    """
    Remove todas as gravações de uma câmera específica.
    Remove ambas as pastas _h264 e _h265 se existirem.
    """
    base_path = Path(RECORDINGS_BASE) / "live" / client_id

    # Remove todas as possíveis pastas
    paths_to_remove = [
        base_path / f"{camera_name}_h265",
        base_path / f"{camera_name}_h264",
        base_path / camera_name  # Pasta antiga
    ]

    for camera_path in paths_to_remove:
        if camera_path.exists() and camera_path.is_dir():
            try:
                shutil.rmtree(camera_path)
                print(f"[STORAGE] Removidas gravações da câmera: {camera_path}")
            except Exception as e:
                print(f"[STORAGE] Erro ao remover {camera_path}: {e}")

def cleanup_client_recordings(client_id: str):
    """Remove todas as gravações de um cliente (inclui todas as câmeras)."""
    client_path = Path(RECORDINGS_BASE) / "live" / client_id
    if client_path.exists() and client_path.is_dir():
        try:
            shutil.rmtree(client_path)
            print(f"[STORAGE] Removidas gravações do cliente: {client_path}")
        except Exception as e:
            print(f"[STORAGE] Erro ao remover {client_path}: {e}")

def list_camera_recordings(client_id: str, camera_name: str) -> Dict:
    """
    Lista todas as gravações de uma câmera com timestamps precisos.
    Usa o nome do arquivo (formato: 2025-10-27_19-41-28.mp4) como fonte de verdade.

    Busca em ordem de prioridade:
    1. camera_name_h265 (transcodificado)
    2. camera_name_h264 (nativo)
    3. camera_name (pasta antiga)
    """
    base_path = Path(RECORDINGS_BASE) / "live" / client_id

    # Tenta encontrar pasta de gravação
    possible_paths = [
        base_path / f"{camera_name}_h265",  # Prioridade 1: H.265
        base_path / f"{camera_name}_h264",  # Prioridade 2: H.264
        base_path / camera_name              # Prioridade 3: Antiga
    ]

    camera_path = None
    for path in possible_paths:
        if path.exists() and path.is_dir():
            camera_path = path
            break

    if not camera_path:
        return {
            "recordings": [],
            "total_size": 0,
            "total_duration_seconds": 0,
            "start_date": None,
            "end_date": None,
            "count": 0
        }

    # Lista arquivos MP4
    mp4_files = sorted(camera_path.glob("*.mp4"))

    recordings = []
    total_size = 0

    # Extrai o nome real da pasta (com sufixo _h264/_h265)
    camera_folder_name = camera_path.name

    # 1ª passagem: coleta informações básicas + parse do timestamp do nome
    for mp4_file in mp4_files:
        try:
            stat_info = mp4_file.stat()
            file_size = stat_info.st_size
            total_size += file_size

            start_ts = _parse_start_from_filename(mp4_file.name)

            if start_ts is None:
                continue  # Pula arquivos que não conseguiu fazer parse

            recordings.append({
                "filename": mp4_file.name,
                "size": file_size,
                "start_ts": start_ts,
                "duration_seconds": SEGMENT_SECONDS,
                "created_at": datetime.utcfromtimestamp(stat_info.st_ctime).isoformat() + "Z",
                "modified_at": datetime.utcfromtimestamp(stat_info.st_mtime).isoformat() + "Z",
                "path": f"/live/{client_id}/{camera_folder_name}/{mp4_file.name}"
            })
        except Exception as e:
            logger.warning(f"Error processing file {mp4_file}: {e}")
            continue

    # Ordena por start_ts
    recordings.sort(key=lambda r: r["start_ts"])

    # 2ª passagem: calcula end_ts preciso
    for i, rec in enumerate(recordings):
        # Se há próximo arquivo, usa seu início como nosso fim
        if i + 1 < len(recordings):
            rec["end_ts"] = recordings[i + 1]["start_ts"]
            rec["duration_seconds"] = (rec["end_ts"] - rec["start_ts"]) / 1000
            rec["is_recording"] = False  # Arquivo completo
        else:
            # Último arquivo: usa timestamp de modificação ou estima
            file_path = camera_path / rec["filename"]
            try:
                file_mtime_ms = int(file_path.stat().st_mtime * 1000)
                now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
                is_being_written = (now_ms - file_mtime_ms) < 130000

                # ✅ RETORNA INFORMAÇÃO PARA O FRONTEND
                rec["is_recording"] = is_being_written

                if is_being_written:
                    rec["end_ts"] = now_ms
                else:
                    rec["end_ts"] = file_mtime_ms

                # Garante duração entre 1s e 120s
                duration_ms = rec["end_ts"] - rec["start_ts"]
                duration_ms = max(1000, min(duration_ms, SEGMENT_SECONDS * 1000))
                rec["end_ts"] = rec["start_ts"] + duration_ms
                rec["duration_seconds"] = duration_ms / 1000
            except:
                # Fallback: assume 120s
                rec["end_ts"] = rec["start_ts"] + (SEGMENT_SECONDS * 1000)
                rec["duration_seconds"] = SEGMENT_SECONDS
                rec["is_recording"] = False

    # Calcula duração total
    total_duration = sum(r["duration_seconds"] for r in recordings)

    # Datas de início/fim
    if recordings:
        start_date = datetime.utcfromtimestamp(recordings[0]["start_ts"] / 1000).isoformat() + "Z"
        end_date = datetime.utcfromtimestamp(recordings[-1]["end_ts"] / 1000).isoformat() + "Z"
    else:
        start_date = None
        end_date = None

    return {
        "recordings": recordings,
        "total_size": total_size,
        "total_duration_seconds": int(total_duration),
        "start_date": start_date,
        "end_date": end_date,
        "count": len(recordings)
    }

def get_recording_path(client_id: str, camera_name: str, filename: str) -> Path | None:
    """
    Retorna o caminho completo de um arquivo de gravação se existir.

    Busca em ordem de prioridade:
    1. camera_name_h265
    2. camera_name_h264
    3. camera_name (pasta antiga)
    """
    base_path = Path(RECORDINGS_BASE) / "live" / client_id

    possible_paths = [
        base_path / f"{camera_name}_h265" / filename,
        base_path / f"{camera_name}_h264" / filename,
        base_path / camera_name / filename
    ]

    for recording_path in possible_paths:
        if recording_path.exists() and recording_path.is_file() and recording_path.suffix == ".mp4":
            return recording_path

    return None
