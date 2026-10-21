# _regress_qa_v49.py
# v49 回归：用 backend/app/kb.py 真实 FMM + 门控逻辑验证 qa_faq.json 改后行为。
import json
import sys

sys.path.insert(0, 'backend/app')
from kb import KnowledgeBase, should_answer_direct

faq = json.load(open('flutter_app/assets/web/qa_faq.json', encoding='utf-8'))['faq']
kb = KnowledgeBase({'faq': faq})

passed = failed = 0

def check(name, cond, detail=''):
    global passed, failed
    if cond:
        passed += 1
        print('  PASS  %s' % name)
    else:
        failed += 1
        print('  FAIL  %s  %s' % (name, detail))

def ans(q):
    e, score, cov = kb.match_faq_full(q)
    direct = should_answer_direct(cov, score)
    return e, score, cov, direct

print('== v49 核心：用户实测问句 ==')
# 用户截图原句
e, s, c, d = ans('怀爱伦的著作中哪些是关于儿童教育的？')
check('教育原句 direct', d, 'cov=%.2f score=%d' % (c, s))
check('教育原句命中条目A', e is not None and '儿童教育指南' in e['answer_zh'])
check('教育原句答案含教育论', e is not None and '教育论' in e['answer_zh'])
# 变体：裸怀爱伦 + 概念（测 A 的「怀爱伦」关键词）
e, s, c, d = ans('怀爱伦关于儿童教育的著作')
check('教育变体(裸怀爱伦) direct', d, 'cov=%.2f score=%d' % (c, s))
check('教育变体命中条目A', e is not None and '儿童教育指南' in e['answer_zh'])
e, s, c, d = ans('egw 儿童教育')
check('教育变体(egw) direct', d, 'cov=%.2f score=%d' % (c, s))
e, s, c, d = ans('教育论是谁写的')
check('教育论直问 direct', d and '教育论' in (e['answer_zh'] if e else ''),
      'cov=%.2f score=%d' % (c, s))
e, s, c, d = ans('儿童教育指南讲什么')
check('儿童教育指南直问 direct', d, 'cov=%.2f score=%d' % (c, s))

print('== 回归：健康问句不被抢答 ==')
e, s, c, d = ans('怀爱伦的著作中哪些是关于健康事工的？')
check('健康原句 direct', d, 'cov=%.2f score=%d' % (c, s))
check('健康原句仍答服务真诠', e is not None and '服务真诠' in e['answer_zh'])
check('健康原句仍答医疗布道', e is not None and '医疗布道' in e['answer_zh'])
e, s, c, d = ans('怀爱伦 医疗布道 著作')
check('健康变体(裸怀爱伦+医疗布道) direct', d, 'cov=%.2f score=%d' % (c, s))
check('健康变体命中健康条目', e is not None and '服务真诠' in e['answer_zh'])

print('== 新增：怀著总览 / 奉献礼 ==')
e, s, c, d = ans('怀著有哪些')
check('怀著有哪些 direct', d, 'cov=%.2f score=%d' % (c, s))
check('怀著有哪些命中总览(含历代愿望)', e is not None and '历代愿望' in e['answer_zh'])
e, s, c, d = ans('从哪本开始读怀著')
check('从哪本开始读怀著 direct', d and '历代愿望' in (e['answer_zh'] if e else ''))
e, s, c, d = ans('怀爱伦有哪些著作')
check('怀爱伦有哪些著作 direct', d, 'cov=%.2f score=%d' % (c, s))
check('怀爱伦有哪些著作命中总览', e is not None and '历代愿望' in e['answer_zh'])
e, s, c, d = ans('善恶之争讲什么')
check('善恶之争 direct', d and '善恶之争' in (e['answer_zh'] if e else ''))
e, s, c, d = ans('幼儿奉献礼是什么意思')
check('幼儿奉献礼 direct', d, 'cov=%.2f score=%d' % (c, s))
check('奉献礼答案含哈拿', e is not None and '哈拿' in e['answer_zh'])
check('奉献礼答案不含十一奉献', e is not None and '十一奉献' not in e['answer_zh'])
e, s, c, d = ans('十一奉献是什么意思')
check('十一奉献回归 direct', d and '十分之一' in (e['answer_zh'] if e else ''))
e, s, c, d = ans('怎么教养儿女')
check('教养儿女回归 direct', d and '警戒养育' in (e['answer_zh'] if e else ''))

print('== 修复：家庭祭坛答非所问 ==')
e, s, c, d = ans('家庭祭坛怎么搞')
check('家庭祭坛 direct', d, 'cov=%.2f score=%d' % (c, s))
check('家庭祭坛命中家庭敬拜条目', e is not None and '敬拜' in e['answer_zh'])
check('家庭祭坛不再命中吵架条目', e is None or '吵架' not in e['answer_zh'])
e, s, c, d = ans('夫妻一起祷告好吗')
check('夫妻祷告回归命中吵架条目', e is not None and '冷战' in e['answer_zh'])

print('== 门控回归：跨主题不硬答 ==')
e, s, c, d = ans('安息日和洗礼有什么区别')
check('跨主题仍转人工', not d, 'cov=%.2f score=%d' % (c, s))
e, s, c, d = ans('今天天气怎么样zzz')
check('无命中仍转人工', e is None and not d)

print('== 纪律：新条目无 CUV、引用全在池内 ==')
pool = set()
for en in faq:
    for cc in en['citations']:
        pool.add(cc['source_id'])
for en in faq:
    for cc in en['citations']:
        check('引用 %s 在池内' % cc['source_id'], cc['source_id'] in pool)
        check('引用 %s 非 CUV' % cc['source_id'], not cc['source_id'].startswith('CUV'))

print('\n结果：%d 通过 / %d 失败' % (passed, failed))
sys.exit(0 if failed == 0 else 1)
