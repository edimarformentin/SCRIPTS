#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# _preflight_sanity.sh
# Verifica sintaxe dos scripts, gera compose e valida, e acusa problemas comuns.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPTS_DIR="/home/edimar/SCRIPTS"
SISTEMA_DIR="/home/edimar/SISTEMA"

echo "[SANITY] Validando sintaxe bash (*.sh) ..."
fail=0
while IFS= read -r -d '' f; do
  if ! bash -n "$f" 2>/tmp/sanity.err; then
    echo "  !! Erro de sintaxe em: $f"
    cat /tmp/sanity.err
    fail=1
  fi
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" -print0)

[[ $fail -eq 0 ]] && echo "[SANITY] Sintaxe OK." || { echo "[SANITY] Corrija os erros acima."; exit 1; }

# Gera compose e valida
echo "[SANITY] (re)Gerando docker-compose.yml..."
bash "$SCRIPTS_DIR/05-servicos-docker-compose.sh"

echo "[SANITY] Validando docker-compose.yml..."
if docker compose -f "$SISTEMA_DIR/docker-compose.yml" config >/dev/null 2>/tmp/compose.err; then
  echo "[SANITY] docker-compose.yml OK."
else
  echo "[SANITY] docker-compose.yml inválido:"
  cat /tmp/compose.err
  exit 1
fi

# Dica de permissões do Postgres (bind mount)
if grep -q "data/postgres" "$SISTEMA_DIR/docker-compose.yml"; then
  p="$SISTEMA_DIR/data/postgres"
  mkdir -p "$p"
  perm=$(stat -c "%u:%g %a" "$p" 2>/dev/null || echo "n/a")
  echo "[SANITY] Verificando permissões do volume Postgres: $p -> $perm"
  echo "        Se travar 'unhealthy', rode: bash $SCRIPTS_DIR/_debug_postgres.sh --fix-perms"
fi

echo "[SANITY] Tudo certo. Pode rodar: bash $SCRIPTS_DIR/instalar_sistema.sh"
