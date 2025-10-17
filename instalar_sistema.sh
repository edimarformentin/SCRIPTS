#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}"
PROJECT_ROOT="$(dirname "${SCRIPTS_DIR}")"
: "${SISTEMA_DIR:=${PROJECT_ROOT}/SISTEMA}"
export SISTEMA_DIR SCRIPTS_DIR

STEPS=(
  "00_prereqs.sh"
  "01_fetch_sistema.sh"
  "02_patch_mediamtx.sh"
  "03_patch_ui_gravacoes.sh"
  "00_env_bootstrap.sh"   # <- NOVO: cria/popula .env se faltar
  "00_pull_images.sh"
  "05_compose_up.sh"
  "90_smoketest.sh"       # só com --smoke
)

FLAG_SMOKE=0
for arg in "$@"; do case "$arg" in --smoke) FLAG_SMOKE=1;; *) echo "Parâmetro desconhecido: $arg"; exit 2;; esac; done

log(){ printf "\033[1;36m[INSTALADOR]\033[0m %s\n" "$*"; }
die(){ printf "\033[1;31m[ERRO]\033[0m %s\n" "$*" >&2; exit 1; }
ensure_execs(){ chmod +x "${SCRIPTS_DIR}/"*.sh || true; }

run_step(){
  local f="$1" p="${SCRIPTS_DIR}/${f}"
  [ -x "$p" ] || die "Script não encontrado/executável: ${f} (em ${SCRIPTS_DIR})"
  if [ "${f}" = "90_smoketest.sh" ] && [ "${FLAG_SMOKE}" -ne 1 ]; then log "pulado (--smoke)"; return; fi
  log ">> ${f}"; "$p"; log "<< ${f} OK"
}

main(){ ensure_execs; log "SCRIPTS_DIR=${SCRIPTS_DIR}"; log "SISTEMA_DIR=${SISTEMA_DIR}"; for f in "${STEPS[@]}"; do run_step "$f"; done; log "Pronto 🚀"; }
main "$@"
