extends "res://scripts/highway.gd"

func outside_bounds(at:Vector3) -> bool:
	return at.y < -4 or at.y > 100 or at.x < -360 or at.x > 1730 or at.z < -790 or at.z > 710
## Training loop connected to an offline, stylized Public Square street blockout.
const OFFSET := Vector3(1000,0,-75)
var map_data:Dictionary
var entered:=false
var is_downtown:=true
var spawn_position:=Vector3(260,0.15,0)
var spawn_heading:=0.0
var road_samples:Array[Vector3]=[]
var street_paths:Array[Array]=[]
var entry:=Vector3.ZERO
var map_cache:Dictionary={}
var surfaces:Dictionary={}
var solid_faces:=PackedVector3Array()
var depot:=Vector3(962,0,-43)
var barriers:Node3D # Compatibility: the separate motorway owns its barriers.
var road_grid:Dictionary={}
var road_names:Array[String]=[]
var scenery_material:ShaderMaterial

func _ready() -> void:
	training_mode=true
	super._ready()
	map_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/cleveland.json"))
	# The extended training terrain covers downtown too. A second overlapping
	# floor can exhaust the character solver's slides and obscure asphalt.
	var closest:=INF
	for road in map_data.roads:
		var path:Array=[]
		for p in road.points:path.append(Vector3(p[0],0,p[1])+OFFSET)
		if not road.foot:street_paths.append(path)
		for i in range(1,path.size()):
			road_segment(path[i-1],path[i],road.width,road.foot)
			if not road.foot:
				var length:float=path[i-1].distance_to(path[i])
				for j in maxi(1,ceili(length/8)):add_road_sample(path[i-1].lerp(path[i],float(j)/maxi(1,ceili(length/8))),road.name)
		if "Superior" in road.name and not road.foot:
			for p in path:
				var score:float=p.distance_to(Vector3(420,0,-75))
				if score<closest:closest=score;entry=p
	road_segment(Vector3(250,0,-75),entry,14,false)
	for i in 30:add_road_sample(Vector3(250,0,-75).lerp(entry,i/29.0),"Cleveland training exit")
	for park in map_data.parks:flat_polygon(park.polygon,0.018,"779b59")
	for building in map_data.buildings:building_mesh(building)
	finish_surfaces()
	build_terminal()
	build_street_details()
	consolidate_boxes()
	prepare_map(Rect2(23,521,220,165))
	prepare_map(Rect2(305,125,670,365))

func triangle(a:Vector3,b:Vector3,c:Vector3,color:String,solid:=false) -> void:
	var cell:=Vector2i(floori(a.x/128),floori(a.z/128))
	var key:=str(cell.x)+","+str(cell.y)
	var origin:=Vector3(cell.x*128,0,cell.y*128)
	if not surfaces.has(key):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[key]=tool
	for p in [a,b,c]:
		surfaces[key].set_color(Color(color));surfaces[key].add_vertex(p-origin)
	if solid:solid_faces.append_array(PackedVector3Array([a,b,c]))

func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:String,solid:=false) -> void:
	triangle(a,c,b,color,solid);triangle(a,d,c,color,solid)

func road_segment(a:Vector3,b:Vector3,width:float,foot:bool) -> void:
	if a.distance_to(b)<0.05:return
	var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*width/2
	var up:=Vector3.UP*(0.022 if foot else 0.012)
	quad(a-side+up,a+side+up,b+side+up,b-side+up,"c9bfaa" if foot else "505461")
	if not foot:
		var outward:=side.normalized()*2.2
		var step_up:=Vector3.UP*.012
		quad(a-side-outward+up+step_up,a-side+up+step_up,b-side+up+step_up,b-side-outward+up+step_up,"b8ad96")
		quad(a+side+up+step_up,a+side+outward+up+step_up,b+side+outward+up+step_up,b+side+up+step_up,"b8ad96")
	if not foot and width>8:
		var dir:Vector3=(b-a).normalized()
		for j in int(a.distance_to(b)/10):
			var p:=a+dir*(j*10+2)+Vector3.UP*0.03
			quad(p-side.normalized()*0.07,p+side.normalized()*0.07,p+side.normalized()*0.07+dir*3,p-side.normalized()*0.07+dir*3,"e6cd79")

func flat_polygon(polygon:Array,height:float,color:String) -> void:
	var poly:=PackedVector2Array()
	for p in polygon:poly.append(Vector2(p[0],p[1]))
	var indices:=Geometry2D.triangulate_polygon(poly)
	for i in range(0,indices.size(),3):
		var vs:Array=[]
		for j in 3:
			var p:=poly[indices[i+j]];vs.append(Vector3(p.x,height,p.y)+OFFSET)
		if (vs[1]-vs[0]).cross(vs[2]-vs[0]).y>0:triangle(vs[0],vs[2],vs[1],color)
		else:triangle(vs[0],vs[1],vs[2],color)

func building_mesh(building:Dictionary) -> void:
	if building.name=="Terminal Tower":return
	var height:float=building.height
	flat_polygon(building.polygon,height,"979387")
	var poly:Array=building.polygon.duplicate()
	var signed_area:=0.0
	for i in poly.size():signed_area+=poly[i][0]*poly[(i+1)%poly.size()][1]-poly[(i+1)%poly.size()][0]*poly[i][1]
	if signed_area<0:poly.reverse()
	var palette:Array[String]=["bea98c","ad785f","a7a7a0","d0bea0","a79a8d","a9b8b7"]
	var color:String=palette[absi(hash(str(poly[0])))%palette.size()]
	for i in poly.size():
		var a:=Vector3(poly[i][0],0,poly[i][1])+OFFSET
		var b:=Vector3(poly[(i+1)%poly.size()][0],0,poly[(i+1)%poly.size()][1])+OFFSET
		quad(a,a+Vector3.UP*height,b+Vector3.UP*height,b,color,true)
		if a.distance_to(b)>9:
			for floor_index in range(1,mini(60,int(height/4))):
				var y:=floor_index*4.0
				var normal:=Vector3((b-a).z,0,-(b-a).x).normalized()*0.06
				quad(a+Vector3.UP*y+normal,a+Vector3.UP*(y+1.8)+normal,b+Vector3.UP*(y+1.8)+normal,b+Vector3.UP*y+normal,"395967")
		var normal:=Vector3((b-a).z,0,-(b-a).x).normalized()*.09
		for y in [0.22,3.4,height-0.5]:
			quad(a+Vector3.UP*y+normal,a+Vector3.UP*(y+.23)+normal,b+Vector3.UP*(y+.23)+normal,b+Vector3.UP*y+normal,"e0d1b4" if y>1 else "403b3c")

func finish_surfaces() -> void:
	scenery_material=art.material(Color.WHITE).duplicate()
	scenery_material.set_shader_parameter("use_vertex_color",true)
	art.cache["downtown_vertex_colors"]=scenery_material
	for key in surfaces:
		var tool:SurfaceTool=surfaces[key];tool.generate_normals()
		var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit()
		var cell:=Vector2i(int(key.split(",")[0]),int(key.split(",")[1]))
		mesh.position=Vector3(cell.x*128,0,cell.y*128)
		mesh.material_override=scenery_material
		mesh.visibility_range_end=1800
		add_child(mesh)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var collision:=ConcavePolygonShape3D.new()
	collision.backface_collision=true;collision.set_faces(solid_faces);shape.shape=collision
	body.add_child(shape);add_child(body)
	surfaces.clear()

func build_terminal() -> void:
	var landmark:Dictionary=map_data.landmarks["Terminal Tower"]
	var center:=Vector3(landmark.center[0],0,landmark.center[1])+OFFSET
	for part in [[Vector3(0,18,0),Vector3(65,36,55)],[Vector3(0,73,0),Vector3(36,110,34)],[Vector3(0,145,0),Vector3(26,34,25)],[Vector3(0,171,0),Vector3(20,18,20)],[Vector3(0,191,0),Vector3(12,22,12)],[Vector3(0,209,0),Vector3(6,14,6)]]:
		block(self,center+part[0],part[1],Color("c6b99a"),true)
	for i in 46:
		var y:=12+i*4.2
		var width:=31.0 if y<126 else (22.0 if y<160 else 16.0 if y<180 else 8.0)
		for side in [-1,1]:
			block(self,center+Vector3(0,y,side*(width/2+0.1)),Vector3(width,1.7,0.12),Color("365463"))
	var spire:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=0.15;cone.bottom_radius=4.3;cone.height=16
	spire.mesh=cone;spire.position=center+Vector3(0,224,0);spire.material_override=art.material(Color("577465"),true);add_child(spire)
	label(center+Vector3(0,9,-29),"TOWER CITY\nTERMINAL TOWER",0,0.065)

func label(at:Vector3,text:String,yaw:=0.0,pixel:=0.025) -> void:
	var node:=Label3D.new();node.text=text;node.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf");node.font_size=48;node.pixel_size=pixel;node.position=at;node.rotation.y=yaw;node.modulate=Color("ffe0a0");add_child(node)

func build_street_details() -> void:
	label(Vector3(295,5,-88),"DOWNTOWN CLEVELAND\nPUBLIC SQUARE / TOWER CITY",-PI/2)
	block(self,Vector3(295.08,5,-88),Vector3(.18,3.0,13),Color("253b3d"))
	for z in [-93,-83]:block(self,Vector3(295.08,2,z),Vector3(.18,4,.18),Color("353441"))
	var square_sign:=Vector3(975,1.65,-48)
	block(self,square_sign,Vector3(4.4,1.15,.15),Color("253b3d"))
	for x in [-1.7,1.7]:block(self,square_sign+Vector3(x,-.75,0),Vector3(.09,1.5,.09),Color("353441"))
	label(square_sign+Vector3(0,0,.09),"PUBLIC SQUARE",0,.008)
	label(depot+Vector3(0,3,0),"FedUp RECOVERY DEPOT",0,0.018)
	block(self,depot+Vector3(0,0.04,0),Vector3(7,0.06,7),Color("765494"))
	var rng:=RandomNumberGenerator.new();rng.seed=44114
	var trunks:Array[Transform3D]=[];var crowns:Array[Transform3D]=[]
	for i in 75:
		var angle:=rng.randf_range(0,TAU);var radius:=rng.randf_range(35,75)
		var p:=OFFSET+Vector3(cos(angle)*radius,0,sin(angle)*radius)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.5,5,0.5)),p+Vector3.UP*2.5))
		crowns.append(Transform3D(Basis().scaled(Vector3(4,5,4)),p+Vector3.UP*6))
	batch_boxes(trunks,Color("65503a"));var sphere:=SphereMesh.new();sphere.radial_segments=8;sphere.rings=4
	batch_mesh(sphere,crowns,Color("638f49"),true)

func _physics_process(_delta:float) -> void:
	var game:Node=get_parent()
	if not entered and game.get("van") and game.van.active and game.van.position.x>285:
		entered=true
		game.van.notify_driver("TRAINING COMPLETE - welcome to Public Square / Tower City")

func has_road_near(at:Vector3,distance:=7.0) -> bool:
	if at.x<300:return absf(Vector2(at.x,at.z).length()-260)<8
	var cell:=Vector2i(floori(at.x/32),floori(at.z/32))
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			for index in road_grid.get(Vector2i(x,z),[]):
				if road_samples[index].distance_squared_to(at)<distance*distance:return true
	return false

func add_road_sample(at:Vector3,road_name:String) -> void:
	var cell:=Vector2i(floori(at.x/32),floori(at.z/32))
	if not road_grid.has(cell):road_grid[cell]=[]
	road_grid[cell].append(road_samples.size());road_samples.append(at);road_names.append(road_name)

func nearest_road(at:Vector3) -> Dictionary:
	var result:Dictionary={"name":"Downtown Cleveland","point":spawn_position,"distance":INF}
	for index in road_samples.size():
		var p:=road_samples[index]
		var d:float=p.distance_to(at)
		if d<result.distance:result.point=p;result.distance=d;result.name=road_names[index]
	return result

func map_point(at:Vector3,rect:Rect2) -> Vector2:
	return rect.position+Vector2(12,32)+Vector2((at.x+320)/2000,(at.z+740)/1400)*(rect.size-Vector2(24,60))

func prepare_map(rect:Rect2) -> void:
	var key:=str(rect.size)
	if map_cache.has(key):return
	var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'>" % [rect.size.x,rect.size.y]
	var local:=Rect2(Vector2.ZERO,rect.size)
	for path in street_paths:
		var coords:=PackedStringArray()
		for p in path:
			var v:=map_point(p,local);coords.append("%.1f,%.1f" % [v.x,v.y])
		svg+="<polyline points='%s' fill='none' stroke='#899c9e' stroke-width='1.3'/>" % " ".join(coords)
	var coords:=PackedStringArray()
	for i in 81:
		var v:=map_point(Vector3(cos(i*TAU/80)*260,0,sin(i*TAU/80)*260),local);coords.append("%.1f,%.1f" % [v.x,v.y])
	svg+="<polyline points='%s' fill='none' stroke='#e8c67a' stroke-width='2'/>" % " ".join(coords)
	var a:=map_point(Vector3(250,0,-75),local);var b:=map_point(entry,local)
	svg+="<path d='M%.1f %.1f L%.1f %.1f' stroke='#e8c67a' stroke-width='2'/>" % [a.x,a.y,b.x,b.y]
	svg+="</svg>";var image:=Image.new()
	if image.load_svg_from_string(svg)==OK:map_cache[key]=ImageTexture.create_from_image(image)

func draw_map(canvas:Control,rect:Rect2,at:Vector3) -> void:
	prepare_map(rect)
	if map_cache.has(str(rect.size)):canvas.draw_texture_rect(map_cache[str(rect.size)],rect,false)
	canvas.draw_circle(map_point(at,rect),4,Color("70e5e0"))
