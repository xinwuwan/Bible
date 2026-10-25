# _fix_c2_aliases.py
import re, io

p = '_kb_data_c2.py'
src = io.open(p, encoding='utf-8').read()

# 1) 修复 "aliases='X'.length and [] or [...]" 笔误 → 普通列表
pat = re.compile(r"aliases='([^']*)'\.length and \[\] or (\[[^\]]*\])")
src, n = pat.subn(lambda m: 'aliases=%s' % m.group(2), src)
print('fixed weird aliases:', n)

# 2) 错别字
src = src.replace('带状庖疹', '带状疱疹')
src = src.replace('fever 期少油腻', '发热期少油腻')

# 3) 校验不再有 .length and
assert '.length and' not in src, 'still has weird pattern'
io.open(p, 'w', encoding='utf-8').write(src)
print('OK')
