"""Finish a Godot export with notices and verify the publish directory."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/web'
(OUT/'presentation').mkdir(exist_ok=True)
shutil.copy2(ROOT/'assets/art/presentation/cleveland-key-art.png',OUT/'presentation/cleveland-key-art.png')
for asset in (ROOT/'assets/fonts').iterdir():
    if asset.is_file() and asset.suffix in ['.ttf','.txt']:shutil.copy2(asset,OUT/'presentation'/asset.name)
for name in ['index.html','index.js','index.wasm','index.pck']:
    path=OUT/name
    if not path.is_file() or not path.stat().st_size:raise RuntimeError('Missing export: '+name)
for name in ['LICENSE_GODOT.txt','THIRD_PARTY_NOTICES.md','GODOT_THIRD_PARTY.json']:
    shutil.copy2(ROOT/'web'/name,OUT/name)
(OUT/'.nojekyll').touch()
version=json.loads((ROOT/'data/build_version.json').read_text()) if (ROOT/'data/build_version.json').exists() else {'state_id':'local-development'}
version['commit']=subprocess.check_output(['git','-c','safe.directory='+ROOT.as_posix(),'rev-parse','HEAD'],cwd=ROOT,text=True).strip()
(OUT/'version.json').write_text(json.dumps(version,indent=2))
# Every saved source gets distinct engine URLs. A phone cannot pair a cached
# older PCK with the current loader or silently retain obsolete controls.
html=(OUT/'index.html').read_text(encoding='utf-8')
match=re.search(r'const config=(\{.*?\});',html)
if not match:raise RuntimeError('Missing Godot export configuration')
config=json.loads(match.group(1));old=config['executable'];base='game-'+version['state_id']
for suffix in ['js','wasm','pck','audio.worklet.js','audio.position.worklet.js']:
    (OUT/(old+'.'+suffix)).replace(OUT/(base+'.'+suffix))
html=html.replace('src="'+old+'.js"','src="'+base+'.js"')
config['executable']=base
config['fileSizes']={key.replace(old+'.',base+'.',1):value for key,value in config['fileSizes'].items()}
html=html.replace(match.group(0),'const config='+json.dumps(config,separators=(',',':'))+';')
html=html.replace('__FEDUP_BUILD__',version['state_id'])
(OUT/'index.html').write_text(html,encoding='utf-8')
for path in OUT.iterdir():
    if re.fullmatch(r'game-[0-9a-f]{12}\.(js|wasm|pck|audio\.worklet\.js|audio\.position\.worklet\.js)',path.name) and not path.name.startswith(base+'.'):path.unlink()
manifest={p.relative_to(OUT).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in OUT.rglob('*') if p.is_file() and p.name!='build-manifest.json'}
(OUT/'build-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Browser export verified:',sum(x['bytes'] for x in manifest.values()),'bytes')
