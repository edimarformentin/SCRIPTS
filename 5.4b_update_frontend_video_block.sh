#!/usr/bin/env bash
set -euo pipefail

TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"
START="<!-- ========== Modal de Vídeo de Evento (injetado) ========== -->"
END="<!-- ========== Fim do bloco de vídeo de evento ========== -->"

[ -f "$TPL" ] || { echo "[ERRO] Não encontrei $TPL"; exit 1; }

# Remove bloco antigo entre START/END (se existir)
if grep -qF "$START" "$TPL"; then
  awk -v start="$START" -v end="$END" '
    BEGIN{skip=0}
    index($0,start){skip=1; next}
    index($0,end){skip=0; next}
    skip==0{print}
  ' "$TPL" > "${TPL}.tmp"
  mv "${TPL}.tmp" "$TPL"
fi

# Acrescenta bloco novo (com fallback de /FRIGATE -> /media_files/FRIGATE)
cat >> "$TPL" <<'HTMLEOF'

<!-- ========== Modal de Vídeo de Evento (injetado) ========== -->
<div id="eventVideoModal" class="fixed inset-0 hidden items-center justify-center bg-black/70 z-50">
  <div class="bg-white rounded-2xl max-w-4xl w-11/12 shadow-xl overflow-hidden">
    <div class="flex items-center justify-between px-4 py-3 border-b">
      <h3 class="text-lg font-semibold">Vídeo do Evento</h3>
      <button id="closeEventVideoModal" class="px-3 py-1 rounded-md border">Fechar</button>
    </div>
    <div class="p-4">
      <video id="eventVideoPlayer" class="w-full rounded-xl" controls preload="metadata"></video>
      <p id="eventVideoHint" class="text-sm text-gray-500 mt-2"></p>
    </div>
  </div>
</div>

<script>
(function(){
  function toVideoUrlFromImg(src){
    if (!src) return "";
    // troca .jpg -> .mp4 (preserva querystring)
    try {
      const u = new URL(src, window.location.origin);
      const hasQ = u.search || "";
      let v = u.pathname.replace(/\.jpg$/i, ".mp4") + hasQ;

      // fallback: se veio como /FRIGATE/..., a app serve em /media_files/FRIGATE/...
      if (v.startsWith("/FRIGATE/")) {
        v = v.replace(/^\/FRIGATE\//, "/media_files/FRIGATE/");
      }
      return v;
    } catch(e){
      // src relativo simples
      let v = src.replace(/\.jpg(\?.*)?$/i, '.mp4$1');
      if (v.startsWith("/FRIGATE/")) v = v.replace(/^\/FRIGATE\//, "/media_files/FRIGATE/");
      return v;
    }
  }

  const grid = document.querySelector('#eventos-grid') || document.body;
  const imgs = grid.querySelectorAll('img');

  imgs.forEach((img) => {
    try {
      const src = img.getAttribute('src') || '';
      if (!/events\/.+\.jpg(\?.*)?$/i.test(src)) return;

      const card = img.closest('.card, .shadow, .rounded, .event-card') || img.parentElement;
      if (!card) return;
      if (card.querySelector('.btn-ver-video')) return;

      const btn = document.createElement('button');
      btn.textContent = 'Ver vídeo';
      btn.className = 'btn-ver-video mt-2 px-3 py-1 rounded-lg border shadow-sm hover:shadow transition text-sm';
      btn.addEventListener('click', () => {
        const videoUrl = toVideoUrlFromImg(src);
        const modal = document.getElementById('eventVideoModal');
        const player = document.getElementById('eventVideoPlayer');
        const hint = document.getElementById('eventVideoHint');
        if (!modal || !player) return;

        player.src = videoUrl;
        hint.textContent = videoUrl;

        modal.classList.remove('hidden');
        modal.classList.add('flex');

        const onError = () => {
          alert('Vídeo do evento ainda não disponível para este snapshot.');
        };
        player.addEventListener('error', onError, { once: true });
        player.play().catch(()=>{});
      });

      img.insertAdjacentElement('afterend', btn);
    } catch(e){
      console.warn('botão de vídeo: falha ao injetar em um cartão', e);
    }
  });

  const modal = document.getElementById('eventVideoModal');
  const close = document.getElementById('closeEventVideoModal');
  function closeModal(){
    const player = document.getElementById('eventVideoPlayer');
    if (player) { player.pause(); player.removeAttribute('src'); player.load(); }
    modal.classList.add('hidden'); modal.classList.remove('flex');
  }
  if (close && modal) close.addEventListener('click', closeModal);
  if (modal) modal.addEventListener('click', (ev) => { if (ev.target === modal) closeModal(); });
})();
</script>
<!-- ========== Fim do bloco de vídeo de evento ========== -->
HTMLEOF

echo "[OK] Bloco de vídeo atualizado em: $TPL"
