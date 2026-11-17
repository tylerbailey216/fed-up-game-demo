"""Inspect alpha silhouettes and write sprite pivots; never alter the artwork.

The generated source atlases contain twelve drawings in two rows. Register the
head center and a common floor line, without resizing each pose independently.
This also includes boots that extend across the nominal grid-cell boundaries.
Requires the existing local Pillow, NumPy and OpenCV packages (authoring only).
"""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
output={"columns":6,"rows":2,"directions":{}}
for direction in ("front","back","left","right"):
    relative=f"assets/art/presentation/worker-walk-{direction}.png"
    pixels=np.asarray(Image.open(ROOT/relative).convert("RGBA"))
    mask=(pixels[:,:,3]>90).astype(np.uint8)
    count,labels,stats,centroids=cv2.connectedComponentsWithStats(mask,8)
    bodies=[row for row in stats[1:] if row[4]>12000]
    if len(bodies)!=12:raise ValueError(f"{direction}: expected twelve complete silhouettes, got {len(bodies)}")
    bodies.sort(key=lambda row:(int((row[1]+row[3]/2)//(pixels.shape[0]/2)),row[0]))
    frame_data=[]
    floor_lines={row:max(int(b[1]+b[3]) for b in bodies[row*6:row*6+6]) for row in range(2)}
    reference_height=max(floor_lines[i//6]-int(b[1]) for i,b in enumerate(bodies))
    for i,body in enumerate(bodies):
        x,y,w,h,area=map(int,body)
        top=mask[y+12:y+int(h*.32),x:x+w]
        columns=np.flatnonzero(top.any(axis=0))
        head_center=x+(int(columns[0])+int(columns[-1]))/2
        left=max(0,x-3);right=min(pixels.shape[1],x+w+3)
        upper=max(0,y-3);lower=min(pixels.shape[0],y+h+3)
        frame_data.append({"region":[left,upper,right-left,lower-upper],"pivot":[head_center,floor_lines[i//6]]})
    output["directions"][direction]={"texture":"res://"+relative,"height":reference_height,"frames":frame_data}
path=ROOT/"data/worker_walk.json"
path.write_text(json.dumps(output,indent=2)+"\n")
print("Registered 48 complete drawings:",path)
