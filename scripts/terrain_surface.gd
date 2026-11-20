extends RefCounted
## Classifies one actual wheel-ray hit; it does not infer ground from the truck centre.
## `terrain_kind` on a static collider is an authoritative material override. Supported
## values: grass, vegetation, dirt, sand, water, snow, asphalt and sidewalk.
## The legacy shared floor's `surface_kind=grass` is deliberately different: downtown
## asphalt is visual geometry over that floor, so its exact road footprint wins first.
## Unknown props/roofs return "solid", missing/vertical/dynamic hits return "none".
const KINDS := ["grass","vegetation","dirt","sand","water","snow","asphalt","sidewalk"]
const CELL := 64.0
static var motorway_cache:Dictionary={}

static func kind(van:Node,hit:Dictionary) -> String:
	if hit.is_empty() or not hit.get("collider") is StaticBody3D:return "none"
	var normal:Vector3=hit.get("normal",Vector3.ZERO)
	if normal.y<.45:return "none"
	var collider:StaticBody3D=hit.collider
	var at:Vector3=hit.get("position",Vector3.ZERO)
	var explicit:=str(collider.get_meta("terrain_kind",""))
	if explicit in KINDS:return "grass" if explicit=="vegetation" else explicit
	var legacy:=str(collider.get_meta("surface_kind",""))
	# Raised concrete and discrete future terrain do not use the visual-road fallback.
	if legacy in KINDS and legacy!="grass":return "grass" if legacy=="vegetation" else legacy
	var world:Node=van.get("location_world")
	if is_instance_valid(world):
		var script:Script=world.get_script()
		var path:String=script.resource_path if script else ""
		if path.ends_with("/independence.gd"):
			var index:=motorway_index(world)
			if collider.get_instance_id()==int(index.road_body):
				# The motorway body contains road decks and green embankments, but not
				# buildings. Interpolated deck height prevents grass below a bridge from
				# being classified as the road above it.
				return "asphalt" if motorway_road(at,index) else "grass"
			if legacy=="grass" or shared_floor(collider):return "grass"
		elif path.ends_with("/downtown.gd") or path.ends_with("/arcade_world.gd"):
			if legacy=="grass" or shared_floor(collider):
				var streets:Node=world.get("streets")
				if absf(at.y)<.09 and is_instance_valid(streets) and streets.on_road(at):return "asphalt"
				return "grass"
	# Legacy loop roads have physical decks; never turn an unknown prop into grass
	# merely because it lies outside a road sample radius.
	if legacy=="grass" or shared_floor(collider):return "grass"
	if legacy_road(collider,at):return "asphalt"
	return "solid"

static func shared_floor(body:StaticBody3D) -> bool:
	# Both current maps' terrain beds are explicit, very large BoxShape3Ds. This
	# conservative fallback recognizes the older untagged motorway floor only.
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size:Vector3=child.shape.size*body.global_basis.get_scale().abs()
			if size.x>=1000 and size.z>=1000 and size.y<=2:return true
	return false

static func legacy_road(body:StaticBody3D,at:Vector3) -> bool:
	if absf(at.y)>.06:return false
	for child in body.get_children():
		if not child is CollisionShape3D or not child.shape is BoxShape3D:continue
		var size:Vector3=child.shape.size*body.global_basis.get_scale().abs()
		if absf(size.y-.6)>.03:continue
		# The original circular decks are 15.5 m wide; district roads are 14 m.
		if absf(size.x-15.5)<.03 or absf(size.x-14)<.03 or absf(size.z-14)<.03:return true
	return false

static func motorway_index(world:Node) -> Dictionary:
	var id:=world.get_instance_id()
	if motorway_cache.has(id) and motorway_cache[id].world.get_ref()==world:return motorway_cache[id]
	# Build once per loaded map, not once per wheel sample. Weak references and
	# cleanup avoid retaining an unloaded location or reusing an old instance id.
	for old in motorway_cache.keys():
		if not is_instance_valid(motorway_cache[old].world.get_ref()):motorway_cache.erase(old)
	var index:Dictionary={"world":weakref(world),"grid":{},"segments":[],"road_body":0}
	var points:Array[Vector3]=world.get("road_points")
	var data:Dictionary=world.get("map_data")
	for road in data.roads:
		var nodes:Array=road.nodes
		var width:float=float(road.width)+(2.0 if road.kind in ["motorway","motorway_link"] else 0.0)
		var left:Array[Vector3]=[];var right:Array[Vector3]=[]
		for i in nodes.size():
			var p:Vector3=points[int(nodes[i])]
			var direction:Vector3=points[int(nodes[mini(i+1,nodes.size()-1)])]-points[int(nodes[maxi(i-1,0)])]
			var side:=Vector3(-direction.z,0,direction.x).normalized()*width*.5
			left.append(p-side);right.append(p+side)
		for i in range(1,nodes.size()):
			var quad:Array[Vector3]=[left[i-1],right[i-1],right[i],left[i]]
			var segment:Dictionary={"a":points[int(nodes[i-1])],"b":points[int(nodes[i])],"quad":quad}
			var n:int=index.segments.size();index.segments.append(segment)
			var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
			for p in quad:
				var flat:=Vector2(p.x,p.z);low=low.min(flat);high=high.max(flat)
			for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
				for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
					var cell:=Vector2i(x,z)
					if not index.grid.has(cell):index.grid[cell]=[]
					index.grid[cell].append(n)
	# The combined motorway contact body contains exactly the stored road faces.
	# Match it once to avoid identifying other concave building colliders as terrain.
	var faces:PackedVector3Array=world.get("road_faces")
	for body in world.get_children():
		if not body is StaticBody3D:continue
		for shape in body.get_children():
			if not shape is CollisionShape3D or not shape.shape is ConcavePolygonShape3D:continue
			var actual:PackedVector3Array=shape.shape.get_faces()
			if actual.size()==faces.size() and actual.size()>2 and actual[0].is_equal_approx(faces[0]) and actual[1].is_equal_approx(faces[1]) and actual[2].is_equal_approx(faces[2]):
				index.road_body=body.get_instance_id();break
		if int(index.road_body)!=0:break
	motorway_cache[id]=index
	return index

static func motorway_road(at:Vector3,index:Dictionary) -> bool:
	var p:=Vector2(at.x,at.z);var cell:=Vector2i(floori(at.x/CELL),floori(at.z/CELL))
	for n in index.grid.get(cell,[]):
		var segment:Dictionary=index.segments[n]
		var quad:Array=segment.quad
		# Match the actual two triangles used by independence.quad(), including
		# their deck height at corners rather than a broad centre-line radius.
		if on_triangle(at,p,quad[0],quad[2],quad[1]) or on_triangle(at,p,quad[0],quad[3],quad[2]):return true
	return false

static func on_triangle(at:Vector3,p:Vector2,a:Vector3,b:Vector3,c:Vector3) -> bool:
	var origin:=Vector2(a.x,a.z);var ab:=Vector2(b.x-a.x,b.z-a.z);var ac:=Vector2(c.x-a.x,c.z-a.z)
	var area:=ab.cross(ac)
	if absf(area)<.0001:return false
	var offset:=p-origin
	var u:=offset.cross(ac)/area;var v:=ab.cross(offset)/area
	if u<-.0001 or v<-.0001 or u+v>1.0001:return false
	return absf(at.y-(a.y+(b.y-a.y)*u+(c.y-a.y)*v))<.025
