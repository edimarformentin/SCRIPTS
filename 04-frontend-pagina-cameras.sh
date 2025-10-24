#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 04-frontend-pagina-cameras.sh (public/)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  ensure_dirs "$FRONTEND_DIR/public" "$FRONTEND_DIR/public/js"

  # cameras.html
  cat > "$FRONTEND_DIR/public/cameras.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>VaaS • Câmeras</title>
  <link rel="stylesheet" href="/css/cameras.css" />
</head>
<body>
<div class="container">
  <h1>VaaS • Câmeras</h1>
  <nav class="nav">
    <a href="/index.html">Clientes</a>
    <a href="/cameras.html">Câmeras</a>
  </nav>

  <section class="panel">
    <h2 style="margin-top:0">Nova Câmera</h2>
    <div class="form-grid">
      <div><label>Cliente (UUID)</label><input id="cliente_id" placeholder="UUID do cliente" /></div>
      <div><label>Nome</label><input id="nome" /></div>
      <div>
        <label>Protocolo</label>
        <select id="protocolo">
          <option>RTSP</option>
          <option>RTMP</option>
          <option>HLS</option>
        </select>
      </div>
      <div><label>Endpoint</label><input id="endpoint" placeholder="rtsp://... | rtmp://... | http://...m3u8" /></div>
    </div>
    <div style="margin-top:10px">
      <button id="salvar">Salvar</button>
    </div>

    <div class="tabs" style="margin-top:10px">
      <div class="tab active" data-tab="rtsp">RTSP</div>
      <div class="tab" data-tab="rtmp">RTMP</div>
      <div class="tab" data-tab="hls">HLS</div>
    </div>
    <div class="panel player">
      <video id="player" controls muted playsinline></video>
      <small class="muted">Dica: para HLS (.m3u8) no navegador, use HLS.js; já habilitamos no JS.</small>
    </div>
  </section>

  <section class="panel">
    <h2 style="margin-top:0">Câmeras</h2>
    <table class="table" id="tbl">
      <thead>
        <tr><th>Nome</th><th>Cliente</th><th>Protocolo</th><th>Endpoint</th><th>Ativo</th></tr>
      </thead>
      <tbody id="tbody"><tr><td colspan="5" class="empty">Carregando...</td></tr></tbody>
    </table>
  </section>
</div>

<div id="toast" class="toast"></div>
<script src="https://cdn.jsdelivr.net/npm/hls.js@1"></script>
<script defer src="/js/cameras.js"></script>
</body>
</html>
HTML

  # js/cameras.js
  cat > "$FRONTEND_DIR/public/js/cameras.js" <<'JS'
const API = "/api";
const toast = (m,ms=2200)=>{const t=document.getElementById("toast");t.textContent=m;t.classList.add("show");setTimeout(()=>t.classList.remove("show"),ms);};

async function fetchJSON(path,opt={}){
  const res = await fetch(API+path, {headers:{"Content-Type":"application/json"}, ...opt});
  if(!res.ok) throw new Error(await res.text());
  return res.json();
}

async function loadCameras(){
  const tbody = document.getElementById("tbody");
  try{
    const cams = await fetchJSON("/cameras");
    if(!cams.length){ tbody.innerHTML = `<tr><td colspan="5" class="empty">Nenhuma câmera.</td></tr>`; return; }
    tbody.innerHTML = cams.map(c=>`
      <tr data-ep="${c.endpoint}">
        <td>${c.nome}</td>
        <td>${c.cliente_id}</td>
        <td>${c.protocolo}</td>
        <td><a href="#" class="play">${c.endpoint}</a></td>
        <td>${c.ativo ? "Sim":"Não"}</td>
      </tr>
    `).join("");
  }catch(e){
    tbody.innerHTML = `<tr><td colspan="5" class="empty">Falha ao carregar: ${e.message}</td></tr>`;
  }
}

async function createCamera(){
  const payload = {
    cliente_id: document.getElementById("cliente_id").value.trim(),
    nome: document.getElementById("nome").value.trim(),
    protocolo: document.getElementById("protocolo").value.trim(),
    endpoint: document.getElementById("endpoint").value.trim(),
    ativo: true
  };
  if(!payload.cliente_id || !payload.nome || !payload.protocolo || !payload.endpoint){
    toast("Preencha todos os campos."); return;
  }
  try{
    await fetchJSON("/cameras", {method:"POST", body: JSON.stringify(payload)});
    toast("Câmera criada!");
    document.getElementById("nome").value="";
    document.getElementById("endpoint").value="";
    await loadCameras();
  }catch(e){ toast("Erro: "+e.message); }
}

document.getElementById("salvar").addEventListener("click", createCamera);

// Tabs (só visual)
document.querySelectorAll(".tab").forEach(t => t.addEventListener("click", (ev)=>{
  document.querySelectorAll(".tab").forEach(x=>x.classList.remove("active"));
  ev.currentTarget.classList.add("active");
}));

// Player - se endpoint terminar com .m3u8 usa HLS.js; senão tenta setar src direto (RTSP/RTMP não tocam nativo)
function playEndpoint(url){
  const video = document.getElementById("player");
  if (url.endsWith(".m3u8") && window.Hls && Hls.isSupported()){
    const hls = new Hls(); hls.loadSource(url); hls.attachMedia(video); video.play().catch(()=>{});
  } else {
    video.src = url; video.play().catch(()=>{});
  }
}

document.getElementById("tbody").addEventListener("click", ev=>{
  if(!ev.target.classList.contains("play")) return;
  ev.preventDefault();
  const tr = ev.target.closest("tr");
  const url = tr?.dataset?.ep || ev.target.textContent;
  playEndpoint(url);
});

loadCameras();
JS

  ok "Frontend (câmeras) gravado em public/."
}
main "$@"
