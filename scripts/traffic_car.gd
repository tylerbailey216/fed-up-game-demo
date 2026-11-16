extends RigidBody3D
## Force-driven traffic: sensing/braking never locks a car against player pushes.
var district: Node3D
var route: Array[Vector3] = []
var waypoint := 0
var cruise_speed := 9.0
var blocked_time := 0.0
var horn_cooldown := 0.0
var last_target_speed := 0.0
var waiting_for_signal := false
var wheel_nodes: Array[Node3D] = []
var wheel_roll := 0.0
var horn_player: AudioStreamPlayer3D
var impact_player: AudioStreamPlayer3D
var brake_material: StandardMaterial3D

func _ready() -> void:
	mass = 1100
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 0.35
	angular_damp = 2.5
	continuous_cd = true
	var tire_contact := PhysicsMaterial.new()
	tire_contact.friction = 0.05
	tire_contact.bounce = 0.05
	physics_material_override = tire_contact
	contact_monitor = true
	max_contacts_reported = 8
	add_to_group("traffic_vehicle")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.95,1.5,4.3)
	shape.shape = box
	shape.position.y = 0.75
	add_child(shape)
	horn_player = AudioStreamPlayer3D.new()
	horn_player.stream = preload("res://assets/audio/horn.wav")
	horn_player.volume_db = -16
	horn_player.max_distance = 65
	horn_player.unit_size = 8
	add_child(horn_player)
	impact_player = AudioStreamPlayer3D.new()
	impact_player.stream = preload("res://assets/audio/impact.wav")
	impact_player.volume_db = -9
	impact_player.max_distance = 75
	impact_player.unit_size = 10
	add_child(impact_player)
	body_entered.connect(func(other: Node):
		if (other.is_in_group("traffic_vehicle") or other == district.game.van) and linear_velocity.length()>2:
			impact_player.play()
	)

func _physics_process(delta: float) -> void:
	if not district.game.van.active or route.is_empty() or freeze:
		return
	var master: float = district.game.master_volume
	impact_player.volume_db = linear_to_db(maxf(0.0001,master*0.4))
	if master==0:
		impact_player.stop()
		horn_player.stop()
	var target := route[waypoint]
	var gap := Vector3(target.x-position.x,0,target.z-position.z)
	if gap.length()<6:
		waypoint = (waypoint+1)%route.size()
		target = route[waypoint]
		gap = Vector3(target.x-position.x,0,target.z-position.z)
	var heading := atan2(-gap.x,-gap.z)
	var error := wrapf(heading-rotation.y,-PI,PI)
	var speed := Vector3(linear_velocity.x,0,linear_velocity.z).length()
	var desired := cruise_speed
	if absf(error)>0.25 or gap.length()<13:
		desired = minf(desired,4.5)
	var signal_limit: float = district.signal_speed_limit(self)
	waiting_for_signal = signal_limit<desired
	desired = minf(desired,signal_limit)
	var forward := -global_basis.z
	var ray_length := maxf(5.0,speed*speed/9.0+3.0)
	for side in [-0.65,0.65]:
		var start: Vector3 = global_position+Vector3(0,0.8,0)+forward*2.25+global_basis.x*side
		var query := PhysicsRayQueryParameters3D.create(start,start+forward*ray_length)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var distance: float = start.distance_to(hit.position)
			desired = minf(desired,sqrt(maxf(0,2.0*4.5*(distance-2.0))))
	last_target_speed = desired
	var target_velocity := forward*desired
	var horizontal := Vector3(linear_velocity.x,0,linear_velocity.z)
	var force := (target_velocity-horizontal)*mass*1.8
	force = force.limit_length(mass*5.0)
	apply_central_force(force)
	angular_velocity.y = move_toward(angular_velocity.y,clampf(error*2.4,-1.3,1.3)*clampf(speed/2.0,0,1),delta*2.5)
	blocked_time = blocked_time+delta if desired<0.5 and not waiting_for_signal else 0.0
	horn_cooldown = maxf(0,horn_cooldown-delta)
	if blocked_time>2.0 and horn_cooldown==0 and master>0:
		horn_player.volume_db = linear_to_db(maxf(0.001,district.game.master_volume*0.18))
		horn_player.play()
		horn_cooldown = 7.0
	if brake_material:
		brake_material.albedo_color = Color("ff5049") if desired<speed-0.5 or desired<0.5 else Color("8e2634")
	wheel_roll -= speed*delta/0.34
	for wheel in wheel_nodes:
		wheel.rotation.x = wheel_roll
		wheel.rotation.y = clampf(error,-0.4,0.4) if wheel.position.z<0 else 0.0
	# A car shoved off its lane steers back physically; no path-position snapping.
	if position.y < -10:
		linear_velocity = Vector3.ZERO
		position = route[waypoint]+Vector3(0,0.1,0)
