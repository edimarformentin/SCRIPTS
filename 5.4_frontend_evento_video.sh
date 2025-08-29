#!/usr/bin/env bash
set -euo pipefail

TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"

if [ ! -f "$TPL" ]; then
  echo "[ERRO] Template não encontrado: $TPL"
  exit 1
fi

# Evita duplicar bloco se já existir
if grep -q "id=\"eventVideoModal\"" "$TPL"; then
  echo "[INFO] Bloco de vídeo já encontrado no template. Nada a fazer."
  exit 0
fi

echo "[INFO] Injetando modal + JS no final do ver_eventos.html ..."
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
  // Seleciona cartões que tenham <img> de evento e injeta botão "Ver vídeo"
  const grid = document.querySelector('#eventos-grid') || document.body;
  const imgs = grid.querySelectorAll('img');

  imgs.forEach((img) => {
    try {
      // evita pegar imagens que não são snapshots
      const src = img.getAttribute('src') || '';
      if (!src) return;
      if (!/events\/.+\.jpg(\?.*)?$/i.test(src)) return;

      // acha um contêiner razoável pra colocar o botão
      const card = img.closest('.card, .shadow, .rounded, .event-card') || img.parentElement;
      if (!card) return;

      // evita duplicar
      if (card.querySelector('.btn-ver-video')) return;

      // cria botão
      const btn = document.createElement('button');
      btn.textContent = 'Ver vídeo';
      btn.className = 'btn-ver-video mt-2 px-3 py-1 rounded-lg border shadow-sm hover:shadow transition text-sm';
      btn.addEventListener('click', () => {
        // constrói URL do vídeo trocando .jpg -> .mp4 (mantém querystring se existir)
        const url = new URL(src, window.location.origin);
        const qs = url.search; // preserva query
        const videoUrl = url.pathname.replace(/\.jpg$/i, '.mp4') + qs;

        // abre modal e carrega
        const modal = document.getElementById('eventVideoModal');
        const player = document.getElementById('eventVideoPlayer');
        const hint = document.getElementById('eventVideoHint');
        if (!modal || !player) return;

        player.src = videoUrl;
        hint.textContent = videoUrl;

        modal.classList.remove('hidden');
        modal.classList.add('flex');

        // tentativa de play; se 404, onerror do <video> mostra alerta
        const onError = () => {
          alert('Vídeo do evento ainda não disponível para este snapshot.');
        };
        player.addEventListener('error', onError, { once: true });

        player.play().catch(() => {/* ok se o browser bloquear autoplay */});
      });

      // insere botão abaixo da imagem
      img.insertAdjacentElement('afterend', btn);
    } catch(e) {
      // não quebra a página se algo der errado num card
      console.warn('botão de vídeo: falha ao injetar em um cartão', e);
    }
  });

  // fechar modal
  const modal = document.getElementById('eventVideoModal');
  const close = document.getElementById('closeEventVideoModal');
  if (close && modal) {
    close.addEventListener('click', () => {
      const player = document.getElementById('eventVideoPlayer');
      if (player) { player.pause(); player.removeAttribute('src'); player.load(); }
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    });
  }
  // fechar clicando fora
  if (modal) {
    modal.addEventListener('click', (ev) => {
      if (ev.target === modal) {
        const player = document.getElementById('eventVideoPlayer');
        if (player) { player.pause(); player.removeAttribute('src'); player.load(); }
        modal.classList.add('hidden');
        modal.classList.remove('flex');
      }
    });
  }
})();
</script>
<!-- ========== Fim do bloco de vídeo de evento ========== -->
HTMLEOF

echo "[OK] Template atualizado: $TPL"
