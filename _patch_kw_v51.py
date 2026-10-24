# _patch_kw_v51.py
# v51：关键词小补丁——给 idx9（救恩条目）补「救主/救世主」。
#   探测发现「谁是救主」完全无命中（cov=0），因「救主」不在任何条目关键词中。
#   救恩条目的核心就是耶稣是救主，补词安全（不与「耶稣」条目串味：问句含
#   「救主」时 idx9 得 cov=1.0 直接答）。
# 可复现：读 qa_faq.json -> 定位 idx9 -> 补词 -> compact 写回。
import json
from pathlib import Path

FAQ = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06/flutter_app/assets/web/qa_faq.json")
doc = json.loads(FAQ.read_text(encoding="utf-8"))
faq = doc["faq"]

ADD = ["救主", "救世主"]
i9 = None
for i, e in enumerate(faq):
    if "得救" in e.get("keywords", []) and "救恩" in e.get("keywords", []):
        i9 = i
        break
assert i9 is not None, "FATAL: 未找到救恩条目"
kw = faq[i9]["keywords"]
added = [w for w in ADD if w not in kw]
assert added, "FATAL: 关键词已存在（脚本重复运行）"
faq[i9]["keywords"] = kw + added
FAQ.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("idx%d 补词: %s -> %d 条" % (i9, added, len(faq[i9]["keywords"])))
