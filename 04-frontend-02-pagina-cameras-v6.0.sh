#!/usr/bin/env bash
set -euo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
log "Atualizando página de câmeras v6.0 (player genérico)..."

# JS de player reutilizável (inclui hls.js via CDN simples)
cat > "$FRONTEND_DIR/static/js/player-live.js" <<'JS'
window.LivePlayer = (function(){
  let currentVideoEl = null;

  async function getPlayback(cameraId){
    const r = await fetch(`/api/v1/cameras/${cameraId}/playback`);
    if(!r.ok) throw new Error('Falha ao obter playback');
    return r.json();
  }

  function ensureVideoElement(){
    let el = document.getElementById('player-live-video');
    if(!el){
      const ctn = document.getElementById('player-live-container') || document.body;
      el = document.createElement('video');
      el.id = 'player-live-video';
      el.autoplay = true;
      el.controls = true;
      el.muted = true;
      el.playsInline = true;
      el.style.width = '100%';
      ctn.appendChild(el);
    }
    return el;
  }

  async function play(cameraId){
    const data = await getPlayback(cameraId);
    if(!data || data.protocol !== 'hls' || !data.url){
      alert('Stream indisponível para reprodução HLS.');
      return;
    }
    const video = ensureVideoElement();
    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = data.url;
      video.play().catch(()=>{});
    } else {
      if(!window.Hls){
        const s = document.createElement('script');
        s.src = 'https://cdn.jsdelivr.net/npm/hls.js@latest';
        s.onload = () => attachHls(video, data.url);
        document.head.appendChild(s);
      } else {
        attachHls(video, data.url);
      }
    }
  }

  function attachHls(video, url){
    if(window.hlsInstance){ window.hlsInstance.destroy(); }
    const hls = new Hls();
    window.hlsInstance = hls;
    hls.loadSource(url);
    hls.attachMedia(video);
    hls.on(Hls.Events.MANIFEST_PARSED, function(){ video.play().catch(()=>{}); });
  }

  return { play };
})();
JS

# Ajuste na página para usar o mesmo botão existente, acionando LivePlayer.play(id)
# Mantém layout/HTML; só adiciona data-atributo e listener seguro.
sed -i 's/data-acao="ver-ao-vivo"/data-acao="ver-ao-vivo"/g' "$FRONTEND_DIR/templates/cameras.html" || true

# Injeta listener (idempotente)
if ! grep -q "data-acao=\"ver-ao-vivo\"" "$FRONTEND_DIR/templates/cameras.html"; then
  # Caso página seja diferente, não falha
  true
fi

# Garante container do player (não quebra layout)
if ! grep -q "player-live-container" "$FRONTEND_DIR/templates/cameras.html"; then
  sed -i '/<\/body>/i \
  <div id="player-live-container" class="player-live-ctn"></div>\n  <script src="/static/js/player-live.js"></script>\n  <script>\n    document.addEventListener("click", function(e){\n      const btn = e.target.closest("[data-acao=\\"ver-ao-vivo\\"]");\n      if(btn){ const id = btn.getAttribute("data-id"); if(id){ window.LivePlayer.play(id); } }\n    });\n  </script>\n' "$FRONTEND_DIR/templates/cameras.html"
fi

log "Frontend v6.0 pronto (player genérico HLS)."
