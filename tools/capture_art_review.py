"""Capture the same three real environments, one native game at a time."""
import argparse,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--before',action='store_true');parser.add_argument('--zone',choices=['all','arcade','city','open-road'],default='all');args=parser.parse_args()
env=os.environ.copy();env['APPDATA']=str(ROOT/'tools/userdata');env['LOCALAPPDATA']=str(ROOT/'tools/localdata')
for zone,flags in [('arcade',[]),('city',['--city','--zen']),('open-road',['--outerbelt','--zen'])]:
    if args.zone not in ['all',zone]:continue
    command=[str(ROOT/'tools/Godot_v4.5.1-stable_win64_console.exe'),'--path',str(ROOT),'--','--art-review']+(['--before'] if args.before else [])+flags
    result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
    output=result.stdout+result.stderr;print(output,flush=True)
    if result.returncode or 'SCRIPT ERROR:' in output or 'Parse Error:' in output:raise RuntimeError('Art review capture failed')
