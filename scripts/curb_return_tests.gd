extends Node
## Drive both ways over the shipping sidewalks, including a stopped grass return.
## A raycast alone cannot prove that the truck can cross a surface boundary.
var failures:Array[String]=[]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("CURB RETURN TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func release_controls() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake"]:Input.action_release(action)

func point_input(direction:Vector3,strength:float) -> void:
	var input:=Vector2(direction.x,direction.z).normalized()*strength
	for pair in [["steer_left",-input.x],["steer_right",input.x],["accelerate",-input.y],["brake_reverse",input.y]]:
		if pair[1]>.001:Input.action_press(pair[0],pair[1])
		else:Input.action_release(pair[0])

func diagnose(van:Node,target:Vector3,stalled:int) -> void:
	var contacts:Array[Dictionary]=[]
	for i in van.get_slide_collision_count():
		var contact:KinematicCollision3D=van.get_slide_collision(i)
		var hits:Array[Dictionary]=[]
		for j in contact.get_collision_count():
			var collider:Object=contact.get_collider(j)
			hits.append({"normal":contact.get_normal(j),"position":contact.get_position(j),"collider":str(collider),"shape":contact.get_collider_shape(j),"local_shape":contact.get_local_shape(j),"surface":collider.get_meta("surface_kind","") if collider else "","terrain":collider.get_meta("terrain_kind","") if collider else ""})
		contacts.append({"travel":contact.get_travel(),"remainder":contact.get_remainder(),"hits":hits})
	var supports:Array[Dictionary]=[]
	var space:PhysicsDirectSpaceState3D=van.get_world_3d().direct_space_state
	for x in [-1.0,0.0,1.0]:
		for z in [-2.65,0.0,2.65]:
			var at:Vector3=van.to_global(Vector3(x,0,z))
			var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1);ray.exclude=[van.get_rid()]
			var hit:=space.intersect_ray(ray)
			supports.append({"local":Vector2(x,z),"position":hit.get("position"),"normal":hit.get("normal"),"kind":preload("res://scripts/terrain_surface.gd").kind(van,hit)})
	print("CURB STALL ticks=",stalled," target=",target," at=",van.position," heading=",van.rotation.y," forward=",-van.global_basis.z," speed=",van.speed," velocity=",van.velocity," planar=",van.planar_velocity," input=",Input.get_vector("steer_left","steer_right","accelerate","brake_reverse",.12)," floor=",van.is_on_floor()," wall=",van.is_on_wall()," floor_normal=",van.get_floor_normal()," solver_wall_normal=",van.get_wall_normal()," last_motion=",van.get_last_motion()," wall_timer=",van.wall_timer," contacts=",contacts," supports=",supports)

func drive_to(van:Node,target:Vector3,strength:float) -> bool:
	var best:=INF;var stalled:=0
	var crashes:int=van.crash_serial
	var verbose:bool="--curb-diagnostics" in OS.get_cmdline_user_args()
	for i in 1000:
		var remaining:=Vector3(target.x-van.position.x,0,target.z-van.position.z)
		if remaining.length()<.6:
			release_controls();await frames(65)
			return true
		if remaining.length()<best-.1:best=remaining.length();stalled=0
		else:stalled+=1
		if stalled==181 or (verbose and stalled in [30,90]):diagnose(van,target,stalled)
		if stalled>180:break
		point_input(remaining,strength)
		await frames(1)
		if van.crash_serial!=crashes:
			crashes=van.crash_serial;diagnose(van,target,-1)
		if van.overturned or van.wrecked or van.driver_on_foot:break
	release_controls();await frames(65)
	return false

func shot(game:Node,name:String,captures:bool) -> void:
	if not captures or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://tools/curb-return-"+name+".png")

func simulator_to(van:Node,origin:Vector3,axis:Vector3,target:float,reverse:bool) -> bool:
	var best:=INF;var stalled:=0;var crashes:int=van.crash_serial
	for i in 900:
		var distance:float=(van.position-origin).dot(axis)
		if (distance<=target+.4 if reverse else distance>=target-.4):
			release_controls();Input.action_press("handbrake");await frames(50);release_controls();await frames(15)
			return true
		var remaining:=absf(distance-target)
		if remaining<best-.1:best=remaining;stalled=0
		else:stalled+=1
		if stalled>180:diagnose(van,origin+axis*target,stalled);break
		Input.action_press("brake_reverse" if reverse else "accelerate",1.0 if reverse else .6)
		await frames(1)
		if van.crash_serial!=crashes:crashes=van.crash_serial;diagnose(van,origin+axis*target,-1)
		if van.overturned or van.wrecked or van.driver_on_foot:break
	release_controls();return false

func run_city(game:Node,captures:=false) -> Array[String]:
	check(not game.arcade and not game.outerbelt,"City curb checks use the actual City Streets simulator world")
	if game.arcade or game.outerbelt:return failures
	game.start_drive();release_controls();await frames(25)
	var van:Node=game.van
	var traffic_mode:int=game.traffic.process_mode;var life_mode:int=game.city_life.process_mode
	game.traffic.process_mode=Node.PROCESS_MODE_DISABLED;game.city_life.process_mode=Node.PROCESS_MODE_DISABLED
	var frozen:Array[bool]=[];var citizen_physics:Array[bool]=[]
	for car in game.traffic.cars:frozen.append(car.freeze);car.freeze=true
	for citizen in game.city_life.citizens:citizen_physics.append(citizen.is_physics_processing());citizen.set_physics_process(false)
	var start:=Vector3(250,0,-75);var direction:Vector3=(game.highway.entry-start).normalized()
	var side:=Vector3(-direction.z,0,direction.x);var road:Vector3=start.lerp(game.highway.entry,.16)
	van.new_truck();van.position=road+Vector3.UP*.15;van.rotation.y=atan2(-side.x,-side.z);await frames(30)
	var crashes:int=van.crash_serial;var resets:int=van.reset_count;var recoveries:int=van.offroad_recoveries
	var bumps:int=van.surface_bump_serial;var launches:int=van.stunts.launch_serial;var damage:float=game.cargo.damage
	check(await simulator_to(van,road,side,14.0,false),"City simulator gas drives over the actual sidewalk onto grass")
	check(absf(van.speed)<.05 and van.planar_velocity.length()<.05,"City truck stops on grass before using true reverse")
	var grass_wheels:=0
	for contact in van.surface_sampler.wheel_contacts:
		if not contact.is_empty() and contact.kind=="grass":grass_wheels+=1
	check(grass_wheels==4,"City grass return starts with all four wheels supported on grass")
	await shot(game,"city-grass",captures)
	check(await simulator_to(van,road,side,0.0,true),"City simulator true reverse returns over the same sidewalk without finding a gap")
	var asphalt_wheels:=0
	for contact in van.surface_sampler.wheel_contacts:
		if not contact.is_empty() and contact.kind=="asphalt":asphalt_wheels+=1
	check(asphalt_wheels==4 and van.is_on_floor() and absf(van.position.y)<.03,"City return finishes on the original asphalt road")
	check(van.surface_bump_serial>bumps and van.stunts.launch_serial==launches,"City moderate-speed curb retains suspension feedback without a stunt launch")
	check(van.crash_serial==crashes and game.cargo.damage==damage and not van.overturned,"City sidewalk crossing causes no false crash or damage")
	check(van.reset_count==resets and van.offroad_recoveries==recoveries,"City return uses physical driving without reset or road recovery")
	print("CITY CURB RETURN position=",van.position," bumps=",van.surface_bump_serial-bumps," crashes=",van.crash_serial-crashes)
	await shot(game,"city-road",captures)
	release_controls();van.new_truck()
	for i in game.traffic.cars.size():game.traffic.cars[i].freeze=frozen[i]
	for i in game.city_life.citizens.size():game.city_life.citizens[i].set_physics_process(citizen_physics[i])
	game.traffic.process_mode=traffic_mode;game.city_life.process_mode=life_mode
	return failures

func run(game:Node,captures:=false) -> Array[String]:
	check(game.arcade,"Curb return checks run in the shipping Delivery Mayhem world")
	if not game.arcade:return failures
	game.start_drive();release_controls();await frames(25)
	var van:Node=game.van
	var traffic_mode:int=game.traffic.process_mode;var citizen_mode:int=game.city_life.process_mode
	game.traffic.process_mode=Node.PROCESS_MODE_DISABLED;game.city_life.process_mode=Node.PROCESS_MODE_DISABLED
	var frozen:Array[bool]=[]
	for car in game.traffic.cars:frozen.append(car.freeze);car.freeze=true
	var citizen_physics:Array[bool]=[]
	for citizen in game.city_life.citizens:citizen_physics.append(citizen.is_physics_processing());citizen.set_physics_process(false)
	# The renderer intentionally leaves grass 5 cm below asphalt. Support must
	# meet the bevel toe; an exposed low lip is still a wall to a flat hull.
	var space:PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	var exclude:Array[RID]=[van.get_rid()]
	for car in game.traffic.cars:exclude.append(car.get_rid())
	for sample in [[Vector3(-46,0,25),"asphalt",0.0],[Vector3(-54.5,0,25),"sidewalk",.16],[Vector3(-62,0,25),"grass",0.0]]:
		var ray:=PhysicsRayQueryParameters3D.create(sample[0]+Vector3.UP,sample[0]-Vector3.UP,1);ray.exclude=exclude
		var hit:=space.intersect_ray(ray)
		check(not hit.is_empty(),"Shipping "+sample[1]+" has physical support")
		if hit.is_empty():continue
		check(absf(hit.position.y-float(sample[2]))<.008,"Shipping "+sample[1]+" support meets its intended elevation")
		check(preload("res://scripts/terrain_surface.gd").kind(van,hit)==sample[1],"Surface identities remain distinct at the curb")
	# These actual roads have clear grass beyond the sidewalk and no crossing
	# driveway gaps. Both screen axes and an oblique approach must work.
	var cases:Array[Dictionary]=[
		{"name":"west-low","road":Vector3(-46,0,25),"grass":Vector3(-62,0,25),"strength":.30},
		{"name":"west-moderate-65","road":Vector3(-47,0,25),"grass":Vector3(-62,0,25),"strength":.65,"settle":18},
		{"name":"west-moderate-70","road":Vector3(-46.7,0,25),"grass":Vector3(-62,0,25),"strength":.70,"settle":37},
		{"name":"west-digital","road":Vector3(-47,0,25),"grass":Vector3(-61.5,0,25),"strength":1.0,"settle":29},
		{"name":"east-moderate","road":Vector3(46,0,-18),"grass":Vector3(62,0,-18),"strength":.70},
		{"name":"north-low","road":Vector3(0,0,-51.5),"grass":Vector3(0,0,-67.5),"strength":.30},
		{"name":"west-diagonal","road":Vector3(-46,0,25),"grass":Vector3(-62,0,21),"strength":.70}
	]
	for item in cases:
		release_controls();van.new_truck();van.position=item.road+Vector3.UP*.15
		var heading:Vector3=(item.grass-item.road).normalized();van.rotation.y=atan2(-heading.x,-heading.z)
		await frames(int(item.get("settle",25)))
		var resets:int=van.reset_count;var recoveries:int=van.offroad_recoveries
		var crashes:int=van.crash_serial;var launches:int=van.stunts.launch_serial;var bumps:int=van.surface_bump_serial
		var damage:float=game.cargo.damage
		var spray:int=game.terrain_particles.emitted
		check(await drive_to(van,item.grass,item.strength),item.name+": road -> sidewalk -> grass completes with directional input")
		check(van.speed<.05 and van.planar_velocity.length()<.05,item.name+": truck stops on grass before the return")
		var grass_wheels:=0
		for contact in van.surface_sampler.wheel_contacts:
			if not contact.is_empty() and contact.kind=="grass":grass_wheels+=1
		check(grass_wheels==4 and game.terrain_particles.emitted>spray,item.name+": supported grass tires retain grass/dirt spray")
		await shot(game,item.name+"-grass",captures)
		check(await drive_to(van,item.road,item.strength),item.name+": stopped grass -> sidewalk -> same road completes without a gap")
		check(van.is_on_floor() and absf(van.position.y)<.03,item.name+": truck finishes supported on the road")
		var road_wheels:=0
		for contact in van.surface_sampler.wheel_contacts:
			if not contact.is_empty() and contact.kind=="asphalt":road_wheels+=1
		check(road_wheels==4,item.name+": road tires stay asphalt despite the aligned grass support below")
		check(van.surface_bump_serial>bumps,item.name+": sidewalk retains suspension feedback")
		check(van.stunts.launch_serial==launches and not van.overturned,item.name+": low/moderate crossing remains grounded")
		check(van.crash_serial==crashes and game.cargo.damage==damage,item.name+": ordinary curb crossings do not become crashes or lose energy")
		check(van.reset_count==resets and van.offroad_recoveries==recoveries,item.name+": return uses continuous driving without recovery/reset")
		print("CURB RETURN ",item.name," position=",van.position," bumps=",van.surface_bump_serial-bumps," crashes=",van.crash_serial-crashes)
		await shot(game,item.name+"-road",captures)
	# Correcting grass support must not make raised solid objects passable.
	# This is the original west face of the northeast building, not a fixture.
	release_controls();van.new_truck();van.position=Vector3(0,.15,-27);van.rotation.y=-PI/2;await frames(25)
	var solid_start:Vector3=van.position
	var solid_recoveries:int=van.offroad_recoveries
	point_input(Vector3.RIGHT,.30);await frames(460);release_controls();await frames(65)
	check(van.position.x>solid_start.x+5 and van.position.x<14.5,"The same input crosses a sidewalk but cannot pass the original solid building footprint")
	check(not van.overturned and van.offroad_recoveries==solid_recoveries,"Low-speed solid-object contact does not need a recovery bypass")
	release_controls();van.new_truck()
	for i in game.traffic.cars.size():game.traffic.cars[i].freeze=frozen[i]
	for i in game.city_life.citizens.size():game.city_life.citizens[i].set_physics_process(citizen_physics[i])
	game.traffic.process_mode=traffic_mode;game.city_life.process_mode=citizen_mode
	await frames(3)
	return failures
