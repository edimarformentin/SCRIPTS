#!/usr/bin/env bash
set -euo pipefail

TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"
[ -f "$TPL" ] || { echo "[ERRO] Não encontrei $TPL"; exit 1; }

START="<!-- [patch-5.8] botao ver video -->"
END="<!-- [/patch-5.8] -->"

# remove bloco antigo (se existir)
if grep -qF "$START" "$TPL"; then
  awk -v s="$START" -v e="$END" 'BEGIN{skip=0}
    index($0,s){skip=1; next}
    index($0,e){skip=0; next}
    !skip{print $0}' "$TPL" > "${TPL}.tmp" && mv "${TPL}.tmp" "$TPL"
fi

# injeta bloco novo no final
cat >> "$TPL" <<'HTMLEOF'

<!-- [patch-5.8] botao ver video -->
<script>
(function(){
  function ensureModal(){
    if (document.getElementById('eventVideoModal')) return;
    const modal = document.createElement('div');
    modal.id = 'eventVideoModal';
    modal.className = 'fixed inset-0 hidden items-center justify-center bg-black/70 z-50';
    modal.innerHTML = `
      <div class="bg-white rounded-2xl max-w-4xl w-11/12 shadow-xl overflow-hidden">
        <div class="flex items-center justify-between px-4 py-3 border-b">
          <h3 class="text-lg font-semibold">Vídeo do Evento</h3>
          <button id="closeEventVideoModal" class="px-3 py-1 rounded-md border">Fechar</button>
        </div>
        <div class="p-4">
          <video id="eventVideoPlayer" class="w-full rounded-xl" controls preload="metadata"></video>
          <p id="eventVideoHint" class="text-sm text-gray-500 mt-2"></p>
        </div>
      </div>`;
    document.body.appendChild(modal);
    document.getElementById('closeEventVideoModal').addEventListener('click', closeModal);
    modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });
    function closeModal(){
      modal.classList.add('hidden'); modal.classList.remove('flex');
      const v = document.getElementById('eventVideoPlayer');
      v.pause(); v.removeAttribute('src'); v.load();
    }
    window.__closeEventVideoModal = closeModal;
  }

  async function resolveFromApi(jpg){
    try{
      const u = new URL(jpg, window.location.origin);
      const r = await fetch(`/api/event-video?jpg=${encodeURIComponent(u.pathname)}`);
      if(!r.ok) return null;
      const j = await r.json();
      return j?.url || null;
    }catch(_){ return null; }
  }

  window.openEventVideo = async function(jpg){
    ensureModal();
    const modal = document.getElementById('eventVideoModal');
    const player = document.getElementById('eventVideoPlayer');
    const hint = document.getElementById('eventVideoHint');
    let url = await resolveFromApi(jpg);
    if(!url){
      url = jpg.replace('/FRIGATE/','/media_files/FRIGATE/').replace('.jpg','.mp4');
    }
    player.setAttribute('src', url);
    player.load();
    hint.textContent = url;
    modal.classList.remove('hidden'); modal.classList.add('flex');
  };

  function addButtons(){
    const imgs = Array.from(document.querySelectorAll('img'))
      .filter(i => /\/(FRIGATE|media_files\/FRIGATE)\/.+\/events\/.+\.jpg$/i.test(i.src));
    imgs.forEach(img => {
      const card = img.closest('div');
      if(!card || card.querySelector('[data-ver-video]')) return;
      const row = document.createElement('div');
      row.className = 'mt-2 flex gap-2';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.dataset.verVideo = '1';
      btn.className = 'px-3 py-2 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700';
      btn.textContent = 'Ver vídeo';
      btn.addEventListener('click', () => openEventVideo(img.src));
      row.appendChild(btn);
      card.appendChild(row);

      // (opcional) duplo clique na imagem abre o vídeo
      img.addEventListener('dblclick', (e) => { e.preventDefault(); openEventVideo(img.src); });
    });
  }

  document.addEventListener('DOMContentLoaded', addButtons);
  setTimeout(addButtons, 1000); // pega cards renderizados tardiamente
})();
</script>
<!-- [/patch-5.8] -->
HTMLEOF

docker restart sistema-gestao-web >/dev/null
echo "[OK] Botão 'Ver vídeo' injetado e container reiniciado."
