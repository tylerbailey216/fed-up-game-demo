extends Node
## Real inputs drive the complete perimeter route; no lap checkpoint teleports.
var failures:Array[String]=[]
const ACTIONS=["steer_left","steer_right","accelerate","brake_reverse"]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("ARCADE DRIVING TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func release() -> void:
	for action in ACTIONS:Input.action_release(action)
	Input.action_release("handbrake")

func point_stick(direction:Vector2) -> void:
	var values:Array[float]=[maxf(0,-direction.x),maxf(0,direction.x),maxf(0,-direction.y),maxf(0,direction.y)]
	for i in ACTIONS.size():
		if values[i]>.01:Input.action_press(ACTIONS[i],values[i])
		else:Input.action_release(ACTIONS[i])

func prepare(game:Node,at:=Vector3(0,.15,0),heading:=0.0) -> void:
	release();game.van.new_truck();game.van.position=at;game.van.rotation=Vector3(0,heading,0)
	game.van.active=true;game.van.parking_brake=false;game.van.engine_on=true
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	game.van.surface_sampler.previous.clear();game.fixed_camera.update_camera(0)
	await frames(15)

func run(game:Node,captures:=false) -> Array[String]:
	var cargo:Node=game.cargo;var population:Array[Dictionary]=[]
	var traffic_active:bool=game.traffic.is_physics_processing();var life_active:bool=game.city_life.is_physics_processing();var cargo_active:bool=cargo.is_physics_processing()
	game.touch_controls.release_inputs();game.traffic.set_physics_process(false);game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		population.append({"node":car,"physics":car.is_physics_processing(),"layer":car.collision_layer,"mask":car.collision_mask,"freeze":car.freeze})
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0;car.collision_mask=0
	for citizen in game.city_life.citizens:
		population.append({"node":citizen,"physics":citizen.is_physics_processing(),"layer":citizen.collision_layer,"mask":citizen.collision_mask})
		citizen.set_physics_process(false);citizen.collision_layer=0;citizen.collision_mask=0
	cargo.set_physics_process(false)
	check(absf(sin(preload("res://scripts/fixed_arcade_camera.gd").BEARING))<.001,"Camera bearing aligns screen directions with the street grid")
	await check_directions(game)
	await check_uturn(game)
	await check_refuel(game)
	await check_legacy_branch(game)
	cargo.set_physics_process(true)
	await drive_lap(game,captures)
	# Replay is the normal reset following a successful lap. On failure, force
	# only cleanup so independent cargo checks still run and report their errors.
	if not cargo.complete:cargo.complete=true
	cargo.next_stage();release();await frames(12)
	cargo.set_physics_process(cargo_active);game.traffic.set_physics_process(traffic_active);game.city_life.set_physics_process(life_active)
	for item in population:
		item.node.set_physics_process(item.physics);item.node.collision_layer=item.layer;item.node.collision_mask=item.mask
		if item.has("freeze"):item.node.freeze=item.freeze
	print("ARCADE DRIVING TEST PASS" if failures.is_empty() else "ARCADE DRIVING TEST FAIL: "+str(failures))
	return failures

func check_directions(game:Node) -> void:
	for wish in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2(1,-1).normalized(),Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(-1,-1).normalized()]:
		await prepare(game)
		var start:Vector3=game.van.position
		point_stick(wish);await frames(120)
		var travel:Vector3=game.van.position-start
		var ground:=Vector2(travel.x,travel.z)
		var forward:Vector3=-game.van.global_basis.z
		check(ground.length()>3 and ground.normalized().dot(wish)>.8,"Directional input autoaccelerates toward screen %s / actual=%s" % [wish,ground])
		check(Vector2(forward.x,forward.z).dot(wish)>.85 and game.van.speed>=0,"Truck faces the requested direction without signed reverse: "+str(wish))
		check(game.van.speed<=10.5,"Arcade speed remains bounded")
		var stop_at:Vector3=game.van.position;var brake_speed:float=game.van.speed;release()
		if wish==Vector2.UP:
			var peak_squeal:=0.0
			for frame in 90:await frames(1);peak_squeal=maxf(peak_squeal,game.van.tire_squeal)
			check(brake_speed>8 and peak_squeal>.12,"A full-speed straight release retains hard-stop tire/audio feedback / speed=%.2f squeal=%.3f" % [brake_speed,peak_squeal])
		else:await frames(90)
		check(absf(game.van.speed)<.15 and game.van.planar_velocity.length()<.25 and game.van.position.distance_to(stop_at)<6,"Releasing direction brakes promptly instead of coasting: "+str(wish))

func check_uturn(game:Node) -> void:
	await prepare(game,Vector3(0,.15,24))
	point_stick(Vector2.UP);await frames(65)
	var turn_at:Vector3=game.van.position;var minimum_speed:=INF
	point_stick(Vector2.DOWN)
	for i in 180:
		await frames(1);minimum_speed=minf(minimum_speed,game.van.speed)
	var forward:Vector3=-game.van.global_basis.z
	check(minimum_speed>=-.05 and forward.z>.8 and game.van.position.z>turn_at.z+3,"Opposite input performs a forward U-turn and travels the requested way")
	release();await frames(90)

func check_refuel(game:Node) -> void:
	await prepare(game)
	game.van.fuel_gallons=0;game.van.engine_on=false
	point_stick(Vector2.UP);await frames(20);release()
	check(game.van.speed<.1,"An empty tank cannot power directional driving")
	check(game.van.refuel() and game.van.engine_on,"Arcade refueling restarts an available truck without a hidden ignition action")
	var start:Vector3=game.van.position;point_stick(Vector2.UP);await frames(65);release()
	check(game.van.speed>2 and game.van.position.z<start.z-2,"Directional controls move the serviced truck without toggling ignition")
	await frames(90)

func check_legacy_branch(game:Node) -> void:
	# Use the real vehicle branch on the same safe ground, without creating a
	# second game/map instance. The world flag is restored before route driving.
	game.highway.is_arcade=false
	await prepare(game)
	var start:Vector3=game.van.position
	point_stick(Vector2.RIGHT);await frames(65);release()
	check(absf(game.van.speed)<.1 and game.van.position.distance_to(start)<.3,"Exploration steering alone does not autoaccelerate")
	point_stick(Vector2.UP);await frames(90);release();await frames(60)
	check(game.van.speed>1.5 and game.van.position.z<start.z-3,"Exploration keeps heading-based gas and simulator coasting")
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
	start=game.van.position;point_stick(Vector2.DOWN);await frames(120);release()
	check(game.van.speed< -1 and game.van.position.z>start.z+1,"Exploration retains actual reverse rather than arcade U-turns")
	game.highway.is_arcade=true

func drive_lap(game:Node,captures:bool) -> void:
	var van:Node=game.van;var cargo:Node=game.cargo;var route:Node=cargo.arcade_run
	cargo.set_physics_process(false)
	await prepare(game,game.highway.spawn_position,game.highway.spawn_heading)
	cargo.damage=0;cargo.collision_count=0;cargo.seen_collision=van.crash_serial;route.reset();cargo.set_physics_process(true)
	var corners:Array[Vector3]=[Vector3(46,0,51.5),Vector3(46,0,-51.5),Vector3(-46,0,-51.5),Vector3(-46,0,51.5)]
	var waypoints:Array[Vector3]=corners.duplicate();waypoints.append(cargo.checkpoint_position)
	var visited:Array[bool]=[false,false,false,false]
	var longest_gap:=0.0;var actual_distance:=0.0;var previous:Vector3=van.position
	var crash_at:int=van.crash_serial;var recovery_at:int=van.offroad_recoveries;var reset_at:int=van.reset_count
	for index in waypoints.size():
		var target:Vector3=waypoints[index];var arrived:=false
		for frame in 1200:
			# Ground bearing remains valid even when a distant junction is behind
			# the camera, where perspective projection would reverse its direction.
			# No position, heading, speed or route state is set during this lap.
			var delta:Vector3=target-van.position
			var local:Vector3=Basis(Vector3.UP,preload("res://scripts/fixed_arcade_camera.gd").BEARING).inverse()*Vector3(delta.x,0,delta.z)
			point_stick(Vector2(local.x,local.z).normalized())
			if frame%300==0:print("ARCADE LAP approach ",index+1," at=",van.position," heading=",van.rotation.y," error=",wrapf(atan2(-delta.x,-delta.z)-van.rotation.y,-PI,PI))
			await frames(1)
			actual_distance+=van.position.distance_to(previous);previous=van.position
			longest_gap=maxf(longest_gap,float(game.highway.nearest_road(van.position).distance))
			for corner in corners.size():
				if Vector2(van.position.x-corners[corner].x,van.position.z-corners[corner].z).length()<10:visited[corner]=true
			if van.wrecked or van.overturned or cargo.on_foot:break
			var radius:float=2.0 if index==waypoints.size()-1 else 7.0
			if Vector2(van.position.x-target.x,van.position.z-target.z).length()<radius:arrived=true;break
		check(arrived,"Actual input reaches perimeter junction %d / at=%s target=%s speed=%.2f" % [index+1,van.position,target,van.speed])
		print("ARCADE LAP junction ",index+1," arrived=",arrived," at=",van.position," heading=",van.rotation.y," road_gap=",longest_gap," route=",route.route_index)
		if not arrived:break
	release()
	check(visited.all(func(value):return value),"One uninterrupted lap passes all four perimeter intersections")
	check(actual_distance>350 and longest_gap<8.5,"Actual lap covers the block on its road network / distance=%.1f road_gap=%.2f" % [actual_distance,longest_gap])
	check(van.crash_serial==crash_at and van.offroad_recoveries==recovery_at and van.reset_count==reset_at,"Lap requires no curb crashes, off-road recovery, reset or teleport")
	check(route.route_finished(),"Actual driving crosses every ordered purple route gate")
	await frames(210)
	check(cargo.complete and van.delivery_complete and absf(van.speed)<.1,"Release braking inside the bay completes a clean delivery after the actual lap")
	if captures and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/arcade-actual-controls-lap.png")
