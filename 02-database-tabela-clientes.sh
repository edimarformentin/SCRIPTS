#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 02-database-tabela-clientes.sh
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main() {
  wait_for_postgres         # agora usa DB_READY_MAX_WAIT (900s default)
  ensure_database_exists

  log "Aplicando schema da tabela 'clientes'..."
  sql_exec <<'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS public.clientes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        VARCHAR(255) NOT NULL,
  documento   VARCHAR(32)  NOT NULL UNIQUE,
  email       VARCHAR(255) UNIQUE,
  telefone    VARCHAR(32),
  status      VARCHAR(16)  NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','inativo')),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_clientes_set_updated_at') THEN
    CREATE TRIGGER trg_clientes_set_updated_at
      BEFORE UPDATE ON public.clientes
      FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_clientes_nome   ON public.clientes (nome);
CREATE INDEX IF NOT EXISTS idx_clientes_status ON public.clientes (status);
SQL

  ok "Tabela 'clientes' verificada/criada com sucesso."
}

main "$@"
