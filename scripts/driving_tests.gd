extends Node
## Accelerated simulated-time regression using the same input actions as the player.
var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("DRIVING FAIL: "+message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func release_inputs() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake"]:
		Input.action_release(action)

func run(game: Node) -> void:
	game.start_drive()
	var van = game.van
	await frames(120)
	Input.action_press("accelerate")
	await frames(180)
	check(van.speed > 8.0,"Throttle action must accelerate")
	Input.action_release("accelerate")
	Input.action_press("brake_reverse")
	await frames(100)
	check(absf(van.speed) < 0.2,"Brake must stop before reverse hold")
	await frames(120)
	check(van.speed < -1.0,"Held brake must enable reverse")
	release_inputs()
	game.reset_van()
	await frames(60)
	# Five simulated minutes. Controller only presses analog input actions:
	# no pose teleporting or forced speed during the circuit.
	var reset_before: int = van.reset_count
	var safety_before: int = van.offroad_recoveries
	var max_error := 0.0
	var min_height := 100.0
	Input.action_press("accelerate")
	for frame in 18000:
		var angle := atan2(van.position.z,van.position.x)
		var radius := Vector2(van.position.x,van.position.z).length()
		var error := radius-260.0
		max_error = maxf(max_error,absf(error))
		min_height = minf(min_height,van.position.y)
		var heading_error := wrapf(-angle-van.rotation.y,-PI,PI)
		var feedforward: float = 1.0/(van.steering_gain(van.speed)*260.0)
		var turn := clampf(feedforward+heading_error*4.0+error*0.06,-1,1)
		Input.action_press("steer_left",maxf(turn,0))
		Input.action_press("steer_right",maxf(-turn,0))
		await get_tree().physics_frame
	check(van.reset_count == reset_before,"No fall-through auto resets during circuit")
	check(van.offroad_recoveries == safety_before,"Road circuit must not trigger off-road safety recovery")
	check(min_height > -0.1,"Stay above road for complete circuit")
	check(max_error < 3.0,"Feedback driver should remain within lane region")
	check(van.distance > 9000,"Five-minute drive should complete multiple circuits")
	check(van.speed > 34.0 and van.speed <= 34.73,"Top speed must remain capped")
	print("CIRCUIT: simulated_seconds=300 distance_m=%.1f max_radial_error_m=%.3f min_y=%.3f resets=%d" % [van.distance,max_error,min_height,van.reset_count-reset_before])
	release_inputs()
	Input.action_press("handbrake")
	await frames(240)
	check(absf(van.speed) < 0.1,"Handbrake must stop van")
	release_inputs()
	game.reset_van()
	await frames(60)
	van.rotation.y = -PI/2
	van.speed = 20.0
	await frames(180)
	check(van.position.x < 268.0,"Outer barrier must contain van")
	check(van.speed < 1.0,"Barrier contact must slow van")
	for wall_side in [-1,1]:
		for steer_action in ["steer_left","steer_right"]:
			game.reset_van()
			await frames(60)
			van.rotation.y = -wall_side*PI/2
			van.speed = 12.0
			await frames(120)
			var stuck: Vector3 = van.position
			Input.action_press("brake_reverse")
			Input.action_press(steer_action)
			await frames(120)
			check(van.position.distance_to(stuck)>1,"Reverse must escape wall with "+steer_action+" side="+str(wall_side))
			check(van.speed < -1,"Reverse remains responsive after barrier")
			release_inputs()
			game.reset_van()
			await frames(60)
			van.rotation.y = -wall_side*PI/2
			van.speed = 12.0
			await frames(120)
			stuck = van.position
			Input.action_press("accelerate")
			Input.action_press(steer_action)
			await frames(360)
			check(van.position.distance_to(stuck)>2,"Forward steering must recover from wall with "+steer_action+" side="+str(wall_side))
			var recovery_radius := Vector2(van.position.x,van.position.z).length()
			print("RECOVERY side=%d steer=%s radius=%.2f y=%.2f distance=%.2f speed=%.2f" % [wall_side,steer_action,recovery_radius,van.position.y,van.position.distance_to(stuck),van.speed])
			check(recovery_radius>252 and recovery_radius<268 and van.position.y<0.2,"Recovery must remain inside barriers")
			release_inputs()
	print("BARRIER RECOVERY: both walls, left/right, forward/reverse checked")
	# Short mirrored steering pulses exercise real lateral momentum and camera
	# separation without requiring traffic or leaving the empty highway.
	for side in [-1,1]:
		game.reset_van()
		van.set_view(false)
		await frames(30)
		van.speed = 18.0
		Input.action_press("accelerate")
		Input.action_press("steer_left" if side>0 else "steer_right",0.7)
		await frames(30)
		var ordinary_slip: float = absf(van.slip_angle)
		check(ordinary_slip>0.015,"Turning must preserve lateral momentum on both sides")
		check(absf(van.body.rotation.z)>0.01,"Body must lean through turns")
		check(absf(wrapf(van.rotation.y-van.chase_heading,-PI,PI))>0.025,"Chase heading must reveal turning angle")
		Input.action_release("accelerate")
		Input.action_press("handbrake")
		await frames(15)
		check(absf(van.slip_angle)>ordinary_slip,"Handbrake must increase slip")
		print("TURN side=%d slip_deg=%.2f body_roll_deg=%.2f camera_lag_deg=%.2f" % [side,rad_to_deg(van.slip_angle),rad_to_deg(van.body.rotation.z),rad_to_deg(wrapf(van.rotation.y-van.chase_heading,-PI,PI))])
		release_inputs()
		await frames(30)
		check(absf(van.slip_angle)<ordinary_slip,"Released steering must regain grip")
		check(van.body.rotation.length()<0.18,"Suspension must remain bounded")
	game.reset_van()
	check(van.planar_velocity==Vector3.ZERO and van.slip_angle==0,"Reset must clear drift")
	van.rotation.y = -PI/2
	van.speed = 12.0
	var serial_before: int = van.impact_serial
	await frames(90)
	check(van.impact_serial>serial_before,"Barrier must trigger directional suspension impact")
	print("DRIFT PASS CHECKS: mirrored slip, handbrake, grip recovery, body roll, chase lag, impact, reset")
	# Functional dashboard values and navigation are exercised, not fixed artwork.
	game.reset_van()
	van.engine_on = true
	van.fuel_gallons = 18
	Input.action_press("accelerate")
	await frames(120)
	check(van.fuel_gallons < 18,"Fuel must respond to engine/movement")
	check(game.vehicle_visuals.wheels.size()==4,"Four independently rolling wheels required")
	check(absf(game.vehicle_visuals.wheels[0].rotation.x)>0.1,"Wheels must rotate with actual movement")
	check(is_equal_approx(game.dashboard.speed,absf(van.speed)*2.2369363),"Dashboard must display mph")
	check(not van.refuel(),"Moving refuel must be rejected")
	release_inputs()
	game.reset_van()
	check(van.refuel() and van.fuel_gallons == van.TANK_GALLONS,"Stopped refuel must fill actual tank")
	game.dashboard_key(KEY_Q)
	check(van.indicator == -1 and not van.hazards,"Left signal toggles state")
	game.dashboard_key(KEY_E)
	check(van.indicator == 1,"Right signal replaces left")
	game.dashboard_key(KEY_H)
	check(van.hazards and van.indicator == 0,"Hazards control both sides")
	game.dashboard_key(KEY_L)
	check(van.headlights,"Headlights toggle")
	game.dashboard_key(KEY_K)
	check(van.high_beam and van.headlights,"High beam toggle")
	game.navigation.select_target(0)
	game.navigation.update_position(Vector3(260,0,0),10)
	check(absf(game.navigation.remaining_m-TAU*260/4)<1,"GPS measures along road")
	game.navigation.update_position(Vector3(0,0,-260),10)
	check(game.navigation.arrived,"GPS recognizes destination")
	game.reset_van()
	van.speed = 12
	van.toggle_cruise()
	check(van.cruise,"Cruise should set above minimum speed")
	await frames(30)
	check(absf(van.speed-12)<0.7,"Cruise maintains chosen speed")
	Input.action_press("brake_reverse")
	await frames(3)
	check(not van.cruise,"Braking cancels cruise")
	release_inputs()
	game.reset_van()
	van.parking_brake = true
	Input.action_press("accelerate")
	await frames(60)
	check(van.speed == 0,"Parking brake holds against throttle")
	release_inputs()
	van.parking_brake = false
	van.fuel_gallons = 0.0000001
	await frames(3)
	check(not van.engine_on and not van.cruise,"Empty fuel stops engine and cruise")
	van.refuel()
	van.toggle_engine()
	for player in game.audio_manager.players.values():
		check(player.stream != null,"All original audio assets must load")
	await frames(5)
	check(game.audio_manager.players["engine_idle"].playing,"Engine audio must run with ignition")
	check(game.audio_manager.players["city_ambience"].playing,"Supplied city ambience must play")
	game.dashboard_key(KEY_B)
	await frames(3)
	check(game.audio_manager.players["horn"].playing,"Horn button triggers audio")
	game.toggle_options()
	var mirror_before: bool = game.dashboard.show_mirror
	game.options.checks["show_mirror"].button_pressed = not mirror_before
	check(game.dashboard.show_mirror != mirror_before,"HUD checkbox must change live setting")
	game.options.checks["show_mirror"].button_pressed = mirror_before
	var volume_before: float = game.master_volume
	game.options.master_slider.value = 0.3
	check(is_equal_approx(game.audio_manager.master_volume,0.3),"Audio slider must reach mixer controller")
	game.options.master_slider.value = volume_before
	var fuel_before: float = van.fuel_gallons
	var blink_before: float = van.blink_time
	await frames(10)
	check(van.fuel_gallons == fuel_before and van.blink_time == blink_before,"Dashboard controls pause simulation")
	game.toggle_options()
	van.engine_on = false
	Input.action_press("accelerate")
	await frames(120)
	check(van.speed == 0,"Engine off must disable throttle")
	release_inputs()
	van.engine_on = true
	print("DASHBOARD PASS CHECKS: mph, fuel/refuel, signals, hazards, lights, GPS, wheels, pause, ignition")
	await run_crash(game)
	game.reset_van()
	game.return_to_menu()
	check(not van.active and not game.driving,"Main menu must stop driving")
	print("DRIVING TEST "+("FAIL" if failed else "PASS")+": throttle, brake, reverse, 300s circuit, speed cap, handbrake, barrier, menu")
	await game.quit_demo(1 if failed else 0)

func run_crash(game: Node) -> void:
	game.start_drive()
	var van = game.van
	release_inputs()
	van.new_truck()
	await run_contacts(game)
	await frames(30)
	van.speed = 18.0
	Input.action_press("handbrake")
	await frames(12)
	check(van.tire_squeal>0.2,"Hard stop must trigger tire squeal")
	check(game.audio_manager.players["tire_squeal"].playing,"Tire squeal audio must enter playback")
	release_inputs()
	van.reset_vehicle()
	await frames(20)
	check(van.tire_squeal==0,"Stopped truck must not squeal")
	van.speed = 25.0
	Input.action_press("steer_left")
	await frames(30)
	check(van.tire_squeal>0.1,"Steep turn must trigger squeal")
	release_inputs()
	van.reset_vehicle()
	check(not van.begin_rollover(34,3,1),"Fast glancing impact must not roll truck")
	check(not van.begin_rollover(12,12,1),"Low-speed impact must not roll truck")
	for crash in 3:
		van.reset_vehicle()
		await frames(15)
		van.rotation.y = (-1 if crash%2==0 else 1)*PI/4
		van.speed = 34.0
		await frames(35)
		check(van.overturned and is_instance_valid(van.roll_body),"Actual angled impact must enter physical crash simulation")
		check(van.collision_kind=="crash" and game.audio_manager.players["crash"].playing,"Hard impact must play crash sound")
		check(not van.recover_upright(),"Recovery must wait for rollover to settle")
		await frames(360)
		check(van.flip_count==crash+1,"Resting/contact must not double count flips")
		check(van.roll_settled and van.roll_body.global_basis.y.dot(Vector3.UP)<0.25,"Truck must physically settle on its side or roof")
		check(not game.upright_button.disabled and game.upright_button.visible,"Recovery button must enable when settled")
		check(van.wrecked==(crash==2),"Only third rollover must total vehicle")
		if crash==2:
			check(game.vehicle_visuals.smoke.emitting,"Third flip must emit hood smoke")
		var crash_position: Vector3 = van.global_position
		game.upright_button.pressed.emit()
		await frames(3)
		check(not van.overturned,"Tap recovery button must right truck")
		check(van.global_position.distance_to(crash_position)<2.1,"Recovery must stay near crash site")
		check(van.flip_count==crash+1,"Recovery must preserve damage count")
		check(van.engine_on==(crash<2),"Recoverable truck restarts; totalled truck stays off")
	van.toggle_engine()
	van.refuel()
	van.reset_vehicle()
	Input.action_press("accelerate")
	await frames(90)
	check(van.wrecked and not van.engine_on and van.speed==0,"Ignition/refuel/reset/throttle cannot bypass totalled state")
	check(game.vehicle_visuals.smoke.emitting,"Smoke must persist after upright recovery")
	release_inputs()
	game.new_truck_button.pressed.emit()
	await frames(3)
	check(not van.wrecked and van.flip_count==0 and van.engine_on,"New truck button must clear damage")
	check(not game.vehicle_visuals.smoke.emitting,"New truck must stop smoke emission")
	print("CRASH TEST "+("FAIL" if failed else "PASS")+": turn/brake squeal, 3 actual impacts, rollover settling, recovery UI, damage lockout, hood smoke, new truck")

func run_contacts(game: Node) -> void:
	var van = game.van
	var visuals = game.vehicle_visuals
	await frames(15)
	var bursts: int = visuals.exhaust_bursts
	Input.action_press("accelerate")
	await frames(5)
	check(visuals.exhaust.emitting and visuals.exhaust_bursts>bursts,"Throttle acceleration must puff exhaust")
	Input.action_release("accelerate")
	await frames(20)
	check(not visuals.exhaust.emitting,"Throttle release must stop new exhaust")
	van.engine_on = false
	Input.action_press("accelerate")
	await frames(5)
	check(not visuals.exhaust.emitting,"Engine off must not emit exhaust")
	release_inputs()
	van.new_truck()
	for impact_speed in [8.0,18.0]:
		van.reset_vehicle()
		await frames(15)
		van.rotation.y = -PI/2
		van.speed = impact_speed
		var serial: int = van.collision_serial
		for frame in 90:
			await frames(1)
			if van.collision_serial>serial:
				break
		await get_tree().process_frame
		await get_tree().process_frame
		check(van.collision_serial>serial and van.collision_kind=="bump","Normal/moderate contact must select bump audio")
		check(game.audio_manager.players["bump"].playing,"Minor collision sound must play")
		check(not van.overturned and not van.wrecked and van.flip_count==0 and van.wall_ride_time==0,"Normal/moderate hit must remain a fender bender")
	for side in [-1,1]:
		van.reset_vehicle()
		await frames(15)
		van.position.x = 260.0+side*4.0
		van.rotation.y = -side*0.32
		van.speed = 30.0
		var peak_height := 0.0
		var peak_bank := 0.0
		var rode_wall := false
		var heard_scrape := false
		for frame in 120:
			await frames(1)
			peak_height = maxf(peak_height,van.position.y)
			peak_bank = maxf(peak_bank,absf(van.body.rotation.z))
			rode_wall = rode_wall or van.wall_ride_time>0
			heard_scrape = heard_scrape or game.audio_manager.players["scrape"].playing
		check(rode_wall and peak_height>0.3 and peak_height<0.85,"Fast angled hit must physically climb within safe height")
		check(peak_bank>0.15,"Wall climb must visibly bank truck")
		check(heard_scrape,"Wall ride must play metal scrape audio")
		check(not van.overturned and van.flip_count==0,"Angled wall ride must not count a rollover")
		check(van.position.y<0.15,"Wall ride must land back on road")
		var radius := Vector2(van.position.x,van.position.z).length()
		check(radius>252 and radius<268,"Wall climb must stay on highway")
		check(van.collision_kind=="scrape" or van.collision_kind=="bump","Wall ride must register collision audio")
		print("WALL RIDE side=%d max_y=%.3f bank_deg=%.1f radius=%.2f" % [side,peak_height,rad_to_deg(peak_bank),radius])
	van.new_truck()
	print("CONTACT CHECKS: low/moderate bumps, angled wall climbs, exhaust throttle/off/release")
