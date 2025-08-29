#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/home/edimar/SCRIPTS/logs"
PY_SCRIPT="/home/edimar/SCRIPTS/event_assembler_host.py"
mkdir -p "$LOG_DIR"

# 1) Checagens básicas
if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERRO] python3 não encontrado no host. Instale python3 e rode novamente."
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[ERRO] ffmpeg não encontrado no host. Instale com:"
  echo "  sudo apt-get update && sudo apt-get install -y ffmpeg"
  echo "ou equivalente para sua distro, e rode este script de novo."
  exit 1
fi

# 2) Criar o script Python que monta o clipe do evento
cat > "$PY_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, re, json, subprocess, shutil, time
from pathlib import Path
from datetime import datetime, timedelta, timezone

# ----------------- Config -----------------
DEFAULT_PRE = int(os.environ.get("EVENT_PRESECONDS", "12"))
DEFAULT_POST = int(os.environ.get("EVENT_POSTSECONDS", "12"))
EXTRA_PAD = 2  # segundos a mais para garantir junção
VERBOSE = int(os.environ.get("EVENT_VERBOSE", "1"))

# Candidatos de base do FRIGATE no host (ajuste aqui caso precise)
DEFAULT_BASE_CANDIDATES = [
    "/home/edimar/FRIGATE",
    "/data/FRIGATE",
    "/FRIGATE",
    "/var/lib/frigate/FRIGATE",
]

DATE_RE = re.compile(r"(?P<date>\d{8})[_\-\.](?P<time>\d{6})")  # 20250825_123456
# -----------------------------------------

def log(*a):
    if VERBOSE:
        print(*a, flush=True)

def parse_snapshot_time(p: Path) -> datetime:
    m = DATE_RE.search(p.name)
    if m:
        d = m.group("date")
        t = m.group("time")
        dt = datetime.strptime(d+t, "%Y%m%d%H%M%S").replace(tzinfo=timezone.utc)
        return dt
    # fallback: mtime
    ts = p.stat().st_mtime
    return datetime.fromtimestamp(ts, tz=timezone.utc)

def ensure_parent(p: Path):
    p.parent.mkdir(parents=True, exist_ok=True)

def run_ffmpeg(args):
    cmd = ["ffmpeg","-hide_banner","-nostdin","-y"] + args
    log("[ffmpeg]", " ".join(cmd))
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        return p.returncode, p.stdout
    except Exception as e:
        return 1, str(e)

def escape_path(p: Path) -> str:
    # para arquivo de concat do ffmpeg
    s = str(p)
    return s.replace("'", r"'\''")

def build_concat_and_trim(segments, out_final: Path, t_start: datetime, t_end: datetime):
    if not segments:
        return False, "sem segmentos"
    tmp_dir = out_final.parent / ".tmp_event_build"
    ensure_parent(tmp_dir)
    tmp_dir.mkdir(exist_ok=True)
    concat_list = tmp_dir / "files.txt"
    with concat_list.open("w") as f:
        for seg in segments:
            f.write(f"file '{escape_path(seg)}'\n")

    tmp_concat = tmp_dir / "concat.mp4"
    # Concat sem reencode
    rc, out = run_ffmpeg(["-f","concat","-safe","0","-i", str(concat_list), "-c","copy", str(tmp_concat)])
    if rc != 0 or not tmp_concat.exists():
        return False, f"concat falhou: {out}"

    # Trim (primeira tentativa: -c copy; se falhar, reencode)
    # Para calcular offsets relativos, consideramos que os segmentos estão ordenados por mtime
    first_seg_start = datetime.fromtimestamp(segments[0].stat().st_mtime, tz=timezone.utc) - timedelta(seconds=EXTRA_PAD)
    # offset para início
    ss = max(0.0, (t_start - first_seg_start).total_seconds())
    dur = max(0.1, (t_end - t_start).total_seconds())

    tmp_out = tmp_dir / "tmp_cut_copy.mp4"
    rc, out = run_ffmpeg(["-ss", f"{ss:.3f}", "-t", f"{dur:.3f}", "-i", str(tmp_concat), "-c","copy", str(tmp_out)])
    if rc != 0 or not tmp_out.exists() or tmp_out.stat().st_size < 2000:
        # fallback reencode
        log("[info] fallback reencode (bordas não keyframe ou streams variáveis)")
        tmp_out2 = tmp_dir / "tmp_cut_reenc.mp4"
        rc, out = run_ffmpeg([
            "-ss", f"{ss:.3f}", "-t", f"{dur:.3f}", "-i", str(tmp_concat),
            "-c:v","libx264","-preset","veryfast","-crf","20",
            "-c:a","aac","-movflags","+faststart",
            str(tmp_out2)
        ])
        if rc != 0 or not tmp_out2.exists():
            return False, f"trim reencode falhou: {out}"
        ensure_parent(out_final)
        shutil.move(str(tmp_out2), str(out_final))
    else:
        ensure_parent(out_final)
        shutil.move(str(tmp_out), str(out_final))

    # limpar tmp
    try:
        tmp_concat.unlink(missing_ok=True)
        concat_list.unlink(missing_ok=True)
        tmp_dir.rmdir()
    except Exception:
        pass
    return True, "ok"

def pick_base_dir(cli_base: str|None) -> Path:
    if cli_base:
        p = Path(cli_base)
        if p.exists():
            return p
        else:
            log(f"[aviso] base fornecida não existe: {p}")
    envb = os.environ.get("FRIGATE_BASE")
    if envb and Path(envb).exists():
        return Path(envb)
    for cand in DEFAULT_BASE_CANDIDATES:
        if Path(cand).exists():
            return Path(cand)
    raise SystemExit("[ERRO] Não encontrei a base FRIGATE. Defina FRIGATE_BASE ou use --base.")

def recordings_dirs_for_range(uid_dir: Path, camera: str, t0: datetime, t1: datetime):
    rec_root = uid_dir / "media" / "frigate" / "recordings"
    out = []
    cur = datetime(t0.year, t0.month, t0.day, t0.hour, tzinfo=timezone.utc)
    end = datetime(t1.year, t1.month, t1.day, t1.hour, tzinfo=timezone.utc)
    while cur <= end:
        day = cur.strftime("%Y-%m-%d")
        hour = cur.strftime("%H")
        d = rec_root / day / hour / camera
        if d.exists():
            out.append(d)
        cur += timedelta(hours=1)
    return out

def select_segments(dirs, t0: datetime, t1: datetime):
    # Seleciona mp4 com mtime dentro de janela estendida
    window_start = t0 - timedelta(seconds=60)
    window_end   = t1 + timedelta(seconds=60)
    segs = []
    for d in dirs:
        for f in sorted(d.glob("*.mp4")):
            try:
                mt = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
            except Exception:
                continue
            if window_start <= mt <= window_end:
                segs.append(f)
    # fallback: se nada, pega tudo da(s) pasta(s) (melhor gerar longo do que falhar)
    if not segs:
        for d in dirs:
            segs.extend(sorted(d.glob("*.mp4")))
    # ordenar por mtime
    segs.sort(key=lambda p: p.stat().st_mtime)
    return segs

def find_snapshots(base: Path):
    # Espera estrutura: base/<unique_id>/events/<camera>/*.jpg
    for uid_dir in sorted([p for p in base.iterdir() if p.is_dir()]):
        events_dir = uid_dir / "events"
        if not events_dir.exists():
            continue
        for cam_dir in sorted([p for p in events_dir.iterdir() if p.is_dir()]):
            for jpg in sorted(cam_dir.glob("*.jpg")):
                yield uid_dir, cam_dir.name, jpg

def build_output_paths(jpg: Path):
    stem = jpg.with_suffix('').name
    out_mp4 = jpg.with_suffix('.mp4')
    out_json = jpg.with_suffix('.json')
    return out_mp4, out_json, stem

def main():
    import argparse
    ap = argparse.ArgumentParser(description="Monta clipes de evento a partir das gravações do Frigate.")
    ap.add_argument("--base", help="Pasta base FRIGATE (contendo <unique_id>/events e <unique_id>/media/frigate/recordings)")
    ap.add_argument("--pre", type=int, default=DEFAULT_PRE, help="segundos de prebuffer")
    ap.add_argument("--post", type=int, default=DEFAULT_POST, help="segundos de postbuffer")
    ap.add_argument("--limit", type=int, default=0, help="processar no máximo N eventos (0 = todos)")
    ap.add_argument("--verbose", type=int, default=1)
    args = ap.parse_args()

    global VERBOSE
    VERBOSE = int(args.verbose)

    base = pick_base_dir(args.base)
    log(f"[info] base: {base}")
    cnt = 0
    for uid_dir, camera, jpg in find_snapshots(base):
        out_mp4, out_json, stem = build_output_paths(jpg)
        if out_mp4.exists():
            continue
        try:
            snap_ts = parse_snapshot_time(jpg)
            t_start = snap_ts - timedelta(seconds=args.pre)
            t_end   = snap_ts + timedelta(seconds=args.post)
            dirs = recordings_dirs_for_range(uid_dir, camera, t_start, t_end)
            if not dirs:
                log(f"[warn] sem diretórios de gravação para {uid_dir.name}/{camera} no intervalo {t_start}..{t_end}")
                continue
            segs = select_segments(dirs, t_start, t_end)
            if not segs:
                log(f"[warn] sem segmentos para {uid_dir.name}/{camera} no intervalo {t_start}..{t_end}")
                continue
            ok, msg = build_concat_and_trim(segs, out_mp4, t_start, t_end)
            if not ok:
                log(f"[ERRO] {uid_dir.name}/{camera} {jpg.name}: {msg}")
                continue

            meta = {
                "unique_id": uid_dir.name,
                "camera": camera,
                "snapshot": str(jpg),
                "video": str(out_mp4),
                "created_utc": datetime.now(timezone.utc).isoformat(),
                "snapshot_ts_utc": snap_ts.isoformat(),
                "start_utc": t_start.isoformat(),
                "end_utc": t_end.isoformat(),
                "pre_s": args.pre,
                "post_s": args.post,
                "method": "concat_copy_then_trim_fallback_reencode"
            }
            with open(out_json, "w") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
            log(f"[ok] gerado: {out_mp4}  (json: {out_json})")
            cnt += 1
            if args.limit and cnt >= args.limit:
                break
        except Exception as e:
            log(f"[ERRO] exception em {jpg}: {e}")
    log(f"[fim] processados: {cnt}")

if __name__ == "__main__":
    main()
PYEOF

chmod +x "$PY_SCRIPT"

# 3) Rodar 1x (teste sobre poucos eventos)
FRIGATE_BASE="${FRIGATE_BASE:-/home/edimar/FRIGATE}"
echo "[info] usando FRIGATE_BASE=${FRIGATE_BASE}"

python3 "$PY_SCRIPT" \
  --base "$FRIGATE_BASE" \
  --pre 12 \
  --post 12 \
  --limit 5 \
  --verbose 1 | tee "$LOG_DIR/event_assembler_phase1.log"

echo
echo "[OK] Fase 1 concluída. Log salvo em $LOG_DIR/event_assembler_phase1.log"
