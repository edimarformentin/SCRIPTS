#!/bin/bash
# Script para reiniciar MediaMTX (chamado pela API)
cd /home/edimar/SISTEMA
docker compose restart mediamtx > /dev/null 2>&1
