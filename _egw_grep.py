# _egw_grep.py — 在语料里按短语检索段落（词边界、大小写不敏感），输出 ref + 全文。
import json
import re
import sys
from pathlib import Path

CORPUS = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06/_egw_corpus")


def clean(html: str) -> str:
    t = re.sub(r"<[^>]+>", " ", html)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                 ("&#39;", "'"), ("&quot;", '"'), ("&rsquo;", "\u2019"),
                 ("&lsquo;", "\u2018"), ("&ldquo;", "\u201c"), ("&rdquo;", "\u201d"),
                 ("&mdash;", "\u2014"), ("&ndash;", "\u2013")):
        t = t.replace(a, b)
    return re.sub(r"\s+", " ", t).strip()


def main():
    queries = sys.argv[1:]
    paras = []
    for f in sorted(CORPUS.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for p in d["paras"]:
            txt = clean(p.get("content") or "")
            if len(txt) >= 30:
                paras.append((d["code"], p.get("ref") or "", txt))
    for q in queries:
        pat = re.compile(r"\b" + q.replace(" ", r"\s+"), re.I)
        hits = [(c, r, t) for c, r, t in paras if pat.search(t)]
        print("### '%s' -> %d hits" % (q, len(hits)))
        for c, r, t in hits[:6]:
            print("  [%s %s] %s" % (c, r, t[:340]))
        print()


if __name__ == "__main__":
    main()
