#!/bin/bash
# =================================================================
# Script: 05-servicos-01-docker-compose.sh
#
# Propósito:
# Este script gera o arquivo 'docker-compose.yml' principal, que
# define e orquestra todos os serviços (contêineres) que compõem
# o sistema VaaS.
#
# O que ele faz:
# 1. Cria o arquivo .env com as credenciais do banco de dados.
# 2. Gera o docker-compose.yml definindo cada serviço:
#    - postgres-db: O banco de dados PostgreSQL.
#    - rabbitmq: O message broker para comunicação assíncrona.
#    - gestao-web: A API backend FastAPI.
#    - frontend-web: O servidor Nginx que serve a UI e atua como proxy.
#    - mediamtx: O servidor de mídia para ingestão e gravação de vídeo.
#    - worker-ia: O worker que processará os vídeos (lógica futura).
#    - orquestrador: O serviço que sincroniza o DB com o MediaMTX.
#    - janitor: O novo serviço para limpeza de gravações antigas.
# 3. Define as redes, volumes, dependências e portas para cada serviço.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 5.1: Configurando os serviços com Docker Compose (com Janitor)..."
mkdir -p "$GESTAO_WEB_DIR"

cat > "$GESTAO_WEB_DIR/.env" << 'ENV_EOF'
POSTGRES_DB=vaas_db
POSTGRES_USER=vaas_user
POSTGRES_PASSWORD=vaas_strong_password
POSTGRES_HOST=vaas-postgres-db
ENV_EOF

echo "    -> Criando arquivo docker-compose.yml com todos os serviços..."
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
      - ../GRAVACOES:/var/www/recordings:ro
    depends_on: [gestao-web]
    networks: [vaas-network]

  mediamtx:
    image: bluenviron/mediamtx:latest-ffmpeg
    container_name: vaas-mediamtx
    restart: always
    volumes:
      - ../MEDIAMTX/mediamtx.yml:/mediamtx.yml
      - ../GRAVACOES:/recordings
    ports: ["8554:8554", "1935:1935", "9997:9997"]
    networks: [vaas-network]

  worker-ia:
    container_name: vaas-worker-ia
    build: { context: ../WORKER_IA }
    restart: always
    depends_on: [rabbitmq, mediamtx]
    networks: [vaas-network]

  orquestrador:
    container_name: vaas-orquestrador
    build:
      context: ../ORQUESTRADOR
      dockerfile: Dockerfile
    restart: always
    depends_on: [gestao-web, mediamtx]
    networks: [vaas-network]

  # --- NOVO SERVIÇO JANITOR ---
  janitor:
    container_name: vaas-janitor
    build:
      context: ../JANITOR
      dockerfile: Dockerfile
    restart: always
    volumes:
      # Mapeia o mesmo diretório de gravações para que o janitor possa acessá-lo
      - ../GRAVACOES:/recordings
    depends_on:
      # Garante que a API esteja disponível antes de o janitor iniciar
      - gestao-web
    networks: [vaas-network]

COMPOSE_EOF
echo "--- Configuração completa do Docker Compose concluída."
