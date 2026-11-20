extends "res://scripts/highway.gd"
## A fictional, Cleveland-inspired delivery block. No large-map geometry loads here.
var is_arcade:=true
var is_downtown:=true
var entered:=true
var spawn_position:=Vector3(-28,.15,51.5)
var spawn_heading:=-PI/2
var delivery_position:=Vector3(2,0,51.5)
var delivery_heading:=-PI/2
var depot:=Vector3(2,0,63)
var entry:=Vector3(46,0,51.5)
var route_points:Array[Vector3]=[Vector3(46,0,35),Vector3(46,0,-40),Vector3(-40,0,-51.5),Vector3(-46,0,40)]
var street_paths:Array[Array]=[]
var streets:Node3D
var cutaway_buildings:Array[Dictionary]=[]
var cutaway_count:=0
var facade_material:ShaderMaterial
var cutaway_clock:=0.0
var cutaway_audit_us:=0
var radial_probes:Array[Vector3]=[]

func _ready() -> void:
	var floor_mesh:=block(self,Vector3(0,-.35,0),Vector3(600,.6,600),Color("7f9465"),true)
	var floor_body:=floor_mesh.get_child(0) as StaticBody3D
	floor_body.set_meta("surface_kind","grass")
	# Match the road and bevel toe without lifting the visible grass into the
	# asphalt. The flat truck hull cannot climb an exposed 5 cm underside lip.
	(floor_body.get_child(0) as CollisionShape3D).position.y=.05
	streets=preload("res://scripts/street_surfaces.gd").new();streets.world=self;add_child(streets)
	road(Vector3(-46,0,51.5),Vector3(46,0,51.5),"Parcel Avenue")
	road(Vector3(46,0,51.5),Vector3(46,0,-51.5),"Mayhem Street")
	road(Vector3(46,0,-51.5),Vector3(-46,0,-51.5),"Tower Row")
	road(Vector3(-46,0,-51.5),Vector3(-46,0,51.5),"Depot Street")
	road(Vector3(-46,0,0),Vector3(46,0,0),"Cross Town")
	road(Vector3(0,0,-51.5),Vector3(0,0,51.5),"Public Lane")
	for path in street_paths:
		var a:Vector3=path[0];var b:Vector3=path[1]
		var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*8.5
		for sign_value in [-1,1]:streets.walkway(a+side*sign_value,b+side*sign_value,3.0,str(street_paths.find(path)))
	streets.island(Vector3(20,0,16),Vector3(20,0,30),7)
	streets.finish()
	for x in [-24,24]:
		for z in [-27,27]:
			if x==24 and z==27:continue # Pocket park in the southeast block.
			building(Vector3(x,0,z),Vector3(19,16+absf(x+z)*.18,22),Color("bba88c") if x<0 else Color("ab7863"))
	for i in 10:
		var x:float=-92+i*20
		building(Vector3(x,0,-91),Vector3(15,22+(i%4)*9,17),Color("819797") if i%2 else Color("a99b8d"))
	for x in [-79,79]:
		for z in [-30,15,50]:building(Vector3(x,0,z),Vector3(19,15+absf(z)*.2,26),Color("c3b698"))
	for p in [Vector3(20,0,19),Vector3(20,0,29),Vector3(-60,0,-35),Vector3(60,0,30),Vector3(-26,0,65),Vector3(26,0,-66),Vector3(63,0,-30)]:tree(p)
	for p in [Vector3(-65.8,0,35),Vector3(48.2,0,-35),Vector3(2.2,0,-42),Vector3(2.2,0,42)]:
		var lamp:=Node3D.new();lamp.position=p;add_child(lamp);build_lamp(lamp)
	for z in [-12,12]:
		for i in 7:block(self,Vector3(-5+i*1.6,.035,z),Vector3(.8,.025,3),Color("f3ebd8"))
	sign_at(Vector3(7,5,63),"FedUp / COLLECTION BAY",0)
	sign_at(Vector3(30,4,-62),"TOWER ROW / CLEVELAND",0)
	consolidate_boxes()

func road(a:Vector3,b:Vector3,title:String) -> void:
	var index:=street_paths.size();street_paths.append([a,b,title]);streets.index_road(a,b,14,str(index))
	var d:Vector3=b-a
	var deck:=block(self,(a+b)*.5-Vector3.UP*.3,Vector3(14,.6,d.length()+14),Color("51515c"),true)
	deck.rotation.y=atan2(-d.x,-d.z);deck.material_override=art.material(Color("51515c"),false,true)
	deck.get_child(0).set_meta("terrain_kind","asphalt")
	for i in int(d.length()/9):
		var p:=a+d.normalized()*(i*9+4)
		if absf(p.x)<9 and absf(p.z)<9:continue
		var dash:=block(self,p+Vector3.UP*.022,Vector3(.12,.025,3),Color("eed083"));dash.rotation.y=deck.rotation.y

func building(at:Vector3,dimensions:Vector3,tone:Color) -> void:
	# Keep an honest footprint when tall foreground walls cut away.
	block(self,at+Vector3.UP*.35,Vector3(dimensions.x,.7,dimensions.z),tone.darkened(.2))
	block(self,at+Vector3.UP*.72,Vector3(dimensions.x+.15,.06,dimensions.z+.15),tone.darkened(.4))
	for sign_value in [-1,1]:
		block(self,at+Vector3(sign_value*dimensions.x*.5,.77,0),Vector3(.09,.05,dimensions.z),Color("a18aad"))
		block(self,at+Vector3(0,.77,sign_value*dimensions.z*.5),Vector3(dimensions.x,.05,.09),Color("a18aad"))
	var root:=Node3D.new();root.position=at;add_child(root)
	var first:=boxes.size()
	var main:=block(root,Vector3.UP*dimensions.y*.5,dimensions,tone,true)
	var collider:StaticBody3D=main.get_child(0);collider.set_meta("camera_cover",root)
	block(root,Vector3.UP*(dimensions.y+.2),Vector3(dimensions.x+1,.6,dimensions.z+1),Color("3b3a48"))
	block(root,Vector3.UP*3,Vector3(dimensions.x+.4,.35,dimensions.z+.4),Color("eee0c3"))
	for floor_index in range(1,int(dimensions.y/3)):
		for s in [-1,1]:
			block(root,Vector3(0,4+floor_index*2.6,s*(dimensions.z*.5+.04)),Vector3(dimensions.x-2,1.35,.1),Color("365463"))
			block(root,Vector3(s*(dimensions.x*.5+.04),4+floor_index*2.6,0),Vector3(.1,1.35,dimensions.z-2),Color("365463"))
	for s in [-1,1]:
		block(root,Vector3(0,1.55,s*(dimensions.z*.5+.06)),Vector3(dimensions.x-3,2.5,.12),Color("29434c"))
		var awning:=block(root,Vector3(0,3.2,s*(dimensions.z*.5+.75)),Vector3(dimensions.x-1,.22,1.7),Color("6a39a0"));awning.rotation.x=s*.12
	# One vertex-colored facade draw per building allows individual cutaways
	# without splitting it into dozens of material draws or touching collision.
	if not facade_material:
		facade_material=art.material(Color.WHITE).duplicate();facade_material.set_shader_parameter("use_vertex_color",true)
		art.cache["arcade_facades"]=facade_material
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(first,boxes.size()):
		var box:MeshInstance3D=boxes[index]
		var arrays:Array=box.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var color:Color=box.material_override.get_shader_parameter("base_color")
		for vertex in indices:
			tool.set_color(color);tool.set_normal(box.basis*normals[vertex]);tool.add_vertex(box.transform*vertices[vertex])
		for child in box.get_children():
			if child is StaticBody3D:child.reparent(self,true)
		box.queue_free()
	boxes.resize(first)
	var visual:=MeshInstance3D.new();visual.mesh=tool.commit();visual.material_override=facade_material;root.add_child(visual)
	cutaway_buildings.append({"root":root,"collider":collider,"low":at-Vector3(dimensions.x*.5+1,0,dimensions.z*.5+1),"high":at+Vector3(dimensions.x*.5+1,dimensions.y+1,dimensions.z*.5+1),"hold":0.0,"kind":"building"})
	var cover:Dictionary=cutaway_buildings.back();cover.bounds=AABB(cover.low,cover.high-cover.low)

func tree(at:Vector3) -> void:
	tree_collision(at,.28,3.2);block(self,at+Vector3.UP*1.6,Vector3(.45,3.2,.45),Color("65503a"))
	var leaf:=SphereMesh.new();leaf.radial_segments=7;leaf.rings=3
	var poses:Array[Transform3D]=[]
	for i in 5:poses.append(Transform3D(Basis().scaled(Vector3(2.7,3,2.5)),at+Vector3(cos(i*TAU/5)*1.35,4.6+float(i%2)*.8,sin(i*TAU/5)*1.35)))
	var canopy:=batch_mesh(leaf,poses,Color("638443"),true)
	cutaway_buildings.append({"root":canopy,"low":at+Vector3(-4,2.8,-4),"high":at+Vector3(4,7.3,4),"hold":0.0,"kind":"tree"})
	var cover:Dictionary=cutaway_buildings.back();cover.bounds=AABB(cover.low,cover.high-cover.low)

func segment_covers(from:Vector3,to:Vector3,low:Vector3,high:Vector3) -> bool:
	return AABB(low,high-low).intersects_segment(from,to)!=null

func update_cutaways(camera:Camera3D,focus:Vector3,walking:bool,delta:=.016) -> void:
	cutaway_clock+=delta
	if delta>0 and cutaway_clock<.08:return
	var elapsed:=maxf(.08,cutaway_clock);cutaway_clock=0
	var started:=Time.get_ticks_usec()
	if radial_probes.is_empty():
		for i in 8:radial_probes.append(Vector3(cos(i*TAU/8),0,sin(i*TAU/8)))
	var radius:float=6 if walking else 9
	var samples:Array[Vector3]=[focus,Vector3(focus.x,.2,focus.z)]
	for probe in radial_probes:samples.append(Vector3(focus.x,.4,focus.z)+probe*radius)
	var from:=camera.global_position
	var low:=Vector3(minf(from.x,focus.x-radius),-100,minf(from.z,focus.z-radius))
	var high:=Vector3(maxf(from.x,focus.x+radius),100,maxf(from.z,focus.z+radius))
	cutaway_count=0
	for cover in cutaway_buildings:
		var blocks:=false
		if cover.high.x>=low.x and cover.low.x<=high.x and cover.high.z>=low.z and cover.low.z<=high.z:
			var bounds:AABB=cover.bounds
			for sample in samples:
				# A point inside a building cannot be playable ground to reveal.
				if sample.x>cover.low.x and sample.x<cover.high.x and sample.z>cover.low.z and sample.z<cover.high.z:continue
				if bounds.intersects_segment(from,sample)!=null:blocks=true;break
		cover.hold=.3 if blocks else maxf(0,float(cover.hold)-elapsed)
		cover.root.visible=float(cover.hold)<=0
		if not cover.root.visible:cutaway_count+=1
	cutaway_audit_us=Time.get_ticks_usec()-started

func restore_cutaways() -> void:
	for cover in cutaway_buildings:cover.root.show();cover.hold=0
	cutaway_count=0

func sign_at(at:Vector3,value:String,yaw:float) -> void:
	block(self,at,Vector3(13,1.8,.22),Color("253b3d"),true)
	for s in [-1,1]:block(self,at+Vector3(s*5,-at.y*.5,0),Vector3(.13,at.y,.13),Color("353441"),true)
	var label:=Label3D.new();label.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf");label.text=value;label.font_size=60;label.pixel_size=.014;label.position=at+Vector3(0,0,.15);label.rotation.y=yaw;label.modulate=Color("ffe0a0");add_child(label)

func nearest_road(at:Vector3) -> Dictionary:
	var result:Dictionary={"name":"Delivery Mayhem","point":spawn_position,"distance":INF}
	for path in street_paths:
		var p:=Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),Vector2(path[0].x,path[0].z),Vector2(path[1].x,path[1].z))
		var d:=p.distance_to(Vector2(at.x,at.z))
		if d<result.distance:result={"name":path[2],"point":Vector3(p.x,0,p.y),"distance":d}
	return result

func has_road_near(at:Vector3,distance:=7.0) -> bool:
	return nearest_road(at).distance<distance

func outside_bounds(at:Vector3) -> bool:
	return not at.is_finite() or absf(at.x)>240 or absf(at.z)>240 or at.y< -4 or at.y>100

func map_point(at:Vector3,rect:Rect2) -> Vector2:
	return rect.position+Vector2(16,32)+(Vector2(at.x,at.z)+Vector2(68,72))/Vector2(136,144)*(rect.size-Vector2(32,52))

func draw_map(canvas:Control,rect:Rect2,at:Vector3) -> void:
	for path in street_paths:canvas.draw_line(map_point(path[0],rect),map_point(path[1],rect),Color("899c9e"),3,true)
	canvas.draw_circle(map_point(at,rect),4,Color("70e5e0"))
