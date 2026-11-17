"""Build connected traffic circuits and safe walking corridors from offline OSM."""
import heapq,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'assets/maps/cleveland.json').read_text())
def world(p):return (round(p[0]+1000,2),round(p[1]-75,2))
def dist(a,b):return math.dist(a,b)
graph={}
for r in d['roads']:
    if r['foot'] or r['width']<6:continue
    p=list(map(world,r['points']))
    for a,b in zip(p,p[1:]):
        graph.setdefault(a,{})[b]=dist(a,b)
        graph.setdefault(b,{})
        if not r['oneway']:graph[b][a]=dist(a,b)
def nearest(p):return min(graph,key=lambda n:dist(n,p))
def path(a,b):
    queue=[(0,a)];cost={a:0};previous={}
    while queue:
        score,n=heapq.heappop(queue)
        if n==b:break
        if score!=cost[n]:continue
        for nxt,w in graph[n].items():
            value=score+w
            if value<cost.get(nxt,float('inf')):cost[nxt]=value;previous[nxt]=n;heapq.heappush(queue,(value,nxt))
    if b not in cost:raise ValueError(('Disconnected route',a,b))
    route=[b]
    while route[-1]!=a:route.append(previous[route[-1]])
    return route[::-1]
routes=[]
for hubs in [[(388,-169),(549,-248),(780,96),(646,191),(472,-45)],[(549,-248),(668,-361),(914,7),(780,96)],[(780,96),(856,-79),(1060,-190),(1180,15),(982,-40)]]:
    hubs=list(map(nearest,hubs));route=[]
    for a,b in zip(hubs,hubs[1:]+hubs[:1]):route+=path(a,b)[:-1]
    # Remove dead-end excursions that would require a car to turn in place.
    changed=True
    while changed and len(route)>3:
        changed=False
        for i in range(len(route)):
            if route[i-1]==route[(i+1)%len(route)]:
                route=route[i+1:]+route[:i-1] if i>0 else route[2:]
                changed=True;break
    assert len(route)>10, 'Traffic circuit collapsed to a dead end'
    lane=[]
    for i,p in enumerate(route):
        a,b=route[i-1],route[(i+1)%len(route)];dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz)
        lane.append([round(p[0]-dz/length*1.6,2),round(p[1]+dx/length*1.6,2)])
    routes.append(lane)
def inside(p,poly):
    hit=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:hit=not hit
    return hit
buildings=[list(map(world,b['polygon'])) for b in d['buildings']]
walks=[];cells=set()
for r in sorted(d['roads'],key=lambda r:min(dist(world(p),(950,-50)) for p in r['points'])):
    if not r['foot']:continue
    p=list(map(world,r['points']));length=sum(dist(a,b) for a,b in zip(p,p[1:]))
    if not 22<length<150:continue
    center=p[len(p)//2];cell=(int(center[0]//75),int(center[1]//75))
    if cell in cells or not 390<center[0]<1450 or not -550<center[1]<400:continue
    samples=[]
    for a,b in zip(p,p[1:]):
        count=max(1,math.ceil(dist(a,b)/8))
        samples.extend([(a[0]+(b[0]-a[0])*j/count,a[1]+(b[1]-a[1])*j/count) for j in range(count)])
    samples.append(p[-1])
    if any(inside(q,poly) for q in samples for poly in buildings):continue
    walks.append([[round(x,2),round(z,2)] for x,z in samples]);cells.add(cell)
    if len(walks)==16:break
(ROOT/'data/city_population.json').write_text(json.dumps({'traffic_routes':routes,'walking_paths':walks},indent=2)+'\n')
print('Connected circuits',len(routes),'walk corridors',len(walks),'route nodes',[len(r) for r in routes])

