#!/usr/bin/env bash
set -euo pipefail
log(){ printf "\033[1;36m[03]\033[0m %s\n" "$*"; }

: "${SISTEMA_DIR:?SISTEMA_DIR não definido}"
GW_DIR="${SISTEMA_DIR}/GESTAO_WEB"
ROUTER_DIR="${GW_DIR}/app/routers"
TPL_DIR="${GW_DIR}/app/templates"
MAIN_PY="${GW_DIR}/app/main.py"
REQ_TXT="${GW_DIR}/requirements.txt"

mkdir -p "${ROUTER_DIR}" "${TPL_DIR}"

cat > "${ROUTER_DIR}/gravacoes.py" <<'EOPY'
from fastapi import APIRouter, Query, Request
from fastapi.responses import JSONResponse
from fastapi.templating import Jinja2Templates
from urllib.parse import urlencode
import os, httpx

router = APIRouter(prefix="/gravacoes", tags=["gravacoes"])
templates = Jinja2Templates(directory="SISTEMA/GESTAO_WEB/app/templates")

def _playback_base():
    return os.getenv("MEDIAMTX_PLAYBACK_URL", "http://mediamtx:9996")

def _stream_path(cliente_id: str, camera_id: str) -> str:
    return f"live/{cliente_id}/{camera_id}"

@router.get("", include_in_schema=False)
async def pagina_gravacoes(request: Request, cliente_id: str, camera_id: str):
    return templates.TemplateResponse("gravacoes.html",
      {"request": request, "cliente_id": cliente_id, "camera_id": camera_id})

@router.get("/api/list")
async def listar_janelas(cliente_id: str, camera_id: str,
                         inicio: str | None = Query(None, description="RFC3339"),
                         fim: str | None = Query(None, description="RFC3339")):
    path = _stream_path(cliente_id, camera_id)
    params = {"path": path}
    if inicio: params["start"] = inicio
    if fim: params["end"] = fim
    url = f"{_playback_base()}/list?{urlencode(params)}"
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.get(url)
        r.raise_for_status()
        data = r.json()
    return JSONResponse(data)

@router.get("/api/url")
async def gerar_url_play(cliente_id: str, camera_id: str,
                         inicio: str = Query(..., description="RFC3339 ex: 2025-10-17T12:34:56-03:00"),
                         duracao_seg: float = Query(1800, ge=1, le=86400),
                         formato: str | None = Query("mp4")):
    path = _stream_path(cliente_id, camera_id)
    params = {"path": path, "start": inicio, "duration": duracao_seg}
    if formato: params["format"] = formato
    return JSONResponse({"url": f"{_playback_base()}/get?{urlencode(params)}"})
EOPY

cat > "${TPL_DIR}/gravacoes.html" <<'EOTPL'
{% set titulo = "Gravações" %}
<!doctype html>
<html lang="pt-br">
<head>
  <meta charset="utf-8">
  <title>{{ titulo }}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
  <style>
    :root { --brand:#0ea5e9; --bg-soft:#0b1220; --card:#0f172a; --text:#e2e8f0; --muted:#94a3b8; }
    body { background: var(--bg-soft); color: var(--text); }
    .card { background: var(--card); border: 1px solid rgba(255,255,255,0.08); }
    .btn-brand { background: var(--brand); border: none; }
    .btn-brand:hover { filter: brightness(1.1); }
    .timeline { width:100%; appearance:none; height:6px; border-radius:4px;
      background:linear-gradient(90deg, var(--brand) 0%, var(--brand) 50%, #1f2937 50%, #1f2937 100%); }
    .timeline::-webkit-slider-thumb { appearance:none; width:14px; height:14px; border-radius:50%; background:#fff; border:2px solid var(--brand); }
    .timeline-label { font-variant-numeric: tabular-nums; color: var(--muted); }
    .chip { background: rgba(255,255,255,0.06); padding:.25rem .5rem; border-radius:999px; color: var(--muted); }
  </style>
</head>
<body>
<div class="container py-4">
  <div class="d-flex align-items-center justify-content-between mb-3">
    <h1 class="h3 mb-0">Gravações</h1>
    <div class="d-flex gap-2">
      <span class="chip">Cliente: <strong id="chipCliente">{{ cliente_id }}</strong></span>
      <span class="chip">Câmera: <strong id="chipCamera">{{ camera_id }}</strong></span>
    </div>
  </div>

  <div class="card p-3 mb-3">
    <div class="row g-2 align-items-end">
      <div class="col-12 col-md-4">
        <label class="form-label">Dia</label>
        <input type="date" id="inputDia" class="form-control">
      </div>
      <div class="col-6 col-md-3">
        <label class="form-label">Início</label>
        <input type="time" id="inputHoraIni" class="form-control" step="1" value="00:00:00">
      </div>
      <div class="col-6 col-md-3">
        <label class="form-label">Fim</label>
        <input type="time" id="inputHoraFim" class="form-control" step="1" value="23:59:59">
      </div>
      <div class="col-12 col-md-2 d-grid">
        <button class="btn btn-brand" id="btnBuscar">Buscar</button>
      </div>
    </div>
  </div>

  <div class="card p-3 mb-3">
    <div class="d-flex justify-content-between align-items-center mb-2">
      <div>
        <div class="small text-uppercase text-muted">Timeline</div>
        <div class="timeline-label"><span id="lblInicio">--:--:--</span> — <span id="lblCursor">--:--:--</span> — <span id="lblFim">--:--:--</span></div>
      </div>
      <div class="d-flex gap-2">
        <button class="btn btn-sm btn-outline-light" id="btnVoltar30">-30s</button>
        <button class="btn btn-sm btn-outline-light" id="btnAvancar30">+30s</button>
      </div>
    </div>
    <input type="range" class="timeline" id="rangeTimeline" min="0" max="0" value="0" step="1" disabled>
  </div>

  <div class="card p-2">
    <video id="player" controls playsinline class="w-100 rounded" style="max-height:65vh; background:#000"></video>
  </div>
</div>

<script>
  const cliente = "{{ cliente_id }}";
  const camera = "{{ camera_id }}";

  const $dia = document.getElementById('inputDia');
  const $ini = document.getElementById('inputHoraIni');
  const $fim = document.getElementById('inputHoraFim');
  const $buscar = document.getElementById('btnBuscar');
  const $range = document.getElementById('rangeTimeline');
  const $lblIni = document.getElementById('lblInicio');
  const $lblCur = document.getElementById('lblCursor');
  const $lblFim = document.getElementById('lblFim');
  const $player = document.getElementById('player');

  const pad = n => String(n).padStart(2,'0');
  const toRFC3339 = (d) => new Date(d).toISOString();

  function setLabels(startMs, endMs, curMs) {
    const fmt = ms => { const d=new Date(ms); return pad(d.getHours())+":"+pad(d.getMinutes())+":"+pad(d.getSeconds()); };
    $lblIni.textContent = fmt(startMs); $lblFim.textContent = fmt(endMs); $lblCur.textContent = fmt(curMs);
  }

  async function listarJanelas(dtStart, dtEnd) {
    const qs = new URLSearchParams({ cliente_id: cliente, camera_id: camera, inicio: dtStart, fim: dtEnd });
    const r = await fetch(`/gravacoes/api/list?${qs.toString()}`);
    if (!r.ok) throw new Error('Falha ao listar janelas');
    return await r.json();
  }

  async function gerarURL(inicioRFC3339, duracaoSeg=1800, formato='mp4') {
    const qs = new URLSearchParams({ cliente_id: cliente, camera_id: camera, inicio: inicioRFC3339, duracao_seg: duracaoSeg, formato });
    const r = await fetch(`/gravacoes/api/url?${qs.toString()}`);
    const j = await r.json();
    return j.url;
  }

  let T0 = null, T1 = null;
  $buscar.addEventListener('click', async () => {
    const day = $dia.value; if (!day) { alert("Escolha o dia."); return; }
    const ini = $ini.value || "00:00:00"; const fim = $fim.value || "23:59:59";
    const startLocal = new Date(`${day}T${ini}`); const endLocal = new Date(`${day}T${fim}`);

    const spans = await listarJanelas(toRFC3339(startLocal), toRFC3339(endLocal));
    if (!spans.length) { $range.disabled = true; alert("Sem gravações no intervalo."); return; }

    T0 = new Date(spans[0].start).getTime();
    let lastEnd = T0;
    for (const s of spans) { const ts=new Date(s.start).getTime(); const te=ts + Math.floor(s.duration*1000); if (ts<T0) T0=ts; if (te>lastEnd) lastEnd=te; }
    T1 = lastEnd;

    $range.min = 0; $range.max = Math.floor((T1 - T0)/1000); $range.value = 0; $range.disabled = false;
    setLabels(T0, T1, T0);

    const firstUrl = await gerarURL(new Date(T0).toISOString(), 1800, 'mp4');
    $player.src = firstUrl; $player.play().catch(()=>{});
  });

  $range.addEventListener('input', async (e) => {
    if (T0 === null) return;
    const offsetSec = Number(e.target.value);
    const targetMs = T0 + offsetSec*1000;
    setLabels(T0, T1, targetMs);
    const url = await gerarURL(new Date(targetMs).toISOString(), 1800, 'mp4');
    const wasPlaying = !($player.paused || $player.ended);
    $player.src = url; if (wasPlaying) $player.play().catch(()=>{});
  });

  document.getElementById('btnVoltar30').onclick = () => { if ($range.disabled) return; $range.value = Math.max(Number($range.value)-30, Number($range.min)); $range.dispatchEvent(new Event('input')); };
  document.getElementById('btnAvancar30').onclick = () => { if ($range.disabled) return; $range.value = Math.min(Number($range.value)+30, Number($range.max)); $range.dispatchEvent(new Event('input')); };

  const now = new Date(); $dia.value = now.toISOString().slice(0,10);
</script>
</body>
</html>
EOTPL

if [ -f "${MAIN_PY}" ] && ! grep -q "routers.gravacoes" "${MAIN_PY}"; then
  printf "\n# --- gravações (UI + API) ---\nfrom SISTEMA.GESTAO_WEB.app.routers import gravacoes as gravacoes_router\napp.include_router(gravacoes_router.router)\n" >> "${MAIN_PY}"
  log "Router de gravações incluído em ${MAIN_PY}"
else
  log "main.py já contém (ou não existe) referência ao router; pulando."
fi

if [ -f "${REQ_TXT}" ] && ! grep -q '^httpx' "${REQ_TXT}"; then
  echo "httpx==0.27.2" >> "${REQ_TXT}"
  log "Adicionado httpx em ${REQ_TXT}"
fi
