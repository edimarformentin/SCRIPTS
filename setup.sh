#!/usr/bin/env bash
# =============================================================================
# setup.sh - Instalador Único para o Sistema VaaS
# =============================================================================
# Este script instala e configura o sistema VaaS em um servidor limpo.
# Basta copiar a pasta SISTEMA e executar: bash setup.sh
# =============================================================================
set -Eeuo pipefail

SISTEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SISTEMA_DIR"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# =============================================================================
# FUNÇÕES DE DETECÇÃO
# =============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        err "Sistema operacional não suportado"
        exit 1
    fi
    log "Sistema detectado: $OS $VER"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "Este script precisa de privilégios sudo para instalar dependências"
        warn "Você será solicitado a fornecer sua senha"
    fi
}

check_docker() {
    if command -v docker &> /dev/null; then
        ok "Docker já está instalado: $(docker --version)"
        return 0
    else
        warn "Docker não encontrado"
        return 1
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        ok "Docker Compose já está instalado: $(docker compose version)"
        return 0
    else
        warn "Docker Compose não encontrado"
        return 1
    fi
}

check_nvidia() {
    if command -v nvidia-smi &> /dev/null; then
        ok "NVIDIA GPU detectada:"
        nvidia-smi --query-gpu=name --format=csv,noheader | head -1
        return 0
    else
        warn "NVIDIA GPU não detectada (transcodificação H.265 não disponível)"
        return 1
    fi
}

# =============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS
# =============================================================================

install_docker() {
    log "Instalando Docker..."

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release

        # Adicionar repositório oficial Docker
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Adicionar usuário ao grupo docker
        sudo usermod -aG docker $USER

        ok "Docker instalado com sucesso!"
        warn "IMPORTANTE: Você precisa fazer logout/login para usar docker sem sudo"
    else
        err "Sistema operacional não suportado para instalação automática do Docker"
        err "Instale manualmente: https://docs.docker.com/engine/install/"
        exit 1
    fi
}

install_nvidia_container_toolkit() {
    log "Instalando NVIDIA Container Toolkit..."

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit

        # Configurar Docker para usar NVIDIA runtime
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker

        ok "NVIDIA Container Toolkit instalado!"
    else
        warn "Sistema operacional não suportado para instalação automática do NVIDIA Toolkit"
    fi
}

# =============================================================================
# CONFIGURAÇÃO DO SISTEMA
# =============================================================================

create_env_file() {
    log "Criando arquivo .env..."

    cat > "$SISTEMA_DIR/.env" <<EOF
# =============================================================================
# Configurações do Sistema VaaS
# =============================================================================

# Database
DATABASE_URL=postgresql://postgres:postgres@postgres-db:5432/vaas_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=vaas_db

# Backend
CORS_ORIGINS=*
RECORDINGS_PATH=/recordings

# NVIDIA (se disponível)
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,video,utility

# Portas
FRONTEND_PORT=80
BACKEND_PORT=8000
MEDIAMTX_RTSP_PORT=8554
MEDIAMTX_RTMP_PORT=1935
MEDIAMTX_HLS_PORT=8888
POSTGRES_PORT=5432

# Gravações
SEGMENT_DURATION_SECONDS=120
RETENTION_DAYS=30
EOF

    ok "Arquivo .env criado"
}

detect_hardware() {
    log "Detectando hardware disponível..."

    local has_nvidia=false
    local encoders=[]

    if check_nvidia; then
        has_nvidia=true
        encoders='["h264_nvenc","hevc_nvenc"]'
    else
        encoders='["libx264"]'
    fi

    cat > "$SISTEMA_DIR/.hardware_info.json" <<EOF
{
  "has_nvidia_gpu": $has_nvidia,
  "available_encoders": $encoders,
  "detected_at": "$(date -Iseconds)"
}
EOF

    ok "Hardware detectado e configurado"
}

# =============================================================================
# INICIALIZAÇÃO DO SISTEMA
# =============================================================================

init_database() {
    log "Aguardando PostgreSQL ficar pronto..."

    for i in {1..30}; do
        if docker exec postgres-db pg_isready -U postgres &> /dev/null; then
            ok "PostgreSQL está pronto!"
            return 0
        fi
        echo -n "."
        sleep 1
    done

    err "PostgreSQL não ficou pronto após 30 segundos"
    return 1
}

create_vaas_database() {
    log "Criando banco de dados vaas_db..."

    # Verificar se banco já existe
    DB_EXISTS=$(docker exec postgres-db psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='vaas_db'")

    if [[ "$DB_EXISTS" == "1" ]]; then
        ok "Banco de dados vaas_db já existe"
        return 0
    fi

    # Criar banco de dados vaas_db
    docker exec postgres-db psql -U postgres -d postgres -c "CREATE DATABASE vaas_db;"

    if [[ $? -eq 0 ]]; then
        ok "Banco de dados vaas_db criado"
    else
        err "❌ Falha ao criar banco de dados vaas_db"
        return 1
    fi
}

init_database_schema() {
    log "Inicializando esquema do banco de dados..."

    # Copiar script SQL para dentro do container
    docker cp "$SISTEMA_DIR/init-database.sql" postgres-db:/tmp/init-database.sql

    # Executar script SQL
    docker exec postgres-db psql -U postgres -d vaas_db -f /tmp/init-database.sql > /dev/null 2>&1

    # Limpar arquivo temporário
    docker exec postgres-db rm /tmp/init-database.sql

    ok "Banco de dados inicializado com sucesso"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              🎥 VaaS - Video as a Service                     ║"
    echo "║                    Instalador v2.0                             ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Detecção
    detect_os
    check_root

    # Verificar dependências
    log "Verificando dependências..."
    NEED_DOCKER=false
    NEED_NVIDIA_TOOLKIT=false

    if ! check_docker || ! check_docker_compose; then
        NEED_DOCKER=true
    fi

    HAS_NVIDIA=false
    if check_nvidia; then
        HAS_NVIDIA=true
        # Verificar se NVIDIA Toolkit está instalado
        if ! docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
            NEED_NVIDIA_TOOLKIT=true
        fi
    fi

    # Instalar o que falta
    if [[ "$NEED_DOCKER" == "true" ]]; then
        read -p "Docker não encontrado. Deseja instalar? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_docker
        else
            err "Docker é obrigatório. Instale manualmente e execute novamente."
            exit 1
        fi
    fi

    if [[ "$HAS_NVIDIA" == "true" && "$NEED_NVIDIA_TOOLKIT" == "true" ]]; then
        read -p "GPU NVIDIA detectada. Instalar NVIDIA Container Toolkit? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            install_nvidia_container_toolkit
        fi
    fi

    # Configurar
    create_env_file
    detect_hardware

    # Criar estrutura de diretórios
    log "Criando estrutura de diretórios..."
    mkdir -p data/recordings/live
    mkdir -p data/postgres
    mkdir -p logs

    # Parar containers existentes
    log "Parando containers existentes (se houver)..."
    docker compose down --remove-orphans 2>/dev/null || true

    # Subir sistema
    log "Iniciando containers Docker..."
    docker compose up -d --build

    # Aguardar serviços e inicializar banco
    if init_database; then
        # Nota: O banco vaas_db é criado automaticamente pelo PostgreSQL
        # devido à variável POSTGRES_DB=vaas_db no docker-compose.yml
        init_database_schema
    else
        err "Falha ao inicializar banco de dados"
        exit 1
    fi

    # Aguardar backend ficar pronto
    log "Aguardando backend ficar pronto..."
    for i in {1..30}; do
        if timeout 2 curl -sf http://localhost:8000/health &> /dev/null; then
            ok "Backend está respondendo!"
            break
        fi
        echo -n "."
        sleep 1
    done

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  ✅ INSTALAÇÃO CONCLUÍDA!                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    ok "🌐 Frontend:     http://localhost"
    ok "🔌 API Backend:  http://localhost:8000"
    ok "📚 API Docs:     http://localhost:8000/docs"
    ok "📹 MediaMTX HLS: http://localhost:8888"
    ok "💾 Gravações:    $SISTEMA_DIR/data/recordings/"
    echo ""
    ok "📊 Para verificar status: docker compose ps"
    ok "📋 Para ver logs:         docker compose logs -f"
    ok "🛑 Para parar:            docker compose down"
    echo ""

    if [[ "$NEED_DOCKER" == "true" ]]; then
        warn "⚠️  IMPORTANTE: Você instalou Docker agora."
        warn "   Faça logout/login para usar docker sem sudo."
    fi

    if [[ "$HAS_NVIDIA" == "true" ]]; then
        ok "🎮 GPU NVIDIA detectada - transcodificação H.265 disponível"
    fi

    echo ""
}

# Tratamento de erros
trap 'err "❌ Instalação falhou. Verifique os logs acima."' ERR

main "$@"
