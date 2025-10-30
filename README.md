# 🎥 VaaS - Video as a Service

Sistema completo de gestão de câmeras com streaming ao vivo e gravação automática.

## 📋 Requisitos

- **Sistema Operacional**: Ubuntu 20.04+ ou Debian 11+
- **Hardware Mínimo**:
  - CPU: 4 cores
  - RAM: 8GB
  - Disco: 100GB+ (depende do volume de gravações)
- **Opcional (para transcodificação H.265)**:
  - GPU NVIDIA com suporte a NVENC
  - Drivers NVIDIA instalados

## 🚀 Instalação Rápida

### Método 1: Servidor Limpo (Recomendado)

```bash
# 1. Copiar pasta SISTEMA para o servidor
scp -r SISTEMA usuario@servidor:/home/usuario/

# 2. Entrar na pasta
cd /home/usuario/SISTEMA

# 3. Executar instalador
bash setup.sh
```

O script `setup.sh` irá:
- ✅ Detectar sistema operacional
- ✅ Instalar Docker (se necessário)
- ✅ Instalar NVIDIA Container Toolkit (se GPU disponível)
- ✅ Configurar variáveis de ambiente
- ✅ Criar estrutura de diretórios
- ✅ Subir containers Docker
- ✅ Inicializar banco de dados
- ✅ Inserir dados de demonstração

### Método 2: Docker e Dependências Já Instalados

```bash
cd SISTEMA
docker compose up -d --build
```

## 📁 Estrutura do Projeto

```
SISTEMA/
├── setup.sh                    # Instalador principal
├── docker-compose.yml          # Orquestração de containers
├── .env                        # Variáveis de ambiente (gerado)
├── .hardware_info.json         # Detecção de hardware (gerado)
├── backend/
│   └── api/                    # API FastAPI
│       ├── Dockerfile
│       ├── requirements.txt
│       └── app/
│           ├── main.py         # Entry point
│           ├── models.py       # Models SQLAlchemy
│           ├── database.py     # Configuração DB
│           ├── core/           # Lógica core
│           ├── routers/        # Endpoints REST
│           ├── services/       # Serviços (gravação, sync)
│           └── crud/           # Operações database
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── public/
│       ├── index.html          # Página inicial
│       ├── clientes.html       # Gestão de clientes
│       ├── cameras.html        # Player e gravações
│       └── js/
│           ├── app.js          # Lógica compartilhada
│           └── cameras.js      # Player de vídeo
├── config/
│   └── mediamtx/
│       └── mediamtx.yml        # Configuração servidor streaming
├── servicos/
│   └── janitor/                # Limpeza automática de gravações antigas
├── scripts/                    # Scripts auxiliares
└── data/                       # Dados persistentes (gerado)
    ├── postgres/               # Banco de dados
    └── recordings/             # Gravações de vídeo
        └── live/
            └── {cliente_slug}/
                └── {camera}_h264/ ou {camera}_h265/
```

## 🔧 Configuração

### Variáveis de Ambiente

Edite o arquivo `.env` (gerado automaticamente) para customizar:

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres  # MUDE EM PRODUÇÃO!
POSTGRES_DB=vaas_db

# Portas
FRONTEND_PORT=80
BACKEND_PORT=8000
MEDIAMTX_RTSP_PORT=8554
MEDIAMTX_RTMP_PORT=1935
MEDIAMTX_HLS_PORT=8888

# Gravações
SEGMENT_DURATION_SECONDS=120    # Duração de cada arquivo (2 min)
RETENTION_DAYS=30               # Dias para manter gravações
```

### Transcodificação H.265

Se você tem GPU NVIDIA:

1. O sistema detecta automaticamente
2. No frontend, habilite "Transcodificar para H.265" ao criar/editar câmera
3. Economia de ~40-50% no espaço de armazenamento

## 📹 Uso

### 1. Acessar Interface Web

```
http://seu-servidor
```

### 2. Criar Cliente

1. Vá em "Clientes"
2. Clique "+ Adicionar Cliente"
3. Preencha nome (slug é gerado automaticamente)

### 3. Criar Câmera

1. Vá em "Câmeras"
2. Clique "+ Adicionar Câmera"
3. Escolha:
   - **RTSP**: Para câmeras IP (ex: `rtsp://192.168.1.100:554/stream`)
   - **RTMP**: Para encoders/publicadores (ex: OBS Studio)
   - **HLS**: Para restream de outras fontes

### 4. Publicar Stream (RTMP)

**Usando FFmpeg:**
```bash
ffmpeg -re -i video.mp4 -c copy -f flv \
  rtmp://seu-servidor:1935/live/cliente-slug/nome-camera
```

**Usando OBS Studio:**
- Servidor: `rtmp://seu-servidor:1935/live/cliente-slug/nome-camera`
- Chave: (deixar vazio)

### 5. Assistir Ao Vivo

- **Frontend**: http://seu-servidor → Câmeras → Clicar na câmera
- **HLS Direto**: http://seu-servidor:8888/live/cliente-slug/camera/index.m3u8

### 6. Acessar Gravações

- Vá em "Câmeras"
- Clique em "Ver Gravações"
- Use timeline para navegar entre segmentos

### 7. Painel de Administração

Acesse o painel de administração em `http://seu-servidor/admin.html`

#### Funcionalidades:

**📊 Monitoramento do Sistema**
- Status em tempo real: CPU, RAM, Disco
- Status dos containers Docker
- Uptime do sistema

**💾 Backup**
- Criar backup COMPLETO do sistema (código + configurações + **banco de dados**)
- Inclui: código backend, frontend, scripts, configs, **dump SQL do PostgreSQL**
- Exclui: vídeos (recordings), __pycache__, .git
- Listar backups existentes com data e tamanho
- Download de backups
- Deletar backups antigos
- Backups salvos em `./backups/SISTEMA_backup_YYYYMMDD_HHMMSS.tar.gz`
- **100% confiável**: Extrair backup + executar `setup.sh` = Sistema restaurado completamente

**🔀 Git**
- Configurar repositório Git (nome, email, remote)
- Visualizar status do repositório
- Ver arquivos modificados e não rastreados
- Criar commits
- Push/Pull para remote
- Histórico de commits

**📋 Logs**
- Visualizar logs de qualquer serviço
- Auto-refresh a cada 5 segundos
- Suporte para todos os containers

**🐳 Controle Docker**
- Reiniciar containers individualmente
- Gestão completa dos serviços

## 🛠️ Comandos Úteis

### Gerenciar Containers

```bash
# Ver status
docker compose ps

# Ver logs
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f gestao-web

# Parar tudo
docker compose down

# Reiniciar um serviço
docker compose restart gestao-web

# Recriar containers (após mudanças)
docker compose up -d --build
```

### Acessar Banco de Dados

```bash
docker exec -it postgres-db psql -U postgres -d vaas_db
```

### Ver Processos de Gravação

```bash
docker exec gestao-web ps aux | grep ffmpeg
```

### Limpar Gravações Antigas Manualmente

```bash
docker exec gestao-janitor python3 janitor.py
```

## 📊 API

### Documentação Interativa

```
http://seu-servidor:8000/docs
```

### Principais Endpoints

```bash
# Listar câmeras
GET /api/cameras

# Status das câmeras (online/offline)
GET /api/status/cameras

# Listar gravações de uma câmera
GET /api/recordings/{camera_id}

# Stream de gravação
GET /api/recordings/stream/{camera_id}/{filename}

# Sincronizar câmeras com MediaMTX
POST /api/sync/mediamtx
```

## 🔍 Troubleshooting

### Containers não sobem

```bash
# Ver logs de erro
docker compose logs

# Verificar portas em uso
sudo netstat -tlnp | grep -E '(80|8000|1935|8554|8888|5432)'

# Limpar tudo e recriar
docker compose down -v
docker compose up -d --build
```

### Câmera fica "READY" mas não "ONLINE"

- **RTMP**: Verifique se está publicando na URL correta
- **RTSP**: Verifique credenciais e URL da câmera
- **HLS**: Verifique se a fonte está disponível

```bash
# Testar conexão RTSP
ffprobe -rtsp_transport tcp rtsp://192.168.1.100:554/stream

# Ver logs do MediaMTX
docker logs mediamtx -f
```

### Gravações não aparecem

```bash
# Verificar se FFmpeg está rodando
docker exec gestao-web ps aux | grep ffmpeg

# Ver logs do backend
docker logs gestao-web | grep -i recording

# Verificar permissões
ls -la data/recordings/live/
```

### GPU não está sendo usada

```bash
# Verificar se GPU está acessível no container
docker exec gestao-web nvidia-smi

# Ver encoders disponíveis
docker exec gestao-web ffmpeg -hide_banner -encoders | grep -E '(nvenc|264|265)'

# Verificar .hardware_info.json
cat .hardware_info.json
```

## 🔒 Segurança (Produção)

### 1. Mudar Senhas Padrão

Edite `.env`:
```bash
POSTGRES_PASSWORD=sua_senha_forte_aqui
```

Recrie o container do banco:
```bash
docker compose down postgres-db
docker volume rm sistema_postgres_data
docker compose up -d postgres-db
```

### 2. Usar HTTPS

Configure um proxy reverso (Nginx/Traefik) com Let's Encrypt:

```nginx
server {
    listen 443 ssl http2;
    server_name seu-dominio.com;

    ssl_certificate /etc/letsencrypt/live/seu-dominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/seu-dominio.com/privkey.pem;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
    }
}
```

### 3. Firewall

```bash
# Permitir apenas portas necessárias
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 1935/tcp # RTMP (para publishers)
sudo ufw enable
```

### 4. Limitar Acesso ao Backend

Edite `docker-compose.yml`:
```yaml
services:
  gestao-web:
    ports:
      - "127.0.0.1:8000:8000"  # Apenas localhost
```

## 📦 Backup

### Backup Completo

```bash
#!/bin/bash
BACKUP_DIR="/backups/vaas-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 1. Backup do banco de dados
docker exec postgres-db pg_dump -U postgres vaas_db > "$BACKUP_DIR/database.sql"

# 2. Backup das gravações (últimos 7 dias)
find data/recordings/live -type f -mtime -7 -exec cp --parents {} "$BACKUP_DIR/" \;

# 3. Backup das configurações
cp -r config "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# 4. Comprimir
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup salvo em: $BACKUP_DIR.tar.gz"
```

### Restaurar Backup

```bash
# 1. Extrair backup
tar -xzf backup.tar.gz

# 2. Parar sistema
docker compose down

# 3. Restaurar banco
cat backup/database.sql | docker exec -i postgres-db psql -U postgres -d vaas_db

# 4. Restaurar gravações
cp -r backup/data/recordings/* data/recordings/

# 5. Reiniciar
docker compose up -d
```

## 📈 Monitoramento

### Espaço em Disco

```bash
# Ver tamanho das gravações
du -sh data/recordings/live/*

# Ver gravações por câmera
du -sh data/recordings/live/*/*
```

### Performance

```bash
# CPU e RAM dos containers
docker stats

# Processos no backend
docker top gestao-web
```

## 🤝 Suporte

- **Documentação**: Este README
- **Logs**: `docker compose logs -f`
- **API Docs**: http://localhost:8000/docs

## 📄 Licença

[Insira sua licença aqui]

---

**Versão**: 2.0
**Atualizado**: $(date +%Y-%m-%d)
