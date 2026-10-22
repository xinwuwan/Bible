# _finalize_egw_pool.py
# v50：把人工审定的 (code, ref) 清单变成最终 EGW 引用池 _egw_quote_pool.json。
# 规则：snippet 必须与语料逐字一致（仅做三项净化：去段首编号、去尾部「— Book, page」
# 出处注、按句界截到 <=460 字符）；ref 用标准编号（如 CD 81.2）；source_id=EGW-{code}-{ref}。
import json
import re
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
CORPUS = ROOT / "_egw_corpus"
OUT = ROOT / "_egw_quote_pool.json"

BOOK_TITLE = {
    "SC": "Steps to Christ", "MH": "The Ministry of Healing", "Te": "Temperance",
    "CD": "Counsels on Diet and Foods", "CH": "Counsels on Health",
    "MM": "Medical Ministry", "CME": "A Call to Medical Evangelism",
    "Ed": "Education", "CG": "Child Guidance",
    "CT": "Counsels to Parents, Teachers, and Students",
    "FE": "Fundamentals of Christian Education", "CE": "Christian Education",
    "SpTEd": "Special Testimonies on Education", "AH": "The Adventist Home",
    "MYP": "Messages to Young People", "HDL": "Help in Daily Living",
    "GC": "The Great Controversy", "DA": "The Desire of Ages",
}

# 人工审定清单：code -> [ref, ...]（ref 即 API refcode_short 全串，如 "CD 81.2"）
SELECT = {
    "CD": ["CD 81.2", "CD 412.1", "CD 229.1", "CD 175.2", "CD 421.3", "CD 420.1",
           "CD 301.3", "CD 301.2", "CD 104.1", "CD 18.5", "CD 76.4", "CD 447.2",
           "CD 59.1", "CD 126.3", "CD 50.1", "CD 404.3", "CD 71.1", "CD 421.4",
           "CD 421.6", "CD 339.2", "CD 281.2", "CD 427.2", "CD 173.2", "CD 180.3",
           "CD 176.1"],
    "CH": ["CH 170.3", "CH 344.1", "CH 457.1", "CH 210.3", "CH 28.2", "CH 319.2",
           "CH 202.1", "CH 37.3", "CH 118.3", "CH 247.1"],
    "MH": ["MH 327.1", "MH 241.1"],
    "CG": ["CG 341.4", "CG 124.3", "CG 17.1", "CG 41.1", "CG 296.2", "CG 35.1"],
    "AH": ["AH 182.2", "AH 172.2", "AH 184.2", "AH 389.1", "AH 550.2", "AH 148.1"],
    "CE": ["CE 110.1"],
    "Ed": ["Ed 15.2", "Ed 189.1"],
    "MYP": ["MYP 249.3", "MYP 305.2"],
    "GC": ["GC 434.2", "GC 302.2", "GC 322.1"],
    "DA": ["DA 289.1", "DA 787.2", "DA 37.3"],
}

NUM_PREFIX = re.compile(r"^\d+\.\s*")
TAIL_CITE = re.compile(r"\s*[—–-]\s*(The|A|Counsels|Testimonies|Manuscript|Special|Signs|Review|Uncopied|From|Letter|Appendix|Patriarchs|Prophets|Acts|Desire|Gospel|Ministry)[^—–-]{0,140}$")


def clean(html: str) -> str:
    t = re.sub(r"<[^>]+>", " ", html)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                 ("&#39;", "'"), ("&quot;", '"'), ("&rsquo;", "\u2019"),
                 ("&lsquo;", "\u2018"), ("&ldquo;", "\u201c"), ("&rdquo;", "\u201d"),
                 ("&mdash;", "\u2014"), ("&ndash;", "\u2013")):
        t = t.replace(a, b)
    return re.sub(r"\s+", " ", t).strip()


def trim_sentences(text: str, limit: int = 460) -> str:
    if len(text) <= limit:
        return text
    cut = text[:limit]
    m = list(re.finditer(r"[.!?](?:\u201d|\")?\s", cut))
    if m:
        return cut[:m[-1].end()].strip()
    return cut.strip()


def main():
    # 载入语料并按 (code, ref) 索引
    index = {}
    for f in sorted(CORPUS.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        code = d["code"]
        for p in d["paras"]:
            ref = (p.get("ref") or "").strip()
            if not ref:
                continue
            txt = clean(p.get("content") or "")
            if len(txt) < 30:
                continue
            # 同一 ref 可能多段（重复引用），取最长的一段
            key = (code, ref)
            if key not in index or len(txt) > len(index[key]):
                index[key] = txt

    pool = []
    missing = []
    for code, refs in SELECT.items():
        title = BOOK_TITLE[code]
        for ref in refs:
            key = (code, ref)
            if key not in index:
                missing.append(key)
                continue
            txt = NUM_PREFIX.sub("", index[key]).strip()
            txt = TAIL_CITE.sub("", txt).strip()
            txt = trim_sentences(txt)
            if not txt:
                missing.append(key)
                continue
            pool.append({
                "source_id": "EGW-%s-%s" % (code, ref.split(" ", 1)[1]),
                "book_code": code,
                "book": title,
                "ref": "%s, p. %s (%s)" % (title, ref.split(" ", 1)[1], ref),
                "short_ref": ref,
                "snippet": txt,
            })
    if missing:
        raise SystemExit("FATAL missing paragraphs: %s" % missing)
    OUT.write_text(json.dumps(pool, ensure_ascii=False, indent=1), encoding="utf-8")
    print("pool entries:", len(pool), "-> wrote _egw_quote_pool.json")
    for p in pool:
        print("  %-18s %-42s %s" % (p["source_id"], p["short_ref"], p["snippet"][:70]))


if __name__ == "__main__":
    main()
