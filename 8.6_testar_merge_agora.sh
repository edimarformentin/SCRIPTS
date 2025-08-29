#!/usr/bin/env bash
set -euo pipefail
systemctl start event-merge.service || true
sleep 1
echo "== journal (merge) =="
journalctl -u event-merge.service -n 80 --no-pager || true
echo
echo "== arquivos cam2 (após merge) =="
ls -lh /home/edimar/SISTEMA/FRIGATE/edimar-rdk18/events/cam2 | tail -n 50 || true
