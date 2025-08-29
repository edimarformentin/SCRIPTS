#!/usr/bin/env bash
set -euo pipefail
MAIN="/home/edimar/SISTEMA/GESTAO_WEB/main.py"
[ -f "$MAIN" ] || { echo "[ERRO] main.py não encontrado: $MAIN"; exit 1; }

if grep -q "/api/event-video" "$MAIN"; then
  echo "[INFO] endpoint /api/event-video já existe. Nada a fazer."
  exit 0
fi

cat >> "$MAIN" <<'PYEOF'

# ====== endpoint utilitário: descobrir vídeo de um snapshot (.mp4 exato ou *_merged.mp4) ======
try:
    import re, os
    from pathlib import Path
    from fastapi import Query
    from fastapi.responses import JSONResponse
except Exception:
    pass
else:
    if 'app' in globals():
        _TS_RE = re.compile(r'(?P<ts>\d{8}_\d{6})')

        def _to_rel_from_frigate(p: str) -> str:
            # aceita urls (/media_files/FRIGATE/... ou /FRIGATE/...), caminho host (/home/.../FRIGATE/...), ou relativo
            p = p.strip()
            if p.startswith("http://") or p.startswith("https://"):
                try:
                    from urllib.parse import urlparse
                    u = urlparse(p)
                    p = u.path
                except Exception:
                    pass
            if p.startswith("/media_files/FRIGATE/"):
                return p[len("/media_files/FRIGATE/"):]
            if p.startswith("/FRIGATE/"):
                return p[len("/FRIGATE/"):]
            if "/FRIGATE/" in p:
                return p.split("/FRIGATE/",1)[1]
            return p.lstrip("/")

        @app.get("/api/event-video")
        def api_event_video(jpg: str = Query(..., description="caminho do .jpg (url ou fs)")):
            base = Path("/code/media_files/FRIGATE").resolve()
            rel = _to_rel_from_frigate(jpg)
            fs_jpg = (base / rel).resolve()

            # segurança: precisa estar dentro de base
            if not str(fs_jpg).startswith(str(base)):
                return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

            if not fs_jpg.exists():
                return JSONResponse({"ok": False, "error": "jpg_not_found", "path": f"/media_files/FRIGATE/{rel}"}, status_code=404)

            tried = []
            # 1) .mp4 exato
            mp4_exact = fs_jpg.with_suffix(".mp4")
            tried.append(str(mp4_exact))
            if mp4_exact.exists():
                url = "/media_files/FRIGATE/" + os.path.relpath(mp4_exact, base)
                return JSONResponse({"ok": True, "url": url, "mode": "exact", "tried": tried})

            # 2) procurar *_merged.mp4 com mesmo timestamp inicial
            m = _TS_RE.search(fs_jpg.name)
            if m:
                ts = m.group("ts")
                dirp = fs_jpg.parent
                candidates = sorted(dirp.glob(f"{ts}__*_merged.mp4"))
                for c in candidates:
                    tried.append(str(c))
                    if c.exists():
                        url = "/media_files/FRIGATE/" + os.path.relpath(c, base)
                        return JSONResponse({"ok": True, "url": url, "mode": "merged", "tried": tried})

            return JSONResponse({"ok": False, "error": "video_not_found", "tried": tried}, status_code=404)
# ====== fim endpoint utilitário ======
PYEOF

echo "[OK] endpoint /api/event-video adicionado em $MAIN"
docker restart sistema-gestao-web
