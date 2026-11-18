#!/usr/bin/env python3
"""Preserve original shader pass/stage tokens in a renderer-neutral JSON format."""
import json,sys,zipfile
from pathlib import Path
from parse_shader_states import audit
def export(archive):
 a=audit(archive)
 shaders=[]
 for s in a['shaders']:
  shaders.append({'name':s['shader'],'model_name_match_only':s['model_name_match'],
                  'passes':[{'states':p['states'],'stages':p['stages'],
                             'requires_multipass':len(s['passes'])>1} for p in s['passes']]})
 return {'schema':'cm-shader-ir-v1','semantics':'original tokens; not verified GPU equivalents',
         'counts':{k:a[k] for k in ('shader_count','pass_count','stage_count','texture_references','missing_texture_references')},
         'shaders':shaders}
if __name__=='__main__':
 if len(sys.argv)!=3:raise SystemExit('Usage: python tools/export_material_ir.py assets.zip output.json')
 result=export(sys.argv[1])
 assert result['counts']=={'shader_count':183,'pass_count':199,'stage_count':215,'texture_references':198,'missing_texture_references':0}
 Path(sys.argv[2]).write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
 print(result['counts'])
