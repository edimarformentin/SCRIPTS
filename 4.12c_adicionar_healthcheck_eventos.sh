#!/usr/bin/env bash
set -euo pipefail
MAIN="/home/edimar/SISTEMA/GESTAO_WEB/main.py"
[ -f "$MAIN" ] || { echo "[ERRO] main.py não encontrado: $MAIN"; exit 1; }

if grep -q "/health/event-videos" "$MAIN"; then
  echo "[INFO] endpoint já existe. Nada a fazer."
  exit 0
fi

cat >> "$MAIN" <<'PYEOF'

# ====== endpoint de health para vídeos de evento ======
try:
    from pathlib import Path
    from fastapi.responses import JSONResponse
except Exception:
    pass
else:
    if 'app' in globals():
        @app.get("/health/event-videos")
        def health_event_videos():
            base = Path("/code/media_files/FRIGATE")
            jpg = mp4 = missing = 0
            if base.exists():
                for p in base.rglob("events/*/*.jpg"):
                    jpg += 1
                    if not p.with_suffix(".mp4").exists():
                        missing += 1
                for _ in base.rglob("events/*/*.mp4"):
                    mp4 += 1
            return JSONResponse({
                "ok": True,
                "base": str(base),
                "jpg": jpg,
                "mp4": mp4,
                "missing": missing
            })
# ====== fim endpoint ======
PYEOF

echo "[OK] endpoint adicionado em $MAIN"
docker restart sistema-gestao-web
