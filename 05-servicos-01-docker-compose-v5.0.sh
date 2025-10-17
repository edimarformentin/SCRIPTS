#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 05-servicos-01: Docker Compose (v5.0 - Adiciona RabbitMQ)
#
# Adiciona o serviço RabbitMQ à composição, preparando o terreno
# para a Fase 3 (Processamento com IA).
# =================================================================

echo "--> 5.1: Configurando os serviços com Docker Compose (v5.0 - Adiciona RabbitMQ)..."

# Garante que os diretórios existam
mkdir -p "$GESTAO_WEB_DIR" "$SISTEMA_DIR/BANCO/data" "$SISTEMA_DIR/MEDIAMTX" "$SISTEMA_DIR/ORQUESTRADOR"

# --- Cria o .env (sem alterações) ---
echo "    -> Recriando arquivo de ambiente .env..."
cat << 'ENV_EOF' > "$GESTAO_WEB_DIR/.env"
POSTGRES_DB=vaas_db
POSTGRES_USER=vaas_user
POSTGRES_PASSWORD=vaas_strong_password
POSTGRES_HOST=vaas-postgres-db
ENV_EOF

# --- Cria o nginx.conf (sem alterações) ---
echo "    -> Recriando arquivo de configuração do Nginx..."
cat << 'NGINX_EOF' > "$GESTAO_WEB_DIR/nginx.conf"
server {
    listen 80;
    server_name localhost;
    location /api/ { proxy_pass http://vaas-gestao-web:8000; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; }
    location / { root /usr/share/nginx/html; index index.html; try_files $uri $uri/ /index.html; }
}
NGINX_EOF

# --- Cria o docker-compose.yml com o novo serviço ---
echo "    -> Criando arquivo docker-compose.yml com o serviço RabbitMQ..."
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks: [vaas-network]

  # --- NOVO SERVIÇO ADICIONADO ---
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: vaas-rabbitmq
    restart: always
    ports:
      - "5672:5672"    # Porta para comunicação dos workers
      - "15672:15672"  # Porta para a interface de gerenciamento web
    networks: [vaas-network]

  gestao-web:
    container_name: vaas-gestao-web
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: always
    env_file: .env
    depends_on:
      postgres-db: { condition: service_healthy }
      rabbitmq: { condition: service_started } # Depende do RabbitMQ para iniciar
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
    ports: ["8554:8554", "1935:1935", "8888:8888", "9997:9997"]
    networks: [vaas-network]

  orquestrador:
    container_name: vaas-orquestrador
    build:
      context: ../ORQUESTRADOR
      dockerfile: Dockerfile
    restart: always
    depends_on: [gestao-web, mediamtx]
    networks: [vaas-network]
COMPOSE_EOF
echo "--- Configuração dos serviços (v5.0 ) com RabbitMQ concluída."
