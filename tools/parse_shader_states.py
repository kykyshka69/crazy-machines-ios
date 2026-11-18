#!/usr/bin/env python3
"""Parse original Crazy Machines shader blocks, passes, stages, and render states."""
import json,re,sys,zipfile
def parse(text):
 text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
 text=re.sub(r'//[^\n]*','',text)
 tokens=re.findall(r'[^{}\n]+|[{}]',text)
 root={'children':[],'properties':{}};stack=[root];pending=None
 for token in tokens:
  token=token.strip()
  if not token:continue
  if token=='{':
   if pending is None:raise ValueError('anonymous block')
   node={'name':pending,'children':[],'properties':{}}
   stack[-1]['children'].append(node);stack.append(node);pending=None
  elif token=='}':
   if pending is not None:raise ValueError('dangling name')
   if len(stack)==1:raise ValueError('unbalanced close')
   stack.pop()
  elif len(stack)==1:
   if pending is not None:raise ValueError('missing open brace')
   pending=token
  else:
   if pending is not None:raise ValueError('unexpected name')
   if token.lower() in ('pass','stage'):pending=token
   else:
    parts=token.split()
    stack[-1]['properties'].setdefault(parts[0].lower(),[]).append(parts[1:])
 if len(stack)!=1 or pending is not None:raise ValueError('unclosed block')
 return root['children']
def audit(path):
 with zipfile.ZipFile(path) as z:
  shaders=parse(z.read('scripts/shaders/shaders.shd').decode('latin1'))
  names={n.casefold() for n in z.namelist()}
  models={n.rsplit('/',1)[-1][:-4].casefold() for n in z.namelist() if n.lower().endswith('.ucm')}
  entries=[]
  for sh in shaders:
   passes=[]
   for p in sh['children']:
    if p['name'].lower()!='pass':continue
    stages=[]
    for stage in p['children']:
     if stage['name'].lower()!='stage':continue
     props=stage['properties'];paths=[v[0] for v in props.get('texture',[]) if v]
     stages.append({'states':props,'textures':paths,'texture_exists':[t.casefold() in names for t in paths]})
    passes.append({'states':p['properties'],'stages':stages})
   entries.append({'shader':sh['name'],'model_name_match':sh['name'].casefold() in models,'passes':passes})
  return {'shader_count':len(entries),'pass_count':sum(len(e['passes']) for e in entries),'stage_count':sum(len(p['stages']) for e in entries for p in e['passes']),'texture_references':sum(len(s['textures']) for e in entries for p in e['passes'] for s in p['stages']),'missing_texture_references':sum(not ok for e in entries for p in e['passes'] for s in p['stages'] for ok in s['texture_exists']),'shaders':entries}
if __name__=='__main__':print(json.dumps(audit(sys.argv[1]),ensure_ascii=False,indent=2))
