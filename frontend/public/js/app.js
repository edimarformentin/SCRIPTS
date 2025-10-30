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
