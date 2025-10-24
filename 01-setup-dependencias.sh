#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 01-setup-dependencias.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
require_root_or_sudo_reexec "$@"

detect_pkg_manager(){ command -v apt-get &>/dev/null && { echo apt; return; }
                      command -v dnf &>/dev/null && { echo dnf; return; }
                      command -v yum &>/dev/null && { echo yum; return; }
                      command -v pacman &>/dev/null && { echo pacman; return; }
                      echo unknown; }
install_jq(){
  case "$(detect_pkg_manager)" in
    apt) apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends jq ;;
    dnf) dnf install -y jq ;;
    yum) yum install -y epel-release || true; yum install -y jq ;;
    pacman) pacman -Sy --noconfirm jq ;;
    *) err "Instale 'jq' manualmente."; return 1 ;;
  esac
}
install_docker_engine(){
  if ! command -v docker >/dev/null 2>&1; then
    require_cmd curl
    log "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker || true
    systemctl start docker || true
    ok "Docker instalado."
  else ok "Docker ok."; fi
}
ensure_compose(){
  if docker compose version >/dev/null 2>&1; then ok "Compose v2 ok."; return; fi
  if command -v docker-compose >/dev/null 2>&1; then warn "Usando docker-compose v1."; return; fi
  case "$(detect_pkg_manager)" in
    apt) apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin ;;
    dnf) dnf install -y docker-compose-plugin || dnf install -y docker-compose || true ;;
    yum) yum install -y docker-compose-plugin || yum install -y docker-compose || true ;;
    pacman) pacman -Sy --noconfirm docker-compose || true ;;
    *) warn "Compose não instalado automaticamente."; ;;
  esac
  docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1 || { err "Compose ausente."; exit 1; }
  ok "Compose disponível."
}
add_user_to_docker_group(){
  local target="${SUDO_USER:-$USER}"
  getent group docker >/dev/null 2>&1 || groupadd docker
  if id -nG "$target" | grep -qw docker; then ok "Usuário '$target' já no grupo docker."
  else usermod -aG docker "$target" || true; warn "Adicionado '$target' ao grupo docker (faça logout/login)."; fi
}
main(){
  require_cmd bash awk sed grep
  command -v jq >/dev/null 2>&1 || install_jq
  install_docker_engine
  ensure_compose
  add_user_to_docker_group
  docker --version || true
  (docker compose version || docker-compose --version) || true
  ok "Dependências prontas. 🔨🤖🔧"
}
main "$@"
