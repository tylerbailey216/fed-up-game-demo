"""Build an offline, meter-scale OSM road extract. No Google imagery used."""
import collections
import datetime
import heapq
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/maps/independence_osm.xml'
tree = ET.parse(source).getroot()
origin = (41.4072, -81.6470)
nodes = {n.get('id'): (float(n.get('lat')), float(n.get('lon'))) for n in tree.findall('node')}
def project(p):
    return [(p[1]-origin[1])*111320*math.cos(math.radians(origin[0])), (origin[0]-p[0])*111320]
def inside(p):
    return -1250 <= p[0] <= 950 and -1150 <= p[1] <= 1100

points, lookup, roads, anchors = [], {}, [], {}
edges = collections.defaultdict(dict)
allowed = {'motorway','motorway_link','trunk','trunk_link','primary','primary_link','secondary','tertiary','residential','unclassified','service'}
for way in tree.findall('way'):
    tags = {t.get('k'): t.get('v') for t in way.findall('tag')}
    kind = tags.get('highway')
    if kind not in allowed or tags.get('access') == 'private' or tags.get('area') == 'yes':
        continue
    raw = [project(nodes[n.get('ref')]) for n in way.findall('nd')]
    # Split at the extract boundary; outside geometry never creates distant strips.
    chunks, chunk = [], []
    for p in raw:
        if inside(p): chunk.append(p)
        else:
            if len(chunk)>1: chunks.append(chunk)
            chunk=[]
    if len(chunk)>1: chunks.append(chunk)
    for raw in chunks:
        dense=[]
        for a,b in zip(raw,raw[1:]):
            count=max(1,math.ceil(math.dist(a,b)/10))
            dense.extend([[a[j]+(b[j]-a[j])*i/count for j in range(2)] for i in range(count)])
        dense.append(raw[-1]); ids=[]
        for p in dense:
            key=tuple(round(x,3) for x in p)
            if key not in lookup:
                lookup[key]=len(points);points.append(p)
            idx=lookup[key];ids.append(idx)
            if tags.get('bridge')=='yes':
                height=max(1,int(tags.get('layer','1')))*8
                # OSM layer values are local ordering, not global altitude. SR-21
                # crosses an already elevated/smoothed freeway approach here.
                if tags.get('name')=='Brecksville Road':height=16
                anchors[idx]=max(anchors.get(idx,0),height)
        for a,b in zip(ids,ids[1:]):
            d=math.dist(points[a],points[b])
            if d>0.01: edges[a][b]=d;edges[b][a]=d
        try: lanes=int(tags.get('lanes','2' if kind=='motorway' else '1' if kind.endswith('_link') else '2'))
        except ValueError: lanes=2
        width=lanes*3.65+(3.0 if kind=='motorway' else 2.0 if kind.endswith('_link') else 1.0)
        if kind=='service': width=6.0
        roads.append({'id':way.get('id'),'name':tags.get('name',tags.get('destination',kind.replace('_',' '))), 'ref':tags.get('ref',''),'kind':kind,'lanes':lanes,'width':width,'oneway':tags.get('oneway')=='yes','bridge':tags.get('bridge')=='yes','nodes':ids})

# Relative elevations: OSM layers indicate stacking, not surveyed heights.
# Smooth approaches through the connected road graph; remote surface roads fixed at 0.
dist=[float('inf')]*len(points); queue=[]
for i in anchors: dist[i]=0;heapq.heappush(queue,(0,i))
while queue:
    d,i=heapq.heappop(queue)
    if d!=dist[i]:continue
    for j,length in edges[i].items():
        nd=d+length
        if nd<dist[j]:dist[j]=nd;heapq.heappush(queue,(nd,j))
for i,d in enumerate(dist):
    if d>400:anchors[i]=0.0
heights=[anchors.get(i,0.0) for i in range(len(points))]
# Granger Road passes underneath the I-77 ramps and SR-21. The former unconstrained
# graph relaxation incorrectly raised this surface street almost into those decks.
for road in roads:
    if road['id'] in {'162038255','79732401'}:
        for idx in road['nodes']:anchors[idx]=0.0;heights[idx]=0.0
for _ in range(1800):
    change=0
    for i in edges:
        if i in anchors:continue
        h=sum(heights[j]/length for j,length in edges[i].items())/sum(1/length for length in edges[i].values())
        change=max(change,abs(h-heights[i]));heights[i]=h
    if change<0.0002:break
positions=[[round(p[0],3),round(heights[i],3),round(p[1],3)] for i,p in enumerate(points)]
buildings=[]
for way in tree.findall('way'):
    tags={t.get('k'):t.get('v') for t in way.findall('tag')}
    if 'building' not in tags:continue
    poly=[project(nodes[n.get('ref')]) for n in way.findall('nd')]
    if len(poly)<4 or not all(inside(p) for p in poly):continue
    try:h=float(tags.get('height',float(tags.get('building:levels',2))*3.5))
    except ValueError:h=7.0
    buildings.append({'polygon':[[round(x,2) for x in p] for p in poly[:-1]],'height':min(h,35)})
directed=collections.defaultdict(list)
candidates=[]
for road in roads:
    if road['kind']!='motorway' or road['ref']=='I 77':continue
    for a,b in zip(road['nodes'],road['nodes'][1:]):
        if points[b][0]>points[a][0]:
            directed[a].append(b)
            if road['ref']=='I 480':candidates.append(a)
start=min(candidates,key=lambda i:math.dist(positions[i],[-650,0,-140]))
previous={start:None};pending=[start]
for a in pending:
    for b in directed[a]:
        if b not in previous:previous[b]=a;pending.append(b)
end=max(previous,key=lambda i:points[i][0]);route=[]
while end is not None:route.append(end);end=previous[end]
route.reverse()
data={'origin':origin,'bounds':[-1250,-1150,950,1100],'source':'OpenStreetMap contributors, ODbL 1.0','source_url':'https://www.openstreetmap.org/copyright','retrieved':datetime.date.today().isoformat(),'elevations':'Estimated 8m per OSM layer, graph-smoothed approaches; not surveyed terrain','points':positions,'roads':roads,'buildings':buildings,'test_route':route}
(ROOT/'assets/maps/independence.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf-8')
print(f'{len(roads)} road sections, {len(points)} samples, {len(buildings)} building footprints')
