#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 01-setup-estrutura-diretorios.sh (fix frontend/public/*)
# -----------------------------------------------------------------------------
# - Garante que JS/CSS fiquem dentro de frontend/public/{js,css}
# - Move arquivos antigos (se existirem) de frontend/js e frontend/css
#   para frontend/public/js e frontend/public/css
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  log "Criando árvore em $SISTEMA_DIR ..."

  # pastas base
  ensure_dirs \
    "$BACKEND_DIR" \
    "$API_DIR/app" "$API_DIR/app/core" "$API_DIR/app/schemas" "$API_DIR/app/crud" "$API_DIR/app/routers" "$API_DIR/tests" \
    "$FRONTEND_DIR/public" "$FRONTEND_DIR/public/js" "$FRONTEND_DIR/public/css" "$FRONTEND_DIR/public/assets" \
    "$SERVICOS_DIR/orquestrador" "$SERVICOS_DIR/worker-ia" "$SERVICOS_DIR/janitor" \
    "$CONFIG_DIR/nginx" "$CONFIG_DIR/mediamtx" "$CONFIG_DIR/api" "$CONFIG_DIR/orquestrador" \
    "$COMPOSE_DIR" \
    "$DATA_DIR/postgres" "$DATA_DIR/rabbitmq" "$DATA_DIR/mediamtx" \
    "$LOG_DIR/api" "$LOG_DIR/nginx" "$LOG_DIR/orquestrador" "$LOG_DIR/worker-ia" "$LOG_DIR/janitor" "$LOG_DIR/mediamtx"

  # nunca manter .gitkeep no volume de dados do Postgres
  rm -f "$DATA_DIR/postgres/.gitkeep" 2>/dev/null || true

  # migração: mover js/css "fora de public" para dentro de public
  if [[ -d "$FRONTEND_DIR/js" && -n "$(ls -A "$FRONTEND_DIR/js" 2>/dev/null || true)" ]]; then
    log "Movendo JS de $FRONTEND_DIR/js -> $FRONTEND_DIR/public/js"
    mv -f "$FRONTEND_DIR/js/"* "$FRONTEND_DIR/public/js/" 2>/dev/null || true
    rmdir "$FRONTEND_DIR/js" 2>/dev/null || true
  fi

  if [[ -d "$FRONTEND_DIR/css" && -n "$(ls -A "$FRONTEND_DIR/css" 2>/dev/null || true)" ]]; then
    log "Movendo CSS de $FRONTEND_DIR/css -> $FRONTEND_DIR/public/css"
    mv -f "$FRONTEND_DIR/css/"* "$FRONTEND_DIR/public/css/" 2>/dev/null || true
    rmdir "$FRONTEND_DIR/css" 2>/dev/null || true
  fi

  local readme="$SISTEMA_DIR/README-NAO-EDITE-MANUALMENTE.md"
  [[ -f "$readme" ]] || cat > "$readme" <<'MD'
# Atenção
NÃO edite arquivos aqui manualmente. Tudo em `/home/edimar/SISTEMA`
é gerado pelos scripts em `/home/edimar/SCRIPTS`. Para alterar algo,
edite os scripts e reexecute o instalador.
MD

  ok "Estrutura pronta."
}
main "$@"
