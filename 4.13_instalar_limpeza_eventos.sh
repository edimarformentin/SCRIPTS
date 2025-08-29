#!/usr/bin/env bash
set -euo pipefail

echo "----------------------------------------------------------------"
echo "==== SCRIPT 4.13 (v5): INSTALAR LIMPEZA (COM WAIT-FOR-IT) ===="
echo "----------------------------------------------------------------"

CORE_SCRIPTS_DIR="/home/edimar/SISTEMA/GESTAO_WEB/core_scripts"
PY_SCRIPT="$CORE_SCRIPTS_DIR/event_cleaner_host.py"
SERVICE="/etc/systemd/system/event-cleaner.service"
TIMER="/etc/systemd/system/event-cleaner.timer"
WAIT_SCRIPT="/home/edimar/SCRIPTS/wait-for-it.sh" # Script de espera no host
mkdir -p "$CORE_SCRIPTS_DIR"

FRIGATE_BASE_DEFAULT="/home/edimar/SISTEMA/FRIGATE"

# Baixa o script wait-for-it.sh para o host se ele não existir
if [ ! -f "$WAIT_SCRIPT" ]; then
    echo "[4.13] Baixando wait-for-it.sh para o host..."
    sudo curl -o "$WAIT_SCRIPT" https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
    sudo chmod +x "$WAIT_SCRIPT"
fi

echo "[4.13] Gravando script de limpeza em $PY_SCRIPT ..."
cat > "$PY_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, json, argparse
from pathlib import Path
from datetime import datetime, timedelta, timezone

FRIGATE_BASE_PATH = Path(os.environ.get("FRIGATE_BASE", "/home/edimar/SISTEMA/FRIGATE" ))
DB_CACHE_FILE = FRIGATE_BASE_PATH / ".retention_db.json"
VERBOSE = int(os.environ.get("CLEANER_VERBOSE", "1"))

def log(*args):
    if VERBOSE: print(f"[{datetime.now().isoformat()}]", *args, flush=True)

def get_retention_data_from_db(target_camera_id=None):
    retention_map = {}
    try:
        import psycopg2
        conn_str = "dbname='monitoramento' user='monitoramento' host='localhost' password='senha_super_segura' port='5432'"
        with psycopg2.connect(conn_str) as conn:
            with conn.cursor() as cur:
                sql = "SELECT c.unique_id, cam.nome, cam.ia_event_retention_days FROM clientes c JOIN cameras cam ON c.id = cam.cliente_id WHERE cam.detect_enabled = true"
                params = []
                if target_camera_id:
                    sql += " AND cam.id = %s"
                    params.append(target_camera_id)
                cur.execute(sql, tuple(params))
                for row in cur.fetchall():
                    unique_id, cam_nome, retention_days = row
                    cam_nome_sanitizado = "".join(c for c in cam_nome.replace(' ', '_') if c.isalnum() or c == '_')
                    key = f"{unique_id}/events/{cam_nome_sanitizado}"
                    retention_map[key] = retention_days
        log(f"Sucesso ao carregar {len(retention_map)} regras de retenção do banco.")
        if not target_camera_id: DB_CACHE_FILE.write_text(json.dumps(retention_map, indent=2))
        return retention_map
    except Exception as e:
        log(f"[ERRO] Não foi possível conectar ao banco de dados: {e}")
        if DB_CACHE_FILE.exists():
            try: return json.loads(DB_CACHE_FILE.read_text())
            except json.JSONDecodeError: return {}
        return {}

def main():
    parser = argparse.ArgumentParser(description="Limpa eventos de IA antigos.")
    parser.add_argument("--camera-id", type=int, help="ID da câmera específica para limpar.")
    args = parser.parse_args()
    log(f"--- Iniciando limpeza de eventos (Alvo: {'Camera ID '+str(args.camera_id) if args.camera_id else 'Todas'}) ---")
    if not FRIGATE_BASE_PATH.is_dir(): sys.exit(f"[ERRO] Diretório base não encontrado: {FRIGATE_BASE_PATH}")
    retention_rules = get_retention_data_from_db(args.camera_id)
    if not retention_rules: sys.exit("[AVISO] Nenhuma regra de retenção encontrada.")
    now, files_deleted, bytes_deleted = datetime.now(timezone.utc), 0, 0
    for path_key, retention_days in retention_rules.items():
        event_dir = FRIGATE_BASE_PATH / path_key
        if not event_dir.is_dir(): continue
        cutoff_date = now - timedelta(days=retention_days)
        log(f"Processando '{event_dir.relative_to(FRIGATE_BASE_PATH)}' -> Reter {retention_days} dias (apagar antes de {cutoff_date.strftime('%Y-%m-%d')})")
        for f in event_dir.iterdir():
            try:
                file_date = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
                if file_date < cutoff_date:
                    file_size = f.stat().st_size
                    log(f"  -> Apagando: {f.name} (data: {file_date.strftime('%Y-%m-%d')})")
                    f.unlink()
                    files_deleted += 1
                    bytes_deleted += file_size
            except Exception as e: log(f"    [ERRO] Falha ao apagar {f.name}: {e}")
    log(f"--- Limpeza concluída: {files_deleted} arquivos apagados ({bytes_deleted / (1024*1024):.2f} MB liberados) ---")

if __name__ == "__main__": main()
PYEOF
chmod +x "$PY_SCRIPT"

echo "[4.13] Garantindo dependências do sistema para o script de limpeza..."
sudo apt-get update
sudo apt-get install -y python3-psycopg2

echo "[4.13] Criando serviço e timer do systemd (com espera pelo banco)..."
sudo bash -c "cat > '$SERVICE' <<EOF2
[Unit]
Description=Limpador de Eventos de IA Antigos
# Garante que o serviço só rode depois que o Docker estiver no ar
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=$USER
Group=$(id -gn $USER)
Environment=FRIGATE_BASE=${FRIGATE_BASE_DEFAULT}
# Comando de execução agora espera o banco estar disponível em localhost:5432 antes de rodar o script
ExecStart=/bin/bash -c '${WAIT_SCRIPT} localhost:5432 -t 60 -- /usr/bin/python3 ${PY_SCRIPT}'
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF2"

sudo bash -c "cat > '$TIMER' <<'EOF3'
[Unit]
Description=Timer diário para limpeza de eventos de IA antigos

[Timer]
OnBootSec=5min
OnUnitActiveSec=1day
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF3"

echo "[4.13] Recarregando, habilitando e iniciando o timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now event-cleaner.timer

echo "==== SCRIPT 4.13 (v5) CONCLUÍDO ===="
