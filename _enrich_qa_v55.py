# -*- coding: utf-8 -*-
"""v55：给「怀爱伦论家庭」条目（idx287）补连接变体复合词。

根因：用户问「怀爱伦对于家庭的著作有哪些」时，FMM 切出 {怀爱伦, 家庭, 著作}
三个裸词，家庭条目与入门路线条目三项平局，队尾新条目落败（已由第四决胜键
系统级修复）。此处再补常见连接变体复合词，让这些问法直接拉分，双保险。

幂等：已含则跳过。改完 Grep 复核真实内容（不信工具回执）。
"""
import io
import json
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
FAQ = ROOT / "flutter_app/assets/web/qa_faq.json"

data = json.load(io.open(FAQ, encoding="utf-8"))
faq = data["faq"]
target = faq[-1]
kw = list(target.get("keywords") or [])
assert any("家庭" == k for k in kw), "last entry is not the family entry"

# 连接变体：主语(怀爱伦) + 连接词 + 主题(家庭) + 载体(著作/书) 的常见口语/书面问法
NEW_KW = [
    "对于家庭", "有关家庭", "涉及家庭", "家庭方面", "家庭的著作",
    "关于家庭的著作", "家庭相关", "关于家庭的书", "家庭类的书",
    "家庭教导", "家庭教诲", "家庭指导", "家庭主题",
    # 整句级复合词：让「怀爱伦家庭方面的著作」被 FMM 一次切整句（cov=1.0），
    # 否则先切「怀爱伦家庭」会剩「著作」落单，cov=0.5 够不到直接作答门限
    "怀爱伦家庭的著作", "怀爱伦家庭的书", "怀爱伦家庭的书籍", "怀爱伦家庭的文章",
    "怀爱伦家庭方面", "怀爱伦家庭层面的著作", "怀爱伦家庭领域的著作",
    "怀爱伦家庭方面的著作", "怀爱伦家庭方面的书",
    "家庭方面的著作", "家庭方面的书", "家庭层面的著作", "家庭领域的著作",
]

# 幂等检查（先查后改）：只补缺失的
missing = [k for k in NEW_KW if k not in kw]
if not missing:
    print("ALL PRESENT:", NEW_KW)
    raise SystemExit(0)

before = len(kw)
kw.extend(missing)
target["keywords"] = kw

with io.open(FAQ, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("family entry keywords: %d -> %d" % (before, len(kw)))
print("added:", missing)
print("total faq:", len(faq))
