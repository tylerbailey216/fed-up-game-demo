"""Register generated citizen drawings from alpha; never edit image pixels."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def directional_walk(relative):
    """Register a twelve-drawing source at one fixed scale; read pixels only."""
    pixels=np.asarray(Image.open(ROOT/relative).convert('RGBA'))
    mask=(pixels[:,:,3]>90).astype(np.uint8)
    stats=cv2.connectedComponentsWithStats(mask,8)[2][1:]
    bodies=[list(map(int,s)) for s in stats if s[4]>12000]
    if len(bodies)!=12:raise ValueError((relative,'Expected twelve complete silhouettes',len(bodies)))
    bodies.sort(key=lambda b:(int((b[1]+b[3]/2)//(pixels.shape[0]/2)),b[0]))
    floors=[max(b[1]+b[3] for b in bodies[row*6:row*6+6]) for row in range(2)]
    reference=max(floors[i//6]-b[1] for i,b in enumerate(bodies))
    frames=[]
    for i,(x,y,w,h,area) in enumerate(bodies):
        top=mask[y+12:y+int(h*.32),x:x+w]
        columns=np.flatnonzero(top.any(axis=0))
        center=x+(int(columns[0])+int(columns[-1]))/2
        left=max(0,x-3);upper=max(0,y-3)
        frames.append({'region':[left,upper,min(pixels.shape[1],x+w+3)-left,min(pixels.shape[0],y+h+3)-upper],
                       'pivot':[center,floors[i//6]]})
    return {'texture':'res://'+relative,'height':reference,'frames':frames}

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
    for direction,texture in design.get('walk_textures',{}).items():
        clips['walk_'+direction]=directional_walk(texture)
    if design.get('reaction_texture'):
        reactions=directional_walk(design['reaction_texture'])
        for i,direction in enumerate(['front','back','left','right']):
            for state,offset in [('surprise',0),('tumble',4),('recover',8)]:
                clips[state+'_'+direction]={'texture':reactions['texture'],'height':reactions['height'],
                                            'frames':[reactions['frames'][offset+i]]}
    result["citizens"][name]={"texture":"res://"+relative,"world_height":height,"stride":design['stride'],"identity":design['identity'],"clips":clips}
(ROOT/"data/citizens.json").write_text(json.dumps(result,indent=2)+"\n")
print('Registered',len(result['citizens']),'citizens with 48 walk and 12 reaction drawings each')
