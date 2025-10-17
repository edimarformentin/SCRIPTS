#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-01: Docker Compose (v5.2 - Nginx Proxy para HLS)
#
# Remove a porta 8888 exposta do MediaMTX, pois o Nginx
# agora atuará como proxy reverso para os streams HLS.
# =================================================================

echo "--> 5.1: Configurando os serviços com Docker Compose (v5.2 - Nginx Proxy HLS)..."
mkdir -p "$GESTAO_WEB_DIR"

cat > "$GESTAO_WEB_DIR/.env" << 'ENV_EOF'
POSTGRES_DB=vaas_db
POSTGRES_USER=vaas_user
POSTGRES_PASSWORD=vaas_strong_password
POSTGRES_HOST=vaas-postgres-db
ENV_EOF

echo "    -> Criando arquivo docker-compose.yml sem a porta 8888 exposta..."
cat << 'COMPOSE_EOF' > "$GESTAO_WEB_DIR/docker-compose.yml"
version: '3.8'
networks:
  vaas-network:
    driver: bridge
    name: vaas-net
services:
  postgres-db:
    image: postgres:14-alpine
    container_name: vaas-postgres-db
    restart: always
    env_file: .env
    volumes: ["../BANCO/data:/var/lib/postgresql/data"]
    ports: ["5432:5432"]
    healthcheck: {test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"], interval: 10s, timeout: 5s, retries: 5, start_period: 10s}
    networks: [vaas-network]
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: vaas-rabbitmq
    restart: always
    ports: ["5672:5672", "15672:15672"]
    networks: [vaas-network]
  gestao-web:
    container_name: vaas-gestao-web
    build: { context: ./backend }
    restart: always
    env_file: .env
    depends_on: {postgres-db: {condition: service_healthy}, rabbitmq: {condition: service_started}}
    networks: [vaas-network]
  frontend-web:
    image: nginx:1.25-alpine
    container_name: vaas-frontend-web
    restart: always
    ports: ["80:80"]
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./frontend:/usr/share/nginx/html
    depends_on: [gestao-web]
    networks: [vaas-network]
  mediamtx:
    image: bluenviron/mediamtx:latest-ffmpeg
    container_name: vaas-mediamtx
    restart: always
    volumes: ["../MEDIAMTX/mediamtx.yml:/mediamtx.yml"]
    ports: ["8554:8554", "1935:1935", "9997:9997"]
    networks: [vaas-network]
  worker-ia:
    container_name: vaas-worker-ia
    build: { context: ../WORKER_IA }
    restart: always
    depends_on: [rabbitmq, mediamtx]
    networks: [vaas-network]
COMPOSE_EOF
echo "--- Configuração dos serviços (v5.2) concluída."
