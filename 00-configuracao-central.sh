#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 00-configuracao-central.sh  (smart wait + ensure_database_exists fix)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
umask 022

# Cores/log
if [[ -t 1 ]]; then
  C_RESET="\033[0m"; C_YELLOW="\033[33m"; C_RED="\033[31m"; C_GREEN="\033[32m"; C_BLUE="\033[34m"
else
  C_RESET=""; C_YELLOW=""; C_RED=""; C_GREEN=""; C_BLUE=""
fi
ts(){ date +"%Y-%m-%d %H:%M:%S"; }
log(){  echo -e "${C_BLUE}[$(ts)] [INFO]${C_RESET} $*"; }
warn(){ echo -e "${C_YELLOW}[$(ts)] [WARN]${C_RESET} $*"; }
err(){  echo -e "${C_RED}[$(ts)] [ERRO]${C_RESET} $*" >&2; }
ok(){   echo -e "${C_GREEN}[$(ts)] [OK]${C_RESET} $*"; }
trap 'err "Falha na linha $LINENO. Abortando."' ERR

# Paths
export SCRIPTS_DIR="/home/edimar/SCRIPTS"
export SISTEMA_DIR="/home/edimar/SISTEMA"
export BACKEND_DIR="$SISTEMA_DIR/backend"
export API_DIR="$BACKEND_DIR/api"
export FRONTEND_DIR="$SISTEMA_DIR/frontend"
export SERVICOS_DIR="$SISTEMA_DIR/servicos"
export CONFIG_DIR="$SISTEMA_DIR/config"
export COMPOSE_DIR="$SISTEMA_DIR"
export DATA_DIR="$SISTEMA_DIR/data"
export LOG_DIR="$SISTEMA_DIR/logs"

# DB
export DB_CONTAINER="postgres-db"
export DB_NAME="vaas_db"
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_PORT="5432"
export DB_READY_MAX_WAIT="${DB_READY_MAX_WAIT:-900}"

# Utils
require_cmd(){ local m=0; for c in "$@"; do command -v "$c" &>/dev/null || { err "Falta comando: $c"; m=1; }; done; [[ $m -eq 0 ]]; }
require_root_or_sudo_reexec(){ if [[ $EUID -ne 0 ]]; then warn "Reexecutando com sudo..."; exec sudo -E bash "$0" "$@"; fi; }
ensure_dirs(){ for d in "$@"; do mkdir -p "$d"; : > "$d/.gitkeep"; done; }

is_container_running(){ docker ps --format '{{.Names}}' | grep -Fxq "$1"; }
container_health_status(){ docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null || echo "error"; }

wait_for_container(){
  local name="$1" timeout="${2:-60}" start now
  log "Aguardando container '$name' (timeout=${timeout}s)..."
  start=$(date +%s)
  until is_container_running "$name"; do
    sleep 1; now=$(date +%s); (( now-start > timeout )) && { err "Timeout container '$name'"; return 1; }
  done
  ok "Container '$name' em execução."
}
wait_for_container_healthy(){
  local name="$1" timeout="${2:-$DB_READY_MAX_WAIT}" start now st
  st="$(container_health_status "$name")"
  if [[ "$st" == "none" || "$st" == "error" ]]; then
    warn "Sem healthcheck para '$name'; seguindo..."
    return 0
  fi
  log "Aguardando health=healthy em '$name' (timeout=${timeout}s)..."
  start=$(date +%s)
  while true; do
    st="$(container_health_status "$name")"
    [[ "$st" == "healthy" ]] && { ok "Saudável."; return 0; }
    sleep 2; now=$(date +%s); (( now-start > timeout )) && { err "Timeout saúde '$name'"; return 1; }
  done
}
wait_for_postgres(){
  local timeout="${1:-$DB_READY_MAX_WAIT}" start now
  wait_for_container "$DB_CONTAINER" "$timeout"
  wait_for_container_healthy "$DB_CONTAINER" "$timeout" || true
  log "Testando SELECT 1 no Postgres (timeout=${timeout}s)..."
  start=$(date +%s)
  while true; do
    if docker exec -e PGPASSWORD="$DB_PASSWORD" -i "$DB_CONTAINER" \
         psql -U "$DB_USER" -d postgres -tA -c "SELECT 1" >/dev/null 2>&1; then
      ok "Postgres respondeu."
      break
    fi
    sleep 2; now=$(date +%s); (( now-start > timeout )) && { err "Timeout SELECT 1"; return 1; }
  done
}

# *** FIX: criação do DB fora de transação, sem DO/PLPGSQL ***
ensure_database_exists(){
  log "Garantindo database '$DB_NAME'..."
  local timeout="${1:-$DB_READY_MAX_WAIT}" start now
  start=$(date +%s)
  while true; do
    # já existe?
    if docker exec -e PGPASSWORD="$DB_PASSWORD" -i "$DB_CONTAINER" \
      psql -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
      ok "Database '$DB_NAME' já existe."
      return 0
    fi
    # tenta criar (fora de transação)
    if docker exec -e PGPASSWORD="$DB_PASSWORD" -i "$DB_CONTAINER" \
      psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres -c "CREATE DATABASE \"${DB_NAME}\""; then
      ok "Database '$DB_NAME' criado."
      return 0
    fi
    sleep 2; now=$(date +%s); (( now-start > timeout )) && { err "Timeout criando/verificando DB '$DB_NAME'"; return 1; }
  done
}

sql_exec(){
  docker exec -e PGPASSWORD="$DB_PASSWORD" -i "$DB_CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME"
}

export LC_ALL=C.UTF-8 LANG=C.UTF-8
log "Config central carregada. Diretório: $SISTEMA_DIR"
