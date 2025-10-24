#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# instalar_sistema.sh  — Instalador mestre do VaaS (v2)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

require_root_or_sudo_reexec "$@"

compose_cmd(){ if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi; }

down_if_exists(){
  if [[ -f "$SISTEMA_DIR/docker-compose.yml" ]]; then
    log "Derrubando containers antigos (sem remover volumes)..."
    $(compose_cmd) -f "$SISTEMA_DIR/docker-compose.yml" down --remove-orphans || true
  fi
}

validate_compose(){
  log "Validando docker-compose.yml..."
  $(compose_cmd) -f "$SISTEMA_DIR/docker-compose.yml" config >/dev/null
  ok "docker-compose.yml válido."
}

log "=== VaaS • Instalação/Reconstrução ==="

# 1) Limpeza inicial
down_if_exists

# 2) Dependências + diretórios
bash "$SCRIPTS_DIR/01-setup-dependencias.sh"
bash "$SCRIPTS_DIR/01-setup-estrutura-diretorios.sh"

# 3) Backend/API
bash "$SCRIPTS_DIR/03-api-estrutura-base.sh"
bash "$SCRIPTS_DIR/03-api-schemas-pydantic.sh"
bash "$SCRIPTS_DIR/03-api-logica-crud.sh"
bash "$SCRIPTS_DIR/03-api-endpoints-e-main.sh"

# 4) Frontend
bash "$SCRIPTS_DIR/04-frontend-pagina-clientes.sh"
bash "$SCRIPTS_DIR/04-frontend-pagina-cameras.sh"
bash "$SCRIPTS_DIR/04-frontend-estilos-css.sh"

# 5) Serviços/Configs
bash "$SCRIPTS_DIR/05-servicos-mediamtx-config.sh"
bash "$SCRIPTS_DIR/05-servicos-nginx-config.sh"
bash "$SCRIPTS_DIR/05-servicos-orquestrador-base.sh"
bash "$SCRIPTS_DIR/05-servicos-worker-ia-base.sh"
bash "$SCRIPTS_DIR/05-servicos-janitor-base.sh"
bash "$SCRIPTS_DIR/05-servicos-docker-compose.sh"

validate_compose

# 6) Sobe só Postgres
log "Subindo apenas o Postgres..."
$(compose_cmd) -f "$SISTEMA_DIR/docker-compose.yml" up -d postgres-db

# 7) Aguarda DB ficar pronto (espera real)
export DB_READY_MAX_WAIT="${DB_READY_MAX_WAIT:-1800}"
wait_for_postgres

# 8) Cria DB e tabelas
bash "$SCRIPTS_DIR/02-database-tabela-clientes.sh"
bash "$SCRIPTS_DIR/02-database-tabela-cameras.sh"

# 9) Seed
bash "$SCRIPTS_DIR/06-database-seed-dados.sh"

# 10) Sobe todo o resto
log "Subindo todos os serviços (build)..."
$(compose_cmd) -f "$SISTEMA_DIR/docker-compose.yml" up -d --build

ok "✅ Sistema VaaS pronto!
- Frontend:        http://localhost/
- API (Swagger):   http://localhost:8000/docs
- Healthcheck API: http://localhost:8000/health
- RabbitMQ UI:     http://localhost:15672 (guest/guest)
- HLS (MediaMTX):  http://localhost:8888/    (via proxy nginx: /hls/)
"
