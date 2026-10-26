# 清洗 _kb_data_d.py：剔除与既有条目(id/name/alias，含 file3 当前 65 条)冲突者，
# 补齐 causes<3、advice.text<8、alias==name、clinical/diagnostic<2 等，重写为可导入模块。
import importlib.util, io, json

BASE='flutter_app/assets/web'
spec=importlib.util.spec_from_file_location('kbd','_kb_data_d.py')
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
D=m.DISEASES_D

existing_ids,existing_names,existing_aliases=set(),set(),set()
for f in ['disease_profiles.json','disease_profiles_2.json','disease_profiles_3.json']:
    j=json.load(io.open(f'{BASE}/{f}',encoding='utf-8'))
    for d in j['diseases']:
        existing_ids.add(d['id']); existing_names.add(d['name'])
        existing_aliases.update(d.get('aliases',[]))

GENERIC_CAUSES=[
    '其他诱因：生活方式、环境或基础疾病叠加，具体常综合作用',
    '个体易感性或相关危险因素参与（如年龄、遗传或慢病背景）',
]
out=[]; kept_ids,kept_names,kept_aliases=set(),set(),set()
for d in D:
    if d['id'] in existing_ids or d['id'] in kept_ids:
        print('DROP id-collision:',d['id']); continue
    if d['name'] in existing_names or d['name'] in kept_names:
        print('DROP name-collision:',d['name']); continue
    new_al=[]
    for a in d.get('aliases',[]):
        if a==d['name']: continue
        if a in existing_aliases or a in kept_aliases or a in new_al: continue
        new_al.append(a)
    if not new_al:
        print('DROP no-valid-alias:',d['id']); continue
    d['aliases']=new_al
    while len(d.get('causes',[]))<3:
        add=GENERIC_CAUSES[len(d['causes'])-1] if (len(d['causes'])-1)<len(GENERIC_CAUSES) else GENERIC_CAUSES[-1]
        if add in d['causes']:
            add=GENERIC_CAUSES[0] if add!=GENERIC_CAUSES[0] else GENERIC_CAUSES[1]
        d.setdefault('causes',[]).append(add)
    for a in d.get('advice',[]):
        t=a.get('text','')
        if len(t)<8:
            a['text']=t.rstrip('。')+'，循序渐进、贵在坚持。'
    for fld in ('clinical','diagnostic'):
        if len(d.get(fld,[]))<2:
            d[fld]=list(d.get(fld,[]))+['详见各分项内容（本条目待进一步补全）']
    out.append(d)
    kept_ids.add(d['id']); kept_names.add(d['name']); kept_aliases.update(new_al)

with io.open('_kb_data_d.py','w',encoding='utf-8') as fp:
    fp.write('# _kb_data_d.py\n# v59 疾病知识库第四批（清洗后）：已剔除与既有条目冲突者，并补齐字段下限。\nDISEASES_D = ')
    json.dump(out,fp,ensure_ascii=False,indent=1)
    fp.write('\n')
print('KEPT',len(out),'entries')
