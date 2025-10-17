#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 02-database-02: Tabela Câmeras (v3.4 - SINTAXE CORRIGIDA)
# =================================================================
echo "--> 2.2: Configurando tabela 'cameras' (v3.4 - SINTAXE CORRIGIDA)..."

SQL_COMMAND="
DROP TABLE IF EXISTS cameras CASCADE;

CREATE TABLE cameras (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID NOT NULL,
    nome_camera VARCHAR(100) NOT NULL,
    url_rtmp_path VARCHAR(255) UNIQUE,
    url_rtsp VARCHAR(255) UNIQUE,
    dias_gravacao INTEGER NOT NULL CHECK (dias_gravacao >= 1 AND dias_gravacao <= 7),
    detectar_carros BOOLEAN NOT NULL DEFAULT false,
    detectar_pessoas BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    data_criacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cliente
        FOREIGN KEY(cliente_id)
        REFERENCES clientes(id)
        ON DELETE CASCADE,
    CONSTRAINT chk_source_type CHECK (
        (url_rtmp_path IS NOT NULL AND url_rtsp IS NULL) OR
        (url_rtmp_path IS NULL AND url_rtsp IS NOT NULL)
    ),
    UNIQUE (cliente_id, nome_camera)
);

CREATE INDEX IF NOT EXISTS idx_cameras_cliente_id ON cameras(cliente_id);

DROP TRIGGER IF EXISTS update_cameras_changetimestamp ON cameras;
CREATE TRIGGER update_cameras_changetimestamp
BEFORE UPDATE ON cameras
FOR EACH ROW
EXECUTE PROCEDURE update_changetimestamp_column();
"
echo "    -> Executando SQL para recriar a tabela 'cameras' com suporte a RTSP..."

# --- AQUI ESTÁ A CORREÇÃO ---
# Removido o '\' antes de $SQL_COMMAND para permitir a expansão da variável.
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<< "$SQL_COMMAND"

# Verificação final
if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "\d cameras" | grep -q "chk_source_type"; then
    echo "    -> Tabela 'cameras' configurada com sucesso."
else
    echo "    -> ERRO: Falha ao verificar a nova estrutura da tabela 'cameras'."
    exit 1
fi
echo "--- Configuração da tabela 'cameras' (v3.4) concluída."
