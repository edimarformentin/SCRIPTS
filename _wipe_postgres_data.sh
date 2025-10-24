#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# _wipe_postgres_data.sh
# -----------------------------------------------------------------------------
# ZERA o diretório de dados do Postgres do projeto. USE com cuidado!
# Ideal apenas em ambiente novo/sem dados.
#
# Uso:
#   CONFIRM=YES bash _wipe_postgres_data.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPTS_DIR="/home/edimar/SCRIPTS"
CENTRAL="$SCRIPTS_DIR/00-configuracao-central.sh"
if [[ -f "$CENTRAL" ]]; then source "$CENTRAL"; else
  DB_CONTAINER="postgres-db"
  SISTEMA_DIR="/home/edimar/SISTEMA"
  DATA_DIR="$SISTEMA_DIR/data"
fi
DATA_PATH="${DATA_DIR}/postgres"

if [[ "${CONFIRM:-NO}" != "YES" ]]; then
  echo "ABORTADO. Para confirmar, rode: CONFIRM=YES bash $0"
  exit 1
fi

echo "Parando containers..."
(cd "$SISTEMA_DIR" && (docker compose down --remove-orphans || docker-compose down --remove-orphans || true))

echo "Zerando diretório: $DATA_PATH"
rm -rf "${DATA_PATH:?}/"*

echo "Recriando permissões..."
mkdir -p "$DATA_PATH"
chown -R 999:999 "$DATA_PATH"
chmod 700 "$DATA_PATH"

echo "Subindo apenas postgres-db..."
(cd "$SISTEMA_DIR" && (docker compose up -d postgres-db || docker-compose up -d postgres-db))

echo "Feito. Aguarde a inicialização (pode levar alguns segundos) e reexecute o instalador."
