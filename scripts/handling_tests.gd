extends Node
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("HANDLING FAIL: "+message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func release() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake"]:
		Input.action_release(action)

func run(game: Node) -> void:
	game.start_drive()
	var van = game.van
	var marks = game.tire_marks
	await frames(30)
	for car in game.traffic.cars:
		car.freeze = true
		car.collision_layer = 0
		car.collision_mask = 0
	for side in [-1,1]:
		for speed in [3.0,12.0,25.0]:
			van.new_truck()
			await frames(10)
			van.speed = speed
			var start: float = van.rotation.y
			var action := "steer_left" if side>0 else "steer_right"
			Input.action_press(action)
			await frames(12)
			check(van.steering*side>0.95,"Steering must reach full lock within 0.2 seconds")
			check((van.rotation.y-start)*side>0.015,"Steering must change heading promptly at all test speeds")
			Input.action_release(action)
			Input.action_press("steer_right" if side>0 else "steer_left")
			await frames(12)
			check(van.steering*side< -0.5,"Countersteering must not feel stuck in prior direction")
			release()
			await frames(12)
			check(absf(van.steering)<0.01,"Released wheel must center promptly")
	for surface in [Vector3(260,0.15,0),Vector3(302,0.15,-75),Vector3(466,0.15,-50)]:
		van.new_truck()
		van.position = surface
		await frames(15)
		var before: int = marks.emitted
		van.speed = 18
		Input.action_press("handbrake")
		await frames(30)
		release()
		check(marks.emitted>before+12,"Hard braking must leave contact marks on asphalt plaza and grass")
	van.new_truck()
	await frames(15)
	var before: int = marks.emitted
	van.speed = 16
	Input.action_press("steer_left",0.8)
	await frames(24)
	release()
	check(marks.emitted>before,"Sharp turns must leave marks")
	van.new_truck()
	await frames(15)
	before = marks.emitted
	van.speed = 18
	Input.action_press("handbrake")
	Input.action_press("steer_left",0.5)
	await frames(25)
	release()
	check(marks.emitted>before,"Drifting must leave tire marks")
	game.toggle_options()
	var held_clock: float = marks.clock
	for i in 8:
		await get_tree().process_frame
	check(marks.clock==held_clock,"Tire-mark fade clock must pause with the game")
	game.toggle_options()
	van.new_truck()
	await frames(480)
	check(marks.live_count()==0,"All tire marks must expire after seven gameplay seconds")
	before = marks.emitted
	van.speed = 5
	Input.action_press("accelerate")
	await frames(30)
	release()
	check(marks.emitted==before,"Ordinary acceleration must not paint continuous marks")
	van.new_truck()
	van.position = Vector3(302,3,-75)
	van.speed = 18
	before = marks.emitted
	Input.action_press("handbrake")
	await frames(10)
	release()
	check(marks.emitted==before,"Airborne tires must not leave floating marks")
	# Compare a frontal impact with a wheel-tripping angled hit.
	for heading in [-PI/2,-PI/4,PI/4]:
		van.new_truck()
		await frames(15)
		van.rotation.y = heading
		van.speed = 34
		var peak_tilt := 0.0
		var peak_y := 0.0
		for i in 480:
			await frames(1)
			if is_instance_valid(van.roll_body):
				peak_tilt = maxf(peak_tilt,acos(clampf(van.roll_body.global_basis.y.dot(Vector3.UP),-1,1)))
				peak_y = maxf(peak_y,van.roll_body.global_position.y)
		check(van.position.is_finite(),"Crash body must stay finite")
		print("CRASH heading=%.2f tilt_deg=%.1f center_y=%.2f flips=%d settled=%s active=%s" % [heading,rad_to_deg(peak_tilt),peak_y,van.flip_count,str(van.roll_settled),str(van.overturned)])
		if absf(heading+PI/2)<0.01:
			check(van.flip_count==0,"Frontal collision must not automatically count a flip")
		else:
			check(van.flip_count==1 and van.roll_settled,"Angled trip must physically roll and settle once")
		check(peak_y<3.5,"Crash must not use the old exaggerated airborne arc")
	van.new_truck()
	await frames(15)
	van.rotation.y = -PI/4
	van.speed = 34
	await frames(35)
	game.toggle_options()
	var paused_pose: Transform3D = van.roll_body.global_transform
	for i in 8:
		await get_tree().process_frame
	check(van.roll_body.global_transform==paused_pose,"Pause freezes physical rollover")
	game.toggle_options()
	game.return_to_menu()
	await frames(2)
	paused_pose = van.roll_body.global_transform
	await frames(30)
	check(van.roll_body.global_transform==paused_pose,"Menu freezes an unsettled crash body")
	game.start_drive()
	await frames(360)
	check(van.roll_settled and van.flip_count==1,"Resume completes crash without duplicate flips")
	print("HANDLING TEST "+("FAIL" if failed else "PASS"))
	van.new_truck()
	await game.quit_demo(1 if failed else 0)

func capture(game: Node) -> void:
	game.start_drive()
	var van = game.van
	await frames(30)
	van.set_view(false)
	van.speed = 24
	Input.action_press("handbrake")
	Input.action_press("steer_left",0.55)
	await frames(35)
	release()
	van.speed = 0
	van.parking_brake = true
	van.camera_manual = true
	van.camera.global_position = van.position+Vector3(5,4.5,8)
	van.camera.look_at(van.position+Vector3(0,0.8,3))
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/tire-marks.png")
	await get_tree().create_timer(7.5).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/tire-marks-faded.png")
	van.new_truck()
	van.camera_manual = false
	van.set_view(false)
	van.rotation.y = -PI/4
	van.speed = 34
	await get_tree().create_timer(4.0).timeout
	get_viewport().get_texture().get_image().save_png("res://docs/physical-rollover.png")
	print("HANDLING CAPTURE: emitted=%d live=%d physical_roll=%s flips=%d" % [game.tire_marks.emitted,game.tire_marks.live_count(),str(van.roll_settled),van.flip_count])
	await game.quit_demo()
