# 👋 COMECE AQUI - VaaS Project

> **Para: Desenvolvedores, IAs, e qualquer pessoa trabalhando neste projeto**

Este arquivo é o **ponto de entrada** do projeto. Leia primeiro!

---

## 🎯 O Que é Este Projeto?

**VaaS** (Video as a Service) é um sistema completo de gestão de câmeras com:
- ✅ Streaming ao vivo (RTSP, RTMP, HLS)
- ✅ Gravação automática
- ✅ Player web com timeline
- ✅ API REST completa
- ✅ Interface web responsiva

---

## 📚 Documentação Principal (LEIA NA ORDEM!)

### 1️⃣ Sou Usuário - Quero Instalar

Leia nesta ordem:

1. **`README.md`** ← Documentação completa do usuário
   - O que o sistema faz
   - Como instalar
   - Como usar
   - Troubleshooting

2. **`INSTALACAO_RAPIDA.md`** ← Guia rápido de instalação
   - Passo a passo visual
   - 4 passos simples
   - FAQ

3. **`CHECKLIST_INSTALACAO.txt`** ← Checklist imprimível
   - Use para marcar progresso
   - Validação passo a passo

**COMANDO PARA INSTALAR:**
```bash
cd SISTEMA
bash setup.sh
```

---

### 2️⃣ Sou Desenvolvedor - Quero Modificar/Adicionar Features

Leia nesta ordem:

1. **`DEVELOPMENT.md`** ← **LEIA PRIMEIRO!**
   - Como o projeto está organizado
   - Como adicionar features
   - O que atualizar quando modificar código
   - Armadilhas comuns a evitar
   - Fluxo de trabalho recomendado

2. **`.feature-checklist-template.md`** ← Use toda vez que criar feature
   - Template de checklist
   - Copie e preencha para cada feature
   - Não esqueça nenhum passo

3. **`CHANGELOG.md`** ← Histórico de mudanças
   - O que mudou em cada versão
   - Como documentar suas mudanças
   - Versionamento semântico

4. **`ESTRATEGIA_MANUTENCAO.md`** (no diretório pai) ← Filosofia do projeto
   - Por que escolhemos esta abordagem
   - Como manter o projeto saudável
   - O que NÃO fazer

---

### 3️⃣ Sou IA/Assistente - Preciso Entender o Projeto

**PASSO 1**: Leia este arquivo (START_HERE.md) ← você está aqui

**PASSO 2**: Leia a estrutura do projeto (seção abaixo)

**PASSO 3**: Leia estes arquivos na ordem:

1. **`DEVELOPMENT.md`** - Entender organização e regras
2. **`DEPENDENCIES.md`** - Entender todas as dependências
3. **`README.md`** - Entender funcionalidades
4. **`CHANGELOG.md`** - Entender histórico

**PASSO 4**: Quando o usuário pedir para adicionar feature:

1. Consulte `DEVELOPMENT.md` seção "Checklist: Adicionando Nova Feature"
2. Use `.feature-checklist-template.md` como guia
3. Atualize todos os arquivos necessários (requirements.txt, Dockerfile, setup.sh, README.md, etc)
4. Documente no CHANGELOG.md

---

## 📁 Estrutura do Projeto (Mapa Rápido)

```
SISTEMA/                              ← Raiz do projeto
│
├── 📘 START_HERE.md                  ← VOCÊ ESTÁ AQUI
├── 📘 README.md                      ← Docs usuário
├── 📘 DEVELOPMENT.md                 ← Docs desenvolvedor
├── 📘 CHANGELOG.md                   ← Histórico
├── 📘 DEPENDENCIES.md                ← Todas dependências
├── 📘 INSTALACAO_RAPIDA.md           ← Guia rápido
├── 📄 CHECKLIST_INSTALACAO.txt       ← Checklist visual
├── 📝 .feature-checklist-template.md ← Template features
│
├── 🔧 setup.sh                       ← INSTALADOR PRINCIPAL
├── 🐳 docker-compose.yml             ← Orquestração Docker
├── ⚙️  .env.example                  ← Template configuração
├── 🔐 .hardware_info.json            ← Detecção hardware (gerado)
│
├── backend/                          ← CÓDIGO PYTHON
│   └── api/
│       ├── Dockerfile                ← Build backend
│       ├── requirements.txt          ← Dependências Python
│       └── app/
│           ├── main.py               ← Entry point
│           ├── models.py             ← Models SQLAlchemy
│           ├── database.py           ← Config DB
│           ├── core/                 ← Lógica core
│           │   ├── config.py         ← Configurações (env vars)
│           │   └── storage.py        ← Gestão arquivos
│           ├── routers/              ← Endpoints REST
│           │   ├── clients.py        ← API clientes
│           │   ├── cameras.py        ← API câmeras
│           │   ├── recordings.py     ← API gravações
│           │   ├── status.py         ← API status
│           │   ├── sync.py           ← API sync MediaMTX
│           │   ├── srs_callbacks.py  ← Callbacks streaming
│           │   └── hardware.py       ← API hardware
│           ├── services/             ← Serviços
│           │   ├── mediamtx_sync.py  ← Sync MediaMTX
│           │   └── recording/        ← Sistema gravação
│           │       ├── recording_manager.py   ← Manager
│           │       └── recording_worker.py    ← Worker FFmpeg
│           ├── crud/                 ← Operações DB
│           │   ├── crud_client.py
│           │   └── crud_camera.py
│           └── schemas/              ← Schemas Pydantic
│               ├── client_schema.py
│               └── camera_schema.py
│
├── frontend/                         ← CÓDIGO HTML/JS
│   ├── Dockerfile                    ← Build frontend
│   ├── nginx.conf                    ← Config Nginx
│   └── public/
│       ├── index.html                ← Página inicial
│       ├── clientes.html             ← Gestão clientes
│       ├── cameras.html              ← Player + gravações
│       ├── css/
│       │   └── style.css             ← Estilos globais
│       └── js/
│           ├── app.js                ← Lógica compartilhada
│           └── cameras.js            ← Player de vídeo
│
├── config/                           ← CONFIGURAÇÕES
│   └── mediamtx/
│       └── mediamtx.yml              ← Config streaming server
│
├── servicos/                         ← SERVIÇOS AUXILIARES
│   └── janitor/                      ← Limpeza automática
│       ├── janitor.py                ← Script limpeza
│       └── Dockerfile
│
├── migrations/                       ← MIGRATIONS SQL (IMPORTANTE!)
│   ├── 001-initial-schema.sql       ← Schema inicial
│   └── XXX-sua-migration.sql        ← Adicione aqui
│
├── scripts/                          ← Scripts auxiliares
│   └── backup.sh                     ← Backup sistema
│
└── data/                             ← DADOS (gerado em runtime)
    ├── postgres/                     ← Banco dados
    └── recordings/                   ← Gravações vídeo
        └── live/
            └── {cliente}/
                └── {camera}_h264/
                    └── YYYY-MM-DD_HH-MM-SS.mp4
```

---

## 🔑 Arquivos Críticos (Não Mexa Sem Ler Docs!)

### Instalação
- **`setup.sh`** - Instalador principal
  - Modifique se adicionar dependências de sistema
  - Sempre teste em servidor limpo após modificar

### Configuração
- **`docker-compose.yml`** - Orquestração de serviços
  - Modifique se adicionar/remover serviços
  - Documente mudanças no README.md

- **`.env.example`** - Template de variáveis de ambiente
  - Adicione novas variáveis aqui
  - Documente no README.md

### Dependências
- **`backend/api/requirements.txt`** - Dependências Python
  - Adicione bibliotecas Python aqui
  - Use versões específicas: `biblioteca==x.y.z`

- **`backend/api/Dockerfile`** - Build do backend
  - Adicione ferramentas de sistema aqui (ffmpeg, etc)

### Migrations
- **`migrations/*.sql`** - Mudanças no banco
  - SEMPRE crie migration para mudanças no banco
  - NÃO modifique banco manualmente

---

## 🚨 REGRAS DE OURO (Nunca Quebre!)

### ❌ NUNCA:

1. **Editar arquivos dentro do container**
   ```bash
   # ERRADO!
   docker exec gestao-web vim /app/main.py
   ```
   ➡️ Mudanças serão perdidas ao recriar container

2. **Adicionar dependência sem documentar**
   ```python
   # ERRADO!
   import redis  # ← não adicionou ao requirements.txt
   ```
   ➡️ Instalação falhará em servidor novo

3. **Modificar banco manualmente**
   ```bash
   # ERRADO!
   docker exec postgres-db psql -c "ALTER TABLE..."
   ```
   ➡️ Mudanças não serão replicadas em novas instalações

4. **Hardcoded configurações**
   ```python
   # ERRADO!
   DB_HOST = "192.168.1.100"

   # CERTO!
   DB_HOST = os.getenv("DB_HOST", "localhost")
   ```
   ➡️ Não funcionará em ambientes diferentes

5. **Commitar sem testar**
   ```bash
   # ERRADO!
   git commit -m "adiciona feature" && git push
   # (sem testar em servidor limpo)
   ```
   ➡️ Pode quebrar instalações novas

### ✅ SEMPRE:

1. **Edite código fonte**
   ```bash
   vim backend/api/app/main.py
   docker compose restart gestao-web
   ```

2. **Documente dependências**
   ```bash
   # requirements.txt
   redis==5.0.1

   # código
   import redis
   ```

3. **Crie migrations**
   ```bash
   # migrations/004-add-users.sql
   CREATE TABLE users (...);
   ```

4. **Use variáveis de ambiente**
   ```python
   # config.py
   db_host: str = Field(default="localhost")

   # .env
   DB_HOST=192.168.1.100
   ```

5. **Teste em servidor limpo**
   ```bash
   # VM/Container limpo
   bash setup.sh
   # Valida que tudo funciona
   ```

---

## 🎓 Fluxo de Trabalho Típico

### Adicionar Nova Feature

```
1. Leia DEVELOPMENT.md
2. Copie .feature-checklist-template.md para .feature-minha-feature.md
3. Desenvolva feature
4. Atualize dependências (se necessário)
5. Atualize setup.sh (se necessário)
6. Atualize documentação (README.md, CHANGELOG.md)
7. Teste em servidor limpo
8. Commit com mensagem clara
9. Marque checklist como completo
```

### Corrigir Bug

```
1. Identifique bug
2. Edite código fonte
3. Teste fix localmente
4. Teste em servidor limpo
5. Commit: "fix: descrição do bug corrigido"
6. Atualize CHANGELOG.md
```

### Atualizar Documentação

```
1. Identifique o que mudou
2. Atualize README.md (para usuários)
3. Atualize DEVELOPMENT.md (para devs)
4. Atualize CHANGELOG.md (histórico)
5. Commit: "docs: descrição da atualização"
```

---

## 📞 Precisa de Ajuda?

### Tenho Dúvida Sobre...

- **Instalação** → Leia `README.md` ou `INSTALACAO_RAPIDA.md`
- **Desenvolvimento** → Leia `DEVELOPMENT.md`
- **Adicionar feature** → Leia `DEVELOPMENT.md` + `.feature-checklist-template.md`
- **Estrutura projeto** → Veja seção "Estrutura do Projeto" acima
- **Dependências** → Leia `DEPENDENCIES.md`
- **Histórico** → Leia `CHANGELOG.md`
- **Estratégia** → Leia `ESTRATEGIA_MANUTENCAO.md` (pasta pai)

### Comandos Úteis

```bash
# Ver status do sistema
docker compose ps

# Ver logs
docker compose logs -f

# Reiniciar serviço
docker compose restart gestao-web

# Rebuild completo
docker compose down
docker compose up -d --build

# Validar instalação
bash setup.sh

# Backup
bash scripts/backup.sh

# Acessar banco
docker exec -it postgres-db psql -U postgres -d vaas_db

# Ver processos FFmpeg
docker exec gestao-web ps aux | grep ffmpeg
```

---

## 🎯 Resumo: O Que Ler Para Cada Situação

| Eu Quero...                         | Leia Este Arquivo                        |
|-------------------------------------|------------------------------------------|
| Instalar o sistema                  | README.md                                |
| Instalar rapidamente                | INSTALACAO_RAPIDA.md                     |
| Adicionar feature                   | DEVELOPMENT.md                           |
| Entender estrutura                  | START_HERE.md (este arquivo)             |
| Ver histórico                       | CHANGELOG.md                             |
| Entender dependências               | DEPENDENCIES.md                          |
| Entender filosofia                  | ESTRATEGIA_MANUTENCAO.md                 |
| Checklist para nova feature         | .feature-checklist-template.md           |
| Troubleshooting                     | README.md (seção Troubleshooting)        |
| Configurar variáveis                | .env.example                             |

---

## ✅ Checklist Rápido: Estou Pronto?

Antes de começar a trabalhar no projeto, responda:

- [ ] Li este arquivo (START_HERE.md) completo
- [ ] Entendi a estrutura do projeto
- [ ] Sei onde estão as documentações
- [ ] Sei quais arquivos NÃO devo modificar diretamente
- [ ] Sei como testar mudanças (servidor limpo)
- [ ] Sei como documentar mudanças (CHANGELOG.md)

Se respondeu SIM a todos, você está pronto! 🎉

---

**Última atualização**: 2025-10-30
**Versão do projeto**: 2.0.0
**Mantenedor**: Edimar

---

> 💡 **Dica para IAs**: Se o usuário pedir para "adicionar feature X", sempre consulte `DEVELOPMENT.md` primeiro e siga o checklist em `.feature-checklist-template.md`. Não esqueça de atualizar `requirements.txt`, `Dockerfile`, `setup.sh` (se necessário), `README.md` e `CHANGELOG.md`!
