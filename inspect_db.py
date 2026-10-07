import sqlite3, os

ROOT = r"C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06"
p = os.path.join(ROOT, "app_offline.db")
print("exists:", os.path.exists(p), "size_MB:", round(os.path.getsize(p)/1024/1024, 2) if os.path.exists(p) else 0)

con = sqlite3.connect(p)
cur = con.cursor()
cur.execute("SELECT name, type FROM sqlite_master WHERE type IN ('table','view') ORDER BY name")
objs = cur.fetchall()
print("=== objects ===")
for name, typ in objs:
    try:
        cnt = cur.execute(f"SELECT COUNT(*) FROM '{name}'").fetchone()[0]
    except Exception as e:
        cnt = f"err:{e}"
    print(f"{typ:6} {name:30} rows={cnt}")

print("\n=== schema per table ===")
for name, typ in objs:
    if typ != 'table':
        continue
    print(f"\n--- {name} ---")
    try:
        for row in cur.execute(f"PRAGMA table_info('{name}')"):
            print("  col:", row[1], row[2])
    except Exception as e:
        print("  pragma err", e)

# sample a few rows from likely verse/book tables
for t in ("books", "verses", "chapters", "health_tips", "egw", "references", "books_meta"):
    try:
        cur.execute(f"SELECT * FROM '{t}' LIMIT 2")
        cols = [d[0] for d in cur.description]
        print(f"\n=== sample {t} ===")
        print("cols:", cols)
        for r in cur.fetchall():
            print("  ", r)
    except Exception:
        pass

con.close()
