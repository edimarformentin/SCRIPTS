#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 06-database-seed-dados.sh
# -----------------------------------------------------------------------------
# Popula o banco com clientes e câmeras de teste.
# - Idempotente: usa ON CONFLICT para não duplicar.
# - Não depende de CTEs entre sentenças (evita "relation c1 does not exist").
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh

main(){
  wait_for_postgres
  ensure_database_exists

  log "Inserindo dados iniciais..."

  sql_exec <<'SQL'
-- ============================ CLIENTE 1 ======================================
-- ACME Ltda
INSERT INTO public.clientes (nome, documento, email, telefone, status)
VALUES ('ACME Ltda', '11111111000199', 'contato@acme.local', '+55 11 90000-0000', 'ativo')
ON CONFLICT (documento) DO UPDATE
  SET nome = EXCLUDED.nome,
      email = EXCLUDED.email,
      telefone = EXCLUDED.telefone,
      status = EXCLUDED.status;

-- Câmeras do cliente 1
INSERT INTO public.cameras (cliente_id, nome, protocolo, endpoint, ativo, stream_key, resolucao, fps, bitrate_kbps)
SELECT
  (SELECT id FROM public.clientes WHERE documento='11111111000199'),
  'Entrada', 'RTSP', 'rtsp://camera.acme.local/entrada', TRUE, NULL, '1280x720', 25, 2500
ON CONFLICT (cliente_id, nome) DO NOTHING;

INSERT INTO public.cameras (cliente_id, nome, protocolo, endpoint, ativo, stream_key, resolucao, fps, bitrate_kbps)
SELECT
  (SELECT id FROM public.clientes WHERE documento='11111111000199'),
  'Estoque', 'RTMP', 'rtmp://mediamtx:1935/live/estoque', TRUE, 'estoque123', '1920x1080', 30, 4000
ON CONFLICT (cliente_id, nome) DO NOTHING;

-- ============================ CLIENTE 2 ======================================
-- Beta Cameras
INSERT INTO public.clientes (nome, documento, email, telefone, status)
VALUES ('Beta Cameras', '22222222000188', 'suporte@beta.local', '+55 11 95555-5555', 'ativo')
ON CONFLICT (documento) DO UPDATE
  SET nome = EXCLUDED.nome,
      email = EXCLUDED.email,
      telefone = EXCLUDED.telefone,
      status = EXCLUDED.status;

-- Câmeras do cliente 2
INSERT INTO public.cameras (cliente_id, nome, protocolo, endpoint, ativo, stream_key, resolucao, fps, bitrate_kbps)
SELECT
  (SELECT id FROM public.clientes WHERE documento='22222222000188'),
  'Recepção', 'HLS', 'http://mediamtx:8888/stream/recepcao/index.m3u8', TRUE, NULL, '1280x720', 25, 2500
ON CONFLICT (cliente_id, nome) DO NOTHING;

INSERT INTO public.cameras (cliente_id, nome, protocolo, endpoint, ativo, stream_key, resolucao, fps, bitrate_kbps)
SELECT
  (SELECT id FROM public.clientes WHERE documento='22222222000188'),
  'Pátio', 'RTSP', 'rtsp://camera.beta.local/patio', TRUE, NULL, '1920x1080', 30, 4500
ON CONFLICT (cliente_id, nome) DO NOTHING;
SQL

  ok "Seed aplicado com sucesso."
}

main "$@"
