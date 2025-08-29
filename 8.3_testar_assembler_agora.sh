#!/usr/bin/env bash
set -euo pipefail
echo "== Forçando uma passada do assembler =="
systemctl start event-assembler.service
sleep 1
echo
echo "== Últimas 80 linhas do journal do service =="
journalctl -u event-assembler.service -n 80 --no-pager || true
echo
echo "== Status do timer =="
systemctl status --no-pager event-assembler.timer || true
