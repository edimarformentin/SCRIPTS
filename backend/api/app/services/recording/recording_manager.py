"""
Recording Manager
Orquestrador de gravações
Preparado para integração futura com RabbitMQ + IA para detecção de objetos
"""

import logging
from typing import Dict, List, Optional
from .recording_worker import RecordingWorker, get_recording_worker

logger = logging.getLogger(__name__)


class RecordingManager:
    """
    Gerenciador de gravações

    Responsabilidades atuais:
    - Orquestrar workers de gravação
    - Gerenciar estado de todas as câmeras
    - Fornecer API unificada

    Preparado para futuro (RabbitMQ + IA):
    - Publicar eventos de gravação em fila RabbitMQ
    - Receber requisições de análise de IA
    - Processar detecção de objetos em vídeos
    """

    def __init__(self):
        self.worker = get_recording_worker()
        logger.info("RecordingManager initialized")

    async def start_camera_recording(
        self,
        camera_id: str,
        client_slug: str,
        camera_name: str,
        source_url: str,
        transcode_h265: bool = False
    ) -> bool:
        """
        Inicia gravação de uma câmera

        Args:
            camera_id: ID da câmera
            client_slug: Slug do cliente
            camera_name: Nome da câmera
            source_url: URL do stream (RTSP/RTMP)
            transcode_h265: Se True, transcodifica para H.265. Se False, grava nativo

        Returns:
            True se iniciado com sucesso

        Futuro (RabbitMQ):
            - Publicar evento: recording.started
            - Incluir metadata para IA processar
        """
        mode = "H.265 (transcode)" if transcode_h265 else "Native (copy)"
        logger.info(f"[MANAGER] Starting recording for {camera_name} - Mode: {mode}")

        success = await self.worker.start_recording(
            camera_id=camera_id,
            client_slug=client_slug,
            camera_name=camera_name,
            source_url=source_url,
            transcode_h265=transcode_h265
        )

        if success:
            logger.info(f"[MANAGER] ✅ Recording started for {camera_name}")
            # TODO (Futuro): Publicar em RabbitMQ
            # await self._publish_event("recording.started", {
            #     "camera_id": camera_id,
            #     "client_slug": client_slug,
            #     "camera_name": camera_name,
            #     "transcode_h265": transcode_h265,
            #     "timestamp": datetime.utcnow().isoformat()
            # })
        else:
            logger.error(f"[MANAGER] ❌ Failed to start recording for {camera_name}")

        return success

    async def stop_camera_recording(self, camera_id: str) -> bool:
        """
        Para gravação de uma câmera

        Args:
            camera_id: ID da câmera

        Returns:
            True se parado com sucesso

        Futuro (RabbitMQ):
            - Publicar evento: recording.stopped
        """
        logger.info(f"[MANAGER] Stopping recording for camera {camera_id}")

        success = await self.worker.stop_recording(camera_id)

        if success:
            logger.info(f"[MANAGER] ✅ Recording stopped for {camera_id}")
            # TODO (Futuro): Publicar em RabbitMQ
            # await self._publish_event("recording.stopped", {
            #     "camera_id": camera_id,
            #     "timestamp": datetime.utcnow().isoformat()
            # })
        else:
            logger.error(f"[MANAGER] ❌ Failed to stop recording for {camera_id}")

        return success

    async def restart_camera_recording(
        self,
        camera_id: str,
        client_slug: str,
        camera_name: str,
        source_url: str,
        transcode_h265: bool = False
    ) -> bool:
        """
        Reinicia gravação de uma câmera

        Útil quando:
        - Configuração de transcodificação muda
        - Recuperação de erros
        """
        logger.info(f"[MANAGER] Restarting recording for {camera_name}")

        # Para gravação atual
        await self.stop_camera_recording(camera_id)

        # Aguarda um pouco
        import asyncio
        await asyncio.sleep(2)

        # Inicia novamente
        return await self.start_camera_recording(
            camera_id=camera_id,
            client_slug=client_slug,
            camera_name=camera_name,
            source_url=source_url,
            transcode_h265=transcode_h265
        )

    def get_camera_status(self, camera_id: str) -> Optional[Dict]:
        """
        Retorna status de gravação de uma câmera

        Args:
            camera_id: ID da câmera

        Returns:
            Dicionário com status ou None
        """
        return self.worker.get_job_status(camera_id)

    def get_all_cameras_status(self) -> List[Dict]:
        """
        Retorna status de todas as câmeras gravando

        Returns:
            Lista de dicionários com status
        """
        return self.worker.get_all_statuses()

    async def stop_all_recordings(self):
        """
        Para todas as gravações

        Usado em:
        - Shutdown da aplicação
        - Manutenção do sistema
        """
        logger.info("[MANAGER] Stopping all recordings...")
        await self.worker.stop_all()
        logger.info("[MANAGER] All recordings stopped")

    # ==========================================
    # Futuro: Integração RabbitMQ + IA
    # ==========================================

    # async def _publish_event(self, event_type: str, data: Dict):
    #     """
    #     Publica evento em RabbitMQ
    #
    #     Eventos planejados:
    #     - recording.started: Nova gravação iniciada
    #     - recording.stopped: Gravação parada
    #     - recording.segment_completed: Segmento de 2min completado
    #     - ai.object_detected: IA detectou objeto em vídeo
    #     - ai.analysis_requested: Requisição de análise de IA
    #     """
    #     # TODO: Implementar publisher RabbitMQ
    #     pass

    # async def request_ai_analysis(self, camera_id: str, segment_path: str):
    #     """
    #     Requisita análise de IA para um segmento de vídeo
    #
    #     Args:
    #         camera_id: ID da câmera
    #         segment_path: Caminho do arquivo de vídeo
    #
    #     Fluxo planejado:
    #     1. Publicar mensagem em fila "ai.analysis.requests"
    #     2. Worker IA processa vídeo
    #     3. Worker IA publica resultados em "ai.analysis.results"
    #     4. API recebe e armazena resultados
    #     """
    #     # TODO: Implementar quando RabbitMQ for adicionado
    #     pass


# Singleton
_recording_manager: Optional[RecordingManager] = None


def get_recording_manager() -> RecordingManager:
    """Retorna instância singleton do RecordingManager"""
    global _recording_manager
    if _recording_manager is None:
        _recording_manager = RecordingManager()
    return _recording_manager
