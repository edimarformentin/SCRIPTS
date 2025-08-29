#!/bin/bash
set -e

echo "==== SCRIPT 3: CONFIGURAR SERVIÇO MEDIAMTX ===="
cd /home/edimar/SISTEMA

# Criar arquivo de configuração do MediaMTX
# 1. CRIAR ARQUIVO DE CONFIGURAÇÃO DO MEDIAMTX
cat <<'EOF' > MEDIAMTX/mediamtx.yml
logLevel: info
api: yes

paths:
  all:
    # Permite que qualquer um publique e leia streams por padrão
    # Em produção, considere adicionar autenticação aqui
    source: publisher
    # Em produção, considere adicionar autenticação aqui
EOF

echo "==== SCRIPT 3 CONCLUÍDO! ===="
echo "Configuração do MediaMTX finalizada. Prossiga para o Script 4."
