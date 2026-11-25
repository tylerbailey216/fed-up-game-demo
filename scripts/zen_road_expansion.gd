extends RefCounted
## Fictional scenic return roads outside the original offline map boundary.
## Shared endpoint IDs and tangent-matched cubic bends: no endpoint teleports.
static func expand(data:Dictionary) -> Array[Dictionary]:
	var starts:Dictionary={};var ends:Dictionary={};var roads:Array=[]
	for road in data.roads:
		if road.kind=="motorway" and road.ref in ["I 77","I 480"]:
			roads.append(road);starts[int(road.nodes[0])]=true;ends[int(road.nodes[-1])]=true
	var additions:Array[Dictionary]=[]
	for road in roads:
		var last:int=road.nodes[-1]
		if starts.has(last):continue
		var a:=vec(data.points[last]);var before:=vec(data.points[int(road.nodes[-2])])
		var forward:Vector3=(a-before).normalized();forward.y=0;forward=forward.normalized()
		var partner:Dictionary={};var best:=INF
		for candidate in roads:
			var first:int=candidate.nodes[0]
			if candidate.ref!=road.ref or ends.has(first):continue
			var distance:=a.distance_to(vec(data.points[first]))
			if distance<best:best=distance;partner=candidate
		if partner.is_empty():continue
		var first:int=partner.nodes[0];var b:=vec(data.points[first])
		var incoming:Vector3=(vec(data.points[int(partner.nodes[1])])-b).normalized()
		incoming.y=0;incoming=incoming.normalized()
		var right:=Vector3(-forward.z,0,forward.x)
		var mid:Vector3=(a+b)*.5+forward*700+right*120
		mid.y=(a.y+b.y)*.5
		var ids:Array=[last]
		for half in 2:
			var p:Vector3=a if half==0 else mid
			var q:Vector3=mid if half==0 else b
			var c:Vector3=a+forward*450 if half==0 else mid-right*450
			var d:Vector3=mid+right*450 if half==0 else b-incoming*450
			for step in range(1,101):
				if half==1 and step==100:ids.append(first);continue
				var t:float=step/100.0;var u:=1.0-t
				var at:Vector3=p*u*u*u+c*3*u*u*t+d*3*u*t*t+q*t*t*t
				ids.append(data.points.size());data.points.append([at.x,at.y,at.z])
		var addition:Dictionary={"nodes":ids,"name":"Scenic return loop","ref":road.ref,"kind":"motorway","width":14.0,"lanes":2,"oneway":true,"bridge":false,"zen_return":true}
		data.roads.append(addition);additions.append(addition)
	return additions

static func vec(p:Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

