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
    # ---------- v51 扩充主题（牧师问答深化） ----------
    "sanctification": (["sanctif", "holiness", "holy life", "overcom", "victory", "consecrat"],
                       ["character", "Christ", "life", "growth", "soul", "obedien", "grace", "daily"],
                       {"SC", "AA", "DA", "GC", "MYP", "CG"}),
    "holy_spirit": (["Holy Spirit", "Holy Ghost", "Spirit of God", "Comforter", "Advocate"],
                    ["power", "gift", "guide", "witness", "convict", "presence", "baptism", "fill"],
                    {"AA", "DA", "SC", "GC", "Ed"}),
    "justification": (["justif", "righteousness", "imput", "grace of God", "faith of Jesus"],
                      ["sin", "law", "Christ", "salvation", "pardone", "works", "redeem"],
                      {"GC", "DA", "SC", "SM", "1SM", "AA"}),
    "gospel_mission": (["gospel", "mission", "witness", "evangel"],
                       [" preach", "teach", "nation", "world", "soul", "save", "disciple", "commission"],
                       {"AA", "GC", "DA", "MM", "CME", "6T"}),
    "church_order": (["church", "congregation", "brethren", "elders", "deacon"],
                     ["organ", "order", "authority", "discipline", "fellowship", "member", "unity"],
                     {"AA", "GC", "5T", "EW", "TM"}),
    "marriage": (["marriage", "marry", "husband", "wife", "wedding", "spouse"],
                 ["home", "love", "union", "family", "honor", "yoke", "companion"],
                 {"AH", "MYP", "CG", "Ed", "3T", "7T"}),
    "child_discipline": (["discipline", "correction", "punish", "chasten", "reproof", "govern"],
                         ["child", "children", "parent", "mother", "father", "obedien", "submission"],
                         {"CG", "AH", "Ed", "3T", "4T", "PP"}),
    "youth_dedication": (["youth", "young", "teen", "conversion", "first love"],
                         ["heart", "give", "God", "dedicate", "consecrate", "Savior", "church"],
                         {"MYP", "CG", "Ed", "AH"}),
    "sickness_care": (["sick", "sickness", "disease", "illness", "afflict", "patient"],
                      ["care", "nurse", "sanitarium", "remedy", "physician", "nurse", "recuper", "institution"],
                      {"MM", "CME", "MH", "CH", "2T"}),
    "bereavement": (["bereav", "grief", "mourn", "sorrow", "affliction", "loss"],
                    ["death", "dead", "comfort", "hope", "resurrect", "weep", "sorrow"],
                    {"GC", "DA", "2T", "AH", "SC", "Mar"}),
    "true_repentance": (["repent", "confession", "forsake", "confess"],
                        ["sin", "heart", "pardon", "forgive", "mercy", "God", "contrition"],
                        {"SC", "AA", "DA", "GC", "4T", "5T"}),
    "baptism_meaning": (["baptism", "baptize", "baptiz", "buried", "immersion"],
                        ["Christ", "death", "resurrect", "water", "symbol", "church", "public"],
                        {"DA", "AA", "GC", "6T", "EW"}),
    "creation_origin": (["creation", "created", "Creator", "six days", "Genesis"],
                        ["God", "world", "earth", "beginning", "rest", "Sabbath", "week", "make"],
                        {"Ed", "PP", "GC", "DA", "ST"}),
    "great_controversy": (["controversy", "Satan", "devil", "Lucifer", "rebel"],
                          ["heaven", "war", "sin", "origin", "evil", "earth", "fall", "redeem"],
                          {"GC", "PP", "DA", "SR"}),
    "law_grace": (["law of God", "ten commandments", "commandments", "decree"],
                  ["grace", "obedien", "keep", "moral", "ceremonial", "abolish", "eternal", "written"],
                  {"GC", "PP", "DA", "COL", "4T", "6T"}),
    "last_days_events": (["time of trouble", "mark of the beast", "Sunday law", "seal of God",
                          "close of probation", "probation"],
                         ["end", "last", "day", "beast", "worship", "decree", "faithful", "deliver"],
                         {"GC", "EW", "5T", "Mar", "TM"}),
    "heaven_new_earth": (["new earth", "heaven", "paradise", "city of God", "inheritance"],
                         ["eternal", "restore", "glory", "home", "saint", "everlast", "life", "redeem"],
                         {"GC", "DA", "EW", "Mar", "COL"}),
    "christ_character": (["character of Christ", "Jesus", "Savior", "Redeemer"],
                         ["love", "meek", "lowly", "humble", "compassion", "sympath", "example", "perfect"],
                         {"DA", "SC", "MB", "AA", "CG"}),
    "faith_trials": (["trial", "tribulation", "affliction", "persecut", "suffer", "test"],
                     ["faith", "patience", "endur", "God", "purpose", "refine", "gold", "character"],
                     {"AA", "GC", "DA", "5T", "Mar", "SC"}),
    "providence": (["providence", "God's care", "guidance", "leading"],
                   ["care", "path", "plan", "trust", "permit", "all things", "work", "purpose"],
                   {"SC", "DA", "GC", "Ed", "AH"}),
    "spiritual_darkness": (["spiritualism", "spirit return", "medium", "séance", "seance", "deceiv"],
                           ["dead", "satan", "miracle", "sign", "wonder", "lie", "demon", "apparition"],
                           {"GC", "EW", "Mar", "2SM", "5T"}),
    "work_vocation": (["work", "labor", "vocation", "occupation", "calling", "business"],
                      ["diligence", "honest", "daily", "secular", "trade", "means", "faithful", "serve"],
                       {"CG", "Ed", "AH", "7T", "MM", "CME"}),
    "dress_simplicity": (["dress", "apparel", "clothing", "adorn"],
                         ["simple", "modest", "plain", "pride", "extravagan", "fashion", "ornament"],
                         {"EV", "1T", "2T", "4T", "AH", "CG"}),
    "recreation_amusement": (["amusement", "recreation", "pleasure", "theater", "theatre", "card playing",
                              "dancing", "gambling", "lottery"],
                             ["mind", "soul", "influence", "character", "youth", "time", "waste", "demoral"],
                             {"AH", "CG", "MYP", "Ed", "4T", "CME"}),
    "service_charity": (["poor", "charity", "benevolen", "widow", "orphan", "needy", "help"],
                        ["give", "help", "love", "neighbor", "relief", "suffer", "kindness", "sacrifice"],
                        {"WM", "MM", "6T", "DA", "AH", "CH"}),
    "missionary_spirit": (["missionary", "mission field", "foreign mission", "home mission"],
                          ["give", "send", "support", "field", "worker", "soul", "sacrifice", "offer"],
                          {"6T", "7T", "MM", "CME", "GC", "WM"}),
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
