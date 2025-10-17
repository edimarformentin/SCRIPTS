#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/edimar/SISTEMA"
# Procura cameras.js no projeto (ajuste se souber o caminho exato)
mapfile -t FILES < <(find "$ROOT" -type f -name "cameras.js" 2>/dev/null | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "ERRO: cameras.js não encontrado em $ROOT"
  exit 1
fi

for F in "${FILES[@]}"; do
  echo ">> Patch em: $F"

  # 1) Injeta utilitários (se ainda não existirem)
  if ! grep -q "function vaasPlayWithRetry" "$F"; then
    cat >> "$F" <<'JS'

// === VaaS: autoplay/background helpers (idempotente) ==========================
function vaasPlayWithRetry(video, attempts = 5) {
  const tryPlay = (left) => {
    if (!left) return;
    const p = video.play();
    if (p && typeof p.then === 'function') {
      p.catch((err) => {
        // Ignora AbortError/NotAllowedError e re-tenta
        if (err && (err.name === 'AbortError' || err.name === 'NotAllowedError')) {
          setTimeout(() => tryPlay(left - 1), 400);
        } else {
          // log leve; não quebra
          console.warn('play() falhou:', err?.name || err, 'tentativas restantes:', left - 1);
          setTimeout(() => tryPlay(left - 1), 800);
        }
      });
    }
  };
  tryPlay(attempts);
}

function vaasHardenVideoElement(video) {
  // Garante flags que liberam autoplay silencioso
  if (!video) return;
  video.muted = true;
  video.autoplay = true;
  video.playsInline = true;
  video.setAttribute('muted', '');
  video.setAttribute('playsinline', '');
  // Reage à visibilidade da página
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && video.paused) {
      vaasPlayWithRetry(video, 3);
    }
  });
  // Se o navegador suspender o vídeo (background), tente retomar ao voltar
  ['pause','stalled','suspend','abort','emptied','waiting'].forEach((ev) => {
    video.addEventListener(ev, () => {
      if (!document.hidden) vaasPlayWithRetry(video, 2);
    });
  });
}
// ============================================================================
JS
  fi

  # 2) Chama os utilitários ao abrir o player (inserindo após o primeiro attach)
  # Tentamos inserir apenas 1x: procure um padrão comum de openPlayer (ajuste leve e idempotente)
  if grep -q "function openPlayer" "$F"; then
    # Após a primeira ocorrência de 'function openPlayer', garanta que chamamos vaasHardenVideoElement(video)
    if ! sed -n '/function openPlayer/,/}/{/vaasHardenVideoElement(video)/p}' "$F" | grep -q 'vaasHardenVideoElement(video)'; then
      awk '
        BEGIN{patched=0}
        /function openPlayer/ {infun=1}
        {print}
        infun==1 && patched==0 && /{/{
          print "  // VaaS: endurece o elemento de vídeo para autoplay e background";
          print "  vaasHardenVideoElement(video);";
          patched=1
        }
        infun==1 && /}/ {infun=0}
      ' "$F" > "${F}.tmp" && mv "${F}.tmp" "$F"
    fi
  fi

  # 3) Gancho Hls.js: após MANIFEST_PARSED, retentar play com tolerância
  if grep -q "Hls.Events.MANIFEST_PARSED" "$F"; then
    if ! sed -n '/Hls.Events.MANIFEST_PARSED/,/}/p' "$F" | grep -q 'vaasPlayWithRetry(video'; then
      # injeta uma chamada ao final do callback do MANIFEST_PARSED
      awk '
        BEGIN{inblk=0}
        /Hls\.Events\.MANIFEST_PARSED/ {inblk=1}
        {print}
        inblk==1 && /function *\(.*\) *{/ && !seen { seen=1; next }
        inblk==1 && /^\s*\}\s*[,;]?\s*$/ {
          print "    // VaaS: tenta play com retry (ignora AbortError em background)";
          print "    vaasPlayWithRetry(video, 5);";
          inblk=0
        }
      ' "$F" > "${F}.tmp" && mv "${F}.tmp" "$F"
    fi
  else
    # fallback: logo após hls.attachMedia(video) tenta play com retry
    if grep -q "hls.attachMedia(video)" "$F"; then
      if ! sed -n '1,200p' "$F" | grep -q 'vaasPlayWithRetry(video'; then
        sed -i '0,/hls.attachMedia(video)/s//hls.attachMedia(video);\n    \/\/ VaaS: tenta play com retry\n    vaasPlayWithRetry(video, 5)/' "$F"
      fi
    fi
  fi

done

echo ">> Patch concluído."
