extends CharacterBody3D

signal telemetry(speed_kph: float, gear: String, distance: float)
var speed := 0.0
var distance := 0.0
var steering := 0.0
var active := false
var cockpit := false
var camera: Camera3D
var body: Node3D
var reverse_delay := 0.0
var delivery_complete:=false
var reset_count := 0
var fuel_gallons := 18.0
const TANK_GALLONS := 24.0
var engine_on := true
var temperature_f := 140.0
var rpm := 800.0
var indicator := 0 # -1 left, +1 right
var hazards := false
var blink_time := 0.0
var headlights := false
var high_beam := false
var parking_brake := false
var cruise := false
var cruise_speed := 0.0
var throttle_load := 0.0
var brake_load := 0.0
var wall_normal := Vector3.ZERO
var wall_timer := 0.0
var impact_strength := 0.0
var horn := false
var notice := ""
var notice_time := 0.0
var notice_last_at:=-10000
var wheel_distance := 0.0
var planar_velocity := Vector3.ZERO
var lateral_speed := 0.0
var slip_angle := 0.0
var yaw_rate := 0.0
var acceleration := 0.0
var impact_local := Vector3.ZERO
var impact_serial := 0
var camera_manual := false
var chase_heading := 0.0
var chase_position := Vector3.ZERO
const ROLLOVER_SPEED := 22.0 # ~49 mph total, plus a substantial inward impact.
var flip_count := 0
var wrecked := false
var overturned := false
var roll_time := 0.0
var roll_direction := 1.0
var tire_squeal := 0.0
var wall_ride_time := 0.0
var wall_ride_normal := Vector3.ZERO
var collision_cooldown := 0.0
var collision_serial := 0
var crash_serial := 0
var crash_contact_active := false
var crash_clear_time := 0.0
var crash_origin := Vector3.ZERO
var delivery_collision_rules := false
var crash_guard := BoxShape3D.new()
var camera_high := false
var camera_orbit := 0.0
var camera_pitch:=0.0
var camera_zoom := 1.0
var camera_rig := preload("res://scripts/camera_rig.gd").new()
var collision_kind := "bump"
var collision_level := 0.0
const DEMO_RADIUS := 500.0
var safe_position := Vector3(260,0.15,0)
var safe_heading := 0.0
var safe_sample_time := 0.0
var offroad_recoveries := 0
var roll_body: RigidBody3D
var roll_settled := false
var roll_stable_time := 0.0
var flip_registered := false
var impact_engine_was_on := true
var held_roll_linear := Vector3.ZERO
var held_roll_angular := Vector3.ZERO
var location_world: Node3D
var driver_on_foot := false
var cargo_open := false
var ground_kind:="asphalt"
var ground_tilt:=Vector2.ZERO
var vegetation_contact:=0.0
var surface_bump_serial:=0
var surface_bump_strength:=0.0
var contact_shadow:Node3D
var stunts:=preload("res://scripts/vehicle_stunts.gd").new()
var surface_sampler:=preload("res://scripts/vehicle_surface.gd").new()

func pause_crash(paused: bool) -> void:
	if not is_instance_valid(roll_body):
		return
	if paused and not roll_body.freeze:
		held_roll_linear = roll_body.linear_velocity
		held_roll_angular = roll_body.angular_velocity
		roll_body.freeze = true
	elif not paused and roll_body.freeze:
		roll_body.freeze = false
		roll_body.linear_velocity = held_roll_linear
		roll_body.angular_velocity = held_roll_angular

func steering_gain(at_speed: float) -> float:
	# Stronger low/mid-speed authority with a gradual highway reduction.
	return 0.095/(1.0+absf(at_speed)*0.16)

func set_drive_collision(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled",not enabled)

func dispose_roll_body() -> void:
	if is_instance_valid(roll_body):
		roll_body.collision_layer = 0
		roll_body.collision_mask = 0
		roll_body.freeze = true
		roll_body.queue_free()
	roll_body = null
	set_drive_collision(true)

func simulate_crash(delta: float) -> void:
	stunts.consume_contact()
	roll_time += delta
	if not is_instance_valid(roll_body):
		return
	global_position = roll_body.global_position-Vector3(0,1.575,0)
	stunts.update_shadow(delta)
	var facing := -roll_body.global_basis.z
	if Vector2(facing.x,facing.z).length()>0.25:
		rotation.y = atan2(-facing.x,-facing.z)
	var up_dot := roll_body.global_basis.y.dot(Vector3.UP)
	# A truck resting on its side is a rollover too; count the physical tip,
	# rather than requiring or forcing a complete roof landing.
	if up_dot<0.2 and not flip_registered:
		flip_registered = true
		flip_count += 1
		if not delivery_collision_rules: wrecked = wrecked or flip_count>=3
		notify_driver("TRUCK TOTALLED - start a new truck" if wrecked else ("ROLLOVER - recover once settled / LOAD SECURED" if delivery_collision_rules else "ROLLOVER %d / 3 - recover once settled" % flip_count))
	var still := roll_body.linear_velocity.length()<0.8 and roll_body.angular_velocity.length()<0.6
	roll_stable_time = roll_stable_time+delta if still else 0.0
	roll_settled = roll_time>0.9 and (roll_stable_time>0.35 or roll_body.sleeping)
	if roll_settled and up_dot>0.85 and not flip_registered:
		recover_upright()

func on_known_road(at: Vector3) -> bool:
	if location_world:
		return location_world.has_road_near(at)
	if absf(Vector2(at.x,at.z).length()-260.0)<3.5:
		return true
	if at.x<275 or at.x>437 or at.z< -151 or at.z>51:
		return at.x>=250 and at.x<=275 and absf(at.z+75)<3.5
	for x in [330,430]:
		if absf(at.x-x)<3.5:
			return true
	for z in [-145,-75,-20,45]:
		if absf(at.z-z)<3.5 and (at.x>=323 or z in [-75,-20]):
			return true
	return absf(at.x-280)<3.5 and at.z>= -75 and at.z<= -20

func recovery_space_clear(at: Vector3, heading: float) -> bool:
	if not at.is_finite() or not is_finite(heading):
		return false
	var hull := BoxShape3D.new()
	hull.size = Vector3(2.7,3.3,5.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hull
	query.transform = Transform3D(Basis(Vector3.UP,heading),at+Vector3(0,1.7,0))
	query.exclude = [get_rid()]
	if is_instance_valid(roll_body):
		query.exclude = [get_rid(),roll_body.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func recover_to_road() -> void:
	var at := safe_position
	var heading := safe_heading
	if location_world and not recovery_space_clear(at,heading):
		at = location_world.spawn_position
		heading = location_world.spawn_heading
	elif not recovery_space_clear(at,heading):
		for i in 16:
			var angle := TAU*i/16.0
			var candidate := Vector3(cos(angle)*260,0.15,sin(angle)*260)
			if recovery_space_clear(candidate,-angle):
				at = candidate
				heading = -angle
				break
	position = at
	rotation = Vector3(0,heading,0)
	velocity = Vector3.ZERO
	planar_velocity = Vector3.ZERO
	if is_instance_valid(roll_body):
		roll_body.global_position = at+Vector3(0,1.575,0)
		roll_body.linear_velocity = Vector3.ZERO
		roll_body.angular_velocity = Vector3.ZERO
	speed = 0.0
	steering = 0.0
	lateral_speed = 0.0
	slip_angle = 0.0
	yaw_rate = 0.0
	acceleration = 0.0
	wall_normal = Vector3.ZERO
	wall_timer = 0.0
	wall_ride_time = 0.0
	tire_squeal = 0.0
	throttle_load = 0.0
	cruise = false
	safe_position = at
	safe_heading = heading
	offroad_recoveries += 1
	set_view(cockpit)
	notify_driver("Demo boundary - returned to last clear road")

func outside_driveable_world() -> bool:
	if location_world:
		if location_world.has_method("outside_bounds"):
			return not position.is_finite() or not velocity.is_finite() or not is_finite(speed) or location_world.outside_bounds(position)
		return not position.is_finite() or not rotation.is_finite() or not velocity.is_finite() or not is_finite(speed) or position.y< -4 or position.y>80 or position.x< -1240 or position.x>940 or position.z< -1140 or position.z>1090
	return not position.is_finite() or not rotation.is_finite() or not velocity.is_finite() or not is_finite(speed) or position.y< -3 or position.y>35 or Vector2(position.x,position.z).length()>DEMO_RADIUS

func register_collision(impact_speed: float, closing_speed: float) -> void:
	if closing_speed < 0.8:return
	# Audio may repeat during scraping. Mission damage counts one contact episode.
	if not crash_contact_active:
		crash_serial+=1;crash_contact_active=true;crash_clear_time=0;crash_origin=global_position
	if collision_cooldown > 0:return
	collision_serial += 1
	collision_cooldown = 0.4
	collision_level = clampf(closing_speed/20.0,0.18,1)
	collision_kind = "crash" if impact_speed>=ROLLOVER_SPEED and closing_speed>=12 else ("scrape" if impact_speed>=ROLLOVER_SPEED and closing_speed>=4 else "bump")

func update_crash_contact(delta:float) -> void:
	if not crash_contact_active or overturned or wrecked or driver_on_foot:return
	if global_position.distance_squared_to(crash_origin)<6.25:
		crash_clear_time=0;return
	# A small clearance hull keeps wall jitter and neighboring barrier segments
	# in the same crash. Its bottom clears ordinary ground and road surfaces.
	crash_guard.size=Vector3(2.9,2.8,5.9)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=crash_guard
	query.transform=Transform3D(global_basis,global_position+Vector3.UP*1.8)
	query.collision_mask=1;query.exclude=[get_rid()]
	if is_instance_valid(roll_body):query.exclude.append(roll_body.get_rid())
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		crash_clear_time=0;return
	crash_clear_time+=delta
	if crash_clear_time>=.65 and global_position.distance_to(crash_origin)>=2.5:
		crash_contact_active=false;crash_clear_time=0

func begin_wall_ride(impact_speed: float, closing_speed: float) -> bool:
	if location_world:
		return false # Mapped roads use collision-driven rigid-body impacts, not lift assists.
	if overturned or wrecked or wall_ride_time>0 or impact_speed<ROLLOVER_SPEED or closing_speed<4 or closing_speed>=12:
		return false
	wall_ride_time = 0.9
	wall_ride_normal = wall_normal
	wall_timer = 0.95
	velocity.y = 6.0
	set_view(false)
	notify_driver("BARRIER CLIMB - ease off and steer clear")
	return true

func create_motion_body(physical_impact:bool,stunt:=false) -> void:
	roll_body = preload("res://scripts/stunt_body.gd").new() if stunt else RigidBody3D.new()
	roll_body.mass = 3200
	roll_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	roll_body.center_of_mass = Vector3(0,-0.25,0)
	roll_body.linear_damp = 0.08 if physical_impact else 0.45
	roll_body.angular_damp = 0.4 if physical_impact else 0.9
	roll_body.continuous_cd = true
	roll_body.process_mode = Node.PROCESS_MODE_PAUSABLE
	var contact := PhysicsMaterial.new()
	contact.friction = 0.85
	contact.bounce = 0.02
	roll_body.physics_material_override = contact
	get_parent().add_child(roll_body)
	roll_body.global_transform = Transform3D(global_basis,global_position+Vector3(0,1.575,0))
	for child in get_children():
		if child is CollisionShape3D:
			var shape := CollisionShape3D.new()
			shape.shape = child.shape
			shape.transform = child.transform
			shape.position.y -= 1.575
			roll_body.add_child(shape)
	roll_body.add_collision_exception_with(self)
	set_drive_collision(false)

func begin_rollover(impact_speed: float, closing_speed: float, side: float,physical_impact := false) -> bool:
	# Heavy impacts can pitch and settle upright; an oblique wheel-trip is what
	# supplies roll torque. Speed alone no longer guarantees a counted flip.
	if overturned or wrecked:
		return false
	var lateral_hit := closing_speed*absf(side)
	if physical_impact:
		if impact_speed<22.0 or closing_speed<12.0:return false
	else:
		if impact_speed<26.0 or closing_speed<16.0:return false
		if lateral_hit<12.0 and closing_speed<24.0:return false
	impact_engine_was_on = engine_on
	var incoming := planar_velocity
	if physical_impact:incoming.y=velocity.y
	if wall_normal.length_squared()<0.5:
		wall_normal = global_basis*(Vector3(signf(side),0,0) if absf(side)>0.05 else Vector3.BACK)
	wall_normal = wall_normal.normalized()
	create_motion_body(physical_impact)
	if physical_impact:
		roll_body.linear_velocity=incoming
		roll_body.angular_velocity=Vector3(0,yaw_rate,0)
	else:
		var recoil := wall_normal*clampf(closing_speed*0.05,0.4,1.5)
		roll_body.linear_velocity = incoming.slide(wall_normal)*0.22+recoil
		var twist := 0.0
		if lateral_hit>=12.0:
			twist = -signf(side)*clampf(3.0+(lateral_hit-12.0)*0.16,3.0,4.5)
		roll_body.angular_velocity = global_basis*Vector3(clampf(closing_speed*0.035,0,1.1),0.1*side,twist)
	overturned = true
	roll_settled = false
	roll_stable_time = 0.0
	flip_registered = false
	wall_ride_time = 0.0
	impact_strength = impact_speed/12.0
	roll_time = 0.0
	roll_direction = signf(side) if absf(side)>0.05 else 1.0
	engine_on = false
	cruise = false
	throttle_load = 0.0
	speed = 0.0
	planar_velocity = Vector3.ZERO
	lateral_speed = 0.0
	slip_angle = 0.0
	yaw_rate = 0.0
	tire_squeal = 0.0
	set_view(false)
	notify_driver("HEAVY IMPACT - truck settling")
	return true

func recover_upright() -> bool:
	if not overturned or not roll_settled:
		return false
	overturned = false
	roll_time = 0.0
	var recovered_position := global_position+wall_normal*1.8
	if location_world:
		recovered_position=mapped_recovery_position(recovered_position)
	else:
		recovered_position.y = 0.15
	var recovered_heading := rotation.y
	dispose_roll_body()
	reset_vehicle()
	global_position = recovered_position
	rotation.y = recovered_heading
	set_view(false)
	engine_on = impact_engine_was_on and not wrecked and fuel_gallons > 0
	notify_driver("Truck totalled - new truck required" if wrecked else ("Recovered - load secured" if delivery_collision_rules else "Recovered - flips %d / 3" % flip_count))
	return true

func mapped_recovery_position(at: Vector3) -> Vector3:
	for radius in [0.0,3.0,6.0,9.0]:
		for i in (1 if radius==0 else 12):
			var candidate:Vector3=at+Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*radius
			var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*4,candidate-Vector3.UP*5)
			ray.exclude=[get_rid()]
			if is_instance_valid(roll_body):ray.exclude=[get_rid(),roll_body.get_rid()]
			var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<0.9:continue
			if hit.collider.has_meta("barrier_kind"):continue
			candidate=hit.position+Vector3.UP*0.15
			if (radius==0 or location_world.has_road_near(candidate)) and recovery_space_clear(candidate,rotation.y):return candidate
	if recovery_space_clear(safe_position,safe_heading):return safe_position
	return location_world.spawn_position

func new_truck() -> void:
	delivery_complete=false
	crash_contact_active=false;crash_clear_time=0
	dispose_roll_body()
	flip_count = 0
	wrecked = false
	overturned = false
	roll_time = 0.0
	roll_settled = false
	fuel_gallons = 18.0
	engine_on = true
	reset_vehicle()
	notify_driver("New truck ready")

func gear_text() -> String:
	if parking_brake and absf(speed) < 0.2:
		return "P"
	if speed < -0.1:
		return "R"
	if absf(speed) < 0.1:
		return "N"
	return "D%d" % (1+int(absf(speed)>5)+int(absf(speed)>11)+int(absf(speed)>18)+int(absf(speed)>26))

func notify_driver(message: String) -> void:
	var now:=Time.get_ticks_msec()
	if message==notice and now-notice_last_at<3500:return
	notice = message
	notice_time = 2.6;notice_last_at=now

func refuel() -> bool:
	if absf(speed) > 0.5:
		notify_driver("Stop to refuel")
		return false
	fuel_gallons = TANK_GALLONS
	notify_driver("Demo service: tank refilled")
	return true

func set_indicator(side: int) -> void:
	indicator = 0 if indicator == side else side
	hazards = false
	blink_time = 0.0

func toggle_engine() -> void:
	if wrecked or overturned:
		notify_driver("Truck disabled - recover or start a new truck")
		return
	engine_on = not engine_on and fuel_gallons > 0
	cruise = false
	notify_driver("Engine running" if engine_on else "Engine off")

func toggle_cruise() -> void:
	if cruise:
		cruise = false
	elif absf(speed) >= 5 and speed > 0 and engine_on and not parking_brake and not wrecked and not overturned:
		cruise_speed = speed
		cruise = true
	else:
		notify_driver("Cruise requires 12 mph and engine on")

func _ready() -> void:
	surface_sampler.van=self
	stunts.van=self
	floor_snap_length=.24
	var shape := CollisionShape3D.new()
	# Stadium footprint with vertical sides: rounded in plan without a capsule's
	# curved underside, which can ride up low Jersey barriers.
	var box := BoxShape3D.new()
	box.size = Vector3(2.5,3.15,2.8)
	shape.shape = box
	shape.position.y = 1.575
	add_child(shape)
	for z in [-1.4,1.4]:
		var end := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 1.25
		cylinder.height = 3.15
		end.shape = cylinder
		end.position = Vector3(0,1.575,z)
		add_child(end)
	camera = Camera3D.new()
	camera.far = 1700.0
	camera.near = 0.25
	camera.fov = 72.0
	add_child(camera)
	set_view(false)

func set_view(inside: bool) -> void:
	if fixed_arcade_view():
		cockpit=false;camera_high=true;camera_orbit=0;camera_pitch=0;camera_zoom=1
		if body:body.visible=true
		if not driver_on_foot:camera.make_current()
		var rig:Node=get_parent().get("fixed_camera")
		if is_instance_valid(rig):rig.update_camera(0)
		return
	inside = inside and not overturned
	cockpit = inside
	camera.position = Vector3(-0.55, 2.3, -1.65) if inside else Vector3(0, 5.3, 10)
	camera.rotation = Vector3(0, 0, 0) if inside else Vector3(-0.22, 0, 0)
	chase_heading = rotation.y
	chase_position = camera.global_position
	if body:
		body.visible = not inside
	if not driver_on_foot:
		camera.make_current()

func cycle_camera() -> void:
	if fixed_arcade_view():get_parent().fixed_camera.cycle_view();return
	if cockpit:
		camera_high=false;set_view(false)
	elif not camera_high:
		camera_high=true;set_view(false)
	else:
		camera_high=false;set_view(true)
	camera_orbit=0
	camera_pitch=0

func orbit_camera(amount:float,pitch_amount:float=0.0) -> void:
	if fixed_arcade_view():return
	if cockpit:camera_high=false;set_view(false)
	camera_manual=false
	camera_orbit=wrapf(camera_orbit+amount,-PI,PI)
	camera_pitch=clampf(camera_pitch+pitch_amount,-.18,.72)

func recenter_camera() -> void:
	if fixed_arcade_view():get_parent().fixed_camera.recenter();return
	camera_orbit=0;camera_pitch=0;camera_zoom=1;camera_manual=false
	chase_heading=rotation.y
	notify_driver("CAMERA CENTERED / DRAG TO LOOK AROUND")

func reset_vehicle() -> void:
	if stunts.active:dispose_roll_body()
	stunts.cancel()
	surface_sampler.previous.clear()
	surface_sampler.wheel_contacts.clear();surface_sampler.sample_serial+=1
	# Position reset must not erase rollover damage or bypass the recovery wait.
	if overturned:
		recover_upright()
		return
	reset_count += 1
	position = location_world.spawn_position if location_world else Vector3(260, 0.15, 0)
	rotation = Vector3(0,location_world.spawn_heading,0) if location_world else Vector3.ZERO
	speed = 0.0
	velocity = Vector3.ZERO
	distance = 0.0
	steering = 0.0
	reverse_delay = 0.0
	wall_normal = Vector3.ZERO
	wall_timer = 0.0
	parking_brake = false
	cruise = false
	wheel_distance = 0.0
	planar_velocity = Vector3.ZERO
	lateral_speed = 0.0
	slip_angle = 0.0
	yaw_rate = 0.0
	acceleration = 0.0
	impact_strength = 0.0
	impact_local = Vector3.ZERO
	tire_squeal = 0.0
	wall_ride_time = 0.0
	wall_ride_normal = Vector3.ZERO
	collision_cooldown = 0.0
	safe_position = position
	safe_heading = rotation.y
	safe_sample_time = 0.0
	if body:
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO
	set_view(cockpit)

func _process(delta: float) -> void:
	if fixed_arcade_view():return
	if not active or camera_manual or driver_on_foot:
		return
	if cockpit:
		camera.position = Vector3(-0.55,2.3,-1.65)
		camera.rotation = Vector3(clampf(-acceleration*0.0015,-0.015,0.015),0,clampf(-yaw_rate*0.025,-0.012,0.012))
		return
	# Follow world heading with a spring-like delay, rather than locking to the
	# truck's transform. Turning exposes its flank and countersteering settles it.
	var desired_heading := rotation.y-yaw_rate*1.1
	chase_heading = lerp_angle(chase_heading,desired_heading,1.0-exp(-3.0*delta))
	var base:=Vector3(-steering*1.4,6.7 if camera_high else 3.5,13.5 if camera_high else 10.5)
	var tilt:=clampf(atan2(base.y,base.z)+camera_pitch,.16,1.27)
	var radius:=Vector2(base.y,base.z).length()*camera_zoom
	var offset:=Basis(Vector3.UP,chase_heading+camera_orbit)*Vector3(base.x*camera_zoom,sin(tilt)*radius,cos(tilt)*radius)+Vector3.UP*1.8
	chase_position = chase_position.lerp(global_position+offset,1.0-exp(-7.0*delta))
	var focus:=global_position+Vector3(0,1.8,0)+planar_velocity*0.09
	var excluded:Array[RID]=[get_rid()]
	if is_instance_valid(roll_body):excluded.append(roll_body.get_rid())
	camera.global_position = camera_rig.resolve(get_world_3d().direct_space_state,focus,chase_position,excluded)
	camera.look_at(focus)

func fixed_arcade_view() -> bool:
	return is_instance_valid(location_world) and location_world.get("is_arcade")==true

func _physics_process(delta: float) -> void:
	if not active:
		return
	notice_time=maxf(0,notice_time-delta)
	surface_sampler.update(delta)
	if delivery_complete:
		engine_on=false;parking_brake=true;speed=0;velocity=Vector3.ZERO;planar_velocity=Vector3.ZERO
		throttle_load=0;rpm=0
		telemetry.emit(0,"P",distance)
		return
	update_crash_contact(delta)
	# Run before disabled/rolled early returns too: damage must never strand a
	# vehicle under the world or let the camera pass through the skyline shell.
	if outside_driveable_world():
		recover_to_road()
	blink_time += delta
	collision_cooldown = maxf(0,collision_cooldown-delta)
	wall_ride_time = maxf(0,wall_ride_time-delta)
	if stunts.active:
		stunts.tick(delta)
		telemetry.emit(absf(speed)*3.6,gear_text() if not stunts.active else ("AIR" if not roll_body.supported else "LANDING"),distance)
		return
	if driver_on_foot and not overturned and not wrecked:
		engine_on = false
		speed = 0
		planar_velocity = Vector3.ZERO
		throttle_load = 0
		rpm = 0
		velocity = Vector3(0,velocity.y-9.81*delta,0)
		move_and_slide()
		telemetry.emit(0,"ON FOOT",distance)
		return
	if overturned or wrecked:
		if overturned:
			simulate_crash(delta)
			if not overturned and not wrecked:
				telemetry.emit(0,gear_text(),distance)
				return
		impact_strength = move_toward(impact_strength,0,delta*8)
		engine_on = false
		cruise = false
		speed = 0.0
		rpm = 0.0
		throttle_load = 0.0
		brake_load = 0.0
		if not overturned:
			velocity = Vector3(0,velocity.y-22.0*delta,0)
			move_and_slide()
		telemetry.emit(0, "DISABLED" if wrecked else ("IMPACT" if location_world and not flip_registered else "ROLLED"),distance)
		return
	impact_strength = move_toward(impact_strength,0,delta*8)
	wall_timer = maxf(0,wall_timer-delta)
	var throttle := Input.get_action_strength("accelerate")
	var previous_speed := speed
	var brake := Input.get_action_strength("brake_reverse")
	var direction := Input.get_axis("steer_right", "steer_left")
	brake_load = maxf(brake,float(Input.is_action_pressed("handbrake") or parking_brake))
	if brake_load > 0 or not engine_on or fuel_gallons <= 0:
		cruise = false
	if cruise:
		throttle = maxf(throttle,clampf((cruise_speed-speed)*1.8+0.22,0,1))
	if not engine_on or fuel_gallons <= 0:
		throttle = 0.0
	throttle_load = throttle
	# Braking takes priority; a short standstill hold prevents surprise reverse.
	if brake > 0:
		if speed > 0.05:
			speed = move_toward(speed, 0.0, 6.0 * brake * delta)
			reverse_delay = 0.0
		else:
			reverse_delay += delta
			if reverse_delay >= 0.45 and engine_on and fuel_gallons > 0:
				speed = move_toward(speed, -4.0, 2.0 * brake * delta)
	elif throttle > 0:
		speed = move_toward(speed, 34.72, 3.0 * throttle * delta)
		reverse_delay = 0.0
	else:
		speed = move_toward(speed, 0.0, 0.65 * delta)
		reverse_delay = 0.0
	if ground_kind=="grass":speed=move_toward(speed,0,delta*(.35+absf(speed)*.02+vegetation_contact*.75))
	if Input.is_action_pressed("handbrake") or parking_brake:
		speed = move_toward(speed, 0.0, 10.0 * delta)
	var response := 9.0 if steering*direction<0 else (8.0 if direction==0 else 6.5)
	steering = move_toward(steering,direction,delta*response)
	var previous_heading := rotation.y
	var turn_speed := speed
	# Low-speed recovery remains steerable after impact instead of requiring speed
	# that a pressed-against wall cannot produce. Reverse retains reversed steering.
	if wall_timer > 0 and absf(speed) < 3 and (throttle > 0 or brake > 0):
		turn_speed = -3.0 if brake > 0 else 3.0
		rotation.y += steering*delta*0.55*(-1.0 if brake > 0 else 1.0)
	else:
		rotation.y += steering*turn_speed*delta*steering_gain(turn_speed)
	var forward := -global_transform.basis.z
	yaw_rate = (rotation.y-previous_heading)/delta
	acceleration = (speed-previous_speed)/delta
	var right := global_transform.basis.x
	# Retain sideways momentum as the chassis changes heading. Space releases
	# rear grip while braking; normal grip catches the truck when released.
	var sliding := Input.is_action_pressed("handbrake") and absf(speed)>5 and not parking_brake
	var grip := 1.6 if sliding else 4.8
	lateral_speed = planar_velocity.dot(right)*exp(-grip*delta)
	var limit := minf(absf(speed)*0.35,5.0)
	lateral_speed = clampf(lateral_speed,-limit,limit)
	if absf(speed)<2 or parking_brake:
		lateral_speed = 0.0
	var longitudinal := sqrt(maxf(0,speed*speed-lateral_speed*lateral_speed))*signf(speed)
	planar_velocity = forward*longitudinal+right*lateral_speed
	slip_angle = atan2(lateral_speed,maxf(absf(longitudinal),0.1))
	var turn_squeal := clampf((absf(lateral_speed)-0.6)/1.2,0,1)*clampf((absf(yaw_rate)-0.15)/0.1,0,1)
	var stop_squeal := brake_load*clampf((-acceleration-4.0)/5.0,0,1)
	var squeal_target := maxf(turn_squeal,stop_squeal)*clampf((absf(speed)-4.0)/7.0,0,1)
	tire_squeal = move_toward(tire_squeal,squeal_target,delta*(8 if squeal_target>tire_squeal else 4))
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.z
	if wall_timer > 0:
		var horizontal := Vector3(velocity.x,0,velocity.z)
		if horizontal.dot(wall_normal) < 0:
			horizontal = horizontal.slide(wall_normal)
		# Gentle solver motion away from contact, never a position teleport.
		horizontal += wall_normal*0.65
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	velocity.y -= (9.81 if location_world else 22.0) * delta
	# A short physical climb stays below the crest of the highway barrier.
	if wall_ride_time>0 and velocity.y>0:
		velocity.y = minf(velocity.y,maxf(0,(0.75-position.y)/delta))
	var before := position
	move_and_slide()
	for index in get_slide_collision_count():
		if absf(get_slide_collision(index).get_normal().y) < 0.4:
			var contact := get_slide_collision(index)
			var other := contact.get_collider()
			if other is RigidBody3D:
				var normal := contact.get_normal()
				var relative: Vector3 = planar_velocity-other.linear_velocity
				var closing := maxf(0,-relative.dot(normal))
				var barrel: bool = other.is_in_group("construction_barrel")
				var impulse := -normal*minf(closing*other.mass*0.8,other.mass*12.0)
				other.apply_impulse(impulse,contact.get_position()-other.global_position)
				other.apply_central_force(-normal*throttle*3200.0)
				register_collision(absf(speed),closing*(0.15 if barrel else 1.0))
				if closing>0.8:
					impact_local = global_basis.inverse()*normal*minf(closing/12,0.3 if barrel else 1)
					impact_serial += 1
				if not barrel:
					wall_normal = normal
					if begin_rollover(absf(speed),closing,(global_basis.inverse()*normal).x):
						break
				speed *= 1.0-clampf(other.mass/(3200.0+other.mass)*absf(forward.dot(normal)),0,0.45)
				cruise = false
				wall_timer = 0.0
				continue
			wall_normal = get_slide_collision(index).get_normal()
			wall_normal.y = 0
			wall_normal = wall_normal.normalized()
			wall_timer = 0.3
			var closing_speed := maxf(0,-planar_velocity.dot(wall_normal))
			register_collision(absf(speed),closing_speed)
			if location_world and other is StaticBody3D and other.has_meta("barrier_kind") and absf(speed)>=22 and closing_speed>=12:
				planar_velocity=location_world.barriers.try_break(other,planar_velocity,wall_normal,contact.get_position())
			if begin_rollover(absf(speed),closing_speed,(global_basis.inverse()*wall_normal).x,location_world!=null):
				break
			begin_wall_ride(absf(speed),closing_speed)
			if closing_speed > 0.8:
				impact_local = global_basis.inverse()*wall_normal*minf(closing_speed/12.0,1.0)
				impact_serial += 1
			impact_strength = maxf(impact_strength,absf(speed)/12.0)
			cruise = false
			# Dissipate speed aimed into the wall immediately; the old scalar speed
			# could remain high after the actual body had stopped.
			speed *= maxf(0,1.0-absf(forward.dot(wall_normal)))
			speed = move_toward(speed, 0.0, 18.0 * delta)
	planar_velocity = Vector3(velocity.x,0,velocity.z)
	var moved := Vector2(position.x-before.x,position.z-before.z).length()
	distance += moved
	wheel_distance += Vector3(position.x-before.x,0,position.z-before.z).dot(forward)
	if engine_on and fuel_gallons > 0:
		fuel_gallons = maxf(0,fuel_gallons-moved/1609.344/18.0-delta*0.000025)
		if fuel_gallons <= 0:
			engine_on = false
			cruise = false
			notify_driver("Out of fuel - stop and press F for demo service")
	var target_temp := 175.0+throttle*20 if engine_on else 75.0
	temperature_f = move_toward(temperature_f,target_temp,delta*(0.6 if engine_on else 0.25))
	var stage := 1+int(absf(speed)>5)+int(absf(speed)>11)+int(absf(speed)>18)+int(absf(speed)>26)
	var target_rpm := 780.0+absf(speed)*310.0/stage+throttle*380.0
	rpm = move_toward(rpm,target_rpm if engine_on else 0.0,delta*2400)
	safe_sample_time = maxf(0,safe_sample_time-delta)
	if is_on_floor() and (location_world or absf(position.y)<0.2) and safe_sample_time==0 and not overturned:
		safe_sample_time = 0.75
		if on_known_road(position):
			var candidate := position+Vector3.UP*0.15 if location_world else Vector3(position.x,0.15,position.z)
			if recovery_space_clear(candidate,rotation.y):
				safe_position = candidate
				safe_heading = rotation.y
	telemetry.emit(absf(speed) * 3.6,gear_text(),distance)
