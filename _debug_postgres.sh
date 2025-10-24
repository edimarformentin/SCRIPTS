#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# _debug_postgres.sh
# -----------------------------------------------------------------------------
# Diagnostica por que o postgres-db está "unhealthy" e (opcionalmente)
# corrige permissões do diretório de dados montado.
#
# Uso:
#   bash _debug_postgres.sh
#   bash _debug_postgres.sh --fix-perms         # tenta corrigir chown/chmod
#
# Requisitos: docker, docker compose
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPTS_DIR="/home/edimar/SCRIPTS"
CENTRAL="$SCRIPTS_DIR/00-configuracao-central.sh"
if [[ -f "$CENTRAL" ]]; then source "$CENTRAL"; else
  # fallback mínimo se central não estiver carregável
  DB_CONTAINER="postgres-db"
  SISTEMA_DIR="/home/edimar/SISTEMA"
  DATA_DIR="$SISTEMA_DIR/data"
fi

DATA_PATH="${DATA_DIR}/postgres"
ACTION="${1:-}"

echo "==> Container: $DB_CONTAINER"
echo "==> Data dir:  $DATA_PATH"
echo

echo "== Docker PS (status):"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | (grep -E "^$DB_CONTAINER" || true)
echo

echo "== Health (docker inspect):"
docker inspect -f '{{.State.Health.Status}}' "$DB_CONTAINER" 2>/dev/null || echo "sem health info"
echo

echo "== Últimas linhas do health log:"
docker inspect --format '{{range .State.Health.Log}}{{printf "%s | %s" .Start .Output}}{{println}}{{end}}' "$DB_CONTAINER" 2>/dev/null | tail -n 20 || true
echo

echo "== Logs do Postgres (últimas 200 linhas):"
docker logs --tail 200 "$DB_CONTAINER" 2>&1 || true
echo

echo "== Permissões do diretório de dados (host):"
if [[ -d "$DATA_PATH" ]]; then
  ls -ld "$DATA_PATH" || true
  # Mostra dono numérico também (útil p/ UID 999)
  stat -c "owner=%u group=%g mode=%a" "$DATA_PATH" || true
else
  echo "Diretório $DATA_PATH não existe (a imagem criará na primeira subida)."
fi
echo

echo "== Dentro do container (se subir):"
if docker ps --format '{{.Names}}' | grep -Fxq "$DB_CONTAINER"; then
  docker exec -u root "$DB_CONTAINER" bash -lc 'whoami; id; ls -ld /var/lib/postgresql/data || true' || true
fi
echo

if [[ "$ACTION" == "--fix-perms" ]]; then
  echo "==> Corrigindo permissões (chown 999:999 e chmod 700) no host: $DATA_PATH"
  # Para o container antes de mexer em volume
  (cd "$SISTEMA_DIR" && (docker compose down --remove-orphans || docker-compose down --remove-orphans || true))
  mkdir -p "$DATA_PATH"
  chown -R 999:999 "$DATA_PATH"
  chmod 700 "$DATA_PATH"
  echo "Reiniciando somente o postgres-db..."
  (cd "$SISTEMA_DIR" && (docker compose up -d postgres-db || docker-compose up -d postgres-db))
  echo "Aguardando alguns segundos e rechecando health..."
  sleep 5
  docker inspect -f '{{.State.Health.Status}}' "$DB_CONTAINER" 2>/dev/null || echo "sem health info"
  echo "Pronto. Se ainda estiver 'unhealthy', verifique os logs acima (initdb falhou, cluster antigo, etc.)."
fi

cat <<TXT

DICAS:
- Se os logs mostrarem algo como "data directory ... exists but is not empty" ou
  "FATAL: database files are incompatible with server", o diretório tem lixo antigo
  (ex.: versão diferente de Postgres). Para ambiente NOVO, você pode zerar com:
    bash /home/edimar/SCRIPTS/_wipe_postgres_data.sh   # ⚠️ destrutivo

- Se aparecer "permission denied" dentro do container ao escrever em /var/lib/postgresql/data,
  quase sempre é dona/permissão do host. O --fix-perms acima resolve na maioria dos casos.

TXT
