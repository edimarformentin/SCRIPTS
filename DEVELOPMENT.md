# 🛠️ Guia de Desenvolvimento - VaaS

## 🎯 Para Desenvolvedores

Este documento explica **como adicionar novas features** mantendo o sistema funcional e instalável.

---

## 📋 REGRA DE OURO

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  SEMPRE que adicionar uma feature que precisa de:          │
│                                                             │
│  • Nova dependência Python → Atualizar requirements.txt    │
│  • Nova dependência sistema → Atualizar setup.sh           │
│  • Nova tabela banco → Atualizar setup.sh (SQL)            │
│  • Nova porta → Atualizar docker-compose.yml + README      │
│  • Novo serviço → Atualizar docker-compose.yml             │
│                                                             │
│  SEMPRE teste em servidor limpo antes de commitar!         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 CHECKLIST: Adicionando Nova Feature

Use este checklist **TODA VEZ** que criar uma feature:

### ✅ ANTES DE COMEÇAR

- [ ] Li este documento completo
- [ ] Entendi o que vou modificar
- [ ] Tenho ambiente de teste (VM ou container)

### ✅ DURANTE O DESENVOLVIMENTO

#### 1. Código

- [ ] Código criado/modificado em `backend/` ou `frontend/`
- [ ] Testado localmente com `docker compose up -d --build`
- [ ] Funciona sem erros

#### 2. Dependências Python

Se adicionou biblioteca Python:

- [ ] Adicionei ao `backend/api/requirements.txt`:
  ```
  # Exemplo: adicionar biblioteca para enviar emails
  fastapi-mail==1.4.1
  ```

- [ ] Testei rebuild do container:
  ```bash
  docker compose build gestao-web
  docker compose up -d gestao-web
  ```

- [ ] Container sobe sem erros

#### 3. Dependências do Sistema

Se a feature precisa de ferramenta do sistema (ffmpeg, imagemagick, etc):

- [ ] Adicionei ao `backend/api/Dockerfile`:
  ```dockerfile
  # Exemplo: adicionar imagemagick
  RUN apt-get update && apt-get install -y \
      imagemagick \
      && rm -rf /var/lib/apt/lists/*
  ```

- [ ] Testei rebuild completo

#### 4. Banco de Dados

Se criou nova tabela ou coluna:

- [ ] Criei arquivo SQL em `migrations/`:
  ```bash
  # Exemplo
  touch migrations/004-add-users-table.sql
  ```

- [ ] Documentei migração:
  ```sql
  -- migrations/004-add-users-table.sql
  -- Feature: Sistema de autenticação de usuários
  -- Data: 2025-10-30
  -- Autor: Edimar

  CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );

  CREATE INDEX idx_users_email ON users(email);
  ```

- [ ] Adicionei no `setup.sh` (linha ~240):
  ```bash
  # Aplicar migrações
  if [[ -d "$SISTEMA_DIR/migrations" ]]; then
      for migration in "$SISTEMA_DIR/migrations"/*.sql; do
          docker exec postgres-db psql -U postgres -d vaas_db -f /migrations/$(basename $migration)
      done
  fi
  ```

#### 5. Novas Portas

Se a feature expõe nova porta:

- [ ] Adicionei ao `docker-compose.yml`:
  ```yaml
  services:
    gestao-web:
      ports:
        - "8000:8000"
        - "9000:9000"  # Nova porta
  ```

- [ ] Documentei no `README.md` (seção "Portas")
- [ ] Documentei no `.env.example` se configurável

#### 6. Variáveis de Ambiente

Se a feature usa nova variável:

- [ ] Adicionei ao `.env.example`:
  ```bash
  # Email SMTP
  SMTP_HOST=smtp.gmail.com
  SMTP_PORT=587
  SMTP_USER=seu-email@gmail.com
  SMTP_PASSWORD=sua-senha
  ```

- [ ] Documentei no `README.md`
- [ ] Adicionei default razoável no código (se possível)

### ✅ APÓS DESENVOLVIMENTO

#### 7. Documentação

- [ ] Atualizei `README.md` com:
  - Nova feature nas funcionalidades
  - Como usar
  - Configuração necessária
  - Troubleshooting

- [ ] Atualizei `CHANGELOG.md`:
  ```markdown
  ## [2.2.0] - 2025-10-30
  ### Adicionado
  - Sistema de notificações por email
  - Envio automático de alertas quando câmera fica offline
  ```

#### 8. Testes

- [ ] Testei em servidor limpo:
  ```bash
  # 1. Criar VM/container Ubuntu limpo
  # 2. Copiar pasta SISTEMA
  # 3. Executar bash setup.sh
  # 4. Verificar se feature funciona
  ```

- [ ] Testei sem GPU (se relevante)
- [ ] Testei com GPU (se relevante)
- [ ] Testei com dados existentes (upgrade)

#### 9. Versionamento

- [ ] Fiz commit com mensagem clara:
  ```bash
  git add .
  git commit -m "feat: Adiciona sistema de notificações por email

  - Envia alerta quando câmera fica offline
  - Configurável via SMTP
  - Requer fastapi-mail (requirements.txt atualizado)
  - Nova tabela: email_logs
  "
  ```

- [ ] Incrementei versão (se release):
  - Patch: bug fix (2.1.0 → 2.1.1)
  - Minor: nova feature (2.1.0 → 2.2.0)
  - Major: breaking change (2.1.0 → 3.0.0)

### ✅ VALIDAÇÃO FINAL

- [ ] `bash setup.sh` funciona em servidor limpo
- [ ] Todos containers sobem sem erros
- [ ] Feature funciona conforme esperado
- [ ] Documentação está completa
- [ ] Não quebrou features existentes

---

## 🔧 Tipos Comuns de Modificações

### A. Adicionar Biblioteca Python

**Arquivo**: `backend/api/requirements.txt`

**Exemplo**: Adicionar suporte a WebSockets
```python
# requirements.txt
fastapi[all]==0.104.1
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
python-multipart==0.0.6
websockets==12.0        # ← NOVA
```

**Testar**:
```bash
docker compose build gestao-web
docker compose up -d gestao-web
docker compose logs gestao-web
```

---

### B. Adicionar Ferramenta do Sistema

**Arquivo**: `backend/api/Dockerfile`

**Exemplo**: Adicionar ImageMagick para thumbnails
```dockerfile
FROM python:3.11-slim

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    ffmpeg \
    imagemagick \        # ← NOVA
    && rm -rf /var/lib/apt/lists/*

...
```

**Testar**:
```bash
docker compose build gestao-web
docker exec gestao-web convert --version  # Verificar se instalou
```

---

### C. Adicionar Nova Tabela

**Arquivo**: `migrations/XXX-nome-descritivo.sql`

**Exemplo**: Tabela de usuários
```sql
-- migrations/004-add-users-table.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
```

**Atualizar**: `setup.sh` (adicionar na seção de migrations)

---

### D. Adicionar Novo Serviço Docker

**Arquivo**: `docker-compose.yml`

**Exemplo**: Adicionar Redis para cache
```yaml
services:
  # ... serviços existentes ...

  redis:
    image: redis:7-alpine
    container_name: vaas-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - ./data/redis:/data
    command: redis-server --appendonly yes
```

**Atualizar**:
- `README.md`: Documentar nova porta
- `.env.example`: Adicionar `REDIS_URL=redis://redis:6379`
- `backend/api/requirements.txt`: Adicionar `redis==5.0.1`

---

### E. Adicionar Variável de Configuração

**Arquivos**: `.env.example`, `backend/api/app/core/config.py`

**Exemplo**: Configurar retenção de gravações
```python
# backend/api/app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ... configs existentes ...

    # Nova configuração
    retention_days: int = 30  # ← NOVA (com default)

    class Config:
        env_file = ".env"

settings = Settings()
```

```bash
# .env.example
# Retenção de gravações (dias)
RETENTION_DAYS=30
```

**Documentar** no `README.md`

---

## 🚨 Armadilhas Comuns (EVITE!)

### ❌ NÃO FAÇA:

1. **Editar arquivos diretamente no container**
   ```bash
   # ERRADO
   docker exec gestao-web vim /app/main.py
   ```
   Motivo: Mudanças são perdidas quando container é recriado

2. **Adicionar dependência sem documentar**
   ```python
   # ERRADO: apenas import no código
   import redis
   ```
   Motivo: Instalação falhará em servidor novo

3. **Hardcoded URLs/IPs**
   ```python
   # ERRADO
   SMTP_HOST = "smtp.gmail.com"

   # CERTO
   SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
   ```

4. **Criar tabelas manualmente no psql**
   ```sql
   # ERRADO
   docker exec -it postgres-db psql -U postgres -c "CREATE TABLE..."
   ```
   Motivo: setup.sh não criará a tabela em novas instalações

5. **Modificar portas sem documentar**
   ```yaml
   # ERRADO: mudar porta sem atualizar README
   ports:
     - "9999:8000"  # Não documentado!
   ```

### ✅ FAÇA:

1. **Editar código fonte**
   ```bash
   # CERTO
   vim backend/api/app/main.py
   docker compose restart gestao-web
   ```

2. **Documentar dependências**
   ```bash
   # requirements.txt
   redis==5.0.1

   # código
   import redis
   ```

3. **Usar variáveis de ambiente**
   ```python
   # config.py
   smtp_host: str = Field(default="smtp.gmail.com")

   # .env
   SMTP_HOST=smtp.gmail.com
   ```

4. **Criar migrations SQL**
   ```bash
   # migrations/004-users-table.sql
   CREATE TABLE users (...);

   # setup.sh aplica automaticamente
   ```

5. **Documentar tudo**
   ```markdown
   # README.md
   ## Portas
   - 8000: API Backend
   - 9999: WebSocket Server ← NOVA
   ```

---

## 📚 Arquivos Importantes

```
SISTEMA/
├── setup.sh                    ← Instalador (atualizar se mudar deps)
├── README.md                   ← Docs usuário (sempre atualizar)
├── DEVELOPMENT.md              ← Este arquivo (para devs)
├── CHANGELOG.md                ← Histórico de mudanças
├── .env.example                ← Template de configs
├── docker-compose.yml          ← Orquestração (novos serviços)
├── migrations/                 ← Migrations SQL
│   ├── 001-initial.sql
│   ├── 002-add-transcode.sql
│   └── XXX-sua-migration.sql   ← Novas migrations aqui
├── backend/api/
│   ├── Dockerfile              ← Deps sistema (ffmpeg, etc)
│   ├── requirements.txt        ← Deps Python
│   └── app/
│       ├── core/config.py      ← Configurações (env vars)
│       └── ...
└── frontend/
    └── ...
```

---

## 🧪 Testando em Ambiente Limpo

### Opção 1: Docker Container Ubuntu

```bash
# 1. Criar container Ubuntu limpo
docker run -it --rm \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/SISTEMA:/SISTEMA \
  ubuntu:22.04 bash

# 2. Instalar dependências mínimas
apt-get update
apt-get install -y sudo curl

# 3. Testar instalação
cd /SISTEMA
bash setup.sh

# 4. Validar
docker compose ps
curl http://localhost:8000/health
```

### Opção 2: VM Local (VirtualBox/VMware)

```bash
# 1. Criar VM Ubuntu 22.04
# 2. Copiar pasta SISTEMA
# 3. Executar setup.sh
# 4. Validar funcionamento
```

### Opção 3: Servidor Cloud Temporário

```bash
# 1. Criar droplet/EC2 Ubuntu
# 2. scp SISTEMA para servidor
# 3. bash setup.sh
# 4. Validar
# 5. Destruir servidor
```

---

## 📊 Versionamento Semântico

Siga [SemVer](https://semver.org/): `MAJOR.MINOR.PATCH`

### Quando incrementar:

- **MAJOR** (3.0.0): Mudanças que quebram compatibilidade
  - Remover API endpoint
  - Mudar schema do banco (incompatível)
  - Mudar formato de configuração

- **MINOR** (2.3.0): Nova funcionalidade (compatível)
  - Adicionar endpoint
  - Adicionar tabela
  - Nova feature

- **PATCH** (2.2.1): Correção de bugs
  - Fix de bug
  - Correção de segurança
  - Melhoria de performance

---

## 🎯 Resumo: Fluxo Ideal

```
1. Criar branch: git checkout -b feature/nome
2. Desenvolver feature localmente
3. Atualizar dependências (requirements.txt, Dockerfile, etc)
4. Atualizar setup.sh se necessário
5. Atualizar documentação (README.md, CHANGELOG.md)
6. Testar em ambiente limpo
7. Commit: git commit -m "feat: descrição"
8. Merge: git merge feature/nome
9. Tag: git tag v2.2.0 (se release)
10. Push: git push --tags
```

---

## 💡 Dúvidas?

Se não tiver certeza se precisa atualizar algo:

**PERGUNTE:**
- "Esta mudança precisa de nova dependência?"
- "setup.sh consegue instalar isso automaticamente?"
- "Um servidor limpo vai ter tudo que precisa?"

**TESTE:**
- Execute setup.sh em VM limpa
- Se funcionar, está pronto!
- Se falhar, falta documentar algo

---

**Versão**: 1.0
**Última atualização**: 2025-10-30
