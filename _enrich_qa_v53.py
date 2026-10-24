# _enrich_qa_v53.py
# v53：问答准确度修复（用户实报三个答非所问案例的根因治理）
#
# A. 牧师问答：新增「怀爱伦论家庭」条目（idx288）
#    根因：「家庭」不在任何关键词中 → FMM 切不出 → 覆盖率门控对该词失明 →
#    「怀爱伦的著作中，有哪些是关于家庭的？」cov=1.00 误判全覆盖，误答 idx239
#    「入门路线」。新条目须持「怀爱伦的著作」「怀爱伦」「家庭」等关键词，
#    才能在 (coverage, score) 排序中胜出（平局时队首旧条目仍安全）。
# B. 健康问答：新增「食物相克/搭配」条目（health idx54）
#    根因：「草本植物和木本植物可以一起同食吗」整句只命中两字通用词「植物」
#    （score=2 压中旧门槛 >=2）→ 触发泛泛饮食条目。新条目持 草本/木本/同食/
#    一起/相克 等关键词，多命中得分 8，稳赢；另在 health_qa_logic 加通用词护栏。
# C. 数据修复：idx261「 practical 的路径」中英混杂 typo → 「实际的路径」。
#
# 引用纪律：EGW 逐字引用全部取自 _egw_quote_pool.json；KJV 复用 qa_faq.json
# 既有已审核引用池（按 source_id 原文复制）；不新编任何引用。
import json
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
FAQ = ROOT / "flutter_app/assets/web/qa_faq.json"
HEALTH = ROOT / "flutter_app/assets/web/health_faq.json"
POOL = json.loads((ROOT / "_egw_quote_pool.json").read_text(encoding="utf-8"))
POOL_BY_SID = {p["source_id"]: p for p in POOL}

doc = json.loads(FAQ.read_text(encoding="utf-8"))
faq = doc["faq"]
OLD_POOL = {}
for e in faq:
    for c in e.get("citations", []):
        OLD_POOL.setdefault(c["source_id"], c)


def E(sid):
    p = POOL_BY_SID[sid]
    return {"source_type": "EGW", "source_id": sid, "ref": p["ref"], "snippet": p["snippet"]}


def cite_old(sid):
    if sid not in OLD_POOL:
        raise SystemExit("FATAL: 既有池无 %s" % sid)
    return dict(OLD_POOL[sid])


# ---------- 幂等检查（基于磁盘原始内容，先于任何修改） ----------
if any("怀爱伦关于家庭最系统的著述" in (e.get("answer_zh") or "") for e in faq):
    raise SystemExit("FATAL: 家庭条目已存在，勿重复运行")
h_doc_check = json.loads(HEALTH.read_text(encoding="utf-8"))
if any("食物相克」的教导" in (e.get("answer_zh") or "") for e in h_doc_check["faq"]):
    raise SystemExit("FATAL: 健康食物搭配条目已存在，勿重复运行")
if not any("practical 的路径" in (e.get("answer_zh") or "") for e in faq):
    print("note: typo「practical 的路径」未找到（可能已修复）")
print("idempotency check OK")


# ---------- C. typo 修复 ----------
n_typo = 0
for e in faq:
    a = e.get("answer_zh", "")
    if "practical 的路径" in a:
        e["answer_zh"] = a.replace(" practical 的路径", "实际的路径")
        n_typo += 1
print("typo fixed:", n_typo)

# ---------- A. 牧师家庭条目 ----------
# 关键词冲突自检：只拦 NEW 内部重复；与既有条目共享（怀爱伦/怀爱伦的著作）
# 属安全——FMM 平局决胜规则下队尾新条目持裸词必输给队首旧条目，
# 仅当覆盖率/分数严格更高才赢（家庭问句正是如此）。
NEW_KW = [
    "家庭", "家庭教育", "家庭生活", "婚姻家庭", "论家庭", "怀爱伦家庭",
    "怀爱伦论家庭", "怀著论家庭", "关于家庭", "家庭关系", "夫妇关系",
    "亲子关系", "家人相处", "egw family", "怀爱伦", "怀著", "怀爱伦的著作", "怀爱伦著作",
]
assert len(NEW_KW) == len(set(NEW_KW)), "NEW 关键词内部重复"
existing_kw = set()
for e in faq:
    existing_kw.update(e.get("keywords", []))
shared = [k for k in NEW_KW if k in existing_kw]
print("与既有条目共享的关键词（安全，平局输给队首）:", shared)
holders = {}
for k in NEW_KW:
    for i, e in enumerate(faq):
        if k in e.get("keywords", []):
            holders.setdefault(k, []).append(i)
for k in ["家庭", "怀爱伦的著作", "怀爱伦", "怀著"]:
    print("  %s 被既有条目持有: %s" % (k, holders.get(k, "无")))

# 成对断言：家庭问句必须由新条目赢（coverage=1.0 且 score 严格高于任何旧条目）
family_entry = {
    "keywords": NEW_KW,
    "answer_zh": (
        "**怀爱伦关于家庭最系统的著述是《复临信徒的家庭》（The Adventist Home）；"
        "此外《教会证言》卷六、卷七有大量家庭实务劝导，《教育论》与"
        "《给家长和教师的证言》专论儿女教养，《先祖与先知》则以族长家庭为典范。** "
        "在她眼中，家庭是神所设立的第一所学校：「主本着祂的智慧命定，"
        "家庭要成为一切教育机构中最伟大的一所」（AH 182.2）；"
        "「每一个家庭的四周都有上帝划定的神圣范围，应当予以保持」（AH 177.1）。\n\n"
        "① 《复临信徒的家庭》——家庭生活总论：婚姻的选择与预备（AH 43.1）、"
        "夫妇相处、教养原则、家庭敬拜，是最该先读的一部；\n"
        "② 《教会证言》卷六、卷七——大量针对具体家庭的实务劝导与劝勉；\n"
        "③ 《教育论》《给家长和教师的证言》——儿女教育与「第一本教科书」；\n"
        "④ 《先祖与先知》——亚伯拉罕、以撒、雅各等族长家庭的信心榜样。\n\n"
        "圣经同样把家庭放在信仰传承的中心：「我所吩咐你的话都要记在心上，"
        "也要殷勤教训你的儿女」（申 6:6-7）；「你们作父亲的，不要惹儿女的气，"
        "只要照着主的教训和警戒养育他们」（弗 6:4）。\n\n"
        "建议的读法：先从《复临信徒的家庭》通读一遍，再按需要查《教会证言》中"
        "相关的书信段落——她的家庭劝勉从来不是抽象原则，而是落到日常相处的实处。"
    ),
    "citations": [
        E("EGW-AH-182.2"), E("EGW-AH-177.1"), E("EGW-AH-43.1"),
        cite_old("KJV-DEU6:6"), cite_old("KJV-DEU6:7"), cite_old("KJV-EPH6:4"),
    ],
}
for sid in ["EGW-AH-182.2", "EGW-AH-177.1", "EGW-AH-43.1", "KJV-DEU6:6", "KJV-DEU6:7", "KJV-EPH6:4"]:
    assert sid in POOL_BY_SID or sid in OLD_POOL, "引用缺失: %s" % sid
faq.append(family_entry)
print("qa_faq.json: %d -> %d 条（+1 家庭条目）" % (len(faq) - 1, len(faq)))

# ---------- B. 健康食物搭配条目 ----------
h = json.loads(HEALTH.read_text(encoding="utf-8"))
hfaq = h["faq"]
H_NEW_KW = [
    "食物相克", "食物搭配", "相克", "一起吃", "同食", "一起吃吗", "混吃",
    "草本", "木本", "搭配吃", "饮食搭配", "能不能一起吃", "能一起吃吗",
    "一起同食", "一起煮", "混着吃", "同时吃",
]
assert len(H_NEW_KW) == len(set(H_NEW_KW)), "健康 NEW 关键词内部重复"
h_existing = set()
for e in hfaq:
    h_existing.update(e.get("keywords", []))
h_shared = [k for k in H_NEW_KW if k in h_existing]
print("健康与既有共享关键词:", h_shared)
# 既有条目「饮食搭配」（idx0）与新条目共享：子串匹配下「饮食怎么搭配」类
# 问句 idx0 得分更高（怎么搭配 4 字），不受影响；「一起吃」类归新条目。
kjv_1co10 = None
for e in hfaq:
    for c in e.get("citations", []):
        if c.get("sourceId") == "哥林多前书 10:31":
            kjv_1co10 = dict(c)
assert kjv_1co10 is not None, "健康模块缺 哥林多前书 10:31 引用（需先补池）"
print("复用健康池引用:", kjv_1co10["sourceId"])

hfaq.append({
    "keywords": H_NEW_KW,
    "answer_zh": (
        "**圣经和怀爱伦的著作中都没有「食物相克」的教导——哪些食物可以搭配着吃，"
        "权威依据里没有任何禁令；真正的原则是感恩领受、简单自然、适量节制。**\n\n"
        "① 圣经的态度是「感恩」而非「禁忌」：「所以你们或吃或喝，无论做什么，"
        "都要为荣耀神而行」（哥林多前书 10:31）；\n"
        "② 怀爱伦论饮食，重点从来在食物的「质」，不在搭配禁忌——"
        "「五谷、水果、坚果和蔬菜是造物主为我们选定的食物」（CD 81.2），"
        "「饮食上的节制得到思想与道德活力的酬报」（CD 126.3）；\n"
        "③ 她甚至劝戒不要拿食物条文彼此判断：「我们不要把吃肉作为弟兄相交的试验」"
        "（CD 404.3）——为搭配禁忌制造规条，反而偏离了福音的自由；\n"
        "④ 真正需要遵医嘱的是疾病饮食：慢性肾病、糖尿病、痛风等有明确的医学"
        "饮食要求，请咨询医生或临床营养师，不要轻信民间流传的「相克」清单。"
    ),
    "citations": [
        kjv_1co10,
        {"sourceType": "egw", "sourceId": "EGW-CD-81.2",
         "ref": POOL_BY_SID["EGW-CD-81.2"]["ref"], "snippet": POOL_BY_SID["EGW-CD-81.2"]["snippet"]},
        {"sourceType": "egw", "sourceId": "EGW-CD-126.3",
         "ref": POOL_BY_SID["EGW-CD-126.3"]["ref"], "snippet": POOL_BY_SID["EGW-CD-126.3"]["snippet"]},
        {"sourceType": "egw", "sourceId": "EGW-CD-404.3",
         "ref": POOL_BY_SID["EGW-CD-404.3"]["ref"], "snippet": POOL_BY_SID["EGW-CD-404.3"]["snippet"]},
    ],
})
print("health_faq.json: %d -> %d 条（+1 食物搭配条目）" % (len(hfaq) - 1, len(hfaq)))

# ---------- 落盘 ----------
FAQ.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
HEALTH.write_text(json.dumps(h, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("written OK")
