#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

log "Aplicando padronização dos botões Ao vivo (data-acao e data-id) v6.1..."

ARQ="$FRONTEND_DIR/templates/cameras.html"

# 1) Converte padrões com onclick="verAoVivo(...)" para data-acao + data-id
#    (duplas e simples, além de possível variante ver_ao_vivo)
sed -i 's/ onclick="verAoVivo([^"]*)"/ data-acao="ver-ao-vivo" data-id="{{ camera.id }}"/g' "$ARQ"
sed -i "s/ onclick='verAoVivo([^']*)'/ data-acao=\"ver-ao-vivo\" data-id=\"{{ camera.id }}\"/g" "$ARQ"
sed -i 's/ onclick="ver_ao_vivo([^"]*)"/ data-acao="ver-ao-vivo" data-id="{{ camera.id }}"/g' "$ARQ"
sed -i "s/ onclick='ver_ao_vivo([^']*)'/ data-acao=\"ver-ao-vivo\" data-id=\"{{ camera.id }}\"/g" "$ARQ"

# 2) Para elementos que já possuem data-acao="ver-ao-vivo" mas ainda não têm data-id, insere antes do '>'
#    (idempotente: só adiciona quando não existe data-id na MESMA linha)
sed -i '/data-acao="ver-ao-vivo"/{/data-id=/! s/\(data-acao="ver-ao-vivo"[^>]*\)>/\1 data-id="{{ camera.id }}">/g}' "$ARQ"

# 3) Caso exista variante de contexto de template "cam.id" ao invés de "camera.id",
#    oferecemos um fallback opcional: descomente a linha abaixo para trocar automaticamente.
# sed -i 's/data-id="{{ camera.id }}"/data-id="{{ cam.id }}"/g' "$ARQ"

log "Padronização concluída (v6.1)."
