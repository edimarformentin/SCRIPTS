"""
Router de administração do sistema VaaS
Funções: backup, git, configurações, logs, docker
"""
from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import subprocess
import tarfile
import shutil
import psutil
import git
import docker
from pathlib import Path
from datetime import datetime
import json
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin"])

# Docker client
try:
    docker_client = docker.DockerClient(base_url='unix://var/run/docker.sock')
except Exception as e:
    logger.warning(f"Failed to initialize Docker client: {e}")
    docker_client = None

# Configurações
SISTEMA_DIR = Path("/sistema")  # Volume montado em .:/sistema:ro no docker-compose.yml
BACKUP_DIR = Path("/backups")  # Volume montado em ./backups
ENV_FILE = SISTEMA_DIR / ".env"

# Criar diretório de backup se não existir
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

# =============================================================================
# SCHEMAS
# =============================================================================

class SystemStatus(BaseModel):
    """Status geral do sistema"""
    cpu_percent: float
    memory_percent: float
    memory_used_gb: float
    memory_total_gb: float
    disk_percent: float
    disk_used_gb: float
    disk_total_gb: float
    containers: List[Dict[str, Any]]
    uptime_seconds: float

class BackupInfo(BaseModel):
    """Informações de um backup"""
    filename: str
    size_mb: float
    created_at: str
    path: str

class GitConfig(BaseModel):
    """Configuração Git"""
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    remote_url: Optional[str] = None
    remote_name: str = "origin"

class GitCommitRequest(BaseModel):
    """Request para commit"""
    message: str
    push: bool = False

class GitStatusResponse(BaseModel):
    """Status do repositório Git"""
    is_repo: bool
    branch: str = ""
    modified: List[str] = []
    untracked: List[str] = []
    ahead: int = 0
    behind: int = 0
    clean: bool = True

class EnvConfig(BaseModel):
    """Configurações do .env"""
    configs: Dict[str, str]

# =============================================================================
# SISTEMA - STATUS
# =============================================================================

@router.get("/system/status", response_model=SystemStatus)
async def get_system_status():
    """Retorna status do sistema (CPU, RAM, Disco, Containers)"""
    try:
        # CPU e RAM
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()

        # Disco
        disk = psutil.disk_usage("/")

        # Containers Docker
        containers = []
        if docker_client:
            try:
                # Lista todos os containers (do projeto compose)
                for container in docker_client.containers.list(all=True):
                    containers.append({
                        "Name": container.name,
                        "Service": container.labels.get("com.docker.compose.service", container.name),
                        "State": container.status,
                        "Image": container.image.tags[0] if container.image.tags else "unknown"
                    })
            except Exception as e:
                logger.error(f"Error listing containers: {e}")

        # Uptime
        uptime_seconds = psutil.boot_time()
        current_time = datetime.now().timestamp()
        uptime = current_time - uptime_seconds

        return SystemStatus(
            cpu_percent=round(cpu_percent, 2),
            memory_percent=round(memory.percent, 2),
            memory_used_gb=round(memory.used / (1024**3), 2),
            memory_total_gb=round(memory.total / (1024**3), 2),
            disk_percent=round(disk.percent, 2),
            disk_used_gb=round(disk.used / (1024**3), 2),
            disk_total_gb=round(disk.total / (1024**3), 2),
            containers=containers,
            uptime_seconds=round(uptime, 0)
        )

    except Exception as e:
        logger.error(f"Error getting system status: {e}")
        raise HTTPException(500, f"Erro ao obter status: {str(e)}")

# =============================================================================
# BACKUP
# =============================================================================

@router.post("/backup/create")
async def create_backup(custom_name: Optional[str] = None):
    """Cria backup COMPLETO do código, configurações E banco de dados

    Args:
        custom_name: Nome customizado para o backup (opcional).
                     Ex: "antes-atualizacao" gera "SISTEMA_backup_antes-atualizacao_20250130_123456.tar.gz"
    """
    # Inicializar variáveis de caminho para cleanup em caso de erro
    sql_dump_path = None
    backup_path = None

    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Gerar nome do arquivo com custom_name se fornecido
        if custom_name and custom_name.strip():
            # Sanitizar custom_name (remover caracteres especiais)
            safe_name = "".join(c for c in custom_name.strip() if c.isalnum() or c in ('-', '_')).rstrip()
            backup_filename = f"SISTEMA_backup_{safe_name}_{timestamp}.tar.gz"
        else:
            backup_filename = f"SISTEMA_backup_{timestamp}.tar.gz"

        backup_path = BACKUP_DIR / backup_filename

        # Arquivo temporário para o dump SQL
        sql_dump_path = BACKUP_DIR / f"database_dump_{timestamp}.sql"

        logger.info(f"[BACKUP] Starting COMPLETE backup creation: {backup_path}")
        logger.info(f"[BACKUP] Backup directory: {BACKUP_DIR}")
        logger.info(f"[BACKUP] Backup directory exists: {BACKUP_DIR.exists()}")

        # ==============================================
        # PASSO 1: Criar dump do banco PostgreSQL
        # ==============================================
        logger.info("[BACKUP] Step 1/2: Creating PostgreSQL database dump...")
        try:
            # Executar pg_dump no container postgres-db
            container = docker_client.containers.get("postgres-db")

            # Comando pg_dump para exportar TODOS os dados
            dump_cmd = [
                "pg_dump",
                "-U", "postgres",
                "-d", "vaas_db",
                "--no-owner",
                "--no-acl",
                "--clean",
                "--if-exists"
            ]

            # Executar e capturar output
            exit_code, output = container.exec_run(dump_cmd, demux=False)

            if exit_code != 0:
                raise Exception(f"pg_dump failed with exit code {exit_code}")

            # Salvar dump em arquivo
            sql_dump_path.write_bytes(output)

            # Validar que o dump foi criado e não está vazio
            dump_size = sql_dump_path.stat().st_size
            if dump_size < 100:  # Dump válido deve ter pelo menos 100 bytes
                raise Exception(f"Database dump too small ({dump_size} bytes) - probably empty or failed")

            logger.info(f"[BACKUP] ✅ Database dump created successfully: {dump_size} bytes")

        except Exception as e:
            logger.error(f"[BACKUP] ❌ Failed to create database dump: {e}")
            # Limpar arquivo parcial se existir
            if sql_dump_path.exists():
                sql_dump_path.unlink()
            raise HTTPException(500, f"Falha ao criar dump do banco de dados: {str(e)}")

        # ==============================================
        # PASSO 2: Criar tar.gz com SISTEMA + dump SQL
        # ==============================================
        logger.info("[BACKUP] Step 2/2: Creating tar.gz with all files + database...")
        files_added = 0

        sistema_path = Path("/sistema")
        if not sistema_path.exists():
            # Limpar dump criado
            sql_dump_path.unlink()
            raise HTTPException(500, "Pasta SISTEMA não encontrada no container")

        with tarfile.open(backup_path, "w:gz") as tar:
            logger.info("[BACKUP] Tarfile opened successfully")

            # 1. ADICIONAR DUMP DO BANCO PRIMEIRO
            logger.info(f"[BACKUP] Adding database dump: {sql_dump_path.name}")
            tar.add(str(sql_dump_path), arcname=f"SISTEMA/{sql_dump_path.name}")
            files_added += 1

            # 2. ADICIONAR TODOS OS ARQUIVOS DA PASTA SISTEMA
            logger.info(f"[BACKUP] Scanning SISTEMA folder: {sistema_path}")
            for item in sistema_path.rglob("*"):
                try:
                    # Pular diretórios (só adicionar arquivos)
                    if not item.is_file():
                        continue

                    item_str = str(item)

                    # EXCLUSÕES:
                    # 1. Vídeos em data/recordings/
                    if "data/recordings" in item_str:
                        continue

                    # 2. Banco de dados em data/postgres/
                    if "data/postgres" in item_str:
                        continue

                    # 3. Arquivos .tar.gz (backups)
                    if item_str.endswith(".tar.gz"):
                        continue

                    # 4. __pycache__ e .pyc
                    if "__pycache__" in item_str or item_str.endswith(".pyc"):
                        continue

                    # 5. .git (se existir)
                    if "/.git/" in item_str:
                        continue

                    # Calcular caminho relativo para o tar
                    rel_path = item.relative_to(sistema_path)
                    arc_path = f"SISTEMA/{rel_path}"

                    # Adicionar arquivo ao backup
                    tar.add(str(item), arcname=arc_path, recursive=False)
                    files_added += 1

                    if files_added % 100 == 0:
                        logger.info(f"[BACKUP] Progress: {files_added} files added...")

                except (OSError, PermissionError, ValueError, FileNotFoundError) as e:
                    # Ignorar arquivos individuais que causam erro
                    logger.debug(f"[BACKUP] Skipping file {item}: {e}")
                    continue

            logger.info(f"[BACKUP] ✅ Completed: {files_added} files added to backup")

        # Limpar dump temporário
        sql_dump_path.unlink()
        logger.info("[BACKUP] Cleaned up temporary SQL dump file")

        # Obter tamanho final
        size_mb = backup_path.stat().st_size / (1024 * 1024)

        # VALIDAÇÃO FINAL: Verificar que backup foi criado e tem tamanho razoável
        if not backup_path.exists():
            raise Exception("Backup file was not created")

        if size_mb < 0.01:  # Menos de 10KB = algo deu errado
            backup_path.unlink()
            raise Exception(f"Backup too small ({size_mb:.2f} MB) - probably incomplete")

        logger.info(f"[BACKUP] ✅✅✅ COMPLETE BACKUP CREATED: {backup_path} ({size_mb:.2f} MB, {files_added} files)")

        return {
            "success": True,
            "filename": backup_filename,
            "size_mb": round(size_mb, 2),
            "files_count": files_added,
            "path": str(backup_path),
            "created_at": datetime.now().isoformat(),
            "includes_database": True,
            "note": "✅ Backup COMPLETO: código + configurações + BANCO DE DADOS. Extrair e executar setup.sh para restaurar sistema completo!"
        }

    except Exception as e:
        logger.error(f"[BACKUP] ❌ Error creating backup: {e}")
        # Limpar arquivos parciais se existirem
        if sql_dump_path and sql_dump_path.exists():
            sql_dump_path.unlink()
        if backup_path and backup_path.exists():
            backup_path.unlink()
        raise HTTPException(500, f"Erro ao criar backup: {str(e)}")

@router.get("/backup/list", response_model=List[BackupInfo])
async def list_backups():
    """Lista todos os backups existentes"""
    try:
        backups = []

        # Procurar arquivos SISTEMA_backup_*.tar.gz
        for backup_file in BACKUP_DIR.glob("SISTEMA_backup_*.tar.gz"):
            stat = backup_file.stat()
            backups.append(BackupInfo(
                filename=backup_file.name,
                size_mb=round(stat.st_size / (1024 * 1024), 2),
                created_at=datetime.fromtimestamp(stat.st_mtime).isoformat(),
                path=str(backup_file)
            ))

        # Ordenar por data (mais recente primeiro)
        backups.sort(key=lambda x: x.created_at, reverse=True)

        return backups

    except Exception as e:
        logger.error(f"Error listing backups: {e}")
        raise HTTPException(500, f"Erro ao listar backups: {str(e)}")

@router.get("/backup/download/{filename}")
async def download_backup(filename: str):
    """Download de um backup específico"""
    try:
        # Validar filename (segurança)
        if not filename.startswith("SISTEMA_backup_") or not filename.endswith(".tar.gz"):
            raise HTTPException(400, "Nome de arquivo inválido")

        backup_path = BACKUP_DIR / filename

        if not backup_path.exists():
            raise HTTPException(404, "Backup não encontrado")

        return FileResponse(
            path=str(backup_path),
            filename=filename,
            media_type="application/gzip"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error downloading backup: {e}")
        raise HTTPException(500, f"Erro ao baixar backup: {str(e)}")

@router.delete("/backup/delete/{filename}")
async def delete_backup(filename: str):
    """Deleta um backup específico"""
    try:
        # Validar filename (segurança)
        if not filename.startswith("SISTEMA_backup_") or not filename.endswith(".tar.gz"):
            raise HTTPException(400, "Nome de arquivo inválido")

        backup_path = BACKUP_DIR / filename

        if not backup_path.exists():
            raise HTTPException(404, "Backup não encontrado")

        backup_path.unlink()

        return {"success": True, "message": f"Backup {filename} deletado"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting backup: {e}")
        raise HTTPException(500, f"Erro ao deletar backup: {str(e)}")

# =============================================================================
# GIT
# =============================================================================

@router.get("/git/status", response_model=GitStatusResponse)
async def get_git_status():
    """Retorna status do repositório Git"""
    try:
        # Verificar se é um repo Git
        try:
            repo = git.Repo(SISTEMA_DIR)
        except git.InvalidGitRepositoryError:
            return GitStatusResponse(is_repo=False)

        # Branch atual
        try:
            branch = repo.active_branch.name
        except TypeError:
            branch = "detached HEAD"

        # Arquivos modificados e não rastreados
        modified = [item.a_path for item in repo.index.diff(None)]
        untracked = repo.untracked_files

        # Ahead/behind (se tiver remote)
        ahead = 0
        behind = 0
        try:
            tracking_branch = repo.active_branch.tracking_branch()
            if tracking_branch:
                ahead = len(list(repo.iter_commits(f'{tracking_branch}..{branch}')))
                behind = len(list(repo.iter_commits(f'{branch}..{tracking_branch}')))
        except:
            pass

        # Clean?
        clean = len(modified) == 0 and len(untracked) == 0

        return GitStatusResponse(
            is_repo=True,
            branch=branch,
            modified=modified,
            untracked=untracked,
            ahead=ahead,
            behind=behind,
            clean=clean
        )

    except Exception as e:
        logger.error(f"Error getting git status: {e}")
        raise HTTPException(500, f"Erro ao obter status Git: {str(e)}")

@router.post("/git/config")
async def set_git_config(config: GitConfig):
    """Configura Git (nome, email, remote)"""
    try:
        # Inicializar repo se não existir
        try:
            repo = git.Repo(SISTEMA_DIR)
        except git.InvalidGitRepositoryError:
            repo = git.Repo.init(SISTEMA_DIR)
            logger.info(f"Initialized Git repository at {SISTEMA_DIR}")

        # Configurar user.name
        if config.user_name:
            repo.config_writer().set_value("user", "name", config.user_name).release()

        # Configurar user.email
        if config.user_email:
            repo.config_writer().set_value("user", "email", config.user_email).release()

        # Configurar remote
        if config.remote_url:
            try:
                # Remover remote existente
                repo.delete_remote(config.remote_name)
            except:
                pass

            # Adicionar remote
            repo.create_remote(config.remote_name, config.remote_url)

        return {"success": True, "message": "Configuração Git salva"}

    except Exception as e:
        logger.error(f"Error setting git config: {e}")
        raise HTTPException(500, f"Erro ao configurar Git: {str(e)}")

@router.get("/git/config")
async def get_git_config():
    """Retorna configuração Git atual"""
    try:
        try:
            repo = git.Repo(SISTEMA_DIR)
        except git.InvalidGitRepositoryError:
            return {"is_repo": False}

        config_reader = repo.config_reader()

        # Ler configs
        user_name = config_reader.get_value("user", "name", default="")
        user_email = config_reader.get_value("user", "email", default="")

        # Remote URL
        remote_url = ""
        try:
            remote = repo.remote("origin")
            remote_url = list(remote.urls)[0] if remote.urls else ""
        except:
            pass

        return {
            "is_repo": True,
            "user_name": user_name,
            "user_email": user_email,
            "remote_url": remote_url
        }

    except Exception as e:
        logger.error(f"Error getting git config: {e}")
        raise HTTPException(500, f"Erro ao obter configuração Git: {str(e)}")

@router.post("/git/commit")
async def git_commit(request: GitCommitRequest):
    """Cria um commit Git"""
    try:
        repo = git.Repo(SISTEMA_DIR)

        # Add all
        repo.git.add(A=True)

        # Commit
        commit = repo.index.commit(request.message)

        result = {
            "success": True,
            "commit_sha": commit.hexsha[:7],
            "message": request.message
        }

        # Push se solicitado
        if request.push:
            try:
                origin = repo.remote("origin")
                # Usar set_upstream=True para configurar branch no primeiro push
                push_info = origin.push(set_upstream=True)
                result["pushed"] = True
                result["push_info"] = str(push_info)
            except Exception as e:
                result["pushed"] = False
                result["push_error"] = str(e)

        return result

    except git.InvalidGitRepositoryError:
        raise HTTPException(400, "Não é um repositório Git. Configure primeiro.")
    except Exception as e:
        logger.error(f"Error committing: {e}")
        raise HTTPException(500, f"Erro ao fazer commit: {str(e)}")

@router.post("/git/push")
async def git_push():
    """Faz push para remote"""
    try:
        repo = git.Repo(SISTEMA_DIR)
        origin = repo.remote("origin")

        # Usar set_upstream=True para configurar branch no primeiro push
        push_info = origin.push(set_upstream=True)

        return {
            "success": True,
            "info": str(push_info)
        }

    except git.InvalidGitRepositoryError:
        raise HTTPException(400, "Não é um repositório Git")
    except Exception as e:
        logger.error(f"Error pushing: {e}")
        raise HTTPException(500, f"Erro ao fazer push: {str(e)}")

@router.post("/git/pull")
async def git_pull():
    """Faz pull do remote"""
    try:
        repo = git.Repo(SISTEMA_DIR)
        origin = repo.remote("origin")

        pull_info = origin.pull()

        return {
            "success": True,
            "info": str(pull_info)
        }

    except git.InvalidGitRepositoryError:
        raise HTTPException(400, "Não é um repositório Git")
    except Exception as e:
        logger.error(f"Error pulling: {e}")
        raise HTTPException(500, f"Erro ao fazer pull: {str(e)}")

@router.get("/git/log")
async def git_log(limit: int = 10):
    """Retorna histórico de commits"""
    try:
        repo = git.Repo(SISTEMA_DIR)

        commits = []
        for commit in repo.iter_commits(max_count=limit):
            commits.append({
                "sha": commit.hexsha[:7],
                "message": commit.message.strip(),
                "author": commit.author.name,
                "date": datetime.fromtimestamp(commit.committed_date).isoformat()
            })

        return commits

    except git.InvalidGitRepositoryError:
        return []
    except Exception as e:
        logger.error(f"Error getting git log: {e}")
        raise HTTPException(500, f"Erro ao obter histórico: {str(e)}")

# =============================================================================
# CONFIGURAÇÕES (.env)
# =============================================================================

@router.get("/config/env")
async def get_env_config():
    """Retorna configurações do .env"""
    try:
        if not ENV_FILE.exists():
            return {"configs": {}}

        configs = {}
        with open(ENV_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                # Ignorar comentários e linhas vazias
                if line and not line.startswith('#'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        configs[key.strip()] = value.strip()

        return {"configs": configs}

    except Exception as e:
        logger.error(f"Error reading .env: {e}")
        raise HTTPException(500, f"Erro ao ler .env: {str(e)}")

@router.put("/config/env")
async def update_env_config(config: EnvConfig):
    """Atualiza configurações do .env"""
    try:
        # Fazer backup do .env atual
        if ENV_FILE.exists():
            backup_path = ENV_FILE.parent / f".env.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            shutil.copy(ENV_FILE, backup_path)

        # Escrever novo .env
        with open(ENV_FILE, 'w') as f:
            for key, value in config.configs.items():
                f.write(f"{key}={value}\n")

        return {
            "success": True,
            "message": "Configurações salvas. Reinicie os containers para aplicar."
        }

    except Exception as e:
        logger.error(f"Error updating .env: {e}")
        raise HTTPException(500, f"Erro ao atualizar .env: {str(e)}")

# =============================================================================
# DOCKER
# =============================================================================

@router.post("/docker/{service}/restart")
async def restart_docker_service(service: str):
    """Reinicia um serviço Docker"""
    try:
        # Validar nome do serviço (segurança)
        valid_services = ["gestao-web", "gestao-nginx", "mediamtx", "postgres-db", "gestao-janitor"]
        if service not in valid_services:
            raise HTTPException(400, f"Serviço inválido. Válidos: {valid_services}")

        if not docker_client:
            raise HTTPException(500, "Docker client não disponível")

        # Encontrar container pelo nome
        try:
            container = docker_client.containers.get(service)
            container.restart(timeout=60)

            return {
                "success": True,
                "message": f"Serviço {service} reiniciado"
            }
        except docker.errors.NotFound:
            raise HTTPException(404, f"Container {service} não encontrado")
    except Exception as e:
        logger.error(f"Error restarting service: {e}")
        raise HTTPException(500, f"Erro ao reiniciar: {str(e)}")

@router.get("/docker/{service}/logs")
async def get_docker_logs(service: str, lines: int = 100):
    """Retorna logs de um serviço Docker"""
    try:
        # Validar nome do serviço (segurança)
        valid_services = ["gestao-web", "gestao-nginx", "mediamtx", "postgres-db", "gestao-janitor"]
        if service not in valid_services:
            raise HTTPException(400, f"Serviço inválido. Válidos: {valid_services}")

        if not docker_client:
            raise HTTPException(500, "Docker client não disponível")

        # Encontrar container pelo nome
        try:
            container = docker_client.containers.get(service)
            logs = container.logs(tail=lines, timestamps=False).decode('utf-8')

            return {
                "service": service,
                "logs": logs
            }
        except docker.errors.NotFound:
            raise HTTPException(404, f"Container {service} não encontrado")
    except Exception as e:
        logger.error(f"Error getting logs: {e}")
        raise HTTPException(500, f"Erro ao obter logs: {str(e)}")
