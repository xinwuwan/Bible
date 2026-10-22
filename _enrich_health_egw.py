# _enrich_health_egw.py
# v50：健康模块去假引用 + 怀著接地。
#   ① health_faq.json 52 处假引用（sourceId=EGW-MH，书名误作《医药布道/服务的价值》）
#      全部替换为 _egw_quote_pool.json 中主题对应的真实引用；怀爱伦未着墨的主题
#      （护眼/牙齿/益生菌等）不硬挂引用，只留圣经依据。
#   ② 重点条目答案末尾追加一句中文概括的怀著劝勉 + 标准引用编号（原文在引用区展示）。
#   ③ health_daily.json 每日一贴的来源书名《医药布道》改为正确书名《服务真诠》。
import json
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
FAQ = ROOT / "flutter_app/assets/web/health_faq.json"
DAILY = ROOT / "flutter_app/assets/web/health_daily.json"
POOL = json.loads((ROOT / "_egw_quote_pool.json").read_text(encoding="utf-8"))
POOL_BY_SID = {p["source_id"]: p for p in POOL}

# 条目序号 -> 真实 EGW source_id；None = 删除假引用（怀爱伦未着墨，不硬挂）
MAP = {
    0: "EGW-CD-81.2", 1: "EGW-CD-81.2", 2: "EGW-CD-421.3", 3: "EGW-CG-124.3",
    4: "EGW-CG-341.4", 5: "EGW-CH-170.3", 6: "EGW-CD-104.1", 7: "EGW-CD-427.2",
    8: "EGW-CH-344.1", 9: "EGW-CD-126.3", 10: "EGW-CD-18.5", 11: "EGW-CD-59.1",
    12: "EGW-CD-229.1", 13: "EGW-CD-339.2", 14: "EGW-CD-81.2", 15: "EGW-CD-173.2",
    16: "EGW-CH-37.3", 17: "EGW-CH-344.1", 18: "EGW-CD-301.3", 19: "EGW-CD-229.1",
    20: "EGW-CD-301.2", 21: "EGW-CH-170.3", 22: None, 23: "EGW-CG-124.3", 24: None,
    25: None, 26: "EGW-CD-175.2", 27: "EGW-CD-18.5", 28: "EGW-MH-327.1",
    29: "EGW-CD-421.3", 30: "EGW-CH-170.3", 31: None, 32: "EGW-CH-344.1",
    33: None, 34: None, 35: None, 36: None, 37: "EGW-CD-421.3", 38: None,
    39: "EGW-CD-180.3", 40: "EGW-CD-421.6", 41: "EGW-CD-81.2", 42: "EGW-CD-81.2",
    43: None, 44: "EGW-CD-412.1", 45: None, 46: None, 47: None, 48: None,
    49: None, 50: "EGW-CD-18.5", 51: None, 52: "EGW-CD-104.1",
}

# 重点条目追加的怀著劝勉句（中文概括 + 标准引用编号；英文原文见引用区）
ENRICH = {
    0: "怀爱伦在《论饮食》中明确劝勉：五谷、水果、坚果和蔬菜，是创造主为我们选定的饮食，用最简单自然的方式烹调，最为健康有益（参 CD 81.2）。",
    2: "怀爱伦对饮品的劝勉直截了当：远离茶、咖啡、啤酒、葡萄酒和一切烈酒，水是最好、最能清洁身体的液体（参 CD 421.3）。",
    3: "怀爱伦提醒我们：懒惰是极大的咒诅，神所赐的神经、器官与肌肉，要靠规律的运动来强健（参 CG 124.3）。",
    4: "怀爱伦称睡眠为「大自然甜美的恢复者」，它使疲倦的身体重新得力，为次日的责任作好预备（参 CG 341.4）。",
    5: "怀爱伦在疗养院观察到：对久病的人，最有助于恢复健康与喜乐的，莫过于身处宜人的乡间，坐着或躺在阳光里（参 CH 170.3）。",
    6: "怀爱伦说，纯净的新鲜空气能使血液健康地周身循环，使身体清爽强健，同时也让头脑平静安宁（参 CD 104.1）。",
    7: "怀爱伦警戒：不节制始于我们的餐桌——不健康的饮食加上持续的放纵，消化器官会渐渐衰弱（参 CD 427.2）。",
    8: "怀爱伦指出，心神与身体的关系极为密切：抑郁、焦虑、不满、内疚与猜疑，会瓦解生命的力量、招来衰败（参 CH 344.1）。",
    9: "怀爱伦劝勉：饮食上的节制，会得回心智与道德的活力，也帮助我们管住各种私欲（参 CD 126.3）。",
    12: "关于零食，怀爱伦对父母的劝勉是：不要让孩子在两餐之间吃糖果、水果、坚果或任何食物，规律进餐才能保住消化系统的健康节奏（参 CD 229.1）。",
    15: "怀爱伦纠正过一个常见误区：早餐时肠胃的状态比一天中后面几餐更好，草草吃早餐、丰盛吃晚餐的习惯是不对的（参 CD 173.2）。",
    16: "怀爱伦劝勉每个人主动学习身体的构造与保健之道，而不是把身体完全托付给医生（参 CH 37.3）。",
    17: "怀爱伦长期观察证实：许多疾病的根源是心理的抑郁，忧伤、焦虑、内疚会耗损生命的力量（参 CH 344.1）。",
    18: "怀爱伦在《论饮食》中列出真正的医治之法：纯净的空气、阳光、节制、休息、运动、适当的饮食、用水，以及信靠神的大能——这正是 NEWSTART 八大原则的出处（参 CD 301.3）。",
    22: "怀爱伦始终把人引向基督的邀请：「到我这里来……我就使你们得安息」——心里的平安，是整体健康最踏实的一块基石（参 CH 319.2）。",
    28: "怀爱伦对烟草的评价毫不含糊：它是一种缓慢、隐蔽、却极为恶毒的毒物，兴奋之后便是麻痹（参 MH 327.1）。",
    29: "关于酒，怀爱伦的劝勉没有任何余地：永远不要喝酒，水才是最好的选择（参 CD 421.3）。",
    39: "关于两餐之间的加餐，怀爱伦说得非常直接：正餐之间，不要让一口食物经过你的嘴唇（参 CD 180.3）。",
    40: "怀爱伦把茶、咖啡、烟草与酒并列为不同程度的人造刺激品，并特别指出咖啡暂时煽动头脑、之后留下的却是疲惫与麻痹（参 CD 421.4、421.6）。",
    44: "怀爱伦在肉食问题上的结论值得我们慎重面对：牲畜的疾病越发普遍，最安全的道路就是完全不吃肉（参 CD 412.1）。",
}


def egw_citation(sid):
    p = POOL_BY_SID[sid]
    return {"sourceType": "egw", "sourceId": sid, "ref": p["ref"], "snippet": p["snippet"]}


def main():
    doc = json.loads(FAQ.read_text(encoding="utf-8"))
    faq = doc["faq"]
    assert len(faq) == 53, "FATAL: 期望 53 条，实际 %d" % len(faq)
    replaced = dropped = 0
    for i, e in enumerate(faq):
        if i not in MAP:
            raise SystemExit("FATAL: 条目 %d 未在映射表中" % i)
        cits = []
        for c in e["citations"]:
            if c.get("sourceId") == "EGW-MH":
                sid = MAP[i]
                if sid is None:
                    dropped += 1
                    continue
                cits.append(egw_citation(sid))
                replaced += 1
            else:
                cits.append(c)
        e["citations"] = cits
        if i in ENRICH:
            if not e["answer_zh"].endswith(ENRICH[i]):
                e["answer_zh"] = e["answer_zh"].rstrip() + " " + ENRICH[i]
    # 自检
    left = [c["sourceId"] for e in faq for c in e["citations"] if c.get("sourceId") == "EGW-MH"]
    assert not left, "FATAL: 假引用残留 %d 处" % len(left)
    for e in faq:
        assert e["answer_zh"].startswith("**"), "FATAL: 答案丢失加粗开头"
        assert e["citations"], "FATAL: 条目无引用"
        for c in e["citations"]:
            if c["sourceType"] == "egw":
                assert c["sourceId"] in POOL_BY_SID, "FATAL: 未知来源 %s" % c["sourceId"]
                assert c["snippet"], "FATAL: %s 无 snippet" % c["sourceId"]
    FAQ.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("health_faq.json: 替换 %d 处，删除 %d 处假引用" % (replaced, dropped))

    # 每日一贴：修正错误书名
    if DAILY.exists():
        d = json.loads(DAILY.read_text(encoding="utf-8"))
        n = 0
        for tip in d:
            if tip.get("source") == "怀爱伦《医药布道》":
                tip["source"] = "怀爱伦《服务真诠》"
                n += 1
        DAILY.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("health_daily.json: 修正书名 %d 条" % n)


if __name__ == "__main__":
    main()
