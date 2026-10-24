# v54 漂移扫描：untracked 且 remote 已存在的文件，本地 hash-object --no-filters
# 与远端 tree sha 比对；DIFFERS 的必须补进 _api_commit.py 的 _extra。
import base64, json, re, subprocess, sys, urllib.request, urllib.parse
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
REPO = "xinwuwan/Bible"
API = "https://api.github.com"

url = subprocess.run(["git", "-C", str(ROOT), "remote", "get-url", "origin"],
                     capture_output=True, text=True).stdout
m = re.search(r"https://([^@/]+)@github\.com/", url)
cred = m.group(1)
TOKEN = cred.split(":", 1)[1] if ":" in cred else cred
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def api(method, path):
    req = urllib.request.Request(API + path, method=method, headers={
        "Authorization": "Bearer " + TOKEN,
        "Accept": "application/vnd.github+json",
        "User-Agent": "wb-drift-scan",
    })
    with opener.open(req, timeout=120) as r:
        return json.loads(r.read().decode())

ref = api("GET", "/repos/%s/git/refs/heads/main" % REPO)
base = ref["object"]["sha"]
t = api("GET", "/repos/%s/git/trees/%s?recursive=1" % (REPO, base))
remote = {i["path"]: i["sha"] for i in t.get("tree", []) if i["type"] == "blob"}
print("remote blobs:", len(remote))

untracked = subprocess.run(
    ["git", "-C", str(ROOT), "ls-files", "--others", "--exclude-standard"],
    capture_output=True, text=True).stdout.splitlines()

differs, same, new = [], [], []
for p in untracked:
    p = p.strip().strip('"')
    if not p:
        continue
    fp = ROOT / p
    if not fp.is_file():
        continue
    local_sha = subprocess.run(
        ["git", "-C", str(ROOT), "hash-object", "--no-filters", p],
        capture_output=True, text=True).stdout.strip()
    if p in remote:
        (same if remote[p] == local_sha else differs).append(p)
    else:
        new.append(p)

print("\n=== DIFFERS（本地与远端不同，必须补进 _extra） ===")
for p in differs:
    print(" ", p)
print("\n=== SAME（远端已有且内容一致） ===")
for p in same:
    print(" ", p)
print("\n=== NEW（远端没有） ===")
for p in new[:40]:
    print(" ", p)
print("... NEW total:", len(new))
