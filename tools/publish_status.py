"""Configure/read Pages with Git's credential helper; never print credentials."""
import argparse,json,subprocess,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPO='tylerbailey216/fed-up-game-demo'
HELPER=Path('C:/Users/Admin/AppData/Local/GitHubDesktop/app-3.5.2/resources/app/git/mingw64/bin/git-credential-manager.exe')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--enable',action='store_true');args=parser.parse_args()
    command=['git','-c','safe.directory='+ROOT.as_posix(),'-c','credential.helper=','-c','credential.helper='+HELPER.as_posix(),'credential','fill']
    result=subprocess.run(command,input='protocol=https\nhost=github.com\n\n',text=True,capture_output=True,check=True,cwd=ROOT)
    credentials=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
    token=credentials['password']
    def api(path,method='GET',data=None):
        request=urllib.request.Request('https://api.github.com'+path,data=json.dumps(data).encode() if data is not None else None,method=method,headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'FedUp-Driver-publisher','Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(request,timeout=45) as response:return json.load(response)
        except urllib.error.HTTPError as e:
            if e.code==404:return None
            raise RuntimeError(f'GitHub API {method} {path}: HTTP {e.code}') from None
    user=api('/user');repo=api('/repos/'+REPO)
    print(json.dumps({'authenticated_as':user['login'],'permissions':repo.get('permissions',{})}),flush=True)
    path='/repos/'+REPO+'/pages';pages=api(path)
    if args.enable:
        if pages is None:pages=api(path,'POST',{'build_type':'workflow'})
        elif pages.get('build_type')!='workflow':pages=api(path,'PUT',{'build_type':'workflow'})
    print(json.dumps({'pages':pages},default=str),flush=True)
    runs=api('/repos/'+REPO+'/actions/runs?per_page=3')
    print(json.dumps({'runs':[{k:r.get(k) for k in ['id','head_sha','status','conclusion','html_url']} for r in (runs or {}).get('workflow_runs',[])]}),flush=True)

if __name__=='__main__':main()
