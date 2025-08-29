#!/bin/bash
set -e

echo "==== SCRIPT 2: CONFIGURAR SERVIÇO DO BANCO DE DADOS ===="
cd /home/edimar/SISTEMA

# Criar subpastas para o banco
# 1. CRIAR SUBPASTAS PARA O BANCO
mkdir -p BANCO/{data,init,backup}

# Criar script de inicialização
# 2. CRIAR SCRIPT DE INICIALIZAÇÃO SQL
cat <<'EOF' > BANCO/init/01_init.sql
-- Script de inicialização do banco de dados
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SET timezone = 'America/Sao_Paulo';
EOF

echo "==== SCRIPT 2 CONCLUÍDO! ===="
echo "Estrutura do banco de dados configurada. Prossiga para o Script 3."
