#!/usr/bin/env bash
set -Eeuo pipefail
SISTEMA_DIR="/home/edimar/SISTEMA"
mkdir -p "$SISTEMA_DIR"
cat > "$SISTEMA_DIR/docker-compose.yml" <<'YML'
services:
  postgres-db:
    image: postgres:16
    container_name: postgres-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres || exit 1"]
      interval: 3s
      timeout: 3s
      start_period: 120s
      retries: 100

  gestao-web:
    build: ./backend/api
    container_name: gestao-web
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres-db:5432/vaas_db
      CORS_ORIGINS: "*"
    depends_on:
      postgres-db:
        condition: service_healthy
    ports:
      - "8000:8000"

  frontend-web:
    image: nginx:1.27-alpine
    container_name: frontend-web
    restart: unless-stopped
    depends_on:
      gestao-web:
        condition: service_started
    ports:
      - "80:80"
    volumes:
      - ./frontend/public:/usr/share/nginx/html:ro
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs/nginx:/var/log/nginx

  mediamtx:
    image: bluenviron/mediamtx:latest
    container_name: mediamtx
    restart: unless-stopped
    volumes:
      - ./config/mediamtx/mediamtx.yml:/mediamtx.yml:ro
      - ./data/mediamtx:/data
    ports:
      - "8554:8554/tcp"
      - "1935:1935/tcp"
      - "8888:8888/tcp"
      - "8889:8889/tcp"

  rabbitmq:
    image: rabbitmq:3.12-management
    container_name: rabbitmq
    restart: unless-stopped
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - ./data/rabbitmq:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD-SHELL", "rabbitmq-diagnostics -q ping || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 60
      start_period: 20s

  orquestrador:
    build: ./servicos/orquestrador
    container_name: orquestrador
    restart: unless-stopped
    environment:
      VAAS_RABBIT_URL: amqp://guest:guest@rabbitmq:5672/
      DATABASE_URL: postgresql://postgres:postgres@postgres-db:5432/vaas_db
    depends_on:
      rabbitmq:
        condition: service_healthy
      gestao-web:
        condition: service_started

  worker-ia:
    build: ./servicos/worker-ia
    container_name: worker-ia
    restart: unless-stopped
    environment:
      VAAS_RABBIT_URL: amqp://guest:guest@rabbitmq:5672/
    depends_on:
      rabbitmq:
        condition: service_healthy

  janitor:
    build: ./servicos/janitor
    container_name: janitor
    restart: unless-stopped
    environment:
      LOG_RETENTION_DAYS: "7"
      LOG_DIR: /logs
      INTERVAL_SEC: "3600"
    volumes:
      - ./logs:/logs

volumes:
  pgdata:
YML
echo "[OK] docker-compose.yml (named volume) gerado."
