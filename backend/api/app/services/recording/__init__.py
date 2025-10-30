"""
Serviços de Gravação
Sistema robusto de gravação com workers preparados para RabbitMQ
"""

from .recording_worker import RecordingWorker, get_recording_worker
from .recording_manager import RecordingManager, get_recording_manager

__all__ = [
    "RecordingWorker",
    "get_recording_worker",
    "RecordingManager",
    "get_recording_manager",
]
