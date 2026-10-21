# _enrich_qa_faq.py
# v49：丰富牧师问答知识库。
#   A. 怀爱伦关于儿童教育的著作（用户实测问句走兜底，cov=0.5 未过门控）
#   C. 怀爱伦著作总览与阅读入门（「怀著有哪些」等通用问句被健康条目抢答）
#   B. 幼儿奉献礼（新主题）
#   同时修 3 处关键词串味：
#     idx113 夫妻吵架 误持「家庭祭坛/家庭敬拜/亲子祷告」系词 -> 移除
#     idx175 家庭敬拜 补「亲子祷告/家庭一起祷告」
#     idx239 健康条目 瘦身为健康专用（通用词移交条目 C）
# 铁律：只复用已审核引用池（按 source_id 原文复制 snippet），不编造新引用；
#       写回保持 compact 单行（json.dumps ensure_ascii=False, separators=(',',':')）。
import json
import sys

PATH = 'flutter_app/assets/web/qa_faq.json'

with open(PATH, encoding='utf-8') as f:
    doc = json.load(f)
faq = doc['faq']

# ---------- 0) 既有引用池（source_id -> citation dict，原文复制） ----------
pool = {}
for e in faq:
    for c in e['citations']:
        pool.setdefault(c['source_id'], c)

def cite(sid):
    if sid not in pool:
        raise SystemExit('FATAL: 引用 %s 不在已审核池' % sid)
    return dict(pool[sid])

# ---------- 1) 新关键词冲突自检（新词不得与既有条目重复持有） ----------
existing = {}  # kw -> [idx]
for i, e in enumerate(faq):
    for k in e['keywords']:
        existing.setdefault(k, []).append(i)

NEW_KEYWORDS = {
    # A 儿童教育
    'A': ['怀爱伦的著作', '怀爱伦著作', '怀爱伦', '儿童教育', '教育论', '儿童教育指南',
          '子女教育', '幼儿教育', '孩童教育', '青少年教育', 'egw education',
          'child guidance', 'counsels to parents', '基督化教育', '复临教育',
          '儿童事工', '怀爱伦教育', '怀爱伦论教育', '给父母教师和学生的劝勉'],
    # C 总览（'怀著'/'著作'/'怀爱伦写过什么'/'怀爱伦写什么'/'怀爱伦的书籍'/'预言之灵的著作'
    #    当前由 idx239 持有，本脚本会从 239 移除，故允许冲突但必须是 239）
    'C': ['怀著', '著作', '怀爱伦写过什么', '怀爱伦写什么', '怀爱伦的书籍',
          '预言之灵的著作', '怀爱伦的著作', '怀爱伦著作', '怀爱伦', 'egw',
          '怀爱伦的著作有哪些', '怀爱伦著作有哪些', '怀爱伦有哪些著作', '怀著有哪些',
          '怀著入门', '从哪本开始读怀著', '先读哪本怀著', '历代愿望', '善恶之争',
          '喜乐的密码', '怀爱伦全集', 'egw writings', '怀著推荐'],
    # B 奉献礼（严禁裸词「奉献」，会撞 #24 十一奉献）
    'B': ['奉献礼', '幼儿奉献礼', '婴儿奉献礼', '儿童奉献礼', '奉献典礼',
          '幼儿奉献', '婴儿奉献'],
}
MOVED_FROM_239 = {'怀著', '著作', '怀爱伦写过什么', '怀爱伦写什么', '怀爱伦的书籍', '预言之灵的著作'}
for grp, kws in NEW_KEYWORDS.items():
    for k in kws:
        holders = existing.get(k, [])
        for h in holders:
            if grp == 'C' and h == 239 and k in MOVED_FROM_239:
                continue  # 允许：即将从 239 移交
            if grp == 'A' and k in ('怀爱伦的著作', '怀爱伦著作') and h == 239:
                continue  # 允许：A 与健康条目共享长词，靠覆盖率门控分流
            if grp == 'C' and k in ('怀爱伦的著作', '怀爱伦著作') and h == 239:
                continue  # 允许：C 与健康条目共享长词，靠插入顺序分流
            if k == '怀爱伦' and h in (23, 239):
                continue  # 允许：裸词「怀爱伦」平局必输给队首 idx23（教义），仅覆盖率更高才赢
            if k == 'egw' and h in (23, 239):
                continue  # 允许：同上
            raise SystemExit('FATAL: 关键词冲突 %r 组%s 已由 idx%s 持有' % (k, grp, h))

# ---------- 2) 修 idx113 夫妻吵架：移除家庭敬拜系词 ----------
i113 = None
for i, e in enumerate(faq):
    if '夫妻吵架' in e['keywords'] and '冷战' in e['keywords']:
        i113 = i
        break
assert i113 is not None, 'FATAL: 未找到 idx113 夫妻吵架'
drop113 = {'家庭祭坛', '家庭敬拜', '亲子祷告', '一起祷告', '家庭一起祷告'}
kw113 = [k for k in faq[i113]['keywords'] if k not in drop113]
assert '夫妻祷告' in kw113 and '夫妻一起祷告' in kw113, 'FATAL: 113 误删夫妻祷告系词'
faq[i113]['keywords'] = kw113

# ---------- 3) idx175 家庭敬拜：补亲子祷告/家庭一起祷告 ----------
i175 = None
for i, e in enumerate(faq):
    if '家庭敬拜' in e['keywords'] and '带领家人灵修' in e['keywords']:
        i175 = i
        break
assert i175 is not None, 'FATAL: 未找到 idx175 家庭敬拜'
kw175 = list(faq[i175]['keywords'])
for k in ('亲子祷告', '家庭一起祷告'):
    if k not in kw175:
        kw175.append(k)
faq[i175]['keywords'] = kw175

# ---------- 4) idx239 健康条目瘦身 ----------
i239 = None
for i, e in enumerate(faq):
    if '怀爱伦的著作' in e['keywords'] and '医疗布道' in e['keywords']:
        i239 = i
        break
assert i239 is not None, 'FATAL: 未找到 idx239 健康条目'
faq[i239]['keywords'] = [
    '怀爱伦的著作', '怀爱伦著作', '怀爱伦', 'egw',
    '健康事工', '医疗布道', '医药布道', 'medical missionary',
    '健康改良', 'health reform', '医疗宣教', '健康布道',
]

# ---------- 5) 条目 A：怀爱伦关于儿童教育的著作 ----------
entry_a = {
    'keywords': NEW_KEYWORDS['A'],
    'answer_zh': (
        '**怀爱伦论述儿童教育的著作，集中在她关于「基督化教育」的系列作品里，最有代表性的有五部：**\n\n'
        '① 《教育论》（Education，1903）——最系统的一部，提出「身体、智力、灵性均衡发展」的教育总纲，'
        '主张一切课程以圣经为中心、以服务人生为指向，反对单纯追逐分数与竞争；\n'
        '② 《儿童教育指南》（Child Guidance，1954）——专论从幼儿到青少年的养育与教导，'
        '从学龄前的日常引导讲到青春期，被许多父母当作实务手册逐章对照；\n'
        '③ 《给父母、教师和学生的劝勉》（Counsels to Parents, Teachers, and Students，1928）——'
        '按主题汇编的劝勉，涵盖家庭教导、学校选择、功课负担、安息日与游戏等具体场景；\n'
        '④ 《论家庭》（The Adventist Home，1952）——把家庭教育置于信仰的核心，'
        '论父母的以身作则、家庭礼拜的建立与家规的执行；\n'
        '⑤ 《基督教教育基础》（Fundamentals of Christian Education，1923）——'
        '论述为何必须建立不随从世界潮流的基督化学校，是理解本会教育立场的钥匙。\n\n'
        '贯穿这些著作的核心主张是：教育不只是知识的灌输，更是品格的塑造；家庭是孩子的第一所学校，'
        '父母是孩子的第一任老师——「教养孩童，使他走当行的道，就是到老他也不偏离」（箴22:6），'
        '任何脱离信仰的教育都是残缺的。'
        '若你只能先读一本，建议从《儿童教育指南》开始——它最贴近日常养育。\n\n'
        '温馨提示：怀爱伦的著作被本会视为「预言恩赐」的印证，为教会带来安慰、指引与纠正，'
        '证实圣经真理，但绝不取代圣经；这些原则性教导也不替代你在具体处境中的祷告与牧者咨询。'
    ),
    'citations': [cite('SDA-B18'), cite('KJV-PRO22:6'), cite('KJV-DEU6:7'), cite('KJV-2TI3:15')],
}

# ---------- 6) 条目 C：怀爱伦著作总览与阅读入门（插在健康条目前，赢通用问句的并列） ----------
entry_c = {
    'keywords': NEW_KEYWORDS['C'],
    'answer_zh': (
        '**怀爱伦的著作数量庞大，初学者不必从第一页读起——稳妥的入门路线是「先读故事性强的，'
        '再读教义性的；先读与耶稣有关的，再读专题劝勉」。** 最常见的四条路径：\n\n'
        '① 认识耶稣：《历代愿望》（The Desire of Ages）——全集中篇幅最大、最动人的一部，'
        '以耶稣生平为轴，字里行间充满对基督的敬爱，适合作为第一本；\n'
        '② 理解大局：《善恶之争》（The Great Controversy）——从善恶之争的起源写到新天新地，'
        '帮你建立「历史与预言」的整体框架；\n'
        '③ 个人灵修：《喜乐的密码》（Steps to Christ）——薄薄一册，专论亲近主、祷告与信心，'
        '最适合送给初信的亲友；\n'
        '④ 教义与史传：接《先知与君王》《使徒行述》《福山宝训》等史传类著作，'
        '再按主题选读《教会证言》与《证言精选》。\n\n'
        '阅读提醒：怀爱伦的著作被本会视为「预言恩赐」的印证，为教会带来安慰、指引与纠正，'
        '证实圣经真理，但绝不取代圣经——每一卷都当以圣经为衡量标准。'
        '上述书目中文世界均有通行中译本，建议从《历代愿望》或《喜乐的密码》开始。'
    ),
    'citations': [cite('SDA-B18'), cite('KJV-ISA8:20'), cite('KJV-REV19:10')],
}

# ---------- 7) 条目 B：幼儿奉献礼 ----------
entry_b = {
    'keywords': NEW_KEYWORDS['B'],
    'answer_zh': (
        '**幼儿奉献礼（儿童奉献礼）不是「婴孩得救」的仪式，而是父母当众立约的典礼——'
        '把孩子重新献给神，并请求教会与他们一同把这孩子抚养成人。** '
        '这一做法最古老的榜样是哈拿：她曾在耶和华面前许愿，若蒙赐予儿子，就将他献给神'
        '（撒上1:11）；圣经也说「儿女是耶和华所赐的产业，所怀的胎是他所给的赏赐」（诗127:3）。\n\n'
        '典礼通常这样进行：牧师当众询问父母——是否立志照着主的教训养育这孩子、以身作则带领他认识主，'
        '父母应「是」；会众则承诺以祷告与团契相助。之后牧师为孩子祝福祷告。\n\n'
        '有两点请留意：其一，得救在于孩子自己将来对福音的回应，父母不能代替；'
        '其二，奉献礼之后，日常的家庭礼拜与身教才是「还愿」的真正内容——'
        '弗6:4 吩咐「照着主的教训和警戒养育他们」。'
    ),
    'citations': [cite('KJV-1SA1:11'), cite('KJV-PSA127:3'), cite('KJV-EPH6:4')],
}

# ---------- 8) 组装：C 插在健康条目前，A/B 追加末尾 ----------
faq.insert(i239, entry_c)
faq.append(entry_a)
faq.append(entry_b)

doc['faq'] = faq
with open(PATH, 'w', encoding='utf-8', newline='\n') as f:
    f.write(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))

print('OK entries=%d (was %d)' % (len(faq), len(faq) - 3))
print('idx113 kw:', kw113)
print('idx175 kw:', kw175)
print('idx239 kw:', faq[i239]['keywords'])
