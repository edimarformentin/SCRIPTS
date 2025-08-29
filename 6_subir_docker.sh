#!/usr/bin/env bash
# Nome do arquivo: 6_subir_docker.sh (SEM POPULAÇÃO DE DADOS)
set -e

echo "==== SCRIPT 6: SUBIR DOCKER (SEM POPULAÇÃO INICIAL) ===="

# 1. NAVEGAR PARA O DIRETÓRIO DO PROJETO
cd /home/edimar/SISTEMA

# 2. INICIAR OS CONTAINERS COM DOCKER COMPOSE
echo "🚀 Subindo containers com docker compose..."
echo "Isso pode levar alguns minutos na primeira vez..."
docker compose up --build -d

# 3. AGUARDAR O BACKEND ESTAR PRONTO
echo "⏳ Aguardando o serviço de backend (gestao_web) ficar totalmente pronto..."
# O contêiner do backend usa o 'wait-for-it.sh' para esperar o banco, então só precisamos esperar a porta 8000.
# Usamos um loop simples para verificar a porta 8000 do contêiner.
while ! docker compose exec -T gestao_web nc -z localhost 8000; do
    echo "   ... backend ainda não disponível, aguardando 5 segundos..."
    sleep 5
done
echo "✅ Serviço de backend está no ar!"

# 4. EXECUTAR O SCRIPT DE POPULAÇÃO DE DADOS
# echo "📊 Populando o banco de dados com o cliente 'Edimar Formentin' e suas câmeras..."
# Executa o script python dentro do contêiner 'gestao_web' que já tem o ambiente pronto.
# docker compose exec -T gestao_web python popular_dados.py

# 5. SINCRONIZAR O FRIGATE PARA O CLIENTE RECÉM-CRIADO
# echo "🐳 Sincronizando o contêiner Frigate para o cliente (ID=1)..."
# Chama o script de gerenciamento para criar o contêiner do Frigate para o cliente com ID 1
# docker compose exec -T gestao_web python gerenciar_frigate.py criar 1

echo "==== SCRIPT 6 CONCLUÍDO! Sistema no ar (sem seed automático). ===="
