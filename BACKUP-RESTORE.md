# 📦 Guia de Backup e Restauração - Sistema VaaS

## 🔴 Problema Comum: "Internal Server Error" após restaurar backup

**Causa:** Backups antigos não incluem as correções necessárias nos schemas Pydantic v2.

**Solução:** Execute o script de correção após restaurar!

---

## ✅ Procedimento Correto de Backup

### 1️⃣ Fazer Backup Completo

```bash
# Parar o sistema
cd /home/edimar/SISTEMA
docker compose down

# Criar backup com data e hora
cd /home/edimar
BACKUP_NAME="sistema_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_NAME" SISTEMA/

# Mover para local seguro
mv "$BACKUP_NAME" /seu/local/de/backups/
```

**O que está incluído:**
- ✅ Código da aplicação (frontend + backend)
- ✅ Configurações (docker-compose.yml, .env)
- ✅ Banco de dados PostgreSQL (`data/postgres/`)
- ✅ Gravações de vídeo (`data/recordings/`)
- ✅ Scripts de setup e correção

---

## 🔄 Procedimento Correto de Restauração

### 2️⃣ Restaurar em Novo Servidor

```bash
# 1. Copiar backup para o novo servidor
scp sistema_backup_*.tar.gz usuario@novo-servidor:/home/edimar/

# 2. No novo servidor, extrair
cd /home/edimar
tar -xzf sistema_backup_*.tar.gz

# 3. IMPORTANTE: Executar script de correção
cd SISTEMA
bash fix-schemas.sh

# 4. Subir o sistema
bash setup.sh
```

---

## 🆘 Se Restaurou e Está Dando Erro 500

Não se preocupe! Execute o script de correção:

```bash
cd /home/edimar/SISTEMA

# Aplicar correções
bash fix-schemas.sh

# Reiniciar backend
docker restart gestao-web

# Aguardar 10 segundos
sleep 10

# Testar
curl http://localhost:8000/api/clients
```

---

## 📋 Checklist de Backup Seguro

Antes de fazer backup, verifique:

- [ ] Sistema está parado (`docker compose down`)
- [ ] Pasta `data/postgres/` existe
- [ ] Pasta `data/recordings/` existe (se quiser manter vídeos)
- [ ] Arquivo `.env` existe
- [ ] Schemas corrigidos (`bash fix-schemas.sh` executado)

---

## 🎯 Tipos de Backup

### Backup Mínimo (só banco de dados)
```bash
cd /home/edimar/SISTEMA
docker compose down
tar -czf sistema_db_$(date +%Y%m%d).tar.gz data/postgres/
```

### Backup Médio (código + banco)
```bash
cd /home/edimar
tar -czf sistema_backup_$(date +%Y%m%d).tar.gz \
    SISTEMA/backend/ \
    SISTEMA/frontend/ \
    SISTEMA/docker-compose.yml \
    SISTEMA/.env \
    SISTEMA/setup.sh \
    SISTEMA/fix-schemas.sh \
    SISTEMA/data/postgres/
```

### Backup Completo (tudo)
```bash
cd /home/edimar
tar -czf sistema_full_$(date +%Y%m%d).tar.gz SISTEMA/
```

---

## 🔧 Manutenção Preventiva

Execute periodicamente para garantir que está tudo correto:

```bash
cd /home/edimar/SISTEMA

# Verificar schemas
bash fix-schemas.sh

# Verificar saúde do sistema
docker compose ps
curl http://localhost:8000/health

# Verificar logs
docker logs gestao-web --tail 50
```

---

## ⚠️ IMPORTANTE

1. **Sempre execute `fix-schemas.sh` após restaurar backup antigo**
2. **Teste o sistema após restauração** (acesse http://localhost)
3. **Mantenha múltiplas versões de backup** (últimos 7 dias, por exemplo)
4. **Backups devem ser armazenados fora do servidor** (para segurança)

---

## 📞 Troubleshooting

### Erro: "Internal Server Error" ao listar clientes
```bash
bash fix-schemas.sh
docker restart gestao-web
```

### Erro: "relation 'clientes' does not exist"
```bash
docker compose down
sudo rm -rf data/postgres
bash setup.sh
```

### Erro: Backend não inicia após restore
```bash
docker logs gestao-web --tail 100
# Verifique se schemas estão corretos
bash fix-schemas.sh
docker compose down && docker compose up -d --build
```

---

## ✅ Como Validar Restauração Bem-Sucedida

```bash
# 1. Containers rodando
docker compose ps
# Todos devem estar "Up"

# 2. Backend respondendo
curl http://localhost:8000/health
# Deve retornar: {"status":"ok"}

# 3. Clientes carregando
curl http://localhost:8000/api/clients
# Deve retornar JSON com lista de clientes

# 4. Frontend acessível
curl -I http://localhost
# Deve retornar: HTTP/1.1 200 OK
```

---

**Data da última atualização:** $(date +%Y-%m-%d)
