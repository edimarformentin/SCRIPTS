import os, time, pathlib, shutil, datetime

LOG_DIR = os.getenv("LOG_DIR", "/logs")
RETENTION = int(os.getenv("LOG_RETENTION_DAYS", "7"))
INTERVAL = int(os.getenv("INTERVAL_SEC", "3600"))

def cleanup():
    base = pathlib.Path(LOG_DIR)
    if not base.exists():
        print("[janitor] log dir não encontrado:", LOG_DIR, flush=True)
        return
    cutoff = datetime.datetime.utcnow() - datetime.timedelta(days=RETENTION)
    for p in base.rglob("*"):
        try:
            if p.is_file():
                mtime = datetime.datetime.utcfromtimestamp(p.stat().st_mtime)
                if mtime < cutoff:
                    print("[janitor] removendo arquivo antigo:", p, flush=True)
                    p.unlink(missing_ok=True)
        except Exception as e:
            print("[janitor] erro ao processar", p, "->", e, flush=True)

def main():
    print("[janitor] iniciado. Retenção:", RETENTION, "dias", "dir:", LOG_DIR, flush=True)
    while True:
        cleanup()
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
