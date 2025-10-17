#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 1.1.2: Configurar Tabela 'clientes' (v3.0)
# =================================================================
echo "--> 1.1.2: Configurando tabela 'clientes' (v3.0)..."

SQL_COMMAND="
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

CREATE OR REPLACE FUNCTION update_changetimestamp_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.data_atualizacao = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_legivel VARCHAR(50) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    endereco TEXT,
    data_criacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS update_clientes_changetimestamp ON clientes;
CREATE TRIGGER update_clientes_changetimestamp
BEFORE UPDATE ON clientes
FOR EACH ROW
EXECUTE PROCEDURE update_changetimestamp_column();
"
echo "    -> Executando SQL para criar a tabela 'clientes'..."
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<< "$SQL_COMMAND"

if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "\dt" | grep -q "clientes"; then
    echo "    -> Tabela 'clientes' configurada com sucesso."
else
    echo "    -> ERRO: Falha ao criar/verificar a tabela 'clientes'."
    exit 1
fi
echo "--- Configuração da tabela 'clientes' concluída."
