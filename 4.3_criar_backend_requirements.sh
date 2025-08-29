#!/bin/bash
# Nome do arquivo: 4.3_criar_backend_requirements.sh
# Função: Cria o arquivo requirements.txt com as dependências Python fixas.

set -Eeuo pipefail

echo "==== SCRIPT 4.3: CRIANDO REQUIREMENTS.TXT DO BACKEND ===="

# Navega para o diretório raiz do sistema.
cd /home/edimar/SISTEMA

echo "--> Gerando GESTAO_WEB/requirements.txt..."

# Usa 'cat' com 'EOF' para escrever o conteúdo do arquivo.
# O arquivo será sobrescrito se já existir, garantindo um estado conhecido.
cat <<'REQUIREMENTS' > GESTAO_WEB/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
jinja2==3.1.2
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
python-multipart==0.0.6
python-dotenv==1.0.0
pydantic-settings==2.1.0
unidecode==1.3.7
PyYAML==6.0.1
docker==7.1.0
httpx==0.27.0
REQUIREMENTS

echo "--> requirements.txt criado com sucesso."
echo "==== SCRIPT 4.3 CONCLUÍDO ===="
