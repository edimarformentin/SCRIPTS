# 📝 Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [2.1.0] - 2025-10-30

### Adicionado

#### Painel de Administração
- **Nova página `admin.html`** - Painel completo de administração do sistema
- **Monitoramento do Sistema**:
  - Status em tempo real: CPU, RAM, Disco
  - Status e uptime dos containers Docker
  - Métricas de uso de recursos

- **Sistema de Backup**:
  - Criar backup COMPLETO do código, configurações E banco de dados (`.tar.gz`)
  - Inclui: código backend, scripts, configurações MediaMTX, **dump SQL do PostgreSQL**
  - Exclui: vídeos (recordings), __pycache__, .git
  - Listar backups existentes com data/hora e tamanho
  - Download de backups
  - Deletar backups antigos
  - Backups salvos em `./backups/SISTEMA_backup_*.tar.gz`
  - **100% confiável**: Extrair backup + executar `setup.sh` = Sistema completo restaurado

- **Integração Git**:
  - Configurar repositório Git (nome, email, remote URL)
  - Inicializar repositório automaticamente se não existir
  - Visualizar status do repositório (branch, modified, untracked)
  - Criar commits com mensagem customizável
  - Push/Pull para remote configurado
  - Histórico dos últimos commits
  - Indicador de commits ahead/behind do remote

- **Visualização de Logs**:
  - Ver logs de qualquer container em tempo real
  - Auto-refresh configurável (5 segundos)
  - Suporte para todos os serviços (backend, frontend, mediamtx, postgres, janitor)
  - Últimas 200 linhas de log

- **Controle de Containers**:
  - Reiniciar containers individuamente via interface
  - Validação de segurança (apenas containers conhecidos)
  - Feedback visual de status

#### Backend - Nova API de Administração
- **Novo router `/api/admin`** com endpoints:
  - `GET /api/admin/system/status` - Status do sistema
  - `POST /api/admin/backup/create` - Criar backup
  - `GET /api/admin/backup/list` - Listar backups
  - `GET /api/admin/backup/download/{filename}` - Download backup
  - `DELETE /api/admin/backup/delete/{filename}` - Deletar backup
  - `GET /api/admin/git/status` - Status Git
  - `GET /api/admin/git/config` - Ver configuração Git
  - `POST /api/admin/git/config` - Salvar configuração Git
  - `POST /api/admin/git/commit` - Criar commit
  - `POST /api/admin/git/push` - Push para remote
  - `POST /api/admin/git/pull` - Pull do remote
  - `GET /api/admin/git/log` - Histórico de commits
  - `GET /api/admin/docker/{service}/logs` - Ver logs de serviço
  - `POST /api/admin/docker/{service}/restart` - Reiniciar serviço

#### Dependências
- **GitPython 3.1.40** - Operações Git (commit, push, pull, log)
- **psutil 5.9.8** (já existente) - Monitoramento de sistema

### Modificado
- `backend/api/app/main.py` - Adicionado import e inclusão do router admin
- `backend/api/requirements.txt` - Adicionado GitPython
- Interface web - Novo link "Admin" no menu de navegação

### Documentação
- `README.md` - Adicionada seção "Painel de Administração"
- `DEPENDENCIES.md` - Documentadas novas dependências
- `CHANGELOG.md` - Esta entrada

---

## [2.0.0] - 2025-10-30

### 🎉 Lançamento Inicial Completo

Primeira versão estável do sistema VaaS (Video as a Service) com instalador autocontido.

### Adicionado

#### Sistema de Instalação
- `setup.sh` - Instalador completo e automático
  - Detecção automática de SO (Ubuntu/Debian)
  - Instalação automática do Docker
  - Detecção e configuração de GPU NVIDIA
  - Criação de estrutura de diretórios
  - Inicialização de banco de dados
  - Dados de demonstração

#### Backend (API FastAPI)
- Sistema de gestão de clientes (CRUD completo)
- Sistema de gestão de câmeras (RTSP, RTMP, HLS)
- Sincronização automática com MediaMTX
- Sistema de gravação automática com FFmpeg
  - Gravação em segmentos de 2 minutos (configurável)
  - Suporte a H.264 (nativo) e H.265 (transcodificação)
  - Auto-start de gravações ao iniciar sistema
  - Detecção automática de hardware (GPU/CPU)
- API de streaming de gravações
  - Suporte a HTTP Range (seek preciso)
  - Streaming otimizado com chunks
- Sistema de limpeza automática (janitor)
  - Remoção de gravações antigas (30 dias padrão)
  - Execução agendada via cron
- Endpoints:
  - `/api/clients` - Gestão de clientes
  - `/api/cameras` - Gestão de câmeras
  - `/api/recordings/{camera_id}` - Listar gravações
  - `/api/recordings/stream/{camera_id}/{filename}` - Stream de gravação
  - `/api/status/cameras` - Status ao vivo das câmeras
  - `/api/sync/mediamtx` - Sincronização manual
  - `/api/hardware` - Informações de hardware

#### Frontend
- Interface web responsiva
- Dashboard de clientes
- Dashboard de câmeras com status ao vivo
- Player de vídeo com:
  - Reprodução de streams ao vivo (HLS)
  - Reprodução de gravações
  - Timeline interativa
  - Navegação entre segmentos
  - Controles completos (play, pause, seek, volume)
  - Fullscreen
  - Picture-in-picture
- Sistema de notificações (toasts)

#### Infraestrutura
- Docker Compose orquestrando 4 serviços:
  - `gestao-web` - Backend FastAPI
  - `gestao-nginx` - Frontend + proxy
  - `mediamtx` - Servidor de streaming
  - `postgres-db` - Banco de dados
- Suporte a NVIDIA GPU para transcodificação
- Volumes persistentes para dados
- Health checks para todos os serviços
- Restart automático de containers

#### Documentação
- `README.md` - Documentação completa do usuário
- `DEVELOPMENT.md` - Guia para desenvolvedores
- `INSTALACAO_RAPIDA.md` - Guia de instalação simplificado
- `CHECKLIST_INSTALACAO.txt` - Checklist visual
- `ESTRATEGIA_MANUTENCAO.md` - Estratégia de manutenção
- `.feature-checklist-template.md` - Template para novas features

### Dependências

#### Backend Python
- FastAPI 0.104.1
- SQLAlchemy 2.0.23
- Psycopg2 2.9.9
- Pydantic 2.5.0
- Python-multipart 0.0.6
- FFmpeg (sistema)

#### Frontend
- Nginx Alpine
- Vanilla JavaScript (sem frameworks)
- HLS.js para reprodução de vídeo

#### Serviços
- PostgreSQL 15
- MediaMTX (latest)
- Docker 24+
- Docker Compose v2

### Banco de Dados

#### Tabelas
- `clientes` - Clientes do sistema
- `cameras` - Câmeras vinculadas a clientes

#### Features
- UUIDs como chave primária
- Triggers automáticos para `updated_at`
- Índices otimizados
- Constraints de validação
- Foreign keys com CASCADE delete

### Segurança

- CORS configurável
- Validação de inputs com Pydantic
- SQL injection protection (SQLAlchemy)
- Sanitização de parâmetros

### Performance

- Streaming com HTTP Range (206 Partial Content)
- Chunks de 64KB para streaming eficiente
- Índices de banco otimizados
- Auto-limpeza de gravações antigas
- Suporte a aceleração por GPU

---

## [Unreleased]

### Planejado

- [ ] Autenticação JWT
- [ ] Sistema de usuários
- [ ] Dashboard com estatísticas
- [ ] Alertas e notificações
- [ ] API de analytics
- [ ] Suporte a múltiplos idiomas
- [ ] Dark mode
- [ ] Exportação de clipes
- [ ] Detecção de movimento
- [ ] Integração com IA (análise de vídeo)

---

## Tipos de Mudanças

- `Adicionado` - Novas funcionalidades
- `Modificado` - Mudanças em funcionalidades existentes
- `Descontinuado` - Funcionalidades que serão removidas
- `Removido` - Funcionalidades removidas
- `Corrigido` - Correções de bugs
- `Segurança` - Correções de vulnerabilidades

---

## Como Adicionar Entradas

Ao fazer uma mudança, adicione na seção `[Unreleased]`:

```markdown
## [Unreleased]

### Adicionado
- Nova feature X que faz Y

### Corrigido
- Bug onde Z acontecia quando...
```

Ao fazer release, mova para nova versão:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Adicionado
- Nova feature X que faz Y

### Corrigido
- Bug onde Z acontecia quando...
```

---

**Formato**: [Keep a Changelog](https://keepachangelog.com/)
**Versionamento**: [Semantic Versioning](https://semver.org/)
