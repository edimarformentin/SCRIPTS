#!/bin/bash
# Nome do arquivo: 7_popular_dados_iniciais.sh
set -e

echo "==== SCRIPT 7: POPULAR DADOS INICIAIS (CLIENTE E CÂMERAS) ===="

# Navega para o diretório da aplicação web onde o ambiente Python está configurado
cd /home/edimar/SISTEMA/GESTAO_WEB

echo "--> Aguardando o serviço do banco de dados (PostgreSQL) ficar pronto..."
# Usa o mesmo script 'wait-for-it.sh' para garantir que o banco esteja acessível
./wait-for-it.sh banco:5432 -t 60 -- echo "Banco de dados está pronto."

echo "--> Executando script Python para inserir os dados no banco..."
# Executa o script de população de dados dentro do contêiner da aplicação web,
# que já tem todas as dependências (SQLAlchemy, etc.) instaladas.
docker compose exec -T gestao_web python popular_dados.py

echo "--> Sincronizando o contêiner Frigate para o novo cliente..."
# Após criar o cliente e as câmeras, chama o script de gerenciamento para criar o contêiner do Frigate
docker compose exec -T gestao_web python gerenciar_frigate.py criar 1

echo "==== SCRIPT 7 CONCLUÍDO! ===="
