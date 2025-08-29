#!/usr/bin/env bash
set -euo pipefail
TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"

cp -a "$TPL" "$TPL.bak.$(date +%s)"
# normaliza finais de linha, caso exista ^M
sed -i 's/\r$//' "$TPL"

# limpa tentativas antigas
sed -i '/INLINE_VIDEO_BOOTSTRAP_START/,/INLINE_VIDEO_BOOTSTRAP_END/d' "$TPL"
sed -i '/INLINE_VIDEO_PATCH_START/,/INLINE_VIDEO_PATCH_END/d' "$TPL"
sed -i '/VIDEO_BTN_MODAL_BOOTSTRAP_START/,/VIDEO_BTN_MODAL_BOOTSTRAP_END/d' "$TPL"
sed -i '/eventVideoModal/,/<\/script>/d' "$TPL"
sed -i '/openEventVideo/,/<\/script>/d' "$TPL"

python3 - <<'PY'
import re, sys
tpl = "/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"
s = open(tpl, encoding="utf-8").read()

# acha o ÚLTIMO {% endblock %} (fecha o block scripts)
ends = list(re.finditer(r'{%-?\s*endblock\s*%}', s))
if not ends:
    print("ERRO: não achei {% endblock %} no template", file=sys.stderr); sys.exit(1)
idx = ends[-1].start()

patch = r"""
<!-- VIDEO_BTN_MODAL_BOOTSTRAP_START -->
<script>
(function(){
  function ensureModal(){
    let modalEl = document.getElementById('eventVideoModal');
    if(modalEl) return modalEl;
    modalEl = document.createElement('div');
    modalEl.id = 'eventVideoModal';
    modalEl.className = 'modal fade';
    modalEl.tabIndex = -1;
    modalEl.innerHTML = `
      <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Vídeo do Evento</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body p-0">
            <video id="eventVideoPlayer" class="w-100" controls preload="metadata"></video>
            <small id="eventVideoHint" class="text-muted d-block px-3 mt-2"></small>
          </div>
        </div>
      </div>`;
    document.body.appendChild(modalEl);
    modalEl.addEventListener('hidden.bs.modal', ()=>{
      const v=document.getElementById('eventVideoPlayer');
      v.pause(); v.removeAttribute('src'); v.load();
    });
    return modalEl;
  }

  function toPath(u){ try { return new URL(u, location.origin).pathname } catch(_) { return u; } }

  async function resolveFromApi(jpg){
    try{
      const r = await fetch('/api/event-video?jpg=' + encodeURIComponent(toPath(jpg)));
      if(!r.ok) return null;
      const d = await r.json();
      return d && d.url ? d.url : null;
    }catch(e){ return null; }
  }

  window.openEventVideo = async function(jpg){
    const modalEl = ensureModal();
    const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
    const player = modalEl.querySelector('#eventVideoPlayer');
    const hint = modalEl.querySelector('#eventVideoHint');

    let url = await resolveFromApi(jpg);
    if(!url){ url = toPath(jpg).replace('/FRIGATE/','/media_files/FRIGATE/').replace('.jpg','.mp4'); }

    player.src = url; player.load(); hint.textContent = url;
    modal.show();
  };

  // injeta botão Bootstrap nos cards
  document.querySelectorAll('.event-image').forEach(img=>{
    const body = img.closest('.card')?.querySelector('.card-body');
    if(!body || body.querySelector('[data-ver-video]')) return;
    const btn = document.createElement('button');
    btn.type='button'; btn.dataset.verVideo='1';
    btn.className='btn btn-outline-primary w-100 mt-2';
    btn.textContent='Ver vídeo';
    btn.addEventListener('click', ()=>openEventVideo(img.getAttribute('src')));
    body.appendChild(btn);
    // atalho: duplo clique na imagem
    img.addEventListener('dblclick', (e)=>{ e.preventDefault(); openEventVideo(img.getAttribute('src')); });
  });
})();
</script>
<!-- VIDEO_BTN_MODAL_BOOTSTRAP_END -->
"""

s = s[:idx] + patch + "\n" + s[idx:]
open(tpl, "w", encoding="utf-8").write(s)
print("OK: patch injetado dentro do block scripts")
PY

echo "[docker] restart sistema-gestao-web..."
docker restart sistema-gestao-web >/dev/null || true
echo "[ok] Abra /cliente/1/eventos e pressione Ctrl+F5."
