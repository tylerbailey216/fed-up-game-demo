"""Capture the same three real environments, one native game at a time."""
import argparse,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--before',action='store_true');parser.add_argument('--zone',choices=['all','arcade','city','open-road'],default='all');args=parser.parse_args()
env=os.environ.copy();env['APPDATA']=str(ROOT/'tools/userdata');env['LOCALAPPDATA']=str(ROOT/'tools/localdata')
# New versioned artwork must be imported before launching a capture game.
imported=subprocess.run([str(ROOT/'tools/Godot_v4.5.1-stable_win64_console.exe'),'--headless','--path',str(ROOT),'--editor','--import','--quit'],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
if imported.returncode or 'SCRIPT ERROR:' in imported.stdout+imported.stderr:raise RuntimeError('Art review import failed: '+(imported.stdout+imported.stderr)[-2000:])
for zone,flags in [('arcade',[]),('city',['--city','--zen']),('open-road',['--outerbelt','--zen'])]:
    if args.zone not in ['all',zone]:continue
    command=[str(ROOT/'tools/Godot_v4.5.1-stable_win64_console.exe'),'--path',str(ROOT),'--','--art-review']+(['--before'] if args.before else [])+flags
    result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
    output=result.stdout+result.stderr;print(output,flush=True)
    if result.returncode or any(error in output for error in ['SCRIPT ERROR:','Parse Error:','No loader found for resource:','Failed loading resource:']):raise RuntimeError('Art review capture failed')
