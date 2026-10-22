# _build_egw_pool.py
# v50：从 _egw_corpus/ 全文中按主题筛选候选段落，产出候选短名单供人工审阅；
# 审阅后由 _finalize_egw_pool.py 按选定的 ref 列表逐字摘录生成最终引用池。
#
# 主题即问答条目主题；关键词命中计分，取每个主题前 N 条候选。
import json
import re
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
CORPUS = ROOT / "_egw_corpus"

TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"\s+")


def clean(html: str) -> str:
    t = TAG_RE.sub(" ", html)
    t = (t.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<")
          .replace("&gt;", ">").replace("&#39;", "'").replace("&quot;", '"')
          .replace("&rsquo;", "\u2019").replace("&lsquo;", "\u2018")
          .replace("&ldquo;", "\u201c").replace("&rdquo;", "\u201d")
          .replace("&mdash;", "\u2014").replace("&ndash;", "\u2013"))
    return WS_RE.sub(" ", t).strip()


def load_corpus():
    paras = []
    for f in sorted(CORPUS.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        code = d["code"]
        for p in d["paras"]:
            txt = clean(p.get("content") or "")
            if len(txt) < 40:
                continue
            paras.append({
                "code": code, "ref": p.get("ref") or "", "reflong": p.get("reflong") or "",
                "type": p.get("type") or "p", "text": txt,
            })
    return paras


# 主题 -> (必须命中的词任一组[全都要], 加分词)
TOPICS = {
    "diet_plant": (["vegetable", "fruit", "grain", "nut", "bean", "legume"],
                   ["diet", "eat", "food", "health", "meal", "wholesome"],
                   {"MH", "CD", "CH", "Te", "MM", "CME"}),
    "diet_flesh": (["flesh", "meat", "animal food"],
                   ["diet", "eat", "food", "disease", "cancer", "blood"],
                   {"MH", "CD", "CH", "Te", "MM", "CME"}),
    "diet_regular": (["meal", "appetite", "eating"],
                     ["regular", "two", "three", "between", "sleep", "stomach", "hour"],
                     {"MH", "CD", "CH", "Te"}),
    "water": (["water"], ["drink", "health", "bath", "clean", "impurit", "fever", "blood"],
              {"MH", "CD", "CH", "Te"}),
    "sunshine": (["sun", "sunlight", "sunshine"],
                 ["health", "room", "sleep", "cheer", "sickroom", "shadow", "ray"],
                 {"MH", "CD", "CH"}),
    "air": (["air"], ["fresh", "breathe", "breath", "ventilat", "room", "impur", "lung"],
            {"MH", "CD", "CH"}),
    "exercise": (["exercise", "walking", "inactivity", "muscular", "gymnastic"],
                 ["health", "muscle", "blood", "body", "labor", "physical", "indoor"],
                 {"MH", "CD", "CH", "Ed", "CG", "CT"}),
    "temperance": (["tobacco", "smoking", "alcohol", "wine", "liquor", "tea", "coffee",
                    "opium", "narcotic", "intoxicat", "stimulant"],
                   ["health", "habit", "stomach", "nerve", "body", "poison", "brain"],
                   {"MH", "CD", "CH", "Te", "CME"}),
    "rest_sleep": (["sleep", "rest"],
                   ["nature", "restor", "night", "hour", "fatigue", "tired", "weary"],
                   {"MH", "CD", "CH"}),
    "joy_cheer": (["joy", "cheerful", "cheerfulness", "gladness", "rejoice", "hope", "courage"],
                  ["health", "heart", "strength", "mind", "soul", "sick", "disease"],
                  {"MH", "CD", "CH", "SC"}),
    "trust_healing": (["trust", "faith", "believe", "confidence"],
                      ["healing", "heal", "sick", "disease", "prayer", "physician", "remedy", "recover"],
                      {"MH", "CD", "CH", "SC"}),
    "medical_missionary": (["medical missionary", "gospel"],
                           ["health", "body", "soul", "save", "work", "minister", "sin"],
                           {"MH", "CD", "CH", "MM", "CME"}),
    "health_religion": (["health", "body"],
                        ["religion", "religious", "duty", "soul", "character", "piety", "law"],
                        {"MH", "CD", "CH"}),
    "education_purpose": (["education", "school", "teacher"],
                          ["character", "image", "restore", "mind", "heart", "soul",
                           "Bible", "God", "true", "higher"],
                          {"Ed", "CG", "CT", "FE", "CE", "SpTEd", "AH"}),
    "education_home": (["home", "mother", "father", "parent", "family"],
                       ["school", "teach", "child", "train", "first", "discipline", "influence"],
                       {"Ed", "CG", "CT", "FE", "CE", "SpTEd", "AH"}),
    "education_bible": (["Bible", "Scripture", "word of God", "Scriptures"],
                        ["school", "study", "book", "lesson", "teach", "class", "educat"],
                        {"Ed", "CG", "CT", "FE", "CE", "SpTEd", "AH"}),
    "education_character": (["character", "habit"],
                            ["form", "build", "child", "school", "youth", "train", "early"],
                            {"Ed", "CG", "CT", "FE", "CE", "SpTEd", "AH"}),
    "education_labor": (["labor", "industry", "work"],
                        ["school", "student", "study", "exercise", "hand", "educat", "trade"],
                        {"Ed", "CG", "CT", "FE", "CE", "SpTEd"}),
    "prayer": (["prayer", "pray", "praying"],
               ["faith", "heart", "God", "answer", "secret", "closet", "burden", "Spirit"],
               {"SC", "MH", "CH"}),
    "bible_study": (["Bible", "Scripture", "word of God", "Scriptures"],
                    ["study", "search", "diligent", "understand", "daily", "read", "feed"],
                    {"SC", "Ed", "CG", "CT"}),
    "faith": (["faith"], ["believe", "trust", "promise", "salvation", "Christ", "heart", "lay hold"],
              {"SC"}),
    "stewardship": (["tithe", "offering", "property", "means", "steward", "treasure"],
                    ["God", "give", "Lord", "goods", "service", "first", "portion"],
                    {"GC", "DA", "CH", "CD", "AH"}),
    "sabbath_rest": (["Sabbath"], ["rest", "holy", "day", "bless", "Creator", "sign", "delight"],
                     {"GC", "DA", "CH"}),
    "death_state": (["dead", "death", "died", "asleep"],
                    ["grave", "resurrect", "dust", "rise", "immortal", "corrupt"],
                    {"GC", "DA", "SC"}),
    "prophecy_gift": (["prophet", "prophets", "prophetic", "spirit of prophecy",
                       "testimony", "testimonies", "gift of prophecy"],
                      ["Bible", "Scripture", "church", "gift", "counsel", "guide", "word"],
                      {"GC", "DA"}),
    "second_coming": (["coming", "advent", "appearing"],
                      ["Christ", "cloud", "heaven", "hope", "near", "sign", "Jesus"],
                      {"GC", "DA", "SC"}),
}


def _hit(text_l: str, word: str) -> bool:
    return re.search(r"\b" + re.escape(word.lower()), text_l) is not None


def score(text_l: str, must_any, bonus):
    """任一同义词组命中即候选；命中组越多、加权越长，排序越靠前。词边界匹配。"""
    groups_hit = 0
    s = 0
    for grp in must_any:
        words = grp if isinstance(grp, (list, tuple)) else [grp]
        if any(_hit(text_l, w) for w in words):
            groups_hit += 1
            s += 5
    if groups_hit == 0:
        return -1
    s += sum(len(w) * len(re.findall(r"\b" + re.escape(w.lower()), text_l))
             for grp in bonus for w in grp)
    s += groups_hit * 5
    return s


def main():
    paras = load_corpus()
    print("corpus paragraphs:", len(paras))
    out = {}
    for topic, spec in TOPICS.items():
        must_any, bonus, books = spec
        cands = []
        for p in paras:
            if p["code"] not in books:
                continue
            tl = p["text"].lower()
            s = score(tl, must_any, bonus)
            if s > 0:
                cands.append((s, p))
        cands.sort(key=lambda x: -x[0])
        picked = []
        seen_txt = set()
        for s, p in cands:
            key = p["text"][:80]
            if key in seen_txt:
                continue
            seen_txt.add(key)
            picked.append({"code": p["code"], "ref": p["ref"], "score": s,
                           "text": p["text"][:300]})
            if len(picked) >= 16:
                break
        out[topic] = picked
        print("%-22s cands=%4d picked=%d" % (topic, len(cands), len(picked)))
    (ROOT / "_egw_candidates.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote _egw_candidates.json")


if __name__ == "__main__":
    main()
