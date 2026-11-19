"""Validate a saved state, mirror D:, publish it, and verify the matching live build.

--watch publishes only after 20 seconds without a source save. Source changes
during validation cancel that attempt; a failing project never replaces the live demo.
"""
import argparse,datetime,hashlib,json,os,subprocess,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=ROOT/'tools/Godot_v4.5.1-stable_win64_console.exe'
HELPER='C:/Users/Admin/AppData/Local/GitHubDesktop/app-3.5.2/resources/app/git/mingw64/bin/git-credential-manager.exe'
GIT=['git','-c','safe.directory='+ROOT.as_posix()]
REMOTE='https://api.github.com/repos/tylerbailey216/fed-up-game-demo'
SITE='https://tylerbailey216.github.io/fed-up-game-demo/'
STATUS=ROOT/'docs/save-state-status.json'

def write_status(phase,**data):
    value={'phase':phase,'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),**data}
    STATUS.write_text(json.dumps(value,indent=2));print(json.dumps(value),flush=True)

def run(command,env=None):
    result=subprocess.run([str(x) for x in command],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace')
    output=result.stdout+result.stderr
    if result.returncode or 'SCRIPT ERROR:' in output or 'Parse Error:' in output or 'TEST FAIL' in output:
        raise RuntimeError('Command failed: '+str(command[0])+'\n'+output[-5000:])
    return result.stdout.strip()

def source_id():
    names=run(GIT+['ls-files','--cached','--others','--exclude-standard']).splitlines()
    digest=hashlib.sha256()
    for name in sorted(set(names)):
        name=name.strip('"')
        if name=='data/build_version.json':continue
        path=ROOT/name
        if path.is_file():digest.update(name.encode());digest.update(path.read_bytes())
    return digest.hexdigest()[:12]

def auth():
    result=subprocess.run(GIT+['-c','credential.helper=','-c','credential.helper='+HELPER,'credential','fill'],input='protocol=https\nhost=github.com\n\n',cwd=ROOT,text=True,capture_output=True,check=True)
    return dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)['password']

def verify_deployment(commit,identity):
    token=auth()
    for attempt in range(90):
        request=urllib.request.Request(REMOTE+'/actions/runs?per_page=8',headers={'Authorization':'Bearer '+token,'User-Agent':'FedUp-Driver-state-sync','Accept':'application/vnd.github+json'})
        with urllib.request.urlopen(request,timeout=30) as response:runs=json.load(response)['workflow_runs']
        match=next((r for r in runs if r['head_sha']==commit),None)
        if match and match['status']=='completed':
            if match['conclusion']!='success':raise RuntimeError('Online build failed: '+match['html_url'])
            try:
                with urllib.request.urlopen(SITE+'version.json?verify='+commit,timeout=30) as response:live=json.load(response)
                if live.get('commit')==commit and live.get('state_id')==identity:return live
            except Exception:pass
        if attempt%3==0:write_status('deploying',state_id=identity,commit=commit)
        time.sleep(10)
    raise RuntimeError('Timed out waiting for the matching Pages deployment')

def save(message):
    initial=source_id();write_status('validating',state_id=initial)
    env=os.environ.copy();env['APPDATA']=str(ROOT/'tools/userdata');env['LOCALAPPDATA']=str(ROOT/'tools/localdata')
    run(['python','tools/build_traffic_shaders.py'])
    run([GODOT,'--headless','--path','.', '--editor','--import','--quit'],env)
    initial=source_id()
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--arcade-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--arcade-switch-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--delivery-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--stunt-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--terrain-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--outerbelt','--terrain-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--outerbelt','--delivery-test'],env)
    run([GODOT,'--headless','--path','.', '--fixed-fps','60','--','--location-switch-test'],env)
    run([GODOT,'--headless','--path','.', '--script','tools/export_licenses.gd'],env)
    if source_id()!=initial:raise RuntimeError('Source changed during validation; waiting for the next stable saved state')
    stamp={'state_id':initial,'saved_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    path=ROOT/'data/build_version.json'
    if not path.exists() or json.loads(path.read_text()).get('state_id')!=initial:path.write_text(json.dumps(stamp,indent=2))
    run(GIT+['add','.gitignore','.github','AGENTS.md','assets','data','scenes','scripts','tools','web','export_presets.cfg','project.godot','README.md','docs','Launch Demo.cmd','Launch Independence.cmd','Open Editor.cmd'])
    if run(GIT+['diff','--cached','--name-only']):run(GIT+['commit','-m',message])
    commit=run(GIT+['rev-parse','HEAD'])
    write_status('exporting',state_id=initial,commit=commit)
    (ROOT/'build/web').mkdir(parents=True,exist_ok=True)
    run([GODOT,'--headless','--path','.', '--export-release','Web','build/web/index.html'],env)
    run(['python','tools/package_web.py'])
    run(['python','tools/sync_external.py'])
    if source_id()!=initial:raise RuntimeError('Source changed before upload; waiting for next saved state')
    run(GIT+['-c','credential.helper=','-c','credential.helper='+HELPER,'push','-u','origin','main'])
    write_status('deploying',state_id=initial,commit=commit)
    live=verify_deployment(commit,initial)
    write_status('mirrored',state_id=initial,commit=commit,online=SITE,external='D:/FedUp Driver',live_version=live)
    return initial

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--watch',action='store_true');parser.add_argument('--message',default='Save verified FedUp Driver project state');args=parser.parse_args()
    if not args.watch:
        try:save(args.message)
        except Exception as error:write_status('error',error=str(error));raise
    else:
        last=source_id();saved=json.loads((ROOT/'data/build_version.json').read_text()).get('state_id') if (ROOT/'data/build_version.json').exists() else None
        changed_at=time.monotonic()
        while True:
            try:
                current=source_id()
                if current!=last:last=current;changed_at=time.monotonic()
                if current!=saved and time.monotonic()-changed_at>=20:
                    saved=save('Mirror saved state '+current)
                    last=source_id();changed_at=time.monotonic()
            except Exception as error:write_status('error',error=str(error));changed_at=time.monotonic()
            time.sleep(3)
