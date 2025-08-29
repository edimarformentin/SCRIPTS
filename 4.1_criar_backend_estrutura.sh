#!/bin/bash
# Nome do arquivo: 4.1_criar_backend_estrutura.sh
# Função: Cria a estrutura de diretórios para o backend e Frigate.

# Garante que o script pare em caso de erro.
set -Eeuo pipefail

echo "==== SCRIPT 4.1: CRIANDO ESTRUTURA DE DIRETÓRIOS DO BACKEND ===="

# Navega para o diretório raiz do sistema para garantir que as pastas sejam criadas no local correto.
cd /home/edimar/SISTEMA

# Cria as pastas necessárias de forma idempotente.
# O comando 'mkdir -p' não gera erro se as pastas já existirem.
echo "--> Garantindo a existência das pastas: GESTAO_WEB/config, GESTAO_WEB/static, e FRIGATE..."
mkdir -p GESTAO_WEB/config
mkdir -p GESTAO_WEB/static/css
mkdir -p GESTAO_WEB/static/js
mkdir -p FRIGATE

echo "--> Estrutura de diretórios criada com sucesso."
echo "==== SCRIPT 4.1 CONCLUÍDO ===="
