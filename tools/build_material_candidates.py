#!/usr/bin/env python3
"""Generate conservative model-to-shader candidates; no inferred submesh assignment."""
import json,sys,zipfile,collections
from pathlib import PurePosixPath
from parse_shader_states import parse

def build(archive):
 with zipfile.ZipFile(archive) as z:
  names=z.namelist(); shaders=parse(z.read('scripts/shaders/shaders.shd').decode('latin1'))
  by_name=collections.defaultdict(list)
  for ordinal,s in enumerate(shaders):
   by_name[s['name'].casefold()].append((ordinal,s))
  paths={x.casefold():x for x in names}
  out=[]
  for model in sorted((x for x in names if x.lower().endswith('.ucm')),key=str.casefold):
   candidates=[]
   for ordinal,shader in by_name[PurePosixPath(model).stem.casefold()]:
    passes=[]
    for p in shader['children']:
     if p['name'].casefold()!='pass':continue
     stages=[]
     for st in p['children']:
      if st['name'].casefold()!='stage':continue
      tex=[v[0] for v in st['properties'].get('texture',[]) if v]
      stages.append({'textures':[{'path':t,'exists':t.casefold() in paths} for t in tex]})
     passes.append({'states':p['properties'],'stages':stages})
    candidates.append({'shader_ordinal':ordinal,'shader_name':shader['name'],'passes':passes})
   out.append({'model':model,'status':'name_match_candidate' if len(candidates)==1 else ('ambiguous' if candidates else 'unresolved'),'candidates':candidates})
 counts=dict(collections.Counter(x['status'] for x in out))
 return {'schema':'cm-candidate-bindings-v1','warning':'Filename match is a heuristic, not verified original engine assignment. Per-submesh bindings unknown.','model_count':len(out),'shader_definition_count':len(shaders),'counts':counts,'models':out}
if __name__=='__main__':print(json.dumps(build(sys.argv[1]),indent=2,ensure_ascii=False))
