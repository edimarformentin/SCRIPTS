#!/usr/bin/env bash
set -euo pipefail
cd /home/edimar/SCRIPTS

# Garante ordem após scripts existentes
sed -i '/02-database-02-tabela-cameras.sh/a bash 02-database-03-alter-tabela-cameras-v2.sh || exit 1' instalar_sistema.sh

sed -i '/03-api-02-schemas-pydantic.*sh/a bash 03-api-02-schemas-pydantic-v3.8.sh || exit 1' instalar_sistema.sh
sed -i '/03-api-03-logica-crud.*sh/a bash 03-api-03-logica-crud-v3.8.sh || exit 1' instalar_sistema.sh
sed -i '/03-api-04-endpoints-e-main.*sh/a bash 03-api-04-endpoints-e-main-v3.8.sh || exit 1' instalar_sistema.sh

sed -i '/04-frontend-02-pagina-cameras.*sh/a bash 04-frontend-02-pagina-cameras-v6.0.sh || exit 1' instalar_sistema.sh

sed -i '/05-servicos-02-orquestrador-base.*sh/a bash 05-servicos-02-orquestrador-base-v2.7.sh || exit 1' instalar_sistema.sh
sed -i '/05-servicos-05-nginx-config.*sh/a bash 05-servicos-05-nginx-config-v1.2.sh || true' instalar_sistema.sh

# utilitário de validação (não crítico)
if ! grep -q "07-validacao-01-streams-mediamtx-v1.4.sh" instalar_sistema.sh; then
  sed -i '$ a bash 07-validacao-01-streams-mediamtx-v1.4.sh || true' instalar_sistema.sh
fi

echo "Patch de instalador aplicado (v3.8)."
