# backend/app/kb.py
# 知识库加载与检索（纯标准库，可在沙箱直接单测）。
#
# kb.json 结构：
#   verses:   [{ref, book_code, chapter, verse, text(KJV 英文), zh(本应用中文产出)}]
#   doctrine: [{belief_id, code, title_en, title_zh, en_text, zh_text}]
#   faq:      [{keywords:[...], answer_zh, citations:[{source_type,source_id,ref,snippet}]}]
import json
import os
import re

# 书卷别名 → 标准 3 字母代码（用于"约翰福音3章16节"这类中文经文引用解析）
BOOK_ALIASES = {
    "genesis": "GEN", "创世记": "GEN", "創世記": "GEN",
    "exodus": "EXO", "出埃及记": "EXO", "出埃及記": "EXO",
    "leviticus": "LEV", "利未记": "LEV", "利未記": "LEV",
    "numbers": "NUM", "民数记": "NUM", "民數記": "NUM",
    "deuteronomy": "DEU", "申命记": "DEU", "申命記": "DEU",
    "joshua": "JOS", "约书亚记": "JOS", "約書亞記": "JOS",
    "judges": "JDG", "士师记": "JDG", "士師記": "JDG",
    "ruth": "RUT", "路得记": "RUT", "路得記": "RUT",
    "1 samuel": "1SA", "撒母耳记上": "1SA", "撒母耳記上": "1SA",
    "2 samuel": "2SA", "撒母耳记下": "2SA", "撒母耳記下": "2SA",
    "1 kings": "1KI", "列王纪上": "1KI", "列王紀上": "1KI",
    "2 kings": "2KI", "列王纪下": "2KI", "列王紀下": "2KI",
    "1 chronicles": "1CH", "历代志上": "1CH", "歷代志上": "1CH",
    "2 chronicles": "2CH", "历代志下": "2CH", "歷代志下": "2CH",
    "ezra": "EZR", "以斯拉记": "EZR", "以斯拉記": "EZR",
    "nehemiah": "NEH", "尼希米记": "NEH", "尼希米記": "NEH",
    "esther": "EST", "以斯帖记": "EST", "以斯帖記": "EST",
    "job": "JOB", "约伯记": "JOB", "約伯記": "JOB",
    "psalms": "PSA", "诗篇": "PSA", "詩篇": "PSA",
    "proverbs": "PRO", "箴言": "PRO", "箴言": "PRO",
    "ecclesiastes": "ECC", "传道书": "ECC", "傳道書": "ECC",
    "song of solomon": "SNG", "雅歌": "SNG", "雅歌": "SNG",
    "isaiah": "ISA", "以赛亚书": "ISA", "以賽亞書": "ISA",
    "jeremiah": "JER", "耶利米书": "JER", "耶利米書": "JER",
    "lamentations": "LAM", "耶利米哀歌": "LAM", "耶利米哀歌": "LAM",
    "ezekiel": "EZK", "以西结书": "EZK", "以西結書": "EZK",
    "daniel": "DAN", "但以理书": "DAN", "但以理書": "DAN",
    "hosea": "HOS", "何西阿书": "HOS", "何西阿書": "HOS",
    "joel": "JOL", "约珥书": "JOL", "約珥書": "JOL",
    "amos": "AMO", "阿摩司书": "AMO", "阿摩司書": "AMO",
    "obadiah": "OBA", "俄巴底亚书": "OBA", "俄巴底亞書": "OBA",
    "jonah": "JON", "约拿书": "JON", "約拿書": "JON",
    "micah": "MIC", "弥迦书": "MIC", "彌迦書": "MIC",
    "nahum": "NAM", "那鸿书": "NAM", "那鴻書": "NAM",
    "habakkuk": "HAB", "哈巴谷书": "HAB", "哈巴谷書": "HAB",
    "zephaniah": "ZEP", "西番雅书": "ZEP", "西番雅書": "ZEP",
    "haggai": "HAG", "哈该书": "HAG", "哈該書": "HAG",
    "zechariah": "ZEC", "撒迦利亚书": "ZEC", "撒迦利亞書": "ZEC",
    "malachi": "MAL", "玛拉基书": "MAL", "瑪拉基書": "MAL",
    "matthew": "MAT", "马太福音": "MAT", "馬太福音": "MAT",
    "mark": "MRK", "马可福音": "MRK", "馬可福音": "MRK",
    "luke": "LUK", "路加福音": "LUK", "路加福音": "LUK",
    "john": "JHN", "约翰福音": "JHN", "約翰福音": "JHN",
    "acts": "ACT", "使徒行传": "ACT", "使徒行傳": "ACT",
    "romans": "ROM", "罗马书": "ROM", "羅馬書": "ROM",
    "1 corinthians": "1CO", "哥林多前书": "1CO", "哥林多前書": "1CO",
    "2 corinthians": "2CO", "哥林多后书": "2CO", "哥林多後書": "2CO",
    "galatians": "GAL", "加拉太书": "GAL", "加拉太書": "GAL",
    "ephesians": "EPH", "以弗所书": "EPH", "以弗所書": "EPH",
    "philippians": "PHP", "腓立比书": "PHP", "腓立比書": "PHP",
    "colossians": "COL", "歌罗西书": "COL", "歌羅西書": "COL",
    "1 thessalonians": "1TH", "帖撒罗尼迦前书": "1TH", "帖撒羅尼迦前書": "1TH",
    "2 thessalonians": "2TH", "帖撒罗尼迦后书": "2TH", "帖撒羅尼迦後書": "2TH",
    "1 timothy": "1TI", "提摩太前书": "1TI", "提摩太前書": "1TI",
    "2 timothy": "2TI", "提摩太后书": "2TI", "提摩太後書": "2TI",
    "titus": "TIT", "提多书": "TIT", "提多書": "TIT",
    "philemon": "PHM", "腓利门书": "PHM", "腓利門書": "PHM",
    "hebrews": "HEB", "希伯来书": "HEB", "希伯來書": "HEB",
    "james": "JAS", "雅各书": "JAS", "雅各書": "JAS",
    "1 peter": "1PE", "彼得前书": "1PE", "彼得前書": "1PE",
    "2 peter": "2PE", "彼得后书": "2PE", "彼得後書": "2PE",
    "1 john": "1JN", "约翰一书": "1JN", "約翰一書": "1JN",
    "2 john": "2JN", "约翰二书": "2JN", "約翰二書": "2JN",
    "3 john": "3JN", "约翰三书": "3JN", "約翰三書": "3JN",
    "jude": "JUD", "犹大书": "JUD", "猶大書": "JUD",
    "revelation": "REV", "启示录": "REV", "啟示錄": "REV",
}

# 保守同义词归一组（组内首词为规范词）。只归一根词，避免语义漂移。
# 与 Dart 端 offline_qa_logic.dart 的 _synGroups 保持一致。
# v51 扩充（7 组，均经 FMM 平局规则验证无回归）：只收指代同一实体的口语变体；
# 裸「奉献」绝不入组（v49 铁律）；「称义/救恩」不并入「得救」（防 idx9 抢答 idx22）。
SYN_GROUPS = [
    ["怀爱伦", "egw", "预言之灵", "怀师母"],
    ["医疗布道", "健康事工", "医药布道", "健康布道", "医疗宣教", "medical missionary"],
    ["祷告", "祈祷", "祈求"],
    ["洗礼", "受洗", "浸礼", "施洗"],
    ["得救", "怎么能得救", "怎样得救", "咋得救"],
    ["耶稣再来", "基督再来", "主再来", "耶稣再临"],
    ["悔改", "忏悔"],
    ["十一奉献", "什一", "纳什一"],
    ["圣灵", "保惠师"],
]
_CANON = {w.lower(): g[0].lower() for g in SYN_GROUPS for w in g}


def _canon(w: str) -> str:
    return _CANON.get((w or "").lower(), (w or "").lower())


def should_answer_direct(coverage: float, score: int) -> bool:
    """覆盖率门控：问题概念被同一条目高比例覆盖才直接回答，否则宁缺毋滥。"""
    if coverage >= 0.999 and score >= 2:
        return True
    if coverage >= 0.6 and score >= 4:
        return True
    return False


class KnowledgeBase:
    def __init__(self, data: dict):
        self.verses = data.get("verses", [])
        self.doctrine = data.get("doctrine", [])
        self.faq = data.get("faq", [])
        self.egw = data.get("egw", [])  # 经审核的怀爱伦(EGW)原版英文引用
        # 经文引用索引： "JHN 3:16" 小写 -> verse
        self._verse_index = {}
        for v in self.verses:
            key = f"{str(v.get('book_code', '')).upper()} {int(v.get('chapter', 0))}:{int(v.get('verse', 0))}".lower()
            self._verse_index[key] = v
        # 概念词典（原始关键词 + 归一词 + 同义词组全体成员），供正向最大匹配切分。
        # 注意：同义词组非规范变体（如「忏悔」「施洗」）须显式入词典，否则 FMM
        # 切不出它们，归一组形同虚设。
        self._concept_dict = set()
        self._max_concept_len = 1
        for g in SYN_GROUPS:
            for w in g:
                wl = (w or "").strip().lower()
                if not wl:
                    continue
                cl = _canon(wl)
                self._concept_dict.add(wl)
                self._concept_dict.add(cl)
                self._max_concept_len = max(self._max_concept_len, len(wl), len(cl))
        for e in self.faq:
            for kw in e.get("keywords", []):
                kl = (kw or "").strip().lower()
                if not kl:
                    continue
                cl = _canon(kl)
                self._concept_dict.add(kl)
                self._concept_dict.add(cl)
                self._max_concept_len = max(self._max_concept_len, len(kl), len(cl))

    @classmethod
    def load(cls, path: str) -> "KnowledgeBase":
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f))

    # ---------- 检索 ----------
    def _concepts(self, question: str):
        """正向最大匹配（FMM）切分问题中的概念集合；空集表示无已知概念。"""
        ql = (question or "").lower()
        out = set()
        i, n = 0, len(ql)
        while i < n:
            hit = 0
            for L in range(min(self._max_concept_len, n - i), 1, -1):
                if ql[i:i + L] in self._concept_dict:
                    hit = L
                    break
            if hit:
                out.add(_canon(ql[i:i + hit]))
                i += hit
            else:
                i += 1
        return out

    def _entry_concepts(self, entry):
        return {_canon(k) for k in entry.get("keywords", []) if (k or "").strip()}

    def match_faq_full(self, question: str):
        """返回 (best_entry, score, coverage)；无命中返回 (None, 0, 0.0)。

        score = 命中概念的长度加权和；coverage = 被同一条目覆盖的问题概念数 /
        问题概念总数。排序键 (coverage, score, 命中数)。
        """
        q = self._concepts(question)
        if not q:
            return None, 0, 0.0
        best, best_key = None, None
        for entry in self.faq:
            matched = self._entry_concepts(entry) & q
            if not matched:
                continue
            score = sum(len(m) for m in matched)
            key = (len(matched) / len(q), score, len(matched))
            if best_key is None or key > best_key:
                best_key, best = key, entry
        if best is None:
            return None, 0, 0.0
        matched = self._entry_concepts(best) & q
        coverage = len(matched) / len(q)
        score = sum(len(m) for m in matched)
        return best, score, coverage

    def match_faq(self, question: str):
        """兼容旧接口：返回 (best_entry, score)。门控判断请用 match_faq_full。"""
        entry, score, _cov = self.match_faq_full(question)
        return entry, score

    def lookup_verse_ref(self, question: str):
        """解析问题中的经文引用（中英均可），命中返回 verse dict，否则 None。"""
        q = (question or "").strip()
        # 英文代码格式：JHN 3:16 / John 3:16
        m = re.search(r"([A-Za-z]{2,4})\s*(\d{1,3})\s*[:：]\s*(\d{1,3})", q)
        if m:
            code = m.group(1).upper()
            # 允许用户输入全称（如 John）
            code = BOOK_ALIASES.get(code.lower(), code)
            key = f"{code} {int(m.group(2))}:{int(m.group(3))}".lower()
            if key in self._verse_index:
                return self._verse_index[key]
        # 中文格式：约翰福音3章16节 / 约3:16
        for name, code in BOOK_ALIASES.items():
            if len(name) <= 2:  # 跳过 "约" 这类过短别名避免误匹配
                continue
            if name in q:
                m2 = re.search(
                    re.escape(name) + r"\s*第?\s*(\d{1,3})\s*章\s*第?\s*(\d{1,3})\s*节?",
                    q,
                )
                if m2:
                    key = f"{code} {int(m2.group(1))}:{int(m2.group(2))}".lower()
                    if key in self._verse_index:
                        return self._verse_index[key]
                # 中文简写：约3:16
                m3 = re.search(re.escape(name) + r"\s*(\d{1,3})\s*[:：]\s*(\d{1,3})", q)
                if m3:
                    key = f"{code} {int(m3.group(1))}:{int(m3.group(2))}".lower()
                    if key in self._verse_index:
                        return self._verse_index[key]
        return None

    def find_egw(self, question: str):
        """按中文/英文主题词匹配经审核的 EGW 原文，返回命中列表。"""
        q = (question or "").lower()
        hits = []
        for e in self.egw:
            topics = [t.lower() for t in e.get("zh_topic", [])] + \
                     [t.lower() for t in e.get("topic", [])]
            if any(t and t in q for t in topics):
                hits.append(e)
        return hits

    def search_verses(self, question: str, top_k: int = 3):
        """按关键词在经文文本/引用上做重叠检索，返回 top_k 条 verse。"""
        q = (question or "").lower()
        scored = []
        for v in self.verses:
            text = (v.get("text", "") + " " + v.get("ref", "")).lower()
            # 英文单词 + 中文逐字重叠
            score = sum(1 for ch in set(q) if ch in text)
            if score > 0:
                scored.append((score, v))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [v for _, v in scored[:top_k]]

    def context_pack(self, limit_doctrine: int = 30, limit_verses: int = 80) -> str:
        """给真 LLM 用的 grounding 上下文（教义 + 经文底本 + EGW 原文）。"""
        lines = []
        for d in self.doctrine[:limit_doctrine]:
            lines.append(
                f"[DOCTRINE {d.get('belief_id')}] {d.get('title_zh','')}: "
                f"{d.get('zh_text','')}"
            )
        for v in self.verses[:limit_verses]:
            lines.append(f"[KJV {v.get('ref','')}] {v.get('text','')}")
        for e in self.egw:
            lines.append(
                f"[EGW {e.get('source_id','')} | {e.get('ref','')}] {e.get('text','')}"
            )
        return "\n".join(lines)
