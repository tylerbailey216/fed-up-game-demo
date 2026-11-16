extends RefCounted

func frames(game: Node,count: int) -> void:
	for i in count:await game.get_tree().physics_frame

func inside_normal(world: Node3D,section: Dictionary) -> Vector3:
	var pos:Vector3=section.frame.origin
	var side:Vector3=section.frame.basis.x
	return side if world.nearest_road(pos+side*3).distance<world.nearest_road(pos-side*3).distance else -side

func find_section(world: Node3D,kind: String) -> Dictionary:
	for section in world.barriers.sections:
		if section.kind!=kind or section.size.z<6:continue
		var at:Vector3=section.frame.origin
		if absf(at.x)>850 or absf(at.z)>950:continue
		if kind=="steel" and at.y>0.1:continue
		if kind=="concrete" and at.y<7:continue
		var normal:=inside_normal(world,section)
		var start:=at+normal*6+Vector3.UP*0.15
		var van:Node=world.get_parent().van
		if world.has_road_near(start) and van.recovery_space_clear(start,atan2(normal.x,normal.z)):
			return section
	assert(false,"Suitable barrier test section")
	return {}

func approach(game: Node,section: Dictionary,speed: float) -> Vector3:
	var normal:=inside_normal(game.highway,section)
	game.van.new_truck()
	await frames(game,2)
	game.van.position=section.frame.origin+normal*6+Vector3.UP*0.15
	game.van.rotation.y=atan2(normal.x,normal.z)
	await frames(game,24)
	game.van.speed=speed
	game.van.planar_velocity=-normal*speed
	return normal

func run(game: Node) -> void:
	var world:Node3D=game.highway
	var manager:Node3D=world.barriers
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/independence_safety.json"))
	assert(data.minimum_clearance>=5,"Grade-separated crossings clear truck and deck")
	var count:=0
	for i in range(0,manager.sections.size(),7):
		var section:Dictionary=manager.sections[i]
		var p:Vector3=section.body.position
		var side:Vector3=section.frame.basis.x
		var query:=PhysicsRayQueryParameters3D.create(p-side,p+side)
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty() and hit.collider.has_meta("barrier_kind"),"Visible edge rail has solid collision")
		count+=1
	var steel:=find_section(world,"steel")
	var concrete:=find_section(world,"concrete")
	for section in [steel,concrete]:
		for speed in [4.0,12.0,20.0]:
			var normal:=await approach(game,section,speed)
			var before:int=manager.breaks
			await frames(game,180)
			var inside:float=(game.van.position-section.frame.origin).dot(normal)
			print("CONTAINMENT ",section.kind," speed=",speed," inside=",inside," y=",game.van.position.y)
			assert(not game.van.overturned,"Moderate barrier hit must not force a crash animation")
			assert(manager.breaks==before,"Moderate hit must not break guardrail")
			assert(inside>0.8,"Truck stays on protected road side")
			assert(absf(game.van.position.y-section.frame.origin.y)<0.4,"Impact remains on same deck")
		var normal:=await approach(game,section,18)
		game.van.planar_velocity=(-normal*0.35+section.frame.basis.z*sqrt(1-0.35*0.35))*18
		var forward:Vector3=game.van.planar_velocity.normalized()
		game.van.rotation.y=atan2(-forward.x,-forward.z)
		await frames(game,180)
		assert(not game.van.overturned and manager.breaks==0,"Glancing moderate impact stays contained")
		assert(absf(game.van.position.y-section.frame.origin.y)<0.5,"Sliding along barrier does not drop to lower road")
	if "--safety-capture" in OS.get_cmdline_user_args():
		await capture(game,concrete,"motorway-guardrails.png",false)
	var normal:=await approach(game,steel,34)
	var before:int=manager.breaks
	for i in 120:
		await frames(game,1)
		if game.van.overturned:break
	assert(game.van.overturned,"Severe impact transfers to physical truck")
	assert(manager.breaks>before,"Sufficient normal impact energy releases steel rail")
	assert(steel.energy_after<=steel.energy_before-450000+1,"Truck plus debris rotation dissipates anchor-yield energy")
	assert(game.van.roll_body.linear_velocity.length()<34.1,"Breakaway does not add truck energy")
	assert(game.van.roll_body.linear_velocity.y<=0.1,"No artificial upward launch")
	await frames(game,100)
	var crossed:float=(game.van.position-steel.frame.origin).dot(normal)
	print("HIGH ENERGY STEEL breaks=",manager.breaks-before," position_side=",crossed," flipped=",game.van.flip_count)
	assert(crossed< -1,"Truck can physically pass yielded guardrail")
	if "--safety-capture" in OS.get_cmdline_user_args():
		await capture(game,steel,"guardrail-breach.png",true)
	await approach(game,concrete,34)
	before=manager.breaks
	for i in 120:
		await frames(game,1)
		if game.van.overturned:break
	assert(game.van.overturned,"Severe concrete hit transfers to physical contact solver")
	assert(manager.breaks==before,"Concrete parapet does not disappear at speed")
	assert(game.van.wall_ride_time==0,"Mapped motorway has no wall-climb boost")
	# Recovery must use the current bridge surface instead of hard-coded ground Y.
	game.van.new_truck()
	await frames(game,2)
	var bridge_point:=Vector3.ZERO
	for road in world.map_data.roads:
		if road.bridge and road.ref=="I 480":
			bridge_point=world.road_points[road.nodes[road.nodes.size()/2]]
			break
	game.van.position=bridge_point+Vector3.UP*0.15
	game.van.velocity=Vector3.ZERO
	game.van.planar_velocity=Vector3.ZERO
	game.van.wall_normal=Vector3.ZERO
	game.van.begin_rollover(30,25,1,true)
	await frames(game,3)
	game.van.roll_body.freeze=true
	game.van.roll_settled=true
	assert(game.van.recover_upright())
	assert(absf(game.van.position.y-bridge_point.y)<0.5,"Recovery stays on bridge deck")
	print("ROAD SAFETY PASS: %d barrier rays, six normal and two glancing moderate impacts, energy-limited breach, physical concrete impact, elevated recovery, %d audited crossings" % [count,data.crossings.size()])

func capture(game: Node,section: Dictionary,filename: String,breach: bool) -> void:
	var normal:=inside_normal(game.highway,section)
	var origin:Vector3=section.frame.origin
	if not breach:origin=game.van.position
	game.van.camera_manual=true
	game.van.camera.global_position=origin+normal*18+section.frame.basis.z*15+Vector3.UP*9
	game.van.camera.look_at(origin-normal*(12 if breach else 0)+Vector3.UP*1.5)
	await game.get_tree().create_timer(0.3).timeout
	game.get_viewport().get_texture().get_image().save_png("res://docs/"+filename)
	game.van.camera_manual=false
