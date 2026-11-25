"""Offline QA only: node mapped intersections; no runtime dependency on Shapely."""
import json,collections
from pathlib import Path
from shapely.geometry import LineString,Point
from shapely.ops import unary_union
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'assets/maps/cleveland.json').read_text())
lines=[LineString(r['points']) for r in data['roads'] if not r['foot'] and len(r['points'])>1]
segments=list(unary_union(lines).geoms)
graph=collections.defaultdict(set)
for line in segments:
    a,b=(tuple(round(v,4) for v in p) for p in [line.coords[0],line.coords[-1]])
    graph[a].add(b);graph[b].add(a)
components=[];seen=set()
for node in graph:
    if node in seen:continue
    todo=[node];part=set()
    while todo:
        at=todo.pop()
        if at in part:continue
        part.add(at);todo.extend(graph[at]-part)
    seen.update(part);components.append(part)
components.sort(key=len,reverse=True)
def component_for(world):
    local=(world[0]-1000,world[1]+75)
    segment=min(segments,key=lambda s:s.distance(Point(local)))
    node=tuple(round(v,4) for v in segment.coords[0])
    return next(i for i,c in enumerate(components) if node in c)
main=components[0];edges=sum(len(graph[n]) for n in main)//2
report={'driveable_km':round(sum(l.length for l in lines)/1000,2),'components':len(components),'main_nodes':len(main),'main_cycle_rank':edges-len(main)+1,'spawn_component':component_for((1125,0)),'gateway_component':component_for((1628,432)),'note':'Intentional private/service cul-de-sacs remain. Intersections noded geometrically, not endpoint-only.'}
print(json.dumps(report,indent=2))
assert report['spawn_component']==report['gateway_component']==0 and report['main_cycle_rank']>0
