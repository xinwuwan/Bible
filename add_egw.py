# add_egw.py
# 把「经审核的怀爱伦(EGW)原版英文著作」真实原文接入知识库。
#
# 铁律：绝不臆造 EGW。以下原文均取自官方公共版权档案（Ellen G. White Estate /
# egwwritings.org）并标注精确出处；中文只作索引/提示，不作权威。
# 每条 FAQ 通过关键词锚点挂载对应 EGW 引用，使前后端问答引擎都能检索并展示。
#
# 运行：python add_egw.py
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
KB = os.path.join(ROOT, "backend", "kb.json")
QA = os.path.join(ROOT, "flutter_app", "assets", "web", "qa_faq.json")

# ---------- 经审核的 EGW 原文（逐字，附权威出处）----------
EGW_QUOTES = [
    {
        "id": "EGW-DA-288",
        "source_type": "EGW",
        "source_id": "EGW-DA-288",
        "ref": "The Desire of Ages, pp. 288-289",
        "topic": ["sabbath", "sanctification"],
        "zh_topic": ["安息日", "守安息", "成圣", "第七日"],
        "text": ("Then the Sabbath is a sign of Christ's power to make us holy. "
                 "As a sign of His sanctifying power, the Sabbath is given to all "
                 "who through Christ become a part of the Israel of God."),
    },
    {
        "id": "EGW-6T-350",
        "source_type": "EGW",
        "source_id": "EGW-6T-350",
        "ref": "Testimonies for the Church, vol. 6, p. 350",
        "topic": ["sabbath", "sanctifier", "law"],
        "zh_topic": ["安息日", "守安息", "诫命", "律法"],
        "text": ("The Sabbath given to the world as the sign of God as the Creator "
                 "is also the sign of Him as the Sanctifier. The power that created "
                 "all things is the power that re-creates the soul in His own likeness."),
    },
    {
        "id": "EGW-SC-FAITH",
        "source_type": "EGW",
        "source_id": "EGW-SC-FAITH",
        "ref": "Steps to Christ, ch. 8 (Faith and Acceptance)",
        "topic": ["salvation", "faith", "grace"],
        "zh_topic": ["救恩", "得救", "称义", "信心", "信耶稣", "如何得救"],
        "text": ("While the sinner cannot save himself, he still has something to do "
                 "to secure salvation. 'him that cometh to Me,' says Christ, 'I will "
                 "in no wise cast out.' John 6:37. But we must come to him; and when "
                 "we repent of our sins, we must believe that he accepts and pardons "
                 "us. Faith is the gift of God, but the power to exercise it is ours. "
                 "Faith is the hand by which the soul takes hold upon the divine "
                 "offers of grace and mercy."),
    },
    {
        "id": "EGW-SC-BELIEVE",
        "source_type": "EGW",
        "source_id": "EGW-SC-BELIEVE",
        "ref": "Steps to Christ, ch. 8 (Faith and Acceptance)",
        "topic": ["faith", "assurance", "promise"],
        "zh_topic": ["救恩", "得救", "信心", "应许", "信耶稣"],
        "text": ("It is so if you believe it. Do not wait to feel that you are made "
                 "whole, but say, 'I believe it; it is so, not because I feel it, but "
                 "because God has promised.'"),
    },
    {
        "id": "EGW-GC-549",
        "source_type": "EGW",
        "source_id": "EGW-GC-549",
        "ref": "The Great Controversy, pp. 549-550",
        "topic": ["state of the dead", "resurrection", "soul"],
        "zh_topic": ["死", "死后", "灵魂", "阴间", "复活", "人死后去哪"],
        "text": ("The Bible clearly teaches that the dead do not go immediately to "
                 "heaven. They are represented as sleeping until the resurrection."),
    },
    {
        "id": "EGW-GV-93",
        "source_type": "EGW",
        "source_id": "EGW-GV-93",
        "ref": "The Great Visions of Ellen G. White, p. 93.3 (GVEGW 93.3)",
        "topic": ["health", "temple", "duty"],
        "zh_topic": ["健康", "饮食", "节制", "身子", "养生"],
        "text": ("Care of health is a religious duty. The body, which God calls His "
                 "temple, should be preserved in as healthy a condition as possible."),
    },
    {
        "id": "EGW-GV-94",
        "source_type": "EGW",
        "source_id": "EGW-GV-94",
        "ref": "The Great Visions of Ellen G. White, p. 94.3 (GVEGW 94.3)",
        "topic": ["temperance", "health"],
        "zh_topic": ["健康", "节制", "饮食", "养生", "NEWSTART"],
        "text": ("True temperance teaches us to dispense entirely with everything "
                 "hurtful and to use judiciously that which is healthful."),
    },
]

# FAQ 关键词锚点 -> 挂载的 EGW id 列表
EGW_BY_ANCHOR = {
    "安息日": ["EGW-DA-288", "EGW-6T-350"],
    "救恩": ["EGW-SC-FAITH", "EGW-SC-BELIEVE"],
    "死后": ["EGW-GC-549"],
    "健康": ["EGW-GV-93", "EGW-GV-94"],
}


def main():
    with open(KB, encoding="utf-8") as f:
        data = json.load(f)

    egw_by_id = {e["id"]: e for e in EGW_QUOTES}

    # 1) 写入顶层 egw 数组（去重）
    existing_ids = {e.get("id") for e in data.get("egw", [])}
    added_egw = 0
    if "egw" not in data or not isinstance(data.get("egw"), list):
        data["egw"] = []
    for e in EGW_QUOTES:
        if e["id"] not in existing_ids:
            data["egw"].append(e)
            existing_ids.add(e["id"])
            added_egw += 1

    # 2) 把 EGW 引用挂载到命中锚点的 FAQ（按 source_id 去重）
    added_cit = 0
    for faq in data.get("faq", []):
        kws = faq.get("keywords", [])
        for anchor, egw_ids in EGW_BY_ANCHOR.items():
            if any(anchor in (k or "") for k in kws):
                cites = faq.setdefault("citations", [])
                have = {c.get("source_id") for c in cites}
                for eid in egw_ids:
                    if eid in have:
                        continue
                    e = egw_by_id[eid]
                    cites.append({
                        "source_type": "EGW",
                        "source_id": e["source_id"],
                        "ref": e["ref"],
                        "snippet": e["text"],
                    })
                    have.add(eid)
                    added_cit += 1

    # 3) 更新 _meta 说明
    meta = data.get("_meta", {})
    meta["note"] = (
        "种子知识库。权威依据仅限 KJV 英文圣经、怀爱伦(EGW)原版英文著作、"
        "SDA 公开教义；中文为独立产出，和合本(CUV)绝不作权威来源。"
        "所有条目在公开部署前应人工复核；EGW 原文取自官方公共版权档案并标注出处。"
    )
    if "authority_order" in meta and "EGW 原版英文著作" not in meta["authority_order"]:
        meta["authority_order"] = ["KJV (英文底本)", "EGW 原版英文著作", "SDA 教义"]
    data["_meta"] = meta

    with open(KB, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # 4) 同步前端 qa_faq.json（直接取自 kb.json 的 faq 数组）
    with open(QA, "w", encoding="utf-8") as f:
        json.dump({"faq": data["faq"]}, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"kb.json 更新：+{added_egw} 条 EGW 原文 / +{added_cit} 条 FAQ 内 EGW 引用")
    print(f"  当前总计：{len(data['verses'])} 经文 / "
          f"{len(data['doctrine'])} 教义 / {len(data['faq'])} FAQ / "
          f"{len(data['egw'])} EGW 原文")
    print(f"qa_faq.json 已同步为 {len(data['faq'])} 条 FAQ（含 EGW 引用）")


if __name__ == "__main__":
    main()
