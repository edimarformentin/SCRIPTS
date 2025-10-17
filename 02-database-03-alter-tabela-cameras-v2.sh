#!/usr/bin/env bash
set -euo pipefail

source /home/edimar/SCRIPTS/00-configuracao-central.sh

log "Aplicando migrações na tabela cameras (v2)..."

SQL_COMMAND="
BEGIN;

-- Campos novos para playback e validação
ALTER TABLE cameras
    ADD COLUMN IF NOT EXISTS stream_input_url TEXT,
    ADD COLUMN IF NOT EXISTS stream_output_slug TEXT,
    ADD COLUMN IF NOT EXISTS playback_protocol TEXT CHECK (playback_protocol IN ('hls','webrtc','dash','none')) DEFAULT 'hls',
    ADD COLUMN IF NOT EXISTS health_status TEXT CHECK (health_status IN ('unknown','ok','warn','error')) DEFAULT 'unknown',
    ADD COLUMN IF NOT EXISTS last_health_check TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS snapshot_url TEXT,
    ADD COLUMN IF NOT EXISTS recording_days INTEGER DEFAULT 0;

-- Índices úteis
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_cameras_output_slug_unique'
    ) THEN
        EXECUTE 'CREATE UNIQUE INDEX idx_cameras_output_slug_unique ON cameras (client_id, stream_output_slug) WHERE stream_output_slug IS NOT NULL';
    END IF;
END\$\$;

COMMIT;
"

docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<< "\$SQL_COMMAND"

log "Migrações aplicadas com sucesso (v2)."
