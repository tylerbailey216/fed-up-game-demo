"""Offline edge coverage and clearance audit. Requires the installed Shapely package."""
import json, math
from pathlib import Path
from shapely.geometry import LineString, Point
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/maps/independence.json').read_text())
points=data['points']; roads=data['roads'];segments=[];meta=[]
def width(road):return road['width']+(2 if road['kind'] in ('motorway','motorway_link') else 0)
def interp(a,b,t):return [a[k]+(b[k]-a[k])*t for k in range(3)]
for ri,road in enumerate(roads):
    for i,(ai,bi) in enumerate(zip(road['nodes'],road['nodes'][1:])):
        a,b=points[ai],points[bi]
        if math.dist(a,b)<.01:continue
        segments.append(LineString([(a[0],a[2]),(b[0],b[2])]))
        meta.append((ri,i,a,b))
tree=STRtree(segments)
def covered(pos,own):
    point=Point(pos[0],pos[2])
    for k in tree.query(point.buffer(24)):
        k=int(k);ri,_,a,b=meta[k]
        if ri==own:continue
        line=segments[k];t=line.project(point)/line.length
        h=a[1]+(b[1]-a[1])*t
        if abs(h-pos[1])<.45 and line.distance(point)<width(roads[ri])/2-.05:return True
    return False

barriers=[];protected=0.;open_merge=0.
for ri,road in enumerate(roads):
    if road['kind'] not in ('motorway','motorway_link') and not road['bridge']:continue
    ids=road['nodes'];left=[];right=[]
    for i,idx in enumerate(ids):
        p=points[idx];before=points[ids[max(0,i-1)]];after=points[ids[min(len(ids)-1,i+1)]]
        dx,dz=after[0]-before[0],after[2]-before[2];length=math.hypot(dx,dz)
        if length<.001:dx,dz,length=1,0,1
        side=(-dz/length,dx/length)
        left.append([p[0]-side[0]*width(road)/2,p[1],p[2]-side[1]*width(road)/2])
        right.append([p[0]+side[0]*width(road)/2,p[1],p[2]+side[1]*width(road)/2])
    for edge in (left,right):
        for a,b in zip(edge,edge[1:]):
            # Test coverage every 1m, so only an actual same-level joining surface
            # removes edge protection. A road below cannot open a hole in a bridge rail.
            count=max(1,math.ceil(math.dist(a,b)))
            start=None
            for i in range(count+1):
                external=i<count and not covered(interp(a,b,(i+.5)/count),ri)
                if external and start is None:start=i
                if not external and start is not None:
                    pa,pb=interp(a,b,start/count),interp(a,b,i/count)
                    n=max(1,math.ceil(math.dist(pa,pb)/8))
                    for j in range(n):
                        aa,bb=interp(pa,pb,j/n),interp(pa,pb,(j+1)/n)
                        if math.dist(aa,bb)<.15:continue
                        barriers.append({'a':[round(v,3) for v in aa],'b':[round(v,3) for v in bb],'kind':'concrete' if road['bridge'] else 'steel','road':road['id']})
                        protected+=math.dist(aa,bb)
                    start=None
                if i<count and not external:open_merge+=math.dist(a,b)/count

crossings=[];bad=[]
for i,line in enumerate(segments):
    for k in tree.query(line,predicate='crosses'):
        k=int(k)
        if k<=i:continue
        ri,_,a,b=meta[i];rj,_,c,d=meta[k]
        if ri==rj:continue
        point=line.intersection(segments[k]);u=line.project(point)/line.length;v=segments[k].project(point)/segments[k].length
        h=a[1]+(b[1]-a[1])*u;h2=c[1]+(d[1]-c[1])*v
        gap=abs(h-h2)
        # Connected level intersections stay at one elevation. Unconnected grade
        # crossings must clear a 4m truck plus a 0.65m deck and margin.
        if roads[ri]['bridge'] or roads[rj]['bridge']:
            record={'roads':[roads[ri]['id'],roads[rj]['id']],'clearance':round(gap-.65,3),'position':[round(point.x,2),round(point.y,2)]}
            crossings.append(record)
            if gap<5.65:bad.append(record)
assert not bad,f'Insufficient bridge clearance: {bad}'
result={'barriers':barriers,'protected_edge_m':round(protected),'open_join_m':round(open_merge),'crossings':crossings,'minimum_clearance':min(x['clearance'] for x in crossings)}
(ROOT/'assets/maps/independence_safety.json').write_text(json.dumps(result,separators=(',',':')))
print(f'{len(barriers)} barrier sections, {protected:.0f}m protected edges, {len(crossings)} grade crossings, minimum clearance {result["minimum_clearance"]:.2f}m')
