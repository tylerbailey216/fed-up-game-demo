extends Node
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("TRAFFIC FAIL: "+message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func place_car(car: RigidBody3D, at: Vector3, heading: float) -> void:
	car.freeze = true
	await frames(2)
	car.global_transform = Transform3D(Basis(Vector3.UP,heading),at)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await frames(2)
	car.freeze = false

func run(game: Node) -> void:
	game.start_drive()
	var district = game.traffic
	var van = game.van
	var original: Vector3 = district.cars[0].position
	await frames(120)
	print("INITIAL car=",district.cars[0].position," velocity=",district.cars[0].linear_velocity," desired=",district.cars[0].last_target_speed," freeze=",district.cars[0].freeze," yaw=",district.cars[0].rotation.y," waypoint=",district.cars[0].waypoint)
	check(game.traffic.cars.size()==12,"Twelve live background vehicles")
	check(district.cars[0].position.distance_to(original)>2,"Traffic moves before the exit trigger")
	check(not district.entered and district.ns_light=="GREEN" and district.ew_light=="RED","Background traffic has default right of way")
	van.reset_vehicle()
	van.position = Vector3(248,0.1,-75)
	van.rotation.y = -PI/2
	van.speed = 6
	var barrel_start: Vector3 = district.barrels[1].position
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	check(van.position.x>267 and district.entered,"Drive through exit must call the signal")
	check(district.barrels[1].position.distance_to(barrel_start)>0.8,"Truck must physically push construction barrel")
	check(van.flip_count==0,"Lightweight barrels must not roll truck")
	print("EXIT x=%.2f barrel_displacement=%.2f" % [van.position.x,district.barrels[1].position.distance_to(barrel_start)])
	van.reset_vehicle()
	van.position = Vector3(272,0.1,-75)
	van.rotation.y = PI/2
	van.speed = 5
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	check(van.position.x<260 and van.position.x>242 and district.entered,"Player can drive back through the exit without resetting world")
	for phase in [1.0,2.5,4.0,18.0,28.5,30.0]:
		district.phase_time = phase
		district.update_signals()
		check(not (district.ns_light=="GREEN" and district.ew_light=="GREEN"),"Opposing signals never green together")
		if phase==2.5:
			check(district.ns_light=="RED" and district.ew_light=="RED","Entry trigger provides all-red clearance")
	# Controlled setups isolate signal and obstruction behavior from other cars.
	van.reset_vehicle()
	var car = district.cars[0]
	var parked: Array[Transform3D] = []
	for i in range(1,district.cars.size()):
		var other = district.cars[i]
		parked.append(other.global_transform)
		other.freeze = true
		other.position = Vector3(448,0,-150+i*16)
	car.route = [Vector3(283,0,-78),Vector3(400,0,-78),Vector3(400,0,-23),Vector3(283,0,-23)] as Array[Vector3]
	car.waypoint = 1
	await place_car(car,Vector3(300,0.05,-78),-PI/2)
	district.phase_time = 18
	district.update_signals()
	await frames(360)
	check(car.position.x<322 and car.linear_velocity.length()<1.5 and car.waiting_for_signal,"AI must queue before a red light")
	print("RED QUEUE x=%.2f speed=%.2f" % [car.position.x,car.linear_velocity.length()])
	district.phase_time = 4
	await frames(240)
	print("GREEN car=",car.position," target=",car.last_target_speed," waiting=",car.waiting_for_signal)
	check(car.position.x>322,"Green light releases queued car")
	# Running a red is an interaction, not an invisible barrier or reset.
	van.position = Vector3(322,0.1,-75)
	van.rotation.y = -PI/2
	van.speed = 7
	district.phase_time = 18
	district.update_signals()
	var violations: int = district.red_light_runs
	await frames(35)
	check(district.red_light_runs>violations and van.position.x>324,"Player may cross red and affect intersection")
	van.reset_vehicle()
	# Block the lane under green: AI must stop for the actual truck collider.
	await place_car(car,Vector3(298,0.05,-78),-PI/2)
	car.waypoint = 1
	van.position = Vector3(311,0.1,-78)
	van.rotation.y = -PI/2
	van.parking_brake = true
	district.phase_time = 4
	await frames(150)
	check(car.position.x<307 and car.last_target_speed<1,"Stopped truck must block and queue traffic")
	# Disable just this car's controller to prove truck pushing is physics-driven.
	car.set_physics_process(false)
	await place_car(car,Vector3(310,0.05,-78),-PI/2)
	van.reset_vehicle()
	van.position = Vector3(302,0.1,-78)
	van.rotation.y = -PI/2
	van.speed = 5
	Input.action_press("accelerate")
	await frames(150)
	Input.action_release("accelerate")
	check(car.position.x>312,"Truck must push an unpowered physical vehicle")
	print("PUSH car_x=%.2f truck_x=%.2f" % [car.position.x,van.position.x])
	car.set_physics_process(true)
	# Two cars transfer collision momentum independently of their controllers.
	var second = district.cars[1]
	car.set_physics_process(false)
	second.set_physics_process(false)
	await place_car(car,Vector3(360,0.05,-78),-PI/2)
	await place_car(second,Vector3(367,0.05,-78),-PI/2)
	car.linear_velocity = Vector3(10,0,0)
	await frames(60)
	check(second.position.x>368,"Cars must collide and transfer momentum")
	await place_car(car,Vector3(360,0.05,-78),-PI/2)
	van.reset_vehicle()
	van.position = Vector3(350,0.1,-78)
	van.rotation.y = -PI/2
	van.speed = 30
	await frames(45)
	check(van.overturned and is_instance_valid(van.roll_body) and van.collision_kind=="crash","High-speed traffic contact must enter physical crash response")
	check(van.flip_count==0,"A frontal traffic hit must not automatically count a rollover")
	van.new_truck()
	car.set_physics_process(true)
	second.set_physics_process(true)
	for i in range(1,district.cars.size()):
		var other = district.cars[i]
		other.global_transform = parked[i-1]
		other.linear_velocity = Vector3.ZERO
		other.angular_velocity = Vector3.ZERO
		other.freeze = false
	van.reset_vehicle()
	# World and signal pause together; returning to the loop does not respawn barrels.
	game.toggle_options()
	var held_position: Vector3 = car.position
	var held_phase: float = district.phase_time
	for i in 10:
		await get_tree().process_frame
	check(car.position==held_position and district.phase_time==held_phase,"Pause freezes traffic and signals")
	game.toggle_options()
	await frames(1800)
	var moving := 0
	for vehicle in district.cars:
		check(vehicle.position.is_finite() and vehicle.position.y> -1,"Traffic stays finite and above city deck")
		if vehicle.linear_velocity.length()>1:
			moving += 1
	check(moving>=3,"Background flow must continue after player disruption")
	game.return_to_menu()
	await frames(3)
	held_position = car.position
	await frames(30)
	check(car.position==held_position,"Menu stops traffic simulation")
	check(district.entered,"World trigger state persists across loop/menu visits")
	print("FLOW moving=%d cars=%d red_runs=%d" % [moving,district.cars.size(),district.red_light_runs])
	print("TRAFFIC TEST "+("FAIL" if failed else "PASS"))
	await game.quit_demo(1 if failed else 0)

func capture(game: Node) -> void:
	game.start_drive()
	var van = game.van
	van.set_view(false)
	van.position = Vector3(250,0.1,-45)
	van.rotation.y = 0
	van.camera_manual = true
	van.camera.global_position = Vector3(249,5.5,-58)
	van.camera.look_at(Vector3(264.5,0.8,-75))
	await get_tree().create_timer(1).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/traffic-gate.png")
	van.reset_vehicle()
	van.position = Vector3(248,0.1,-75)
	van.rotation.y = -PI/2
	van.speed = 6
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	van.speed = 0
	van.parking_brake = true
	van.position = Vector3(310,0.05,-78)
	van.camera.global_position = Vector3(300,7.5,-96)
	van.camera.look_at(Vector3(334,1,-74))
	await get_tree().create_timer(4).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/traffic-intersection.png")
	var timings: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 120:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		timings.append((now-previous)/1000.0)
		previous = now
	var total := 0.0
	for ms in timings:
		total += ms
	timings.sort()
	var report := "Live traffic intersection, 12 rigid-body vehicles, 1280x720. Average FPS %.1f; p95 %.2f ms; draw calls %d. Short stationary-camera sample, not a sustained driving benchmark." % [120000.0/total,timings[113],RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
	FileAccess.open("res://docs/TRAFFIC_RENDER_SAMPLE.txt",FileAccess.WRITE).store_string(report)
	print(report)
	await game.quit_demo()
