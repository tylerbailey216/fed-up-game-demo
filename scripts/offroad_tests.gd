extends Node
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("OFFROAD FAIL: "+message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func run(game: Node) -> void:
	game.start_drive()
	var van = game.van
	await frames(30)
	# Isolate terrain traversal from moving traffic; traffic has its own suite.
	for car in game.traffic.cars:
		car.freeze = true
		car.collision_layer = 0
		car.collision_mask = 0
	var original_resets: int = van.reset_count
	van.position = Vector3(450,0.1,-50)
	van.rotation.y = -PI/2
	van.speed = 10
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	print("CITY EDGE x=%.2f y=%.3f resets=%d" % [van.position.x,van.position.y,van.reset_count-original_resets])
	check(van.position.x>470 and van.position.y> -0.15 and van.reset_count==original_resets,"Drive onto grass without falling/resetting")
	van.rotation.y = PI/2
	van.speed = 4
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	print("GRASS RETURN x=%.2f y=%.3f" % [van.position.x,van.position.y])
	check(van.position.x<456 and absf(van.position.y)<0.1 and van.reset_count==original_resets,"Turn around on grass and drive back into the district")
	van.reset_vehicle()
	van.position = Vector3(302,0.1,-90)
	van.rotation.y = PI
	van.speed = 4
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	print("ROAD RETURN z=%.2f y=%.3f speed=%.2f" % [van.position.z,van.position.y,van.speed])
	check(van.position.z> -80,"Off-road surface must not trap truck below road lip")
	for side in [-1,1]:
		van.reset_vehicle()
		van.position = Vector3(330+side*13,0.1,-55)
		van.rotation.y = side*PI/2
		van.speed = 4
		Input.action_press("accelerate")
		await frames(100)
		Input.action_release("accelerate")
		check(absf(van.position.x-330)<4 and absf(van.position.y)<0.1,"Drive onto north-south road from either side")
	# Reverse onto the road as well: no speed-based step assist should be needed.
	van.reset_vehicle()
	van.position = Vector3(302,0.1,-90)
	van.rotation.y = 0
	Input.action_press("brake_reverse")
	await frames(300)
	Input.action_release("brake_reverse")
	check(van.position.z> -80 and absf(van.position.y)<0.1,"Reverse must cross road edge without snagging")
	# Track a real, clear city-road location before leaving the demo footprint.
	van.reset_vehicle()
	van.position = Vector3(302,0.1,-75)
	van.rotation.y = -PI/2
	van.speed = 4
	Input.action_press("accelerate")
	await frames(60)
	Input.action_release("accelerate")
	var remembered: Vector3 = van.safe_position
	check(remembered.x>300,"Safe-road position must follow actual city driving")
	var recoveries: int = van.offroad_recoveries
	van.engine_on = false
	van.fuel_gallons = 14
	van.flip_count = 2
	van.distance = 123.5
	van.position = Vector3(501,0.1,0)
	await frames(3)
	check(van.offroad_recoveries==recoveries+1 and van.position.distance_to(remembered)<0.5,"Far-off-road boundary must return to last clear road")
	check(van.flip_count==2 and not van.engine_on and van.fuel_gallons==14 and is_equal_approx(van.distance,123.5),"Boundary recovery must preserve damage fuel ignition and trip")
	check(van.speed==0 and Vector2(van.velocity.x,van.velocity.z).length()<0.01 and absf(van.velocity.y)<2,"Recovery clears horizontal motion while gravity settles truck")
	# The below-world and bad-velocity guards also operate on disabled vehicles.
	van.position.y = -4
	await frames(3)
	check(van.position.y> -0.1,"Below-world fault must recover without falling forever")
	van.velocity = Vector3(INF,0,0)
	await frames(3)
	check(van.velocity.is_finite() and van.position.is_finite(),"Non-finite motion must be cleared before simulation")
	van.begin_rollover(30,30,1)
	await frames(360)
	print("DISABLED BEFORE BOUNDARY flips=%d rolled=%s settled=%s y=%.3f" % [van.flip_count,str(van.overturned),str(van.roll_settled),van.position.y])
	van.position = Vector3(600,-5,0)
	await frames(3)
	check(van.wrecked and van.overturned and van.flip_count==3 and not van.engine_on and van.position.y> -0.1,"Totalled/rolled truck must recover position without repair")
	van.recover_upright()
	await frames(3)
	check(van.wrecked and van.speed==0 and not van.engine_on,"Uprighting after boundary recovery must keep totalled lockout")
	van.new_truck()
	# A moving car or solid obstacle may have occupied the remembered road spot.
	remembered = Vector3(304,0.15,-75)
	van.safe_position = remembered
	van.safe_heading = -PI/2
	van.position = Vector3(501,0.1,0)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6,3.5,6)
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.position = remembered+Vector3(0,1.75,0)
	await frames(3)
	check(van.position.distance_to(remembered)>6 and van.recovery_space_clear(van.position+Vector3(0,0.15,0),van.rotation.y),"Occupied recovery spot must select a clear fallback")
	blocker.queue_free()
	print("SAFETY: boundary, last road, fuel/damage/trip, bad velocity, disabled/rolled, occupied fallback checked")
	print("OFFROAD TEST "+("FAIL" if failed else "PASS"))
	await game.quit_demo(1 if failed else 0)

func capture(game: Node) -> void:
	game.start_drive()
	var van = game.van
	await frames(30)
	van.set_view(false)
	van.position = Vector3(450,0.1,-50)
	van.rotation.y = -PI/2
	van.speed = 10
	Input.action_press("accelerate")
	await frames(110)
	Input.action_release("accelerate")
	van.speed = 0
	van.parking_brake = true
	van.camera_manual = true
	van.camera.global_position = van.position+Vector3(7,4,7)
	van.camera.look_at(van.position+Vector3(0,1.6,0))
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/offroad-terrain.png")
	van.position = Vector3(501,0.1,0)
	await frames(3)
	van.camera_manual = false
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/offroad-recovery.png")
	await game.quit_demo()
