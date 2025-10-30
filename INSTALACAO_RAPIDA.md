# 🚀 Guia de Instalação Rápida - VaaS

## 📦 Você Tem: Pasta SISTEMA

## 🎯 Você Quer: Sistema funcionando em servidor novo

---

## ✅ Solução em 4 Passos:

### **PASSO 1: Copiar pasta para servidor**

```bash
# Do seu PC atual, execute:
scp -r SISTEMA/ usuario@192.168.1.100:/home/usuario/
```

**Alternativas:**
- Via FTP/SFTP (FileZilla, WinSCP)
- Via pendrive (se acesso físico)
- Via Git (se tiver repositório)

---

### **PASSO 2: Conectar no servidor**

```bash
ssh usuario@192.168.1.100
```

---

### **PASSO 3: Executar instalador**

```bash
cd /home/usuario/SISTEMA
bash setup.sh
```

**O script vai perguntar:**

```
Docker não encontrado. Deseja instalar? (s/N): s
GPU NVIDIA detectada. Instalar NVIDIA Container Toolkit? (s/N): s
```

Digite `s` e aperte Enter.

---

### **PASSO 4: Aguardar (~5 minutos)**

Você verá:

```
╔════════════════════════════════════════════════════════════════╗
║              🎥 VaaS - Video as a Service                     ║
║                    Instalador v2.0                             ║
╚════════════════════════════════════════════════════════════════╝

[INFO] Sistema detectado: ubuntu 22.04
[OK]   Docker já está instalado: Docker version 24.0.7
[INFO] Criando arquivo .env...
[OK]   Arquivo .env criado
[INFO] Detectando hardware disponível...
[OK]   Hardware detectado e configurado
[INFO] Criando estrutura de diretórios...
[INFO] Iniciando containers Docker...
[INFO] Aguardando PostgreSQL ficar pronto...
[OK]   PostgreSQL está pronto!
[INFO] Criando tabelas do banco de dados...
[OK]   Tabelas criadas com sucesso
[INFO] Inserindo dados de demonstração...
[OK]   Dados de demonstração inseridos
[INFO] Aguardando backend ficar pronto...
[OK]   Backend está respondendo!

╔════════════════════════════════════════════════════════════════╗
║                  ✅ INSTALAÇÃO CONCLUÍDA!                      ║
╚════════════════════════════════════════════════════════════════╝

🌐 Frontend:     http://localhost
🔌 API Backend:  http://localhost:8000
📚 API Docs:     http://localhost:8000/docs
📹 MediaMTX HLS: http://localhost:8888
💾 Gravações:    /home/usuario/SISTEMA/data/recordings/
```

---

## 🎉 PRONTO! Sistema Instalado!

Abra o navegador e acesse:
```
http://IP-DO-SERVIDOR
```

Exemplo:
```
http://192.168.1.100
```

---

## 🔍 Verificar se está funcionando:

```bash
# Ver containers rodando
docker compose ps

# Saída esperada:
NAME                IMAGE                        STATUS
gestao-web          sistema-gestao-web          Up 2 minutes
gestao-nginx        sistema-gestao-nginx        Up 2 minutes
mediamtx            bluenviron/mediamtx:latest  Up 2 minutes
postgres-db         postgres:15                  Up 2 minutes
```

```bash
# Testar API
curl http://localhost:8000/health

# Saída esperada:
{"status":"ok"}
```

```bash
# Ver logs
docker compose logs -f gestao-web
```

---

## ❓ Perguntas Frequentes

### **Q: Preciso instalar Docker antes?**
**A:** NÃO! O setup.sh instala automaticamente.

### **Q: Funciona em CentOS/RedHat?**
**A:** Atualmente apenas Ubuntu/Debian. Para outros, instale Docker manualmente primeiro.

### **Q: E se eu não tiver GPU NVIDIA?**
**A:** Funciona normalmente! Apenas não terá transcodificação H.265 acelerada.

### **Q: Posso mudar as portas?**
**A:** SIM! Edite o arquivo `.env` antes de rodar `docker compose up -d`:
```bash
# Editar .env
vim .env

# Reiniciar
docker compose down
docker compose up -d
```

### **Q: Como atualizar depois?**
**A:**
```bash
# Opção 1: Git
git pull
docker compose up -d --build

# Opção 2: Copiar nova versão
# Parar sistema
docker compose down

# Substituir arquivos
cp -r SISTEMA_NOVO/* SISTEMA/

# Subir novamente
docker compose up -d --build
```

### **Q: Como fazer backup?**
**A:**
```bash
# Backup do banco
docker exec postgres-db pg_dump -U postgres vaas_db > backup.sql

# Backup das gravações
tar -czf gravacoes-backup.tar.gz data/recordings/

# Backup completo
tar -czf sistema-completo-backup.tar.gz SISTEMA/
```

---

## 🆘 Problemas?

### Erro: "Permission denied"
```bash
# Dar permissão de execução
chmod +x setup.sh
bash setup.sh
```

### Erro: "Docker não está instalando"
```bash
# Instalar manualmente:
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# Fazer logout/login
# Executar setup.sh novamente
```

### Portas já em uso
```bash
# Ver quem está usando a porta 80
sudo netstat -tlnp | grep :80

# Parar serviço conflitante
sudo systemctl stop apache2  # ou nginx

# Executar setup.sh novamente
```

### Containers não sobem
```bash
# Ver logs de erro
docker compose logs

# Limpar tudo e recriar
docker compose down -v
bash setup.sh
```

---

## 📞 Suporte

Se encontrar problemas:

1. Verifique os logs: `docker compose logs`
2. Verifique containers: `docker compose ps`
3. Verifique portas: `sudo netstat -tlnp`
4. Leia o README.md completo na pasta SISTEMA/

---

**Versão**: 1.0
**Última atualização**: $(date +%Y-%m-%d)
