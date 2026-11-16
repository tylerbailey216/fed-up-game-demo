"""Offline OSM-derived downtown street/footprint extract; meter-scale game blockout."""
import json,math,heapq,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=ET.parse(ROOT/'assets/maps/cleveland_osm.xml').getroot()
origin=(41.4995,-81.6944)
nodes={n.get('id'):(float(n.get('lat')),float(n.get('lon'))) for n in r.findall('node')}
def p(ref):
 lat,lon=nodes[ref];return [round((lon-origin[1])*111320*math.cos(math.radians(origin[0])),2),round((origin[0]-lat)*111320,2)]
def inside(pt):return -650<pt[0]<650 and -650<pt[1]<650
roads=[];buildings=[];parks=[];landmarks={}
for w in r.findall('way'):
 t={a.get('k'):a.get('v') for a in w.findall('tag')};poly=[p(n.get('ref')) for n in w.findall('nd')]
 if len(poly)<2:continue
 if t.get('highway') in ['primary','secondary','tertiary','residential','unclassified','service','living_street','pedestrian','footway','path'] and t.get('area')!='yes' and t.get('tunnel')!='yes':
  kind=t['highway'];foot=kind in ['footway','pedestrian','path'];chunk=[]
  for point in poly+[None]:
   if point and inside(point):chunk.append(point)
   else:
    if len(chunk)>1:
     try:lanes=int(t.get('lanes',2))
     except ValueError:lanes=2
     roads.append({'id':w.get('id'),'name':t.get('name',kind.replace('_',' ')),'points':chunk,'width':3 if foot else max(7,min(20,lanes*3.3+2)),'foot':foot,'oneway':t.get('oneway')=='yes'})
    chunk=[]
 if t.get('building') and len(poly)>3 and all(inside(x) for x in poly):
  try:h=float(t.get('height',float(t.get('building:levels',4))*3.7))
  except ValueError:h=14.8
  name=t.get('name','')
  if name in ['Terminal Tower','Key Tower','200 Public Square','55 Public Square']:
   center=[sum(x[i] for x in poly[:-1])/(len(poly)-1) for i in range(2)];landmarks[name]={'center':center,'height':h}
  buildings.append({'polygon':poly[:-1],'height':max(5,min(300,h)),'name':name})
 if t.get('leisure')=='park' and len(poly)>3 and all(inside(x) for x in poly):parks.append({'polygon':poly[:-1],'name':t.get('name','Park')})
graph={}
for road in roads:
 if road['foot']:continue
 for a,b in zip(road['points'],road['points'][1:]):
  a,b=tuple(a),tuple(b);d=math.dist(a,b)
  if d<.01:continue
  graph.setdefault(a,[]).append((b,d));graph.setdefault(b,[])
  if not road['oneway']:graph[b].append((a,d))
def path(a,b):
 q=[(0,a)];cost={a:0};prev={a:None}
 while q:
  distance,n=heapq.heappop(q)
  if n==b:break
  if distance!=cost[n]:continue
  for other,d in graph[n]:
   nd=distance+d
   if nd<cost.get(other,1e99):cost[other]=nd;prev[other]=n;heapq.heappush(q,(nd,other))
 if b not in prev:return []
 result=[]
 while b is not None:result.append(b);b=prev[b]
 return result[::-1]
anchors=[min(graph,key=lambda n:math.dist(n,target)) for target in [(-130,-170),(200,-180),(270,230),(-180,240)]]
cycle=[]
for a,b in zip(anchors,anchors[1:]+anchors[:1]):cycle.extend(path(a,b)[:-1])
data={'origin':origin,'offset':[1000,0,-75],'bounds':[-650,-650,650,650],'roads':roads,'buildings':buildings,'parks':parks,'landmarks':landmarks,'traffic_route':cycle,'source':'OpenStreetMap contributors / ODbL 1.0','source_url':'https://www.openstreetmap.org/copyright','elevations':'Flat street blockout; not surveyed terrain or current traffic restrictions'}
(ROOT/'assets/maps/cleveland.json').write_text(json.dumps(data,separators=(',',':')))
print(len(roads),'road/path sections',len(buildings),'buildings',landmarks)
