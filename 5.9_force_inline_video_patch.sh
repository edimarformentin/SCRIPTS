#!/usr/bin/env bash
set -euo pipefail
TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"

echo "[backup] Salvando cópia do template..."
cp -a "$TPL" "$TPL.bak.$(date +%s)"

# Limpa tentativas anteriores
sed -i '/eventVideoModal/,/<\/script>/d' "$TPL"
sed -i '/openEventVideo/,/<\/script>/d' "$TPL"
sed -i '/static\/event_video\.js/d' "$TPL"

echo "[patch] Injetando JS inline (idempotente) no final do <body>..."
cat >>"$TPL" <<'HTML'
<!-- INLINE_VIDEO_PATCH_START -->
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
    const close = () => {
      modal.classList.add('hidden'); modal.classList.remove('flex');
      const v = document.getElementById('eventVideoPlayer');
      v.pause(); v.removeAttribute('src'); v.load();
    };
    document.getElementById('closeEventVideoModal').addEventListener('click', close);
    modal.addEventListener('click', e => { if (e.target === modal) close(); });
    window.__closeEventVideoModal = close;
  }

  async function resolveFromApi(jpgUrl){
    try{
      const p = new URL(jpgUrl, window.location.origin);
      const r = await fetch(`/api/event-video?jpg=${encodeURIComponent(p.pathname)}`);
      if (!r.ok) return null;
      const j = await r.json();
      return j?.url || null;
    }catch(_){ return null; }
  }

  window.openEventVideo = async function(jpgUrl){
    ensureModal();
    const modal = document.getElementById('eventVideoModal');
    const player = document.getElementById('eventVideoPlayer');
    const hint = document.getElementById('eventVideoHint');

    let url = await resolveFromApi(jpgUrl);
    if (!url) url = jpgUrl.replace('/FRIGATE/','/media_files/FRIGATE/').replace('.jpg','.mp4');

    player.src = url; player.load();
    hint.textContent = url;
    modal.classList.remove('hidden'); modal.classList.add('flex');
  };

  function enhance(){
    document.querySelectorAll('img').forEach(img=>{
      let path; try { path = new URL(img.src, location.origin).pathname; } catch(_){ return; }
      if (!/(^|\/)(FRIGATE|media_files\/FRIGATE)\/.*\/events\/.*\.jpg$/i.test(path)) return;
      if (img.dataset.verVideoDone) return;
      img.dataset.verVideoDone = '1';

      const card = img.closest('div') || img.parentElement;
      if (card && !card.querySelector('[data-ver-video]')) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.dataset.verVideo = '1';
        btn.className = 'mt-2 px-3 py-2 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700';
        btn.textContent = 'Ver vídeo';
        btn.addEventListener('click', () => openEventVideo(img.src));
        card.appendChild(btn);
      }
      img.addEventListener('dblclick', e => { e.preventDefault(); openEventVideo(img.src); });
    });
  }

  document.addEventListener('DOMContentLoaded', ()=>{ ensureModal(); enhance(); });
  new MutationObserver(enhance).observe(document.documentElement,{subtree:true, childList:true});
})();
</script>
<!-- INLINE_VIDEO_PATCH_END -->
HTML

echo "[docker] Reiniciando sistema-gestao-web..."
docker restart sistema-gestao-web >/dev/null
echo "[ok] Pronto. Atualize a página com Ctrl+F5."
