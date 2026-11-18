#!/usr/bin/env python3
"""Conservative Metal-oriented render-plan bridge for parsed Crazy Machines shaders."""
import json,sys
from parse_shader_states import audit
BLENDS={'one one':('one','one'),'srcalpha invsrcalpha':('sourceAlpha','oneMinusSourceAlpha'),'zero srccolor':('zero','sourceColor')}
OPS={'modulate':'multiply','modulate2x':'multiply2','modulate4x':'multiply4','add':'add','selectarg1':'selectFirst','disable':'disabled'}
ADDRESS={'wrap':'repeat','clamp':'clampToEdge','mirror':'mirrorRepeat'}
def translate(sh):
 passes=[];warnings=[]
 for pi,p in enumerate(sh['passes']):
  raw=p['states'];b=' '.join(raw.get('blend',[[]])[0]).lower();blend=BLENDS.get(b)
  if b and blend is None:warnings.append(f'pass {pi}: unknown blend {b}')
  stages=[]
  for si,s in enumerate(p['stages']):
   state=s['states'];address=state.get('address',[['wrap','wrap']])[0]
   addr=[ADDRESS.get(x.lower()) for x in address[:2]]
   if None in addr:warnings.append(f'pass {pi} stage {si}: unsupported address {address}')
   ops={}
   for key in ('colorop','alphaop'):
    if key in state:
     args=state[key][0];op=args[0].lower() if args else ''
     ops[key]={'operation':OPS.get(op),'arguments':args[1:],'original':args}
     if op not in OPS:warnings.append(f'pass {pi} stage {si}: unsupported {key} {op}')
   if 'tcgen' in state:warnings.append(f'pass {pi} stage {si}: tcgen needs shader implementation')
   if 'tcmod' in state:warnings.append(f'pass {pi} stage {si}: tcmod needs shader implementation')
   stages.append({'textures':s['textures'],'sampler_address':addr,'ops':ops,'raw_states':state})
  passes.append({'blend':{'source':blend[0],'destination':blend[1]} if blend else None,'raw_states':raw,'stages':stages})
 return {'name':sh['shader'],'passes':passes,'warnings':warnings}
def main(archive):
 data=audit(archive);items=[translate(s) for s in data['shaders']]
 return {'schema':'cm-metal-plan-v1','status':'partial; not a Metal renderer',
 'shader_count':len(items),'pass_count':sum(len(x['passes']) for x in items),
 'warnings_count':sum(len(x['warnings']) for x in items),'materials':items}
if __name__=='__main__':print(json.dumps(main(sys.argv[1]),ensure_ascii=False,indent=2))
