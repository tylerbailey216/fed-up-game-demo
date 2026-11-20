extends Node3D
## Connected live traffic district; all runtime state persists across loop visits.
const Car = preload("res://scripts/traffic_car.gd")
const CROSSING := Vector3(330,0,-75)
var game: Node
var highway: Node3D
var cars: Array[RigidBody3D] = []
var barrels: Array[RigidBody3D] = []
var entered := false
var phase_time := 0.0
var ns_light := "GREEN"
var ew_light := "RED"
var lamps: Array[Dictionary] = []
var red_light_runs := 0
var truck_in_crossing := false
var running := true
var push_count := 0
var disabled_world := false
var city_art:=preload("res://scripts/city_vehicle_art.gd").new()

func spawn_reference_car(kind:String,route:Array[Vector3],edge:int,fraction:float,pace:float) -> RigidBody3D:
	var car:=Car.new();car.district=self;car.definition=city_art.definitions[kind];car.model_kind=kind
	car.route=route.duplicate();car.waypoint=(edge+1)%route.size();car.cruise_speed=pace
	if game.get("zen")==true:car.cruise_speed=minf(pace*.85,5.5)
	car.position=route[edge].lerp(route[car.waypoint],fraction)+Vector3.UP*.06
	var direction:Vector3=route[car.waypoint]-car.position;car.rotation.y=atan2(-direction.x,-direction.z)
	add_child(car);city_art.build(car,highway,kind);cars.append(car);return car

func mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = pos
	node.material_override = highway.art.material(color,true)
	parent.add_child(node)
	return node

func label(at: Vector3, words: String, color := Color("fff0c3"), font_size := 44) -> void:
	var sign := Label3D.new()
	sign.text = words
	sign.position = at
	sign.font_size = font_size
	sign.pixel_size = 0.012
	sign.modulate = color
	sign.outline_size = 7
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)

func road(center: Vector3, size: Vector3) -> void:
	var deck = highway.block(highway,center+Vector3(0,-0.3,0),size,Color("51515c"),true)
	deck.material_override = highway.art.material(Color("51515c"),false,true)
	var along_x := size.x>size.z
	var length: float = maxf(size.x,size.z)
	for i in int(length/8):
		var offset := (i+0.5)*8.0-length/2
		var pos := center+Vector3(offset,0.018,0) if along_x else center+Vector3(0,0.018,offset)
		if pos.distance_to(CROSSING)>12:
			highway.block(highway,pos,Vector3(3,0.025,0.12) if along_x else Vector3(0.12,0.025,3),Color("eec363"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if disabled_world:
		set_physics_process(false)
		return
	# A traversable plaza under the street grid allows off-lane driving too.
	var plaza: MeshInstance3D = highway.block(highway,Vector3(359,-0.48,-50),Vector3(194,0.9,240),Color("b8b29b"),true)
	# Collision is flush with asphalt; the visible slab is lower to avoid
	# coplanar flicker where its footprint overlaps the curved highway.
	var plaza_body := plaza.get_child(0) as StaticBody3D
	(plaza_body.get_child(0) as CollisionShape3D).position.y = 0.03
	road(Vector3(342,0,-75),Vector3(184,0.6,14))
	for x in [280,330,430]:
		road(Vector3(x,0,-50 if x!=280 else -47.5),Vector3(14,0.6,190 if x!=280 else 55))
	for z in [-145,-20,45]:
		road(Vector3(380 if z!=-20 else 355,0,z),Vector3(114 if z!=-20 else 164,0.6,14))
	# Local shops and courtyards give the district street scale and solid frontage.
	for z in [-112,12]:
		for x in [363,397]:
			highway.block(highway,Vector3(x,4,z),Vector3(24,8,25),Color("d9bd8f") if x==363 else Color("9eb7ba"),true)
			highway.block(highway,Vector3(x,8.25,z),Vector3(25,0.5,26),Color("31384a"))
			for face in [-1,1]:
				highway.block(highway,Vector3(x,2,z+face*12.6),Vector3(19,2.5,0.1),Color("345970"))
				highway.block(highway,Vector3(x,3.8,z+face*12.8),Vector3(23,0.35,0.65),Color("663c62"))
				for col in 5:
					var wx: float = x-9+col*4.5
					highway.block(highway,Vector3(wx,6,z+face*12.55),Vector3(2.5,2,0.1),Color("303f51"))
					highway.block(highway,Vector3(wx-0.2,6.3,z+face*12.62),Vector3(1.6,1.2,0.05),Color("719dab"))
				for col in 7:
					highway.block(highway,Vector3(x-9.8+col*3.25,2,z+face*12.7),Vector3(0.12,2.6,0.1),Color("d3cbb2"))
				highway.block(highway,Vector3(x,1.3,z+face*12.75),Vector3(1.7,2.6,0.12),Color("263848"))
			label(Vector3(x,5.5,z-13),"METRO MARKET" if x==363 else "CITY WORKS",Color("fff0c3"),28)
	for x in [320,440]:
		for z in [-130,-100,-45,10,55]:
			highway.block(highway,Vector3(x,3.8,z),Vector3(0.17,7.6,0.17),Color("303846"))
			highway.block(highway,Vector3(x,7.6,z),Vector3(1.5,0.2,0.5),Color("303846"))
			highway.block(highway,Vector3(x,7.48,z),Vector3(1.2,0.035,0.35),Color("fff0c3"))
	for x in [319,341,419,441]:
		for z in [-115,12]:
			highway.block(highway,Vector3(x,0.03,z),Vector3(1.5,0.1,36),Color("d2c6ac"))
	for i in 10:
		highway.block(highway,Vector3(292+i*3,0.018,27),Vector3(0.08,0.03,5.5),Color("f3ebd8"))
	for x in [304,449]:
		highway.block(highway,Vector3(x,0.015,-115),Vector3(13,0.05,26),Color("8f9d59"))
	for z in [-87,-63]:
		highway.block(highway,Vector3(330,0.025,z),Vector3(14,0.025,0.45),Color("f4eee0"))
	for x in [318,342]:
		highway.block(highway,Vector3(x,0.025,-75),Vector3(0.45,0.025,14),Color("f4eee0"))
	for i in 7:
		highway.block(highway,Vector3(321+i*2.7,0.03,-86),Vector3(1.1,0.03,3),Color("eee9d9"))
	make_signal(Vector3(339,0,-84),"NS",0)
	make_signal(Vector3(321,0,-66),"NS",PI)
	make_signal(Vector3(321,0,-84),"EW",PI/2)
	make_signal(Vector3(339,0,-66),"EW",-PI/2)
	highway.block(highway,Vector3(268,2.4,-45),Vector3(0.18,4.8,0.18),Color("303846"))
	highway.block(highway,Vector3(264,5,-45.15),Vector3(9,2.3,0.2),Color("253d49"))
	label(Vector3(264,5,-45),"LIVE CITY EXIT  >\nPUSH ORANGE BARRELS",Color("ffcc68"),35)
	label(Vector3(291,4.5,-83),"LIVE TRAFFIC\nSIGNAL AHEAD",Color("ffcc68"),38)
	label(Vector3(273,3,-65),"<  RETURN TO METRO LOOP",Color("fff0c3"),26)
	for i in 4:
		make_barrel(Vector3(260.5,0.6,-80.0+i*3.3))
	spawn_traffic()
	highway.consolidate_boxes()
	update_signals()

func make_barrel(at: Vector3) -> void:
	var barrel := RigidBody3D.new()
	barrel.mass = 38
	barrel.linear_damp = 0.7
	barrel.angular_damp = 0.6
	barrel.continuous_cd = true
	barrel.add_to_group("construction_barrel")
	add_child(barrel)
	barrel.position = at
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.57
	cylinder.height = 1.2
	shape.shape = cylinder
	barrel.add_child(shape)
	for part in [[0.0,1.1,0.55,Color("eb7629")],[-0.31,0.18,0.56,Color("fff0d4")],[0.25,0.18,0.56,Color("fff0d4")],[-0.55,0.12,0.68,Color("272d3a")]]:
		var mesh := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.height = part[1]
		tube.top_radius = part[2]
		tube.bottom_radius = part[2]
		tube.radial_segments = 12
		mesh.mesh = tube
		mesh.position.y = part[0]
		mesh.material_override = highway.art.material(part[3],true)
		barrel.add_child(mesh)
	barrels.append(barrel)

func make_signal(at: Vector3, axis: String, heading: float) -> void:
	var pole := Node3D.new()
	add_child(pole)
	pole.position = at
	pole.rotation.y = heading
	var solid:=StaticBody3D.new();var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new()
	cylinder.radius=.13;cylinder.height=5.2;shape.shape=cylinder;shape.position.y=2.6;solid.add_child(shape);pole.add_child(solid)
	mesh_box(pole,Vector3(0,2.6,0),Vector3(0.18,5.2,0.18),Color("303846"))
	mesh_box(pole,Vector3(0,4.4,-0.2),Vector3(0.65,1.8,0.4),Color("242a35"))
	for i in 3:
		var lens := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		lens.mesh = sphere
		lens.position = Vector3(0,4.94-i*0.54,-0.44)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens.material_override = mat
		pole.add_child(lens)
		lamps.append({"material":mat,"axis":axis,"state":["RED","AMBER","GREEN"][i]})

func spawn_traffic() -> void:
	var ns: Array[Vector3] = [Vector3(333,0,-142),Vector3(427,0,-142),Vector3(427,0,42),Vector3(333,0,42)]
	var ew: Array[Vector3] = [Vector3(283,0,-72),Vector3(427,0,-72),Vector3(427,0,-23),Vector3(283,0,-23)]
	var colors := [Color("b5414d"),Color("37839e"),Color("d5ae49"),Color("eee9d9"),Color("6f6295"),Color("577d60")]
	for i in 12:
		var car := Car.new()
		car.district = self
		car.route = ns.duplicate() if i<8 else ew.duplicate()
		car.cruise_speed = 8.0+float(i%3)
		if game.get("zen")==true:car.cruise_speed=minf(car.cruise_speed*.85,5.5)
		var edge := (i%8)/2 if i<8 else i%4
		var start: Vector3 = car.route[edge]
		var end: Vector3 = car.route[(edge+1)%4]
		car.position = start.lerp(end,0.22 if i%2==0 else 0.65)+Vector3(0,0.05,0)
		car.waypoint = (edge+1)%4
		car.rotation.y = atan2(-(end-start).x,-(end-start).z)
		add_child(car)
		build_car(car,colors[i%colors.size()],i)
		cars.append(car)

func build_car(car: RigidBody3D, color: Color, variant: int) -> void:
	mesh_box(car,Vector3(0,0.7,0),Vector3(1.9,0.7,4.2),color)
	mesh_box(car,Vector3(0,1.25,0.05),Vector3(1.65,0.75,2.05 if variant%3!=0 else 2.6),color)
	for z in [-1.0,1.1]:
		mesh_box(car,Vector3(0,1.3,z),Vector3(1.48,0.5,0.05),Color("335a71"))
	for side in [-1,1]:
		mesh_box(car,Vector3(side*0.84,1.3,0),Vector3(0.04,0.5,1.65),Color("335a71"))
		mesh_box(car,Vector3(side*0.67,0.75,-2.12),Vector3(0.35,0.22,0.04),Color("fff0c0"))
		var lamp = mesh_box(car,Vector3(side*0.67,0.75,2.12),Vector3(0.35,0.2,0.04),Color("ad3245"))
		var brake := StandardMaterial3D.new()
		brake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if not car.brake_material:
			car.brake_material = brake
		lamp.material_override = car.brake_material
		for z in [-1.35,1.35]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side*0.94,0.34,z)
			car.add_child(pivot)
			var wheel := MeshInstance3D.new()
			var tire := CylinderMesh.new()
			tire.top_radius = 0.34
			tire.bottom_radius = 0.34
			tire.height = 0.22
			tire.radial_segments = 12
			wheel.mesh = tire
			wheel.rotation.z = PI/2
			wheel.material_override = highway.art.material(Color("252b36"),true)
			pivot.add_child(wheel)
			car.wheel_nodes.append(pivot)
	mesh_box(car,Vector3(0,0.48,-2.15),Vector3(1.95,0.16,0.12),Color("303746"))
	mesh_box(car,Vector3(0,0.48,2.15),Vector3(1.95,0.16,0.12),Color("303746"))
	mesh_box(car,Vector3(0,0.8,-2.16),Vector3(0.6,0.2,0.03),Color("303746"))
	mesh_box(car,Vector3(0,0.64,2.23),Vector3(0.42,0.16,0.03),Color("ece6cd"))
	for side in [-1,1]:
		mesh_box(car,Vector3(side*0.98,0.62,0),Vector3(0.04,0.1,2.3),Color("303746"))
		mesh_box(car,Vector3(side*0.87,1.12,0),Vector3(0.05,0.06,0.3),Color("d2d6cd"))
		mesh_box(car,Vector3(side*1.04,1.13,-0.72),Vector3(0.22,0.13,0.26),color)
	# One vertex-colored body preserves every panel color while avoiding a
	# separate body/ink submission for each paint, glass and trim material.
	# Wheel vertices carry axle data for the same roll/steer transform in both
	# color and ink passes. The physical car and live brake lights stay separate.
	var groups: Dictionary = {}
	for child in car.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.material_override
			var key:String="brakes" if mat==car.brake_material else "body"
			if not groups.has(key):groups[key]=[]
			groups[key].append(child)
	for pivot in car.wheel_nodes:
		for wheel in pivot.get_children():
			if not wheel is MeshInstance3D:continue
			wheel.set_meta("merge_transform",pivot.transform*wheel.transform)
			wheel.set_meta("axle",Vector2(pivot.position.x,pivot.position.z))
			wheel.set_meta("kind",1.0 if pivot.position.z<0 else 2.0)
			groups.body.append(wheel)
	for key in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for panel in groups[key]:
			var tone:Color=Color.WHITE if key=="brakes" else panel.material_override.get_shader_parameter("base_color")
			var pose:Transform3D=panel.get_meta("merge_transform",panel.transform)
			var arrays:Array=panel.mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for step in indices.size() if not indices.is_empty() else vertices.size():
				var index:int=indices[step] if not indices.is_empty() else step
				surface.set_color(tone)
				surface.set_uv(panel.get_meta("axle",Vector2.ZERO))
				surface.set_uv2(Vector2(panel.get_meta("kind",0.0),.34))
				surface.set_normal((pose.basis*normals[index]).normalized())
				surface.add_vertex(pose*vertices[index])
			panel.queue_free()
		var merged := MeshInstance3D.new()
		merged.mesh = surface.commit()
		if key=="brakes":merged.material_override=car.brake_material
		else:
			var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/traffic_toon.gdshader")
			material.set_shader_parameter("use_vertex_color",true)
			var ink:=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/traffic_ink.gdshader")
			material.next_pass=ink;car.visual_material=material
			highway.art.cache["traffic_"+str(car.get_instance_id())]=material
			merged.material_override=material
			merged.extra_cull_margin=.4
		car.add_child(merged)

func update_signals() -> void:
	# An entry call serves the player's east-west approach first, then cycles.
	var t := fmod(maxf(0,phase_time-3.0),28.0)
	ew_light = "GREEN" if t<10 else ("AMBER" if t<12 else "RED")
	ns_light = "GREEN" if t>=13 and t<25 else ("AMBER" if t>=25 and t<27 else "RED")
	if not entered:
		ew_light = "RED"
		ns_light = "GREEN"
	elif phase_time<3:
		ew_light = "RED"
		ns_light = "AMBER" if phase_time<2 else "RED"
	for lamp in lamps:
		var state: String = ns_light if lamp.axis=="NS" else ew_light
		var color: Color = {"RED":Color("ff4e42"),"AMBER":Color("ffc844"),"GREEN":Color("68e48b")}[lamp.state]
		lamp.material.albedo_color = color if state==lamp.state else color.darkened(0.86)

func signal_speed_limit(car: RigidBody3D) -> float:
	var forward := -car.global_basis.z
	var gap := CROSSING-car.global_position
	gap.y = 0
	var along := gap.dot(forward)
	var lateral := absf(gap.dot(car.global_basis.x))
	var state := ns_light if absf(forward.z)>absf(forward.x) else ew_light
	if state!="GREEN" and lateral<5 and along>8 and along<42:
		return calm_speed_limit(car,sqrt(maxf(0,2.0*3.5*(along-11))))
	return calm_speed_limit(car,100.0)

func calm_speed_limit(car:RigidBody3D,limit:float) -> float:
	if game.get("zen")!=true:return limit
	# Keep the same physical cars and routes, with room to follow and yield.
	# This only lowers the existing light/obstacle limit; it never moves a car.
	limit=minf(limit,car.cruise_speed)
	car.horn_cooldown=maxf(car.horn_cooldown,1.0)
	for other in cars:
		if other==car or not is_instance_valid(other):continue
		limit=calm_following_limit(car,other.global_position,other.body_width,other.body_length,limit)
	limit=calm_following_limit(car,game.van.global_position,2.5,5.6,limit)
	var life:Node=game.get("city_life")
	if is_instance_valid(life):
		for citizen in life.citizens:
			if citizen.simulation_active:limit=calm_following_limit(car,citizen.global_position,.7,.7,limit)
	var cargo:Node=game.get("cargo")
	if is_instance_valid(cargo) and cargo.on_foot:limit=calm_following_limit(car,cargo.actor.global_position,.7,.7,limit)
	return limit

func calm_following_limit(car:RigidBody3D,at:Vector3,width:float,length:float,limit:float) -> float:
	var gap:=at-car.global_position
	if absf(gap.y)>2.5 or gap.length_squared()>45*45:return limit
	var along:float=gap.dot(-car.global_basis.z)
	var corridor:float=(car.body_width+width)*.5+.35
	if along<=0 or absf(gap.dot(car.global_basis.x))>corridor:return limit
	var clearance:float=along-(car.body_length+length)*.5
	# At cruising speed, maintain about 1.4 seconds plus a 3 m clear gap.
	return minf(limit,maxf(0,clearance-3.0)/1.4)

func in_city(pos: Vector3) -> bool:
	return not disabled_world and pos.x>270 and pos.x<456 and pos.z>-170 and pos.z<70

func _physics_process(delta: float) -> void:
	var active: bool = game.van.active
	if active!=running:
		running = active
		for car in cars:
			car.freeze = not active
			if not active:
				car.horn_player.stop()
				car.impact_player.stop()
		for barrel in barrels:
			barrel.freeze = not active
	if not active:
		return
	if not entered and game.van.position.x>267 and absf(game.van.position.z+75)<9:
		entered = true
		phase_time = 0
		game.van.notify_driver("LIVE CITY - signal triggered; traffic is interactive")
	if entered:
		phase_time += delta
	update_signals()
	var gap: Vector3 = game.van.position-CROSSING
	var inside := absf(gap.x)<7 and absf(gap.z)<7
	if inside and not truck_in_crossing:
		var forward: Vector3 = -game.van.global_basis.z
		var state := ns_light if absf(forward.z)>absf(forward.x) else ew_light
		if state=="RED":
			red_light_runs += 1
			game.van.notify_driver("RED LIGHT - cross traffic has right of way")
	truck_in_crossing = inside

func shutdown() -> void:
	set_physics_process(false)
	for car in cars:
		car.set_physics_process(false)
		car.horn_player.stop()
		car.impact_player.stop()
		car.horn_player.stream = null
		car.impact_player.stream = null
