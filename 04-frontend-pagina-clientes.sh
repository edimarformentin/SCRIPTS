#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 04-frontend-pagina-clientes.sh (public/)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  ensure_dirs "$FRONTEND_DIR/public" "$FRONTEND_DIR/public/js"

  # index.html
  cat > "$FRONTEND_DIR/public/index.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>VaaS • Gestão de Clientes</title>
  <link rel="stylesheet" href="/css/style.css" />
</head>
<body>
<div class="container">
  <h1>VaaS • Gestão de Clientes</h1>
  <nav class="nav">
    <a href="/index.html">Clientes</a>
    <a href="/cameras.html">Câmeras</a>
  </nav>

  <section class="panel">
    <h2 style="margin-top:0">Novo Cliente</h2>
    <div class="form-grid">
      <div><label>Nome</label><input id="nome" /></div>
      <div><label>Documento</label><input id="documento" /></div>
      <div><label>Email</label><input id="email" type="email" /></div>
      <div><label>Telefone</label><input id="telefone" /></div>
    </div>
    <div style="margin-top:10px">
      <button id="salvar">Salvar</button>
    </div>
  </section>

  <section class="panel">
    <h2 style="margin-top:0">Clientes</h2>
    <table class="table" id="tbl">
      <thead>
        <tr><th>Nome</th><th>Documento</th><th>Email</th><th>Status</th><th>Ações</th></tr>
      </thead>
      <tbody id="tbody"><tr><td colspan="5" class="empty">Carregando...</td></tr></tbody>
    </table>
  </section>
</div>

<div id="toast" class="toast"></div>
<script defer src="/js/app.js"></script>
</body>
</html>
HTML

  # js/app.js
  cat > "$FRONTEND_DIR/public/js/app.js" <<'JS'
const API = "/api";

const toast = (msg, ms=2200) => {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  setTimeout(()=>t.classList.remove("show"), ms);
};

async function fetchJSON(path, opt={}){
  const res = await fetch(API+path, {headers:{"Content-Type":"application/json"}, ...opt});
  if(!res.ok) throw new Error(await res.text());
  return res.json();
}

async function loadClients(){
  const tbody = document.getElementById("tbody");
  try{
    const data = await fetchJSON("/clients");
    if(!data.length){
      tbody.innerHTML = `<tr><td colspan="5" class="empty">Nenhum cliente.</td></tr>`;
      return;
    }
    tbody.innerHTML = data.map(c=>`
      <tr>
        <td>${c.nome}</td>
        <td>${c.documento}</td>
        <td>${c.email ?? "-"}</td>
        <td>${c.status}</td>
        <td>
          <button class="secondary" data-del="${c.id}">Remover</button>
        </td>
      </tr>
    `).join("");
  }catch(e){
    tbody.innerHTML = `<tr><td colspan="5" class="empty">Falha ao carregar: ${e.message}</td></tr>`;
  }
}

async function createClient(){
  const payload = {
    nome: document.getElementById("nome").value.trim(),
    documento: document.getElementById("documento").value.trim(),
    email: document.getElementById("email").value.trim() || null,
    telefone: document.getElementById("telefone").value.trim() || null,
  };
  if(!payload.nome || !payload.documento){
    toast("Preencha nome e documento."); return;
  }
  try{
    await fetchJSON("/clients", {method:"POST", body: JSON.stringify(payload)});
    toast("Cliente criado!");
    document.getElementById("nome").value="";
    document.getElementById("documento").value="";
    document.getElementById("email").value="";
    document.getElementById("telefone").value="";
    await loadClients();
  }catch(e){
    toast("Erro: "+e.message);
  }
}

document.getElementById("salvar").addEventListener("click", createClient);

document.getElementById("tbody").addEventListener("click", async (ev)=>{
  const id = ev.target?.dataset?.del;
  if(!id) return;
  if(!confirm("Remover cliente?")) return;
  try{
    const res = await fetch(API+"/clients/"+id, {method:"DELETE"});
    if(res.status === 204){ toast("Removido."); loadClients(); }
    else toast("Falha ao remover.");
  }catch(e){ toast("Erro: "+e.message); }
});

loadClients();
JS

  ok "Frontend (clientes) gravado em public/."
}
main "$@"
