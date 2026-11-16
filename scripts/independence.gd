extends "res://scripts/highway.gd"
## Offline OSM extract; X east, -Z north, one unit = one meter.
var map_data: Dictionary
var road_points: Array[Vector3] = []
var spawn_position := Vector3.ZERO
var spawn_heading := 0.0
var road_faces := PackedVector3Array()
var surfaces: Dictionary = {}
var map_cache: Dictionary = {}
var road_grid: Dictionary = {}
var point_names: Dictionary = {}
var point_widths: Dictionary = {}
const GRID_SIZE := 32.0
var barriers: Node3D

func _ready() -> void:
	map_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/independence.json"))
	for p in map_data.points:
		road_points.append(Vector3(p[0],p[1],p[2]))
	for road in map_data.roads:
		for raw_idx in road.nodes:
			var idx:=int(raw_idx)
			point_widths[idx]=maxf(float(point_widths.get(idx,0)),float(road.width))
			if point_names.has(idx):continue
			point_names[idx]=road.ref+" "+road.name
			var p:=road_points[idx]
			var cell:=Vector2i(floori(p.x/GRID_SIZE),floori(p.z/GRID_SIZE))
			if not road_grid.has(cell):road_grid[cell]=[]
			road_grid[cell].append(int(idx))
	block(self,Vector3(-150,-0.6,-25),Vector3(2500,1,2550),Color("79935d"),true)
	for road in map_data.roads:
		build_road(road)
	for key in surfaces:
		var mesh := MeshInstance3D.new()
		var surface: SurfaceTool = surfaces[key]
		surface.generate_normals()
		mesh.mesh = surface.commit()
		var color: String = key.split("@")[0]
		mesh.material_override = art.material(Color(color),false,color=="505461")
		mesh.visibility_range_end=900
		mesh.visibility_range_end_margin=80
		add_child(mesh)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(road_faces)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	barriers=preload("res://scripts/road_barriers.gd").new()
	barriers.world=self
	add_child(barriers)
	build_buildings()
	build_landscape()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77480
	build_clouds(rng)
	consolidate_boxes()
	# Eastbound I-480 approach west of the interchange, aligned with mapped direction.
	var best := INF
	for road in map_data.roads:
		if road.ref!="I 480": continue
		for i in range(1,road.nodes.size()):
			var a := road_points[road.nodes[i-1]]
			var b := road_points[road.nodes[i]]
			if b.x<a.x: continue
			var score := a.distance_to(Vector3(-650,0,-140))
			if score<best:
				best=score
				spawn_heading=atan2(-(b-a).x,-(b-a).z)
				var right := Vector3(-(b-a).z,0,(b-a).x).normalized()
				spawn_position=a+right*1.8+Vector3.UP*0.16
	# Prepare both static GPS sizes during map loading, avoiding first-open hitches.
	prepare_map(Rect2(23,521,220,165))
	prepare_map(Rect2(305,125,670,365))

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: String,solid := false) -> void:
	var cell:=Vector2i(floori((a.x+c.x)/256.0),floori((a.z+c.z)/256.0))
	var key:=color+"@"+str(cell)
	if not surfaces.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[key]=tool
	var tool: SurfaceTool = surfaces[key]
	# Godot front faces wind clockwise. Cross product points opposite the visible normal.
	var vertices := [a,c,b,a,d,c]
	for p in vertices: tool.add_vertex(p)
	if solid:
		for p in vertices: road_faces.append(p)

func build_road(road: Dictionary) -> void:
	var ids: Array = road.nodes
	var width: float = float(road.width)+(2.0 if road.kind in ["motorway","motorway_link"] else 0.0)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in ids.size():
		var p := road_points[ids[i]]
		var direction := road_points[ids[mini(i+1,ids.size()-1)]]-road_points[ids[maxi(i-1,0)]]
		var side := Vector3(-direction.z,0,direction.x).normalized()
		left.append(p-side*width/2)
		right.append(p+side*width/2)
	for i in range(1,ids.size()):
		var a := road_points[ids[i-1]]
		var b := road_points[ids[i]]
		quad(left[i-1],right[i-1],right[i],left[i],"505461",true)
		if road.bridge:
			quad(left[i-1]-Vector3.UP*0.65,left[i-1],left[i],left[i]-Vector3.UP*0.65,"a0a093")
			quad(right[i],right[i-1],right[i-1]-Vector3.UP*0.65,right[i]-Vector3.UP*0.65,"a0a093")
		elif (a.y>0.8 or b.y>0.8) and pier_clear((a+b)*0.5,width/2+maxf(a.y,b.y)*1.5+3):
			# Supported embankment approaches, kept clear of roads underneath.
			var side_a:Vector3=(right[i-1]-left[i-1]).normalized()
			var side_b:Vector3=(right[i]-left[i]).normalized()
			var low_left_a:=Vector3(left[i-1].x,0,left[i-1].z)-side_a*a.y*1.5
			var low_left_b:=Vector3(left[i].x,0,left[i].z)-side_b*b.y*1.5
			var low_right_a:=Vector3(right[i-1].x,0,right[i-1].z)+side_a*a.y*1.5
			var low_right_b:=Vector3(right[i].x,0,right[i].z)+side_b*b.y*1.5
			quad(low_left_a,left[i-1],left[i],low_left_b,"79935d",true)
			quad(right[i-1],low_right_a,low_right_b,right[i],"79935d",true)
		# Continuous edge stripes and shared lane markings; no barriers across merges.
		var side := (right[i]-left[i]).normalized()
		var old_side := (right[i-1]-left[i-1]).normalized()
		for edge in [-1,1]:
			var pa: Vector3 = a+old_side*(width/2-0.4)*edge+Vector3.UP*0.025
			var pb: Vector3 = b+side*(width/2-0.4)*edge+Vector3.UP*0.025
			quad(pa-old_side*0.065,pa+old_side*0.065,pb+side*0.065,pb-side*0.065,"e8ca65" if edge==-1 and road.oneway else "e8e4cc")
		if i%2==0:
			for lane in range(1,int(road.lanes)):
				var offset: float = (float(lane)/road.lanes-0.5)*(width-2)
				var pa: Vector3 = a+old_side*offset+Vector3.UP*0.03
				var pb: Vector3 = a.lerp(b,0.4)+old_side*offset+Vector3.UP*0.03
				quad(pa-old_side*0.07,pa+old_side*0.07,pb+old_side*0.07,pb-old_side*0.07,"e8e4cc")
		if road.bridge and i%9==0 and a.y>4 and pier_clear(a):
			block(self,Vector3(a.x,a.y/2-0.4,a.z),Vector3(1.5,a.y-0.8,1.5),Color("a0a093"),true)
	if road.kind=="motorway" and ids.size()>35:
		var mid := mini(18,ids.size()-2)
		var p := road_points[ids[mid]]
		var heading := (road_points[ids[mid+1]]-p).normalized()
		var side := Vector3(-heading.z,0,heading.x)
		var sign := Node3D.new()
		sign.position=p+side*(width/2+2)
		sign.rotation.y=atan2(heading.x,heading.z)+PI
		add_child(sign)
		block(sign,Vector3(0,3.5,0),Vector3(0.16,7,0.16),Color("929d9b"),true)
		block(sign,Vector3(0,6,0),Vector3(7,2.2,0.15),Color("245c48"))
		var label := Label3D.new()
		label.text=road.ref+"\n"+("Outerbelt South" if road.ref=="I 480" else "Willow Freeway")
		label.font_size=42
		label.pixel_size=0.019
		label.position=Vector3(0,6,0.09)
		sign.add_child(label)

func pier_clear(at: Vector3,clearance := 5.0) -> bool:
	for idx in local_road_indices(at,maxi(1,ceili((clearance+20)/GRID_SIZE))):
		var p:=road_points[idx]
		if p.y<at.y-0.5 and Vector2(p.x-at.x,p.z-at.z).length()<float(point_widths[idx])/2+clearance:
			return false
	return true

func build_buildings() -> void:
	for building in map_data.buildings:
		var polygon := PackedVector2Array()
		for p in building.polygon: polygon.append(Vector2(p[0],p[1]))
		var triangles := Geometry2D.triangulate_polygon(polygon)
		if triangles.is_empty(): continue
		var h: float = building.height
		var vertices := PackedVector3Array()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,triangles.size(),3):
			var a:=polygon[triangles[i]]
			var b:=polygon[triangles[i+1]]
			var c:=polygon[triangles[i+2]]
			for p in [a,b,c]: vertices.append(Vector3(p.x,h,p.y))
		for i in polygon.size():
			var a:=polygon[i]
			var b:=polygon[(i+1)%polygon.size()]
			for p in [Vector3(a.x,0,a.y),Vector3(a.x,h,a.y),Vector3(b.x,h,b.y),Vector3(a.x,0,a.y),Vector3(b.x,h,b.y),Vector3(b.x,0,b.y)]: vertices.append(p)
		for p in vertices: tool.add_vertex(p)
		tool.generate_normals()
		var instance:=MeshInstance3D.new()
		instance.mesh=tool.commit()
		instance.material_override=art.material(Color("b8ac96"),true)
		instance.visibility_range_end=800
		add_child(instance)
		instance.create_trimesh_collision()

func build_landscape() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=48077
	var crowns: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	for i in 1700:
		var p:=Vector3(rng.randf_range(-1300,1000),0,rng.randf_range(-1200,1150))
		var clear:=true
		for road in map_data.roads:
			for idx in road.nodes:
				var at:=road_points[idx]
				if Vector2(p.x-at.x,p.z-at.z).length()<float(road.width)/2+13:
					clear=false
					break
			if not clear:break
		if not clear:continue
		var height:=rng.randf_range(6,13)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.5,height,0.5)),p+Vector3.UP*height/2))
		crowns.append(Transform3D(Basis().scaled(Vector3(height*0.4,height*0.5,height*0.4)),p+Vector3.UP*height))
	var trunk_mesh:=BoxMesh.new()
	trunk_mesh.size=Vector3.ONE
	batch_scenery(trunk_mesh,trunks,Color("66523b"))
	var sphere:=SphereMesh.new()
	sphere.radial_segments=8
	sphere.rings=4
	batch_scenery(sphere,crowns,Color("52773f"),true)

func batch_scenery(mesh: Mesh,transforms: Array[Transform3D],color: Color,outlined := false) -> void:
	var chunks:Dictionary={}
	for transform in transforms:
		var cell:=Vector2i(floori(transform.origin.x/128.0),floori(transform.origin.z/128.0))
		if not chunks.has(cell):chunks[cell]=[]
		chunks[cell].append(transform)
	for chunk in chunks.values():
		var typed:Array[Transform3D]=[]
		typed.assign(chunk)
		var instance:=batch_mesh(mesh,typed,color,outlined)
		instance.visibility_range_end=600
		instance.visibility_range_end_margin=60

func local_road_indices(at: Vector3,radius := 1) -> Array[int]:
	var result:Array[int]=[]
	var center:=Vector2i(floori(at.x/GRID_SIZE),floori(at.z/GRID_SIZE))
	for x in range(center.x-radius,center.x+radius+1):
		for z in range(center.y-radius,center.y+radius+1):
			var cell:=Vector2i(x,z)
			if road_grid.has(cell):result.append_array(road_grid[cell])
	return result

func has_road_near(at: Vector3,distance := 7.0) -> bool:
	for idx in local_road_indices(at):
		if road_points[idx].distance_squared_to(at)<distance*distance:return true
	return false

func nearest_road(at: Vector3) -> Dictionary:
	var result := {"name":"OFF ROAD","distance":INF,"point":spawn_position}
	var indices:=local_road_indices(at)
	var best_squared:=INF
	for idx in indices:
		var distance:=road_points[idx].distance_squared_to(at)
		if distance<best_squared:
			best_squared=distance
			result={"name":point_names[idx],"distance":sqrt(distance),"point":road_points[idx]}
	if best_squared>GRID_SIZE*GRID_SIZE:
		# Only explicit road-info queries far off road need a global fallback.
		for idx in road_points.size():
			var distance:=road_points[idx].distance_squared_to(at)
			if distance<best_squared:
				best_squared=distance
				result={"name":point_names.get(idx,"Road"),"distance":sqrt(distance),"point":road_points[idx]}
	return result

func prepare_map(rect: Rect2) -> void:
	var scale_xy := (rect.size-Vector2(24,60))/Vector2(2200,2250)
	var key:=str(rect)
	if not map_cache.has(key):
		var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'>" % [int(rect.size.x),int(rect.size.y)]
		for road in map_data.roads:
			var coordinates:=PackedStringArray()
			for idx in road.nodes:
				var p:=road_points[idx]
				var point:=Vector2(12,32)+Vector2(p.x+1250,p.z+1150)*scale_xy
				coordinates.append("%.2f,%.2f" % [point.x,point.y])
			svg+="<polyline points='%s' fill='none' stroke='%s' stroke-width='%d'/>" % [" ".join(coordinates),"#d8bd75" if road.kind=="motorway" else "#82908b",2 if road.kind=="motorway" else 1]
		svg+="</svg>"
		var raster:=Image.new()
		if raster.load_svg_from_string(svg)==OK:map_cache[key]=ImageTexture.create_from_image(raster)

func draw_map(canvas: Control,rect: Rect2,at: Vector3) -> void:
	var scale_xy := (rect.size-Vector2(24,60))/Vector2(2200,2250)
	var origin := rect.position+Vector2(12,32)
	var key:=str(rect)
	prepare_map(rect)
	if map_cache.has(key):canvas.draw_texture_rect(map_cache[key],rect,false)
	canvas.draw_circle(origin+Vector2(at.x+1250,at.z+1150)*scale_xy,4,Color("70e5e0"))

func map_point(at:Vector3,rect:Rect2) -> Vector2:
	return rect.position+Vector2(12,32)+Vector2(at.x+1250,at.z+1150)*(rect.size-Vector2(24,60))/Vector2(2200,2250)
