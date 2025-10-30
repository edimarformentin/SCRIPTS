#!/bin/bash
# =============================================================================
# init-db.sh - Inicialização Rápida do Banco de Dados
# =============================================================================
# Execute este script sempre que restaurar um backup
# Ele cria/atualiza as tabelas e insere dados demo se necessário
# =============================================================================

set -e

SISTEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SISTEMA_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Inicialização Rápida do Banco de Dados VaaS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Verificar se PostgreSQL está rodando
if ! docker ps | grep -q postgres-db; then
    echo -e "${RED}[ERRO]${NC} Container PostgreSQL não está rodando!"
    echo -e "${BLUE}[INFO]${NC} Execute: docker compose up -d"
    exit 1
fi

# Aguardar PostgreSQL ficar pronto
echo -e "${BLUE}[INFO]${NC} Aguardando PostgreSQL ficar pronto..."
for i in {1..30}; do
    if docker exec postgres-db pg_isready -U postgres &> /dev/null; then
        echo -e "${GREEN}[OK]${NC} PostgreSQL pronto!"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# Copiar script SQL para container
echo -e "${BLUE}[INFO]${NC} Copiando script SQL..."
docker cp "$SISTEMA_DIR/init-database.sql" postgres-db:/tmp/init-database.sql

# Executar script SQL
echo -e "${BLUE}[INFO]${NC} Criando/atualizando tabelas..."
if docker exec postgres-db psql -U postgres -d vaas_db -f /tmp/init-database.sql > /dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Banco de dados inicializado com sucesso!"
else
    echo -e "${RED}[ERRO]${NC} Falha ao inicializar banco de dados"
    exit 1
fi

# Limpar arquivo temporário
docker exec postgres-db rm /tmp/init-database.sql

# Verificar dados
echo ""
echo -e "${BLUE}[INFO]${NC} Verificando dados..."
CLIENTE_COUNT=$(docker exec postgres-db psql -U postgres -d vaas_db -tAc "SELECT COUNT(*) FROM clientes;")
CAMERA_COUNT=$(docker exec postgres-db psql -U postgres -d vaas_db -tAc "SELECT COUNT(*) FROM cameras;")

echo -e "${GREEN}[OK]${NC} Clientes cadastrados: ${CLIENTE_COUNT}"
echo -e "${GREEN}[OK]${NC} Câmeras cadastradas: ${CAMERA_COUNT}"

# Mostrar cliente demo
if [ "$CLIENTE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BLUE}[INFO]${NC} Clientes no sistema:"
    docker exec postgres-db psql -U postgres -d vaas_db -c "SELECT nome, documento, email, status FROM clientes;" | head -10
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ BANCO DE DADOS PRONTO!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}[INFO]${NC} Acesse o frontend: ${GREEN}http://localhost${NC}"
echo -e "${BLUE}[INFO]${NC} Acesse a API: ${GREEN}http://localhost:8000${NC}"
echo ""
