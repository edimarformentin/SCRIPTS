#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 02-database-tabela-cameras.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main() {
  wait_for_postgres         # agora usa DB_READY_MAX_WAIT (900s default)
  ensure_database_exists

  log "Aplicando schema da tabela 'cameras'..."
  sql_exec <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.cameras (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id    UUID NOT NULL,
  nome          VARCHAR(255) NOT NULL,
  protocolo     VARCHAR(8)  NOT NULL CHECK (protocolo IN ('RTSP','RTMP','HLS')),
  endpoint      VARCHAR(1024) NOT NULL,
  ativo         BOOLEAN NOT NULL DEFAULT TRUE,
  stream_key    VARCHAR(128),
  resolucao     VARCHAR(32),
  fps           INT CHECK (fps IS NULL OR fps > 0),
  bitrate_kbps  INT CHECK (bitrate_kbps IS NULL OR bitrate_kbps > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_cameras_clientes FOREIGN KEY (cliente_id)
    REFERENCES public.clientes (id) ON DELETE CASCADE,
  CONSTRAINT uq_camera_por_cliente UNIQUE (cliente_id, nome)
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_cameras_set_updated_at') THEN
    CREATE TRIGGER trg_cameras_set_updated_at
      BEFORE UPDATE ON public.cameras
      FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_cameras_cliente   ON public.cameras (cliente_id);
CREATE INDEX IF NOT EXISTS idx_cameras_protocolo ON public.cameras (protocolo);
CREATE INDEX IF NOT EXISTS idx_cameras_ativo     ON public.cameras (ativo);
SQL

  ok "Tabela 'cameras' verificada/criada com sucesso."
}

main "$@"
