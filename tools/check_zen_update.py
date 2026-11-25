"""Run the focused native checks with isolated local Godot user data."""
import os,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
env=os.environ.copy()
env['APPDATA']=str(root/'tools/userdata');env['LOCALAPPDATA']=str(root/'tools/localdata')
args=sys.argv[1:] or ['--zen-roads-test','--zen-road-drive-test','--zen','--outerbelt']
p=subprocess.run([str(root/'tools/Godot_v4.5.1-stable_win64_console.exe'),'--headless','--path','.', '--fixed-fps','60','--',*args],cwd=root,env=env,capture_output=True,text=True,timeout=300)
output=p.stdout+p.stderr
(root/'tools/zen-update-check.log').write_text(output)
print(output[-6500:])
sys.exit(1 if p.returncode or any(x in output for x in ['SCRIPT ERROR','Parse Error','TEST FAIL']) else 0)
