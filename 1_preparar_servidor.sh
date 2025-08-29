#!/bin/bash
# Nome do arquivo: 1_preparar_servidor.sh (VERSÃO CORRIGIDA v2)
set -e

echo "==== SCRIPT 1: PREPARAR AMBIENTE E ESTRUTURA COMPLETA ===="
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl git python3 python3-pip

if ! command -v docker >/dev/null 2>&1; then
  echo "--> Docker não encontrado. Instalando Docker..."
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker $USER
  echo "--> Docker instalado. Você talvez precise fazer logout e login para usar o Docker sem 'sudo'."
fi

echo "--> Criando estrutura de pastas em /home/edimar/SISTEMA..."
cd /home/edimar
mkdir -p SISTEMA
cd SISTEMA
mkdir -p GESTAO_WEB BANCO/data BANCO/init BANCO/backup MEDIAMTX FRIGATE

echo "--> Criando arquivo de ambiente .env..."
cat <<EOFENV > .env
POSTGRES_USER=monitoramento
POSTGRES_PASSWORD=senha_super_segura
POSTGRES_DB=monitoramento
TZ=America/Sao_Paulo
TZ=America/Sao_Paulo
EOFENV

echo "--> Criando arquivo docker-compose.yml principal..."
cat <<'EOFCMP' > docker-compose.yml
services:
  banco:
    image: postgres:16
    container_name: sistema-banco
    env_file: .env
    volumes:
      - ./BANCO/data:/var/lib/postgresql/data
      - ./BANCO/init:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    restart: always
    networks:
      - sistema_network

  gestao_web:
    build:
      context: ./GESTAO_WEB
    container_name: sistema-gestao-web
    env_file: .env
    environment:
      - FRIGATE_HOST_PATH=/home/edimar/SISTEMA/FRIGATE
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./GESTAO_WEB:/code
      - ./FRIGATE:/code/media_files/FRIGATE
    ports:
      - "8000:8000"
    depends_on:
      - banco
      - mediamtx
    restart: always
    networks:
      - sistema_network

  mediamtx:
    image: bluenviron/mediamtx:latest
    container_name: sistema-mediamtx
    volumes:
      - ./MEDIAMTX/mediamtx.yml:/mediamtx.yml
    ports:
      - "1935:1935" # RTMP
      - "8554:8554" # RTSP
      - "8888:8888" # HLS
    restart: always
    networks:
      - sistema_network

networks:
  sistema_network:
    driver: bridge
EOFCMP

echo "--> Criando script de inicialização do banco..."
cat <<'EOFINIT' > BANCO/init/01_init.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SET timezone = 'America/Sao_Paulo';
EOFINIT

# ==== GPU VALIDATION ====
echo "--> Validando GPU e preparando runtime NVIDIA (se houver )..."
(
  set -eu; if set -o 2>/dev/null | grep -q pipefail; then set -o pipefail; fi
  export DEBIAN_FRONTEND=noninteractive

  if lspci | egrep -i 'vga|3d|display' | grep -qi nvidia; then
    echo "[GPU] GPU NVIDIA detectada."
    if ! lsmod | grep -q '^nvidia'; then
      echo "[GPU] Driver NVIDIA não carregado. Tentando instalar..."
      apt-get update
      apt-get install -y nvidia-driver || apt-get install -y nvidia-driver-535 || true
      echo "[GPU] Driver instalado (pode exigir reboot para ser efetivo)."
    else
      echo "[GPU] Driver NVIDIA já está carregado."
    fi

    if ! dpkg -l | grep -q '^ii  nvidia-container-toolkit '; then
      echo "[GPU] Instalando NVIDIA Container Toolkit..."
      apt-get update
      apt-get install -y nvidia-container-toolkit || {
        echo "[GPU] Falha ao instalar nvidia-container-toolkit."
        exit 1
      }
    else
      echo "[GPU] NVIDIA Container Toolkit já instalado."
    fi

    echo "[GPU] Configurando NVIDIA Container Runtime..."
    if command -v nvidia-ctk >/dev/null; then
      nvidia-ctk runtime configure --runtime=docker --set-as-default || true
      # Garante modo legacy
      cfg="/etc/nvidia-container-runtime/config.toml"
      if [ -f "$cfg" ] && ! grep -qE '^modes*=s*"legacy"' "$cfg"; then
        sed -i 's/^s*modes*=s*".*"/mode = "legacy"/' "$cfg" || true
        echo "[GPU] Modo do runtime NVIDIA definido para 'legacy'."
      fi
    fi
    echo "[GPU] Configuração NVIDIA concluída. O Docker será reiniciado a seguir."
  else
    echo "[INFO] Nenhuma GPU NVIDIA foi detectada. O sistema continuará a usar CPU."
  fi
)

# --- CORREÇÃO APLICADA AQUI ---
# Centraliza o reinício do Docker em um único local e verifica seu status.
echo "--> Tentando reiniciar o serviço Docker para aplicar todas as configurações..."
sudo systemctl restart docker

echo "--> Aguardando o Docker daemon ficar ativo..."
max_wait=30
count=0
while ! docker info > /dev/null 2>&1; do
    if [ $count -ge $max_wait ]; then
        echo "ERRO CRÍTICO: O Docker daemon não iniciou após ${max_wait} segundos."
        echo "Por favor, verifique o status com 'systemctl status docker.service' e 'journalctl -xeu docker.service'."
        exit 1
    fi
    echo "    ...aguardando ($((count+1))/${max_wait})..."
    sleep 1
    count=$((count+1))
done
echo "✅ Docker daemon está ativo e pronto."

echo "==== SCRIPT 1 CONCLUÍDO! ===="
