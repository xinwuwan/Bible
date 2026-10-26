# _gen_disease_kb.py
# v57：生成疾病知识库第三批（disease_profiles_3.json）并做全面校验。
#
# 用法：python _gen_disease_kb.py
# 数据来源：_kb_data_a/b/c1/c2.py（65 条新疾病）+ 既有 2 个文件（23 条，仅参与交叉校验）。
# 校验项：字段完整性、id/别名唯一、分类合法、支柱合法、无外链、既有别名不冲突、
#         关键疾病可检索（含用户遇到的孤立性纤维性肿瘤）。
import importlib.util
import io
import json
import re
import sys

BASE = 'flutter_app/assets/web'
OUT = f'{BASE}/disease_profiles_3.json'

CATEGORIES = {
    'cardio', 'neuro', 'resp', 'gi', 'renal', 'blood', 'immune', 'endo',
    'metabolic', 'tumor', 'mental', 'derm', 'eye', 'ent', 'ortho', 'gyne',
    'peds', 'infect', 'other',
}
SEVERITY = {'major', 'severe', 'common'}
PILLARS = {'NUT', 'EXE', 'WAT', 'SUN', 'TEM', 'AIR', 'RES', 'TRU'}
URL_RE = re.compile(r'(https?://|www\.|\.com|\.cn|\.org|\.net)', re.I)

errors = []
warns = []


def err(eid, msg):
    errors.append(f'[{eid}] {msg}')


def load_module(path, var):
    spec = importlib.util.spec_from_file_location(path.replace('/', '_')[:-3], path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return getattr(m, var)


def check_text(eid, field, val, minlen):
    if not isinstance(val, str) or not val.strip():
        err(eid, f'{field} 为空')
    elif len(val) < minlen:
        err(eid, f'{field} 过短（{len(val)}<{minlen}）: {val[:30]}')


def check_list(eid, field, lst, minlen):
    if not isinstance(lst, list) or len(lst) < minlen:
        err(eid, f'{field} 数量不足（需>={minlen}）')
        return []
    for i, s in enumerate(lst):
        if not isinstance(s, str) or not s.strip():
            err(eid, f'{field}[{i}] 为空')
    return lst


def validate_entry(d, existing_ids, existing_names, existing_aliases,
                   require_new_fields=False):
    eid = d.get('id', '?')
    if not re.fullmatch(r'[a-z][a-z0-9_]*', eid):
        err(eid, 'id 格式非法')
    if eid in existing_ids:
        err(eid, 'id 与既有条目重复')
    existing_ids.add(eid)

    name = d.get('name', '')
    check_text(eid, 'name', name, 2)
    if name in existing_names:
        err(eid, f'name 与既有条目重复: {name}')
    existing_names.add(name)

    aliases = check_list(eid, 'aliases', d.get('aliases'), 1)
    for a in aliases:
        if a == name:
            err(eid, f'alias 与 name 相同: {a}')
        if a in existing_aliases:
            err(eid, f'alias 与既有条目冲突: {a}')
        existing_aliases.add(a)

    if d.get('category') not in CATEGORIES:
        err(eid, f'category 非法: {d.get("category")}')
    if d.get('severityHint') not in SEVERITY:
        err(eid, f'severityHint 非法: {d.get("severityHint")}')

    check_text(eid, 'overview', d.get('overview'), 20)
    check_list(eid, 'causes', d.get('causes'), 3)
    check_list(eid, 'impacts', d.get('impacts'), 3)
    check_text(eid, 'prognosis', d.get('prognosis'), 15)

    advice = d.get('advice')
    if not isinstance(advice, list) or len(advice) < 3:
        err(eid, f'advice 数量不足（需>=3）: {type(advice).__name__}')
        advice = []
    for i, a in enumerate(advice):
        if not isinstance(a, dict):
            err(eid, f'advice[{i}] 非对象')
            continue
        if a.get('pillar') not in PILLARS:
            err(eid, f'advice[{i}].pillar 非法: {a.get("pillar")}')
        check_text(eid, f'advice[{i}].text', a.get('text'), 8)

    check_list(eid, 'sources', d.get('sources'), 2)
    check_list(eid, 'differential', d.get('differential'), 2)
    check_list(eid, 'furtherExams', d.get('furtherExams'), 3)
    check_list(eid, 'seeDoctor', d.get('seeDoctor'), 3)
    # 新增字段（v59）：临床表现 / 诊断标准——仅第四批(D)新条目强制填写，
    # 既有 65 条(legacy)逐步补全，不在此阻断生成。
    if require_new_fields:
        check_list(eid, 'clinical', d.get('clinical'), 2)
        check_list(eid, 'diagnostic', d.get('diagnostic'), 2)

    # 外链检查：所有字符串值都不得含网址形态（用户要求：全部内联、零外链）
    def walk(v, path):
        if isinstance(v, str):
            if URL_RE.search(v):
                err(eid, f'{path} 疑似含外链: {v[:60]}')
        elif isinstance(v, list):
            for i, x in enumerate(v):
                walk(x, f'{path}[{i}]')
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(x, f'{path}.{k}')

    walk(d, '')


def main():
    modules = [
        ('_kb_data_a.py', 'DISEASES_A'),
        ('_kb_data_b.py', 'DISEASES_B'),
        ('_kb_data_c1.py', 'DISEASES_C1'),
        ('_kb_data_c2.py', 'DISEASES_C2'),
        ('_kb_data_d.py', 'DISEASES_D'),
    ]
    new = []
    for path, var in modules:
        ds = load_module(path, var)
        print(f'loaded {path}: {len(ds)} entries')
        new.extend(ds)

    # 既有条目（file1/2 仅参与交叉校验 id/name/alias 冲突）。
    # 注意：file3 是 a/b/c1/c2 的生成产物，不能再作为「既有」种子，
    # 否则 c1/c2 自身会与自己冲突；file3 与 D 的冲突在累积校验中捕获。
    existing_ids, existing_names, existing_aliases = set(), set(), set()
    for f in ['disease_profiles.json', 'disease_profiles_2.json']:
        j = json.load(io.open(f'{BASE}/{f}', encoding='utf-8'))
        for d in j['diseases']:
            existing_ids.add(d['id'])
            existing_names.add(d['name'])
            existing_aliases.update(d.get('aliases', []))

    for path, var in modules:
        ds = load_module(path, var)
        for d in ds:
            validate_entry(d, existing_ids, existing_names, existing_aliases,
                           require_new_fields=(path == '_kb_data_d.py'))

    # 关键疾病可检索性（覆盖用户实际遇到的诊断）
    all_profiles = []
    for f in ['disease_profiles.json', 'disease_profiles_2.json']:
        j = json.load(io.open(f'{BASE}/{f}', encoding='utf-8'))
        all_profiles.extend(j['diseases'])
    all_profiles.extend(new)

    def find(diag):
        best, best_len = None, 0
        for p in all_profiles:
            for a in [p['name']] + list(p.get('aliases', [])):
                if a and diag in a and len(a) > best_len:
                    best, best_len = p, len(a)
                if a and a in diag and len(a) > best_len:
                    best, best_len = p, len(a)
        return best

    for diag in ['孤立性纤维性肿瘤', '2型糖尿病', '肺炎', '甲亢', '带状疱疹',
                 '乙肝', '痛风', '荨麻疹', '宫颈癌', '脑膜瘤', '脂肪瘤',
                 '子宫肌瘤', '卵巢囊肿', '腰椎间盘突出症', '青光眼',
                 '过敏性鼻炎', '失眠', '乳腺癌', '肺癌']:
        p = find(diag)
        if p is None:
            err('coverage', f'关键诊断无法检索: {diag}')
        else:
            print(f'  coverage: {diag} -> {p["id"]} ({p["name"]})')

    # SFT 专项：必须有形成机制/影响/来源内容
    sft = find('孤立性纤维性肿瘤')
    if sft:
        for f, minlen in [('causes', 3), ('impacts', 3), ('sources', 2)]:
            if len(sft.get(f, [])) < minlen:
                err('sft', f'SFT {f} 不足')

    if errors:
        print('\n=== VALIDATION FAILED ===')
        for e in errors:
            print('FAIL', e)
        sys.exit(2)

    out = {
        'version': 1,
        'note': '疾病知识库（第三批，v57）：覆盖神经/心血管/呼吸/消化/泌尿/血液/风湿免疫/'
                '内分泌代谢/肿瘤/妇科/儿科/感染/皮肤/五官/骨科等系统。每条含形成机制、'
                '对健康的影响、预后、建议检查、鉴别与就医信号、权威来源（纯文本，无外链）。'
                '医学通识内容，系统不据此下诊断，疾病诊断以医院为准。',
        'diseases': new,
    }
    with io.open(OUT, 'w', encoding='utf-8') as fp:
        json.dump(out, fp, ensure_ascii=False, indent=1)
    print(f'\nWROTE {OUT}: {len(new)} diseases, '
          f'total KB = {len(all_profiles)} entries')
    print('VALIDATION PASSED')


if __name__ == '__main__':
    main()
