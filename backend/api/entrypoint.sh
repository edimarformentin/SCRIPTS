#!/bin/bash
set -e

echo "================================================"
echo "Starting Camera Management API (Recording System)"
echo "================================================"

# Aguarda 5 segundos para garantir que MediaMTX e PostgreSQL estão prontos
echo "Waiting for dependencies..."
sleep 5

# Inicia uvicorn (gravações são inicializadas via lifespan event em main.py)
echo "Starting Uvicorn server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
