"""Register generated citizen drawings from alpha; never edit image pixels."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
result={"citizens":{}}
for design in json.loads((ROOT/'data/citizen_lineup_catalog.json').read_text())['citizens']:
    name,height,relative=design['id'],design['world_height'],design['texture']
    pixels=np.asarray(Image.open(ROOT/relative).convert("RGBA"))
    mask=(pixels[:,:,3]>90).astype(np.uint8)
    stats=cv2.connectedComponentsWithStats(mask,8)[2][1:]
    bodies=[list(map(int,s)) for s in stats if s[4]>2200]
    anchors=sorted([s[1]+s[3]/2 for s in bodies if s[0]+s[2]/2<pixels.shape[1]/6])
    rows=[[] for _ in anchors]
    for body in bodies:
        row=min(range(len(anchors)),key=lambda i:abs(anchors[i]-body[1]-body[3]/2))
        rows[row].append(body)
    for row in rows:
        row.sort(key=lambda s:s[0])
        if len(row)!=6:raise ValueError((name,"Expected six complete characters per row",row))
    if len(rows)!=10:raise ValueError((name,'Expected ten rows',len(rows)))
    clips={}
    def frame(row,column):
        x,y,w,h,_=rows[row][column]
        floor=max(s[1]+s[3] for s in rows[row])
        return {"region":[max(0,x-3),max(0,y-3),min(pixels.shape[1]-max(0,x-3),w+6),min(pixels.shape[0]-max(0,y-3),h+6)],"pivot":[x+w/2,floor]}
    reference=max(s[3] for row in rows[:8] for s in row)
    for i,direction in enumerate(["front","back","left","right"]):
        clips["walk_"+direction]={"height":reference,"frames":[frame(i*2+j//6,j%6) for j in range(12)]}
        # The alien atlas has an extra walk row; reaction rows are always last.
        surprise=len(rows)-2;recover=len(rows)-1
        clips["surprise_"+direction]={"height":reference,"frames":[frame(surprise,i)]}
        clips["tumble_"+direction]={"height":reference,"frames":[frame(surprise,4+i) if i<2 else frame(recover,i-2)]}
        clips["recover_"+direction]={"height":reference,"frames":[frame(recover,i+2)]}
    result["citizens"][name]={"texture":"res://"+relative,"world_height":height,"stride":design['stride'],"identity":design['identity'],"clips":clips}
(ROOT/"data/citizens.json").write_text(json.dumps(result,indent=2)+"\n")
print('Registered',len(result['citizens']),'citizens with 48 walk and 12 reaction drawings each')
