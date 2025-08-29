#!/bin/bash
# Nome do arquivo: 4.7_criar_backend_gerenciar_frigate.sh (MODIFICADO PARA YOLO)
set -Eeuo pipefail
echo "==== SCRIPT 4.7 (MODIFICADO): CRIANDO GERENCIADOR FRIGATE (APENAS GRAVAÇÃO) ===="
cd /home/edimar/SISTEMA
echo "--> Gerando GESTAO_WEB/gerenciar_frigate.py (versão simplificada)..."
cat <<'FRIGATE_PY' > GESTAO_WEB/gerenciar_frigate.py
import os, re, sys, yaml, docker, shutil, subprocess, json
from sqlalchemy import create_engine, Column, Integer, String, Boolean, UniqueConstraint, ForeignKey
from sqlalchemy.orm import sessionmaker, relationship, declarative_base
from sqlalchemy.exc import NoResultFound
from datetime import datetime

# --- Configurações ---
FRIGATE_HOST_BASE_PATH = os.getenv("FRIGATE_HOST_PATH")
if not FRIGATE_HOST_BASE_PATH:
    raise SystemExit("ERRO CRÍTICO: A variável de ambiente FRIGATE_HOST_PATH não está definida.")

DATABASE_URL = "postgresql://monitoramento:senha_super_segura@banco:5432/monitoramento"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- Modelos SQLAlchemy (espelho dos modelos principais) ---
class Cliente(Base):
    __tablename__ = 'clientes'
    id = Column(Integer, primary_key=True)
    unique_id = Column(String, nullable=False, unique=True)
    frigate_port = Column(Integer, nullable=True, unique=True)
    frigate_container_status = Column(String, default='nao_criado')
    cameras = relationship("Camera", back_populates="cliente")
    __table_args__ = (UniqueConstraint('frigate_port', name='uq_frigate_port'),)

class Camera(Base):
    __tablename__ = 'cameras'
    id = Column(Integer, primary_key=True)
    nome = Column(String, nullable=False)
    cliente_id = Column(Integer, ForeignKey('clientes.id'))
    record_enabled = Column(Boolean, default=True)
    dias_armazenamento = Column(Integer, default=3)
    motion_threshold = Column(Integer, default=25)
    cliente = relationship("Cliente", back_populates="cameras")

# --- Funções de Gerenciamento ---
def gerar_config_frigate(cliente: Cliente) -> dict:
    """Gera o dicionário de configuração do Frigate focado apenas em gravação."""
    config = {
        'mqtt': {'enabled': False},
        'database': {'path': '/config/frigate.db'},
        'detectors': {'cpu': {'type': 'cpu'}}, # Detector mínimo, não será usado para IA
        'cameras': {}
    }
    for cam in cliente.cameras:
        if cam.record_enabled:
            cam_nome_sanitizado = re.sub(r'[^a-zA-Z0-9_]', '', cam.nome.replace(' ', '_'))
            config['cameras'][cam_nome_sanitizado] = {
                'ffmpeg': {
                    'inputs': [{
                        'path': f'rtsp://sistema-mediamtx:8554/live/{cliente.unique_id}/{cam_nome_sanitizado}',
                        'roles': ['record']
                    }]
                },
                'detect': {'enabled': False},
                'record': {
                    'enabled': True,
                    'retain': {'days': cam.dias_armazenamento}
                },
                'motion': {
                    'mask': [],
                    'threshold': cam.motion_threshold
                }
            }
    return config

def find_and_allocate_free_port(db: SessionLocal, cliente: Cliente) -> int:
    PORT_RANGE_START, PORT_RANGE_END = 5001, 5999
    docker_client = docker.from_env()
    all_containers = docker_client.containers.list(all=True)
    used_ports_docker = set()
    for container in all_containers:
        if container.name == f"frigate-{cliente.unique_id}":
            continue
        ports = container.attrs.get('HostConfig', {}).get('PortBindings')
        if ports:
            for host_bindings in ports.values():
                if host_bindings:
                    for binding in host_bindings:
                        host_port = binding.get('HostPort')
                        if host_port and host_port.isdigit():
                            used_ports_docker.add(int(host_port))
    if cliente.frigate_port and cliente.frigate_port not in used_ports_docker:
        return cliente.frigate_port
    for port in range(PORT_RANGE_START, PORT_RANGE_END + 1):
        if port not in used_ports_docker:
            print(f"Porta {port} alocada para o cliente {cliente.unique_id}.")
            cliente.frigate_port = port
            db.commit()
            return port
    raise SystemExit(f"ERRO CRÍTICO: Nenhuma porta livre encontrada na faixa {PORT_RANGE_START}-{PORT_RANGE_END}.")

def criar_ou_atualizar_container(cliente_id: int):
    db = SessionLocal()
    try:
        cliente = db.query(Cliente).filter(Cliente.id == cliente_id).one()
        if not any(c.record_enabled for c in cliente.cameras):
            print("AVISO: Nenhuma câmera com gravação ativa. Removendo contêiner Frigate (se existir).")
            remover_container(cliente_id)
            return
        porta_alocada = find_and_allocate_free_port(db, cliente)
        config_atual = gerar_config_frigate(cliente)
        frigate_internal_path = f"/code/media_files/FRIGATE/{cliente.unique_id}"
        os.makedirs(os.path.join(frigate_internal_path, "config"), exist_ok=True)
        with open(os.path.join(frigate_internal_path, 'config', 'config.yml'), 'w') as f:
            yaml.dump(config_atual, f)
        host_path = os.path.join(FRIGATE_HOST_BASE_PATH, cliente.unique_id)
        compose_content = f"""
services:
  frigate:
    container_name: frigate-{cliente.unique_id}
    image: ghcr.io/blakeblackshear/frigate:stable
    restart: unless-stopped
    shm_size: '256m'
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - {os.path.join(host_path, 'config')}:/config
      - {os.path.join(host_path, 'media')}:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 256m
    ports:
      - "{porta_alocada}:5000"
    networks:
      - sistema_network

networks:
  sistema_network:
    name: sistema_sistema_network
    external: true
"""
        compose_file = os.path.join(frigate_internal_path, 'docker-compose.yml')
        with open(compose_file, 'w') as f:
            f.write(compose_content)
        print(f"Executando 'docker compose up' para o cliente {cliente.unique_id}...")
        command = ["docker", "compose", "-f", compose_file, "up", "-d", "--force-recreate", "--remove-orphans"]
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print(f"AVISOS/ERROS DOCKER:\\n{result.stderr}")
        cliente.frigate_container_status = 'rodando'
        print(f"Contêiner Frigate para '{cliente.unique_id}' está ativo na porta {porta_alocada}.")
    except NoResultFound:
        print(f"ERRO: Cliente com ID {cliente_id} não encontrado.")
    except subprocess.CalledProcessError as e:
        if 'cliente' in locals():
            cliente.frigate_container_status = 'erro'
        print(f"ERRO ao executar o Docker Compose para o Frigate: {e.stderr}")
    except Exception as e:
        if 'cliente' in locals():
            cliente.frigate_container_status = 'erro'
        print(f"ERRO inesperado ao gerenciar Frigate: {e}")
    finally:
        if 'cliente' in locals() and db.is_active:
            db.commit()
        db.close()

def remover_container(cliente_id: int):
    db = SessionLocal()
    try:
        cliente = db.query(Cliente).filter(Cliente.id == cliente_id).one()
        frigate_internal_path = f"/code/media_files/FRIGATE/{cliente.unique_id}"
        compose_file = os.path.join(frigate_internal_path, 'docker-compose.yml')
        if os.path.exists(compose_file):
            print(f"Removendo contêiner Frigate para {cliente.unique_id}...")
            subprocess.run(["docker", "compose", "-f", compose_file, "down", "-v"], check=True, capture_output=True, text=True)
        cliente.frigate_port = None
        cliente.frigate_container_status = 'nao_criado'
        db.commit()
        host_path = os.path.join(FRIGATE_HOST_BASE_PATH, cliente.unique_id)
        if os.path.isdir(host_path):
            shutil.rmtree(host_path, ignore_errors=True)
        if os.path.isdir(frigate_internal_path):
            shutil.rmtree(frigate_internal_path, ignore_errors=True)
        print(f"Recursos do Frigate para o cliente {cliente.unique_id} foram removidos.")
    except NoResultFound:
        print(f"AVISO: Cliente com ID {cliente_id} não encontrado para remoção do Frigate.")
    except Exception as e:
        print(f"ERRO ao remover Frigate: {e}")
    finally:
        db.close()

def verificar_status_container(cliente_id: int):
    db = SessionLocal()
    result_data = {"status": "nao_criado", "created_at": None, "uptime": None}
    try:
        cliente = db.query(Cliente).filter(Cliente.id == cliente_id).one()
        container_name = f"frigate-{cliente.unique_id}"
        docker_client = docker.from_env()
        container = docker_client.containers.get(container_name)
        if container.status == 'running':
            result_data["status"] = 'rodando'
            created_str = container.attrs.get('Created', '')
            started_at_str = container.attrs.get('State', {}).get('StartedAt', '')
            if created_str:
                result_data["created_at"] = datetime.fromisoformat(created_str.replace('Z', '+00:00')).strftime('%d/%m/%Y %H:%M:%S')
            if started_at_str and not started_at_str.startswith('0001-01-01'):
                result_data["uptime"] = started_at_str
        else:
            result_data["status"] = 'erro'
    except docker.errors.NotFound:
        result_data["status"] = 'nao_criado'
    except NoResultFound:
        result_data["status"] = 'nao_encontrado'
    except Exception as e:
        print(f"Erro ao verificar status: {e}", file=sys.stderr)
        result_data["status"] = 'erro'
    finally:
        print(json.dumps(result_data))
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python gerenciar_frigate.py [criar|remover|status] [id_do_cliente]")
        sys.exit(1)
    acao, cliente_id_arg = sys.argv[1], int(sys.argv[2])
    if acao == "criar":
        criar_ou_atualizar_container(cliente_id_arg)
    elif acao == "remover":
        remover_container(cliente_id_arg)
    elif acao == "status":
        verificar_status_container(cliente_id_arg)
    else:
        print(f"ERRO: Ação '{acao}' desconhecida. Use 'criar', 'remover' ou 'status'.")
        sys.exit(1)
FRIGATE_PY
echo "--> Arquivo gerenciar_frigate.py foi sobrescrito com a versão simplificada (apenas gravação)."
echo "==== SCRIPT 4.7 (MODIFICADO) CONCLUÍDO ===="
