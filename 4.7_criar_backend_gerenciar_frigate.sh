#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==== SCRIPT 4.7: GERENCIAR FRIGATE (stub) ===="

# Gera um stub inofensivo para compatibilidade com instaladores antigos.
mkdir -p GESTAO_WEB
cat > GESTAO_WEB/gerenciar_frigate.py <<'PY'
#!/usr/bin/env python3
import sys
print("[gerenciar_frigate] (stub) – fluxo antigo desativado; usando workers via RabbitMQ. Nada a fazer.")
sys.exit(0)
PY
chmod +x GESTAO_WEB/gerenciar_frigate.py

echo "==== SCRIPT 4.7 CONCLUÍDO: criado GESTAO_WEB/gerenciar_frigate.py (stub) ===="
