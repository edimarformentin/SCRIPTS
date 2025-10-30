# 📦 Dependências do Sistema VaaS

Este arquivo documenta **TODAS** as dependências do projeto.

**Atualização**: Sempre que adicionar/remover dependência, atualize este arquivo!

---

## 🐍 Python (Backend)

**Arquivo**: `backend/api/requirements.txt`

| Biblioteca | Versão | Propósito |
|------------|--------|-----------|
| fastapi | 0.104.1 | Framework web REST API |
| uvicorn[standard] | 0.24.0 | Servidor ASGI |
| sqlalchemy | 2.0.23 | ORM banco de dados |
| psycopg2-binary | 2.9.9 | Driver PostgreSQL |
| pydantic | 2.5.0 | Validação de dados |
| pydantic-settings | 2.1.0 | Configuração via env vars |
| python-multipart | 0.0.6 | Upload de arquivos |
| python-slugify | 8.0.1 | Geração de slugs |
| psutil | 5.9.8 | Monitoramento de sistema (CPU, RAM, Disco) |
| GitPython | 3.1.40 | Operações Git (commit, push, pull) |
| docker | 7.1.0 | Comunicação com Docker via socket (admin panel) |

### Como Adicionar

```bash
# 1. Adicionar ao requirements.txt
echo "nova-biblioteca==x.y.z" >> backend/api/requirements.txt

# 2. Rebuild container
docker compose build gestao-web

# 3. Atualizar este arquivo (DEPENDENCIES.md)

# 4. Documentar no CHANGELOG.md
```

---

## 🛠️ Ferramentas de Sistema (Backend)

**Arquivo**: `backend/api/Dockerfile`

| Ferramenta | Versão | Propósito | Linha no Dockerfile |
|------------|--------|-----------|---------------------|
| ffmpeg | sistema | Gravação/transcodificação vídeo | ~15 |
| python3.11 | 3.11-slim | Runtime Python | 1 |

### Como Adicionar

```dockerfile
# backend/api/Dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    imagemagick \        # ← NOVA FERRAMENTA
    && rm -rf /var/lib/apt/lists/*
```

---

## 🌐 Frontend (JavaScript)

**Arquivo**: `frontend/public/` (sem package manager)

### Bibliotecas CDN

| Biblioteca | Versão | Propósito | Arquivo |
|------------|--------|-----------|---------|
| HLS.js | 1.4.12 | Reprodução HLS no browser | cameras.html |

### Frameworks

- **Nenhum!** Vanilla JavaScript puro
- Motivo: Simplicidade, sem build step

### Como Adicionar

```html
<!-- frontend/public/cameras.html -->
<script src="https://cdn.jsdelivr.net/npm/nova-lib@x.y.z/dist/nova.min.js"></script>
```

Documente neste arquivo (DEPENDENCIES.md)

---

## 🐳 Docker Images

**Arquivo**: `docker-compose.yml`

| Serviço | Imagem | Versão | Propósito |
|---------|--------|--------|-----------|
| gestao-web | (build local) | - | Backend API |
| gestao-nginx | (build local) | - | Frontend + Proxy |
| mediamtx | bluenviron/mediamtx | latest | Servidor streaming |
| postgres-db | postgres | 15 | Banco de dados |
| gestao-janitor | (build local) | - | Limpeza automática |

### Versões Fixas (Recomendado para Produção)

```yaml
# Ao invés de "latest", use versão fixa:
mediamtx:
  image: bluenviron/mediamtx:1.4.0  # ← Versão específica

postgres-db:
  image: postgres:15.5  # ← Versão específica
```

---

## 🖥️ Sistema Operacional

### Suportado

- Ubuntu 20.04+
- Debian 11+

### Não Testado (mas pode funcionar)

- Ubuntu 18.04 (Docker pode ter problemas)
- Debian 10
- Rocky Linux / AlmaLinux (com ajustes)

### Não Suportado

- CentOS 7 (Docker muito antigo)
- Windows
- macOS (sem GPU NVIDIA)

---

## 🔧 Dependências de Runtime

### Obrigatórias

| Software | Versão Mínima | Propósito | Como Instalar |
|----------|---------------|-----------|---------------|
| Docker | 20.10+ | Containers | `setup.sh` instala |
| Docker Compose | v2.0+ | Orquestração | `setup.sh` instala |
| Bash | 4.0+ | Scripts | Já vem no SO |
| Curl | 7.0+ | Download/testes | `apt install curl` |

### Opcionais

| Software | Versão | Propósito | Como Instalar |
|----------|--------|-----------|---------------|
| NVIDIA Driver | 525+ | Aceleração GPU | Manual (varia por SO) |
| NVIDIA Container Toolkit | 1.14+ | GPU em Docker | `setup.sh` instala |
| Git | 2.0+ | Versionamento | `apt install git` |

---

## 🎮 Hardware

### Mínimo

| Componente | Especificação |
|------------|---------------|
| CPU | 4 cores |
| RAM | 8 GB |
| Disco | 100 GB |
| Rede | 100 Mbps |

### Recomendado

| Componente | Especificação |
|------------|---------------|
| CPU | 8+ cores |
| RAM | 16+ GB |
| Disco | 500+ GB SSD |
| Rede | 1 Gbps |
| GPU | NVIDIA com NVENC (GTX 1050+) |

### GPU NVIDIA (Opcional)

**Propósito**: Transcodificação H.265 acelerada

**Modelos Suportados** (com NVENC):
- GTX 1050 Ti ou superior
- RTX série 20xx, 30xx, 40xx
- Tesla série T4, P4
- Quadro série P

**Drivers**:
- Driver NVIDIA: 525+
- CUDA: 11.8+ (incluído no driver)

**Como Verificar**:
```bash
nvidia-smi
# Deve mostrar sua GPU

docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
# Deve funcionar dentro do container
```

---

## 🌐 Portas de Rede

**Arquivo**: `docker-compose.yml`

| Porta | Protocolo | Serviço | Propósito | Exposta Externamente |
|-------|-----------|---------|-----------|----------------------|
| 80 | HTTP | gestao-nginx | Frontend web | ✅ Sim |
| 8000 | HTTP | gestao-web | API REST | ✅ Sim |
| 8554 | RTSP | mediamtx | Streaming RTSP | ✅ Sim |
| 1935 | RTMP | mediamtx | Ingest RTMP | ✅ Sim |
| 8888 | HTTP | mediamtx | Streaming HLS | ✅ Sim |
| 5432 | PostgreSQL | postgres-db | Banco de dados | ❌ Não (interno) |

### Como Mudar Portas

**Arquivo**: `.env`

```bash
# .env
FRONTEND_PORT=8080      # Ao invés de 80
BACKEND_PORT=9000       # Ao invés de 8000
MEDIAMTX_HLS_PORT=9999  # Ao invés de 8888
```

**Arquivo**: `docker-compose.yml`

```yaml
services:
  gestao-nginx:
    ports:
      - "${FRONTEND_PORT:-80}:80"  # Usa .env ou default 80
```

---

## 📁 Volumes e Diretórios

### Volumes Docker

| Volume | Host | Container | Propósito |
|--------|------|-----------|-----------|
| postgres_data | `./data/postgres` | `/var/lib/postgresql/data` | Dados do banco |
| recordings | `./data/recordings` | `/recordings` | Gravações vídeo |
| mediamtx_config | `./config/mediamtx` | `/mediamtx.yml` | Config MediaMTX (ro) |

### Permissões

```bash
# Gravações: precisa ser writable pelo container
chown -R 1000:1000 data/recordings

# PostgreSQL: gerenciado pelo Docker
# (não precisa alterar)
```

---

## 🔐 Variáveis de Ambiente

**Arquivo**: `.env` (gerado pelo setup.sh)

### Obrigatórias

| Variável | Default | Propósito |
|----------|---------|-----------|
| DATABASE_URL | `postgresql://...` | Conexão banco |
| POSTGRES_USER | `postgres` | Usuário DB |
| POSTGRES_PASSWORD | `postgres` | Senha DB |
| POSTGRES_DB | `vaas_db` | Nome DB |

### Opcionais

| Variável | Default | Propósito |
|----------|---------|-----------|
| CORS_ORIGINS | `*` | CORS origins permitidos |
| RECORDINGS_PATH | `/recordings` | Path gravações |
| SEGMENT_DURATION_SECONDS | `120` | Duração segmentos |
| RETENTION_DAYS | `30` | Dias retenção |
| NVIDIA_VISIBLE_DEVICES | `all` | GPUs visíveis |

### Como Adicionar Nova Variável

```python
# 1. backend/api/app/core/config.py
class Settings(BaseSettings):
    nova_config: str = Field(default="valor")  # ← NOVA

# 2. .env.example
NOVA_CONFIG=valor

# 3. Documentar aqui (DEPENDENCIES.md)

# 4. Documentar no README.md
```

---

## 🗄️ Banco de Dados

### PostgreSQL

**Versão**: 15

**Extensões**: Nenhuma (apenas PostgreSQL padrão)

**Schema**: Veja `migrations/`

### Tabelas

| Tabela | Propósito | Colunas Principais |
|--------|-----------|-------------------|
| clientes | Clientes do sistema | id (UUID), nome, slug |
| cameras | Câmeras | id (UUID), cliente_id, nome, protocolo, endpoint, ativo, transcode_to_h265 |

### Índices

```sql
-- Principais índices
CREATE INDEX idx_cameras_cliente ON cameras(cliente_id);
CREATE INDEX idx_cameras_ativo ON cameras(ativo);
CREATE INDEX idx_cameras_protocolo ON cameras(protocolo);
```

### Como Adicionar Tabela

```sql
-- 1. migrations/XXX-nome.sql
CREATE TABLE nova_tabela (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ...
);

-- 2. backend/api/app/models.py
class NovaTabela(Base):
    __tablename__ = "nova_tabela"
    ...

-- 3. Documentar aqui (DEPENDENCIES.md)
```

---

## 🔄 Dependências Entre Serviços

```
Frontend (gestao-nginx)
    ↓ depende de
Backend (gestao-web)
    ↓ depende de
PostgreSQL (postgres-db)

Backend (gestao-web)
    ↓ usa
MediaMTX (mediamtx)

Janitor (gestao-janitor)
    ↓ acessa
Recordings (volume)
```

### Ordem de Inicialização

1. **postgres-db** (primeiro)
2. **mediamtx** (paralelo)
3. **gestao-web** (aguarda postgres)
4. **gestao-nginx** (aguarda gestao-web)
5. **gestao-janitor** (paralelo, opcional)

**Arquivo**: `docker-compose.yml`

```yaml
depends_on:
  postgres-db:
    condition: service_healthy  # ← Aguarda health check
```

---

## 🧪 Dependências de Desenvolvimento

### Para Desenvolvedores

| Ferramenta | Propósito | Como Instalar |
|------------|-----------|---------------|
| Git | Versionamento | `apt install git` |
| VS Code | Editor | Download do site |
| Python 3.11+ | Testes locais | `apt install python3.11` |
| Docker Desktop | Dev local (Win/Mac) | Download do site |
| Postman/Insomnia | Testes API | Download do site |

### Não Obrigatórias

- Node.js (não usado, frontend é vanilla JS)
- npm/yarn (não usado)
- Webpack/Vite (não usado, sem build)

---

## 📊 Dependências por Feature

### Streaming Ao Vivo

- MediaMTX
- HLS.js (frontend)
- FFmpeg (se transcodificar)

### Gravação

- FFmpeg
- PostgreSQL
- Volume Docker (`recordings`)

### Transcodificação H.265

- NVIDIA GPU
- NVIDIA Driver
- NVIDIA Container Toolkit
- FFmpeg com NVENC

### Player Web

- HLS.js
- Nginx

### API REST

- FastAPI
- Uvicorn
- SQLAlchemy
- PostgreSQL

---

## 🔍 Como Verificar Dependências

### Backend

```bash
# Python libraries
docker exec gestao-web pip list

# System tools
docker exec gestao-web ffmpeg -version
docker exec gestao-web python --version
```

### Frontend

```bash
# Nginx
docker exec gestao-nginx nginx -v

# Verificar se HLS.js carrega
curl -I https://cdn.jsdelivr.net/npm/hls.js@latest/dist/hls.min.js
```

### Database

```bash
# PostgreSQL version
docker exec postgres-db psql -U postgres -c "SELECT version();"

# Listar tabelas
docker exec postgres-db psql -U postgres -d vaas_db -c "\dt"
```

### Hardware

```bash
# GPU
nvidia-smi

# CPU
lscpu

# RAM
free -h

# Disco
df -h
```

---

## 🚨 Dependências Críticas (Não Remova!)

Estas dependências são **essenciais** para o sistema funcionar:

### Backend
- ✅ FastAPI (API framework)
- ✅ SQLAlchemy (ORM)
- ✅ Psycopg2 (PostgreSQL driver)
- ✅ FFmpeg (gravação)

### Frontend
- ✅ Nginx (servidor web)
- ✅ HLS.js (reprodução vídeo)

### Infraestrutura
- ✅ Docker
- ✅ Docker Compose
- ✅ PostgreSQL 15

---

## 📝 Checklist: Adicionando Dependência

Quando adicionar nova dependência:

- [ ] Adicionar ao arquivo correto (requirements.txt, Dockerfile, etc)
- [ ] Especificar versão: `biblioteca==x.y.z`
- [ ] Testar rebuild: `docker compose build`
- [ ] Testar em servidor limpo: `bash setup.sh`
- [ ] Atualizar este arquivo (DEPENDENCIES.md)
- [ ] Documentar no README.md (se relevante para usuário)
- [ ] Documentar no CHANGELOG.md
- [ ] Commit: `chore: adiciona dependência X`

---

## 🔄 Atualizando Dependências

### Python Libraries

```bash
# 1. Atualizar requirements.txt
vim backend/api/requirements.txt
# biblioteca==x.y.z → biblioteca==x.y.w

# 2. Rebuild
docker compose build gestao-web

# 3. Testar
docker compose up -d gestao-web
docker compose logs gestao-web

# 4. Validar funcionamento

# 5. Atualizar CHANGELOG.md
```

### Docker Images

```bash
# 1. Atualizar docker-compose.yml
vim docker-compose.yml
# postgres:15 → postgres:15.6

# 2. Pull nova imagem
docker compose pull postgres-db

# 3. Recriar container
docker compose up -d postgres-db

# 4. Validar

# 5. Atualizar este arquivo + CHANGELOG.md
```

---

**Última atualização**: 2025-10-30
**Versão do projeto**: 2.0.0
**Total de dependências**: ~20 principais

---

> 💡 **Dica**: Sempre que modificar dependências, teste em servidor limpo com `bash setup.sh` para garantir que instalação ainda funciona!
