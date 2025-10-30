"""
Recording Worker
Worker robusto para gravação de vídeo
Preparado para integração futura com RabbitMQ + IA
"""

import asyncio
import logging
import os
import signal
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict
from dataclasses import dataclass
import psutil

logger = logging.getLogger(__name__)


@dataclass
class RecordingJob:
    """Job de gravação"""
    camera_id: str
    client_slug: str
    camera_name: str
    source_url: str
    transcode_h265: bool
    process: Optional[subprocess.Popen] = None
    pid: Optional[int] = None
    started_at: Optional[datetime] = None
    status: str = "stopped"  # stopped, running, error
    error_count: int = 0
    last_error: Optional[str] = None
    output_path: Optional[str] = None


class RecordingWorker:
    """
    Worker de gravação robusto

    Responsabilidades:
    - Gravar vídeos (nativo ou H.265)
    - Segmentar em arquivos de 2 minutos
    - Monitorar e reiniciar processos travados
    - (Futuro) Processar via RabbitMQ + IA
    """

    def __init__(self, recordings_path: str = "/recordings"):
        self.recordings_path = Path(recordings_path)
        self.jobs: Dict[str, RecordingJob] = {}
        self._monitoring_task: Optional[asyncio.Task] = None
        self._hardware_info = self._detect_hardware()
        logger.info(f"RecordingWorker initialized - Hardware: {self._hardware_info}")

    def _detect_hardware(self) -> Dict[str, any]:
        """Detecta hardware disponível"""
        hw_info = {
            "nvidia_available": False,
            "vaapi_available": False,
            "encoder_h265": "libx265",
            "preset": "medium"
        }

        # Verifica NVIDIA
        try:
            result = subprocess.run(
                ["nvidia-smi", "-L"],
                capture_output=True,
                timeout=5
            )
            if result.returncode == 0:
                hw_info["nvidia_available"] = True
                hw_info["encoder_h265"] = "hevc_nvenc"
                hw_info["preset"] = "p4"
                logger.info("✅ NVIDIA GPU detected")
        except:
            pass

        # Verifica VAAPI (Intel QuickSync)
        if not hw_info["nvidia_available"] and Path("/dev/dri/renderD128").exists():
            hw_info["vaapi_available"] = True
            hw_info["encoder_h265"] = "hevc_vaapi"
            hw_info["preset"] = "medium"
            logger.info("✅ Intel QuickSync detected")

        if hw_info["encoder_h265"] == "libx265":
            logger.info("⚠️  Using software encoding (libx265)")

        return hw_info

    def _build_ffmpeg_command(
        self,
        source_url: str,
        output_path: str,
        transcode_h265: bool,
        mediamtx_publish_path: str = None
    ) -> List[str]:
        """
        Constrói comando FFmpeg

        Args:
            source_url: URL da fonte (RTSP/RTMP)
            output_path: Pasta de saída
            transcode_h265: Se True, transcodifica para H.265
            mediamtx_publish_path: Se fornecido, republica no MediaMTX (para RTSP externo)

        Returns:
            Lista com comando FFmpeg
        """
        # Padrão de nome: YYYY-MM-DD_HH-MM-SS.mp4
        timestamp_pattern = os.path.join(output_path, "%Y-%m-%d_%H-%M-%S.mp4")

        cmd = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y"]

        # Detecta se source é RTSP externo (tem @ no URL = credenciais)
        is_external_rtsp = source_url.startswith("rtsp://") and "@" in source_url

        # ==========================================
        # MODO H.265: Transcodifica
        # ==========================================
        if transcode_h265:
            encoder = self._hardware_info["encoder_h265"]
            preset = self._hardware_info["preset"]

            # Hardware acceleration
            if encoder == "hevc_nvenc":
                cmd.extend(["-hwaccel", "cuda", "-hwaccel_device", "0"])
            elif encoder == "hevc_vaapi":
                cmd.extend(["-vaapi_device", "/dev/dri/renderD128", "-hwaccel", "vaapi"])

            # Input + encoding
            cmd.extend([
                "-rtsp_transport", "tcp",
                "-i", source_url,
                "-c:v", encoder,
                "-preset", preset,
                "-b:v", "2M",
                "-maxrate", "2M",
                "-bufsize", "4M",
                "-c:a", "aac",
                "-b:a", "128k",
                "-f", "segment",
                "-segment_time", "120",  # 2 minutos
                "-segment_format", "mp4",
                "-segment_format_options", "movflags=+faststart+frag_keyframe+empty_moov",
                "-reset_timestamps", "1",
                "-strftime", "1",
                timestamp_pattern
            ])

        # ==========================================
        # MODO NATIVO: Stream copy (sem transcodificação)
        # ==========================================
        else:
            cmd.extend([
                "-rtsp_transport", "tcp",
                "-i", source_url,
            ])

            # Para RTSP externo: dual output (gravação + re-stream para preview)
            if is_external_rtsp and mediamtx_publish_path:
                # Output 1: Re-stream para MediaMTX (preview ao vivo)
                cmd.extend([
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-f", "rtsp",
                    "-rtsp_transport", "tcp",
                    f"rtsp://mediamtx:8554/{mediamtx_publish_path}",
                    # Output 2: Gravação em segmentos MP4
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-f", "segment",
                    "-segment_time", "120",
                    "-segment_format", "mp4",
                    "-reset_timestamps", "1",
                    "-strftime", "1",
                    "-movflags", "+faststart+frag_keyframe+empty_moov",
                    timestamp_pattern
                ])
            else:
                # Apenas gravação (RTMP/HLS)
                cmd.extend([
                    "-c:v", "copy",
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-f", "segment",
                    "-segment_time", "120",
                    "-segment_format", "mp4",
                    "-reset_timestamps", "1",
                    "-strftime", "1",
                    "-movflags", "+faststart+frag_keyframe+empty_moov",
                    timestamp_pattern
                ])

        return cmd

    async def start_recording(
        self,
        camera_id: str,
        client_slug: str,
        camera_name: str,
        source_url: str,
        transcode_h265: bool = False
    ) -> bool:
        """
        Inicia gravação para uma câmera

        Args:
            camera_id: ID da câmera
            client_slug: Slug do cliente
            camera_name: Nome da câmera
            source_url: URL RTSP/RTMP
            transcode_h265: Se True, transcodifica para H.265

        Returns:
            True se iniciado com sucesso
        """
        # Verifica se já está gravando
        if camera_id in self.jobs:
            job = self.jobs[camera_id]
            if job.status == "running":
                logger.warning(f"[{camera_id}] Recording already running")
                return True

        # Cria diretório de saída
        codec_suffix = "_h265" if transcode_h265 else "_h264"
        output_dir = self.recordings_path / "live" / client_slug / f"{camera_name}{codec_suffix}"
        output_dir.mkdir(parents=True, exist_ok=True)

        # Determina path do MediaMTX (para re-streaming de RTSP externo)
        mediamtx_path = f"live/{client_slug}/{camera_name}" if source_url.startswith("rtsp://") and "@" in source_url else None

        # Gera comando FFmpeg
        cmd = self._build_ffmpeg_command(
            source_url=source_url,
            output_path=str(output_dir),
            transcode_h265=transcode_h265,
            mediamtx_publish_path=mediamtx_path
        )

        mode = "H.265" if transcode_h265 else "Native (copy)"
        logger.info(f"[{camera_id}] Starting recording - Mode: {mode}")
        logger.info(f"[{camera_id}] FFmpeg command: {' '.join(cmd)}")

        try:
            # Inicia processo FFmpeg
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid  # Novo grupo de processos
            )

            # Registra job
            job = RecordingJob(
                camera_id=camera_id,
                client_slug=client_slug,
                camera_name=camera_name,
                source_url=source_url,
                transcode_h265=transcode_h265,
                process=process,
                pid=process.pid,
                started_at=datetime.now(),
                status="running",
                output_path=str(output_dir)
            )

            self.jobs[camera_id] = job

            logger.info(f"[{camera_id}] ✅ Recording started (PID: {process.pid})")
            return True

        except Exception as e:
            logger.error(f"[{camera_id}] ❌ Failed to start recording: {e}")
            return False

    async def stop_recording(self, camera_id: str, timeout: int = 10) -> bool:
        """
        Para gravação de uma câmera

        Args:
            camera_id: ID da câmera
            timeout: Timeout para graceful shutdown

        Returns:
            True se parado com sucesso
        """
        if camera_id not in self.jobs:
            logger.warning(f"[{camera_id}] No recording job found")
            return False

        job = self.jobs[camera_id]

        if not job.process or job.status == "stopped":
            logger.info(f"[{camera_id}] Recording already stopped")
            del self.jobs[camera_id]
            return True

        try:
            pid = job.pid
            logger.info(f"[{camera_id}] Stopping recording (PID: {pid})")

            # SIGTERM (graceful)
            try:
                os.killpg(os.getpgid(pid), signal.SIGTERM)
            except ProcessLookupError:
                logger.info(f"[{camera_id}] Process already terminated")
                del self.jobs[camera_id]
                return True

            # Aguarda término
            try:
                job.process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                logger.warning(f"[{camera_id}] Process didn't terminate, sending SIGKILL")
                os.killpg(os.getpgid(pid), signal.SIGKILL)
                job.process.wait(timeout=5)

            del self.jobs[camera_id]
            logger.info(f"[{camera_id}] ✅ Recording stopped")
            return True

        except Exception as e:
            logger.error(f"[{camera_id}] ❌ Failed to stop recording: {e}")
            return False

    def get_job_status(self, camera_id: str) -> Optional[Dict]:
        """Retorna status de um job"""
        if camera_id not in self.jobs:
            return None

        job = self.jobs[camera_id]

        # Verifica se processo ainda está vivo
        if job.process and job.process.poll() is not None:
            job.status = "error" if job.process.returncode != 0 else "stopped"

        result = {
            "camera_id": camera_id,
            "client_slug": job.client_slug,
            "camera_name": job.camera_name,
            "status": job.status,
            "transcode_h265": job.transcode_h265,
            "pid": job.pid,
            "started_at": job.started_at.isoformat() if job.started_at else None,
            "output_path": job.output_path,
            "error_count": job.error_count,
            "last_error": job.last_error
        }

        # Adiciona CPU/RAM se rodando
        if job.status == "running" and job.pid:
            try:
                process = psutil.Process(job.pid)
                result["cpu_percent"] = process.cpu_percent(interval=0.1)
                result["memory_mb"] = round(process.memory_info().rss / 1024 / 1024, 1)
            except psutil.NoSuchProcess:
                job.status = "error"
                job.last_error = "Process not found"

        return result

    def get_all_statuses(self) -> List[Dict]:
        """Retorna status de todos os jobs"""
        return [
            self.get_job_status(camera_id)
            for camera_id in list(self.jobs.keys())
        ]

    async def monitor_jobs(self):
        """
        Monitora jobs e reinicia se necessário
        (Futuro: integração com RabbitMQ para fila de jobs)
        """
        logger.info("Job monitoring started")

        while True:
            try:
                await asyncio.sleep(30)  # Verifica a cada 30s

                for camera_id in list(self.jobs.keys()):
                    job = self.jobs[camera_id]

                    if not job.process:
                        continue

                    # Verifica se processo morreu
                    if job.process.poll() is not None:
                        returncode = job.process.returncode

                        if returncode != 0:
                            # Processo crashou
                            stderr_output = ""
                            try:
                                _, stderr = job.process.communicate(timeout=1)
                                stderr_output = stderr.decode('utf-8', errors='ignore')[:500]
                            except:
                                pass

                            logger.error(f"[{camera_id}] Recording crashed (code: {returncode})")
                            if stderr_output:
                                logger.error(f"[{camera_id}] FFmpeg stderr: {stderr_output}")

                            job.error_count += 1
                            job.last_error = f"Exit code: {returncode}"
                            job.status = "error"

                            # Reinicia se não crashou muitas vezes
                            if job.error_count < 3:
                                logger.info(f"[{camera_id}] Attempting restart (attempt {job.error_count})")
                                await self.stop_recording(camera_id)
                                await asyncio.sleep(2)
                                await self.start_recording(
                                    camera_id=job.camera_id,
                                    client_slug=job.client_slug,
                                    camera_name=job.camera_name,
                                    source_url=job.source_url,
                                    transcode_h265=job.transcode_h265
                                )
                            else:
                                logger.error(f"[{camera_id}] Too many errors, giving up")
                                del self.jobs[camera_id]
                        else:
                            # Processo terminou normalmente
                            logger.info(f"[{camera_id}] Recording ended normally")
                            del self.jobs[camera_id]

            except Exception as e:
                logger.error(f"Error in job monitor: {e}")

    def start_monitoring(self):
        """Inicia monitoramento"""
        if not self._monitoring_task:
            loop = asyncio.get_event_loop()
            self._monitoring_task = loop.create_task(self.monitor_jobs())

    async def stop_all(self):
        """Para todos os jobs"""
        logger.info("Stopping all recording jobs...")

        tasks = [
            self.stop_recording(camera_id)
            for camera_id in list(self.jobs.keys())
        ]

        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

        if self._monitoring_task:
            self._monitoring_task.cancel()
            try:
                await self._monitoring_task
            except asyncio.CancelledError:
                pass

        logger.info("All recording jobs stopped")


# Singleton
_recording_worker: Optional[RecordingWorker] = None


def get_recording_worker() -> RecordingWorker:
    """Retorna instância singleton"""
    global _recording_worker
    if _recording_worker is None:
        _recording_worker = RecordingWorker()
        _recording_worker.start_monitoring()
    return _recording_worker
