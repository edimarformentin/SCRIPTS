#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==== SCRIPT 4.10: (stub) GERENCIAR YOLO ===="
# Compatibilidade com instaladores antigos que esperavam YOLO fora dos novos workers.
# Mantém tudo desativado por padrão (o novo stack usa os workers via RabbitMQ).

# Garante flags no .env sem duplicar
grep -q '^YOLO_ENABLED=' .env 2>/dev/null || echo 'YOLO_ENABLED=false' >> .env
grep -q '^YOLO_DEVICE='  .env 2>/dev/null || echo 'YOLO_DEVICE=cpu'   >> .env
grep -q '^YOLO_MODEL='   .env 2>/dev/null || echo 'YOLO_MODEL='       >> .env
grep -q '^YOLO_CONF='    .env 2>/dev/null || echo 'YOLO_CONF=0.5'     >> .env

# Apenas cria diretório de placeholder (sem contêiner extra)
mkdir -p IA/YOLO

echo "==== SCRIPT 4.10 CONCLUÍDO (stub; nenhuma ação necessária) ===="
