#!/usr/bin/env bash
set -euo pipefail

PRE="${1:-12}"   # segundos antes do snapshot
POST="${2:-12}"  # segundos depois do snapshot
BASE="${3:-/home/edimar/SISTEMA/FRIGATE}"

UNIT_DIR="/etc/systemd/system/event-assembler.service.d"
OVR="$UNIT_DIR/override.conf"

echo "[cfg] PRE=${PRE}s  POST=${POST}s"
echo "[cfg] FRIGATE_BASE=${BASE}"

mkdir -p "$UNIT_DIR"
cat > "$OVR" <<OVR
[Service]
Environment=EVENT_PRESECONDS=${PRE}
Environment=EVENT_POSTSECONDS=${POST}
Environment=FRIGATE_BASE=${BASE}
Environment=EVENT_VERBOSE=0
OVR

echo "[cfg] Drop-in gravado em $OVR"
systemctl daemon-reload
systemctl restart event-assembler.timer
systemctl start event-assembler.service

echo
echo "== Status do timer =="
systemctl status --no-pager event-assembler.timer || true
echo
echo "== Últimas linhas do service =="
journalctl -u event-assembler.service -n 50 --no-pager || true
