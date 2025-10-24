#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 04-frontend-estilos-css.sh  (public/css)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
source /home/edimar/SCRIPTS/00-configuracao-central.sh
main(){
  ensure_dirs "$FRONTEND_DIR/public/css"

  cat > "$FRONTEND_DIR/public/css/style.css" <<'CSS'
:root{
  --bg:#0b1321; --panel:#111a2b; --muted:#7f8ca6; --text:#e6edf6; --accent:#34d399; --danger:#ef4444;
  --border:#22304a; --link:#60a5fa; --link-hover:#93c5fd;
}
*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0; font:16px/1.4 system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Helvetica Neue", Arial, "Noto Sans", "Apple Color Emoji", "Segoe UI Emoji";
  color:var(--text); background:linear-gradient(180deg, #0b1321 0%, #0b1321 40%, #0d1830 100%) fixed;
}
a{color:var(--link); text-decoration:none}
a:hover{color:var(--link-hover); text-decoration:underline}

.container{max-width:1100px; margin:36px auto; padding:0 16px}
.nav{display:flex; gap:14px; margin-bottom:22px}
.nav a{padding:6px 10px; background:var(--panel); border:1px solid var(--border); border-radius:8px}
h1{margin:0 0 18px; font-size:26px}
.panel{
  background:rgba(17,26,43,.85); backdrop-filter: blur(6px); border:1px solid var(--border);
  border-radius:12px; padding:16px; margin:14px 0;
  box-shadow: 0 10px 24px rgba(0,0,0,.25), inset 0 1px 0 rgba(255,255,255,.04);
}
.form-grid{display:grid; grid-template-columns: repeat(4, minmax(140px,1fr)); gap:10px}
label{font-size:12px; color:var(--muted); display:block; margin-bottom:6px}
input,select{
  width:100%; padding:10px 12px; border:1px solid var(--border); border-radius:8px; background:#0f172a; color:var(--text);
}
button{
  appearance:none; border:0; border-radius:10px; padding:10px 14px; cursor:pointer; font-weight:600;
  background:linear-gradient(180deg, #22c55e, #16a34a); color:#052e16; box-shadow:0 8px 18px rgba(34,197,94,.25);
}
button.secondary{background:#0f172a; color:var(--text); border:1px solid var(--border)}
button.danger{background:linear-gradient(180deg, #ef4444, #dc2626); color:#fff}

.table{width:100%; border-collapse:collapse; margin-top:8px; font-size:14px}
.table th,.table td{padding:10px 8px; border-bottom:1px solid var(--border)}
.table th{color:var(--muted); text-align:left}
.empty{color:var(--muted); padding:8px 0}

.toast{
  position:fixed; top:14px; right:14px; background:#111827; border:1px solid #1f2937; color:#d1d5db;
  padding:10px 12px; border-radius:10px; box-shadow:0 10px 24px rgba(0,0,0,.3); display:none
}
.show{display:block}
CSS

  cat > "$FRONTEND_DIR/public/css/cameras.css" <<'CSS'
@import url("./style.css");
.tabs{display:flex; gap:8px; margin-bottom:10px}
.tab{padding:8px 12px; border:1px solid var(--border); background:#0f172a; border-radius:8px; cursor:pointer}
.tab.active{background:#1e293b; color:#a7f3d0; border-color:#31445e}
.player{background:#0f172a; border:1px solid var(--border); border-radius:12px; padding:10px; margin-top:10px}
video{width:100%; border-radius:8px; outline:none}
CSS

  ok "CSS gerado em public/css."
}
main "$@"
