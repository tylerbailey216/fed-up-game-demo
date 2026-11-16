"""Finish a Godot export with notices and verify the publish directory."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/web'
for name in ['index.html','index.js','index.wasm','index.pck']:
    path=OUT/name
    if not path.is_file() or not path.stat().st_size:raise RuntimeError('Missing export: '+name)
for name in ['LICENSE_GODOT.txt','THIRD_PARTY_NOTICES.md','GODOT_THIRD_PARTY.json']:
    shutil.copy2(ROOT/'web'/name,OUT/name)
(OUT/'.nojekyll').touch()
manifest={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in OUT.iterdir() if p.is_file() and p.name!='build-manifest.json'}
(OUT/'build-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Browser export verified:',sum(x['bytes'] for x in manifest.values()),'bytes')
