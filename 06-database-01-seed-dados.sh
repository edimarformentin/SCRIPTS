#!/bin/bash
# =================================================================
# Script 06-database-01: Seed de Dados (v2.0 - INSERT Direto)
#
# Popula o banco de dados com clientes e câmeras de teste
# usando comandos SQL diretos para garantir 100% de previsibilidade.
# =================================================================
set -e
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 6.1: Populando o banco com dados de teste via INSERT direto (seeding v2.0)..."

# --- IDs e Dados Fixos ---
CLIENTE1_ID="8504e0b5-e90c-4891-be58-22df3330d2ac"
CLIENTE1_ID_LEGIVEL="edimar-mluswn"
CLIENTE2_ID="7484eea9-4abb-4ee0-97ce-c9254f9ee7e6"
CLIENTE2_ID_LEGIVEL="edimar-k5ort6"

# --- Monta o Comando SQL ---
# Usamos 'ON CONFLICT (id) DO NOTHING' para tornar o script idempotente.
# Se os dados já existirem, ele não fará nada e não dará erro.
SQL_COMMAND="
-- Cliente 1
INSERT INTO clientes (id, id_legivel, nome, email, cpf, endereco) VALUES
('$CLIENTE1_ID', '$CLIENTE1_ID_LEGIVEL', 'Edimar Formentin', 'edimar.formentin@unifique.com.br', '07574540977', 'Beco São Gabriel, 69')
ON CONFLICT (id) DO NOTHING;

-- Câmeras do Cliente 1
INSERT INTO cameras (cliente_id, nome_camera, url_rtmp_path, dias_gravacao, detectar_pessoas, detectar_carros) VALUES
('$CLIENTE1_ID', 'cam1', 'live/$CLIENTE1_ID_LEGIVEL/cam1', 1, true, true),
('$CLIENTE1_ID', 'cam2', 'live/$CLIENTE1_ID_LEGIVEL/cam2', 1, true, true),
('$CLIENTE1_ID', 'cam3', 'live/$CLIENTE1_ID_LEGIVEL/cam3', 1, true, true),
('$CLIENTE1_ID', 'cam4', 'live/$CLIENTE1_ID_LEGIVEL/cam4', 1, true, true)
ON CONFLICT (url_rtmp_path) DO NOTHING;

-- Cliente 2
INSERT INTO clientes (id, id_legivel, nome, email, cpf, endereco) VALUES
('$CLIENTE2_ID', '$CLIENTE2_ID_LEGIVEL', 'Edimar Formentin 2', 'edimarformentin@hotmail.com', '07574540975', '69 Casa')
ON CONFLICT (id) DO NOTHING;

-- Câmera do Cliente 2
INSERT INTO cameras (cliente_id, nome_camera, url_rtsp, dias_gravacao, detectar_pessoas, detectar_carros) VALUES
('$CLIENTE2_ID', 'cam1', 'rtsp://admin:b1n2m32019@187.85.161.250:55533/mode=real&idc=1&ids=1', 1, true, true)
ON CONFLICT (url_rtsp) DO NOTHING;
"

# --- Executa o Comando no Contêiner do Banco ---
log "Executando comandos SQL para inserir dados de teste..."
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<< "$SQL_COMMAND"

echo "--- Seed de dados (v2.0) via INSERT direto concluído com sucesso. ---"
