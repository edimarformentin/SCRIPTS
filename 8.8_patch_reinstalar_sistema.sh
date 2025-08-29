#!/usr/bin/env bash
set -euo pipefail
FILE="/home/edimar/SCRIPTS/reinstalar_sistema.sh"
[ -f "$FILE" ] || { echo "[ERRO] $FILE não existe"; exit 1; }

append_if_missing() {
  local file="$1"; shift
  local key="$1"; shift
  local block="$1"; shift
  grep -qF "$key" "$file" || { printf "%s\n" "$block" >> "$file"; echo "[OK] injetado: $key"; }
}

# Garante que 4_criar_backend.sh (já patchado) e 5_criar_frontend.sh rodem
append_if_missing "$FILE" "bash 4_criar_backend.sh" '
--> Executando: 4_criar_backend.sh
bash 4_criar_backend.sh
'
append_if_missing "$FILE" "bash 5_criar_frontend.sh" '
--> Executando: 5_criar_frontend.sh
bash 5_criar_frontend.sh
'

# (Os mestres 4 e 5 já chamam 4.11/4.12, API e 5.6 via patches anteriores)
echo "[OK] reinstalar_sistema.sh patchado."
