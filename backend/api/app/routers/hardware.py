"""
Router de Hardware (Atualizado com Monitor GPU)
Endpoints para informações sobre hardware, GPU e transcodificação
"""

from fastapi import APIRouter
from typing import Dict, List, Optional
import subprocess
import psutil
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/hardware", tags=["hardware"])

def get_nvidia_gpu_info() -> Optional[Dict]:
    """Obtém informações da GPU NVIDIA"""
    try:
        result = subprocess.run([
            'nvidia-smi',
            '--query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,power.limit',
            '--format=csv,noheader,nounits'
        ], capture_output=True, text=True, timeout=5)

        if result.returncode != 0:
            return None

        lines = result.stdout.strip().split('\n')
        gpus = []

        for line in lines:
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 9:
                def safe_float(value):
                    """Converte para float, retorna 0 se N/A ou contém colchetes"""
                    if not value or value in ['N/A', ''] or '[' in value or ']' in value:
                        return 0
                    try:
                        return float(value)
                    except:
                        return 0

                gpus.append({
                    'index': int(parts[0]),
                    'name': parts[1],
                    'temperature': safe_float(parts[2]),
                    'utilization_gpu': safe_float(parts[3]),
                    'utilization_memory': safe_float(parts[4]),
                    'memory_used_mb': safe_float(parts[5]),
                    'memory_total_mb': safe_float(parts[6]),
                    'power_draw_w': safe_float(parts[7]),
                    'power_limit_w': safe_float(parts[8]),
                })

        return {'gpus': gpus, 'available': True} if gpus else None

    except Exception as e:
        print(f"[HARDWARE] Erro ao obter info da GPU: {e}")
        return None


def get_nvidia_processes() -> List[Dict]:
    """Obtém processos rodando na GPU NVIDIA"""
    try:
        result = subprocess.run([
            'nvidia-smi',
            '--query-compute-apps=pid,process_name,used_memory',
            '--format=csv,noheader,nounits'
        ], capture_output=True, text=True, timeout=5)

        if result.returncode != 0:
            return []

        lines = result.stdout.strip().split('\n')
        processes = []

        for line in lines:
            if not line.strip():
                continue

            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 3:
                try:
                    pid = int(parts[0])
                    # Tentar obter cmdline via /host/proc (PIDs do host)
                    cmdline = parts[1]
                    try:
                        with open(f"/host/proc/{pid}/cmdline", "r") as f:
                            cmdline_raw = f.read()
                            # /proc/<pid>/cmdline usa null bytes como separadores
                            cmdline = cmdline_raw.replace('\x00', ' ').strip()
                    except:
                        # Fallback para /proc local (caso seja PID do container)
                        try:
                            with open(f"/proc/{pid}/cmdline", "r") as f:
                                cmdline_raw = f.read()
                                cmdline = cmdline_raw.replace('\x00', ' ').strip()
                        except:
                            pass

                    processes.append({
                        'pid': pid,
                        'name': parts[1],
                        'cmdline': cmdline,
                        'gpu_memory_mb': float(parts[2]) if parts[2] not in ['N/A', ''] else 0
                    })
                except ValueError:
                    continue

        return processes

    except Exception as e:
        print(f"[HARDWARE] Erro ao obter processos da GPU: {e}")
        return []


def get_system_info() -> Dict:
    """Obtém informações do sistema"""
    try:
        cpu_count = psutil.cpu_count(logical=False)
        cpu_count_logical = psutil.cpu_count(logical=True)
        cpu_percent = psutil.cpu_percent(interval=1, percpu=False)

        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        # Processos FFmpeg
        ffmpeg_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'cpu_percent', 'memory_info']):
            try:
                if 'ffmpeg' in proc.info['name'].lower():
                    cmdline = ' '.join(proc.info['cmdline']) if proc.info['cmdline'] else ''
                    ffmpeg_processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cmdline': cmdline[:200],  # Limitar tamanho
                        'cpu_percent': proc.info['cpu_percent'] or 0,
                        'memory_mb': (proc.info['memory_info'].rss / 1024 / 1024) if proc.info['memory_info'] else 0
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

        return {
            'cpu': {
                'cores': cpu_count,
                'threads': cpu_count_logical,
                'percent': cpu_percent
            },
            'memory': {
                'total_gb': round(memory.total / (1024**3), 2),
                'used_gb': round(memory.used / (1024**3), 2),
                'available_gb': round(memory.available / (1024**3), 2),
                'percent': memory.percent
            },
            'disk': {
                'total_gb': round(disk.total / (1024**3), 2),
                'used_gb': round(disk.used / (1024**3), 2),
                'free_gb': round(disk.free / (1024**3), 2),
                'percent': disk.percent
            },
            'ffmpeg_processes': ffmpeg_processes,
            'ffmpeg_count': len(ffmpeg_processes)
        }

    except Exception as e:
        print(f"[HARDWARE] Erro ao obter info do sistema: {e}")
        return {
            'cpu': {'cores': 0, 'threads': 0, 'percent': 0},
            'memory': {'total_gb': 0, 'used_gb': 0, 'available_gb': 0, 'percent': 0},
            'disk': {'total_gb': 0, 'used_gb': 0, 'free_gb': 0, 'percent': 0},
            'ffmpeg_processes': [],
            'ffmpeg_count': 0
        }


@router.get("")
def get_hardware_status():
    """
    Retorna status completo do hardware:
    - GPU NVIDIA (se disponível)
    - CPU, memória, disco
    - Processos FFmpeg ativos
    """
    gpu_info = get_nvidia_gpu_info()
    gpu_processes = get_nvidia_processes() if gpu_info else []
    system_info = get_system_info()

    return {
        'gpu': gpu_info,
        'gpu_processes': gpu_processes,
        'system': system_info
    }


@router.get("/gpu")
def get_gpu_only():
    """Retorna apenas informações da GPU"""
    gpu_info = get_nvidia_gpu_info()
    gpu_processes = get_nvidia_processes() if gpu_info else []

    if not gpu_info:
        return {
            'available': False,
            'message': 'GPU NVIDIA não disponível ou nvidia-smi não encontrado'
        }

    return {
        'available': True,
        'gpus': gpu_info['gpus'],
        'processes': gpu_processes,
        'process_count': len(gpu_processes)
    }


@router.get("/system")
def get_system_only():
    """Retorna apenas informações do sistema"""
    return get_system_info()


@router.get("/gpu-per-camera")
async def get_gpu_per_camera():
    """
    Retorna uso de GPU por câmera
    Associa processos FFmpeg na GPU com câmeras específicas
    """
    try:
        from app.services.recording import get_recording_manager

        # Pegar processos GPU
        gpu_processes = get_nvidia_processes()
        if not gpu_processes:
            return {"cameras": [], "total_gpu_memory_mb": 0}

        # Pegar jobs de gravação ativos
        manager = get_recording_manager()
        jobs = manager.worker.jobs

        # Mapear camera_name -> camera_info
        camera_map = {}
        for camera_id, job in jobs.items():
            if job.status == "running":
                camera_map[job.camera_name] = {
                    "camera_id": camera_id,
                    "camera_name": job.camera_name,
                    "client_slug": job.client_slug
                }

        # Associar processos GPU com câmeras usando cmdline
        camera_gpu_usage = {}
        total_gpu_memory = 0

        for proc in gpu_processes:
            pid = proc['pid']
            gpu_memory_mb = proc['gpu_memory_mb']
            cmdline = proc['cmdline']
            total_gpu_memory += gpu_memory_mb

            # Tentar encontrar câmera pelo cmdline
            # O cmdline contém o path de saída que inclui o nome da câmera
            matched_camera = None
            for camera_name, camera_info in camera_map.items():
                # Procurar pelo nome da câmera no cmdline
                # Ex: /recordings/live/cliente/cam1_h265/
                if f"/{camera_name}_" in cmdline or f"/{camera_name}/" in cmdline:
                    matched_camera = camera_info
                    break

            if matched_camera:
                camera_name = matched_camera['camera_name']

                if camera_name not in camera_gpu_usage:
                    camera_gpu_usage[camera_name] = {
                        "camera_id": matched_camera['camera_id'],
                        "camera_name": camera_name,
                        "client_slug": matched_camera['client_slug'],
                        "gpu_memory_mb": 0,
                        "process_count": 0
                    }

                camera_gpu_usage[camera_name]["gpu_memory_mb"] += gpu_memory_mb
                camera_gpu_usage[camera_name]["process_count"] += 1

        # Converter para lista e ordenar por nome
        cameras = sorted(camera_gpu_usage.values(), key=lambda x: x['camera_name'])

        return {
            "cameras": cameras,
            "total_gpu_memory_mb": total_gpu_memory,
            "camera_count": len(cameras)
        }

    except Exception as e:
        logger.error(f"[HARDWARE] Erro ao obter GPU por câmera: {e}")
        return {"cameras": [], "total_gpu_memory_mb": 0, "error": str(e)}
