#!/usr/bin/env bash
set -euo pipefail

echo "==== INICIANDO REINSTALAÇÃO COMPLETA DO SISTEMA (v6 - Robusta) ===="
echo "Este modo garante uma limpeza completa antes de reinstalar."

# --- ETAPA 1: LIMPEZA PROFUNDA ---
echo "🛑 Parando e removendo todos os containers do sistema..."
docker ps -a -q --filter "name=sistema-*" | xargs -r docker rm -f
docker ps -a -q --filter "name=frigate-*" | xargs -r docker rm -f
docker ps -a -q --filter "name=yolo-*" | xargs -r docker rm -f
echo "Containers removidos."

echo "🗑️ Removendo diretório SISTEMA antigo para garantir uma configuração limpa..."
sudo rm -rf /home/edimar/SISTEMA

echo "🧹 Removendo scripts de host antigos e serviços systemd..."
# Remove os scripts python da pasta de scripts principal
sudo rm -f /home/edimar/SCRIPTS/event_*_host.py
# Para e desabilita os timers para que não tentem rodar durante a instalação
sudo systemctl stop event-assembler.timer event-merge.timer event-cleaner.timer || true
sudo systemctl disable event-assembler.timer event-merge.timer event-cleaner.timer || true
# Remove os arquivos de serviço antigos
sudo rm -f /etc/systemd/system/event-assembler.service /etc/systemd/system/event-assembler.timer
sudo rm -f /etc/systemd/system/event-merge.service /etc/systemd/system/event-merge.timer
sudo rm -f /etc/systemd/system/event-cleaner.service /etc/systemd/system/event-cleaner.timer
# Recarrega o systemd para ele "esquecer" os serviços removidos
sudo systemctl daemon-reload
echo "Limpeza concluída."

# --- ETAPA 2: EXECUÇÃO DOS SCRIPTS DE INSTALAÇÃO ---
echo "🚀 Iniciando sequência de instalação..."
cd /home/edimar/SCRIPTS

# Scripts principais de configuração e backend/frontend
SCRIPT_SEQUENCE=(
    "1_preparar_servidor.sh"
    "2_banco_dados.sh"
    "3_mediamtx.sh"
    "4_criar_backend.sh"
    "5_criar_frontend.sh"
)
for script in "${SCRIPT_SEQUENCE[@]}"; do
    echo "--> Executando: $script"
    bash "./$script"
done

# Scripts de serviços de host (agora chamados explicitamente)
HOST_SERVICES_SCRIPTS=(
    "4.11_criar_backend_evento_video.sh"
    "4.12_instalar_merge_eventos.sh"
    "4.13_instalar_limpeza_eventos.sh"
)
echo "🔧 Instalando serviços de host (assembler, merge, cleaner)..."
for script in "${HOST_SERVICES_SCRIPTS[@]}"; do
    echo "--> Executando: $script"
    bash "./$script"
done

# --- ETAPA 3: SUBIR AMBIENTE E POPULAR DADOS ---
echo "🐳 Subindo os containers com Docker Compose..."
cd /home/edimar/SISTEMA
docker compose up --build -d

echo "⏳ Aguardando o serviço 'gestao_web' ficar totalmente operacional..."
max_retries=20; count=0
until docker compose exec -T gestao_web nc -z localhost 8000; do
    count=$((count+1))
    if [ $count -ge $max_retries ]; then
        echo "ERRO: O serviço 'gestao_web' não ficou disponível a tempo."
        exit 1
    fi
    echo "   ... aguardando 5 segundos ($count/$max_retries)..."
    sleep 5
done
echo "✅ Serviço 'gestao_web' está pronto."

echo "🌱 Populando dados iniciais e iniciando serviços de IA..."
docker compose exec -T gestao_web python popular_dados.py
docker compose exec -T gestao_web python gerenciar_frigate.py criar 1
docker compose exec -T gestao_web python gerenciar_yolo.py criar-atualizar 1
docker compose exec -T gestao_web python gerenciar_yolo.py criar-atualizar 2
docker compose exec -T gestao_web python gerenciar_yolo.py criar-atualizar 3
docker compose exec -T gestao_web python gerenciar_yolo.py criar-atualizar 4

# --- ETAPA 4: AJUSTE FINAL DE PERMISSÕES ---
echo "🔒 Ajustando permissões da pasta de scripts para o usuário 'edimar'..."
sudo chown -R edimar:edimar /home/edimar/SISTEMA/GESTAO_WEB/core_scripts/

echo "✅ Sistema reinstalado e configurado com sucesso!"
echo "Verificando status final dos contêineres..."
docker ps
