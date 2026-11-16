"""Versioned, non-deleting mirror to the user-requested external project folder."""
import argparse, datetime, hashlib, json, os, shutil, time
from pathlib import Path

SOURCE=Path(__file__).resolve().parents[1]
DEST=Path('D:/FedUp Driver')
STATUS=SOURCE/'docs/external-sync-status.json'
EXCLUDED={'.godot','.git','__pycache__','.history'}
def eligible(path):
    rel=path.relative_to(SOURCE)
    if path.suffix=='.log':return False
    return not any(p in EXCLUDED or p.endswith('_userdata') or p.endswith('_localdata') or p in {'userdata','localdata'} for p in rel.parts) and rel.as_posix() not in {'docs/external-sync-status.json','docs/external-sync.log','docs/save-state-status.json'}
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()
def sync(state):
    if not DEST.parent.exists():raise RuntimeError('External D: drive unavailable')
    DEST.mkdir(exist_ok=True)
    changed=0;stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    for src in SOURCE.rglob('*'):
        if not src.is_file() or not eligible(src):continue
        stat=src.stat();signature=(stat.st_mtime_ns,stat.st_size)
        if state.get(str(src))==signature:continue
        rel=src.relative_to(SOURCE);target=DEST/rel
        checksum=digest(src)
        if target.exists() and target.stat().st_size==stat.st_size and digest(target)==checksum:
            state[str(src)]=signature;continue
        if target.exists():
            history=DEST/'.history'/stamp/rel
            history.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(target,history)
        target.parent.mkdir(parents=True,exist_ok=True)
        temp=target.with_name(target.name+'.sync-tmp')
        shutil.copy2(src,temp)
        if digest(temp)!=checksum:raise RuntimeError('File changed during copy: '+str(rel))
        os.replace(temp,target)
        state[str(src)]=signature;changed+=1
    result={'destination':str(DEST),'updated_files':changed,'tracked_files':len(state),'verified_at':datetime.datetime.now().astimezone().isoformat(),'status':'verified'}
    STATUS.write_text(json.dumps(result,indent=2))
    (DEST/'.sync-status.json').write_text(json.dumps(result,indent=2))
    if changed:print(json.dumps(result),flush=True)
    return result
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--watch',action='store_true');args=parser.parse_args();state={}
    while True:
        try:result=sync(state)
        except Exception as exc:
            STATUS.write_text(json.dumps({'status':'error','error':str(exc)}));print(str(exc),flush=True)
            if not args.watch:raise
        if not args.watch:print(json.dumps(result));break
        time.sleep(2)
