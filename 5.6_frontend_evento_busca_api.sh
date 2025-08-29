#!/usr/bin/env bash
set -euo pipefail

TPL="/home/edimar/SISTEMA/GESTAO_WEB/templates/ver_eventos.html"
[ -f "$TPL" ] || { echo "[ERRO] Não encontrei $TPL"; exit 1; }

# injeta um bloco ao final, sobrescrevendo a função openEventVideo (última definição vence)
cat >> "$TPL" <<'HTMLEOF'

<!-- ===== Patch: openEventVideo via /api/event-video (idempotente) ===== -->
<script>
(async function(){
  function toMediaFiles(url) {
    if (url.startsWith('/media_files/FRIGATE/')) return url;
    if (url.startsWith('/FRIGATE/')) return url.replace('/FRIGATE/', '/media_files/FRIGATE/');
    return url.replace('/FRIGATE/', '/media_files/FRIGATE/');
  }
  async function resolveVideoFromApi(jpgUrl) {
    try {
      const p = new URL(jpgUrl, window.location.origin);
      const rel = p.pathname; // trabalhamos com path
      const params = new URLSearchParams({ jpg: rel });
      const r = await fetch(`/api/event-video?${params.toString()}`);
      if (!r.ok) return null;
      const data = await r.json();
      return data?.url || null;
    } catch(e) { return null; }
  }
  window.openEventVideo = async function(imgUrl){
    const modal = document.getElementById('eventVideoModal');
    const player = document.getElementById('eventVideoPlayer');
    const hint = document.getElementById('eventVideoHint');
    if (!modal || !player) return;

    // 1) tenta API
    let apiUrl = await resolveVideoFromApi(imgUrl);
    if (apiUrl) {
      player.src = apiUrl;
      hint.textContent = 'Fonte: API /api/event-video';
      modal.classList.remove('hidden');
      modal.classList.add('flex');
      player.play().catch(()=>{});
      return;
    }

    // 2) fallback antigo: troca .jpg -> .mp4 e corrige prefixo
    const jpgPath = imgUrl.replace(location.origin, '');
    const mp4Path = jpgPath.replace(/\.jpg$/i, '.mp4');
    const fixed = toMediaFiles(mp4Path);
    player.src = fixed;
    hint.textContent = 'Fonte: fallback direto (.mp4)';
    modal.classList.remove('hidden');
    modal.classList.add('flex');
    player.play().catch(()=>{});
  };
  const closeBtn = document.getElementById('closeEventVideoModal');
  if (closeBtn) closeBtn.addEventListener('click', () => {
    const modal = document.getElementById('eventVideoModal');
    const player = document.getElementById('eventVideoPlayer');
    if (player) { player.pause(); player.removeAttribute('src'); player.load(); }
    modal?.classList.add('hidden'); modal?.classList.remove('flex');
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const modal = document.getElementById('eventVideoModal');
      const player = document.getElementById('eventVideoPlayer');
      if (player) { player.pause(); player.removeAttribute('src'); player.load(); }
      modal?.classList.add('hidden'); modal?.classList.remove('flex');
    }
  });
})();
</script>
<!-- ===== Fim do patch ===== -->
HTMLEOF

docker restart sistema-gestao-web >/dev/null
echo "[OK] Front atualizado com busca via API."
