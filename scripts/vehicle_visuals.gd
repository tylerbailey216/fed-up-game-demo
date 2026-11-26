extends Node
var van: Node
var wheels: Array[Node3D] = []
var doors: Array[Node3D] = []
var lamps: Dictionary = {}
var suspension := Vector3.ZERO
var suspension_velocity := Vector3.ZERO
var seen_impact := 0
var seen_reset := 0
var smoke: CPUParticles3D
var exhaust: CPUParticles3D
var exhaust_puff_time := 0.0
var exhaust_cooldown := 0.0
var previous_throttle := 0.0
var exhaust_bursts := 0
var headlight_was_on:=false
var headlight_update:=0.0
var seen_surface_bump:=0
var reindeer_legs:Array[Node]=[]
var turkey_legs:Array[Node]=[]
var organic_mount:=false
var turkey_rider:Node3D

func _ready() -> void:
	find_wheels(van.body)
	reindeer_legs=van.body.find_children("ReindeerLeg_*","Node3D",true,false)
	turkey_legs=van.body.find_children("TurkeyLeg_*","Node3D",true,false)
	organic_mount=not turkey_legs.is_empty()
	turkey_rider=van.body.find_child("TurkeyRider",true,false) as Node3D
	smoke = CPUParticles3D.new()
	smoke.emitting = false
	smoke.amount = 56
	smoke.lifetime = 3.5
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 24
	smoke.gravity = Vector3(0.3,0.5,0)
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 2.2
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.4
	var growth := Curve.new()
	growth.max_value = 3.0
	growth.add_point(Vector2(0,0.3))
	growth.add_point(Vector2(1,2.5))
	smoke.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0,Color(0.13,0.14,0.16,0.85))
	fade.set_color(1,Color(0.37,0.39,0.41,0))
	smoke.color_ramp = fade
	var puff := SphereMesh.new()
	puff.radius = 0.4
	puff.height = 0.8
	puff.radial_segments = 8
	puff.rings = 4
	var soot := StandardMaterial3D.new()
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.vertex_color_use_as_albedo = true
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = soot
	smoke.mesh = puff
	van.add_child(smoke)
	exhaust = smoke.duplicate() as CPUParticles3D
	exhaust.amount = 36
	exhaust.lifetime = 1.1
	exhaust.direction = Vector3(0,0.2,1)
	exhaust.gravity = Vector3(0,0.6,0)
	exhaust.spread = 18
	exhaust.initial_velocity_min = 1.8
	exhaust.initial_velocity_max = 3.2
	exhaust.scale_amount_min = 0.25
	exhaust.scale_amount_max = 0.65
	var exhaust_fade := Gradient.new()
	exhaust_fade.set_color(0,Color(0.32,0.34,0.36,0.6))
	exhaust_fade.set_color(1,Color(0.55,0.57,0.59,0))
	exhaust.color_ramp = exhaust_fade
	van.add_child(exhaust)
	var pipe := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.075
	tube.bottom_radius = 0.075
	tube.height = 0.35
	pipe.mesh = tube
	pipe.rotation.x = PI/2
	pipe.position = Vector3(-0.92,0.38,2.55)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("333b42")
	pipe.material_override = metal
	van.body.add_child(pipe)
	pipe.visible=not organic_mount
	var id:String=str(van.get_parent().get("vehicle_id"))
	var front_z:float=-2.9 if id=="semi" else (-2.07 if id=="tank" else (-.43 if id=="sleigh" else -2.475))
	var rear_z:float=3.37 if id=="semi" else (2.16 if id=="tank" else (2.56 if id=="sleigh" else 2.48))
	for side in [-1,1]:
		make_lamp("head"+str(side),Vector3(side*0.87,1.19,front_z),Vector3(0.27,0.24,0.025))
		make_lamp("front"+str(side),Vector3(side*0.87,1.49,front_z+.04),Vector3(0.30,0.10,0.025))
		make_lamp("rear"+str(side),Vector3(side*0.89,0.85,rear_z),Vector3(0.15,0.20,0.025))
		make_lamp("signal"+str(side),Vector3(side*0.89,1.11,rear_z),Vector3(0.17,0.11,0.025))

func find_wheels(node: Node) -> void:
	if node is Node3D and str(node.name).begins_with("RearDoorPivot_"):
		doors.append(node)
	if node is Node3D and str(node.name).begins_with("WheelPivot_"):
		wheels.append(node)
	for child in node.get_children():
		find_wheels(child)

func make_lamp(id: String, pos: Vector3, size: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	node.visible=not organic_mount
	van.body.add_child(node)
	lamps[id] = material

func _physics_process(delta: float) -> void:
	if turkey_rider:turkey_rider.visible=not van.driver_on_foot
	for leg in turkey_legs:
		var moving:float=clampf(absf(van.speed)/2,0,1) if not van.wrecked and not van.overturned else 0.0
		var gait:float=sin(van.wheel_distance*2.4+float(leg.get_meta("gait_phase")))
		leg.rotation.x=lerpf(leg.rotation.x,gait*.55*moving,minf(1,delta*12))
		leg.get_node("Knee").rotation.x=lerpf(leg.get_node("Knee").rotation.x,maxf(0,-gait)*.85*moving,minf(1,delta*12))
	var flying:bool=van.fleet_flight and (van.fleet_flight.enabled or van.fleet_flight.landing)
	for leg in reindeer_legs:
		var gait:=sin(van.wheel_distance*2.5+float(leg.get_meta("gait_phase")))
		leg.rotation.x=lerpf(leg.rotation.x,(-.45+gait*.08) if flying else gait*.45*minf(1,absf(van.speed)),minf(1,delta*12))
		leg.get_node("Knee").rotation.x=.85 if flying else maxf(0,-gait)*.65*minf(1,absf(van.speed))
	for wheel in wheels:
		if wheel.has_meta("fleet_base"):
			var base:Vector3=wheel.get_meta("fleet_base")
			wheel.position.y=move_toward(wheel.position.y,base.y+(.48 if flying else 0),delta*1.5)
	for door in doors:
		var side := -1.0 if str(door.name).ends_with("L") else 1.0
		door.rotation.y = move_toward(door.rotation.y,side*2.05 if van.cargo_open else 0.0,delta*4)
	if seen_reset != van.reset_count:
		suspension = Vector3.ZERO
		suspension_velocity = Vector3.ZERO
		seen_reset = van.reset_count
		previous_throttle = 0.0
		exhaust_puff_time = 0.0
		exhaust_cooldown = 0.0
		exhaust.restart()
		exhaust.emitting = false
		if not van.wrecked:
			smoke.restart()
			smoke.emitting = false
	if seen_impact != van.impact_serial:
		suspension_velocity += Vector3(van.impact_local.z*0.65,van.impact_local.x*0.3,-van.impact_local.x*0.8)
		seen_impact = van.impact_serial
	if seen_surface_bump!=van.surface_bump_serial:
		suspension_velocity+=Vector3(van.surface_bump_strength*.8,0,van.ground_tilt.y*3)
		seen_surface_bump=van.surface_bump_serial
	var target := Vector3(clampf(-van.acceleration*0.004,-0.035,0.035),clampf(-van.slip_angle*0.16,-0.035,0.035),clampf(-van.yaw_rate*van.speed*0.009,-0.075,0.075)) if van.active else Vector3.ZERO
	target.x+=van.ground_tilt.x;target.z+=van.ground_tilt.y
	if van.ground_kind=="grass" and absf(van.speed)>1:
		target.x+=sin(van.wheel_distance*5)*.009;target.z+=sin(van.wheel_distance*3.3)*(.007+van.vegetation_contact*.012)
	suspension_velocity += ((target-suspension)*65.0-suspension_velocity*11.0)*delta
	suspension += suspension_velocity*delta
	suspension = suspension.clamp(Vector3(-0.1,-0.06,-0.12),Vector3(0.1,0.06,0.12))
	van.body.rotation = suspension
	if (van.overturned or van.stunts.active) and is_instance_valid(van.roll_body):
		van.body.global_transform = van.roll_body.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-1.575,0))
	else:
		van.body.position = Vector3.ZERO
		if van.wall_ride_time>0:
			var ride: float = sin(clampf(van.wall_ride_time/0.9,0,1)*PI)
			var side: float = (van.global_basis.inverse()*van.wall_ride_normal).x
			van.body.rotation = Vector3(-ride*0.18,0,-side*ride*0.5)
			var center := Vector3(0,1.6,0)
			van.body.position = center-van.body.basis*center
	smoke.global_position = van.body.to_global(Vector3(0,1.25,-2.0))
	smoke.emitting = van.wrecked and van.active and not organic_mount
	exhaust_cooldown = maxf(0,exhaust_cooldown-delta)
	exhaust_puff_time = maxf(0,exhaust_puff_time-delta)
	var accelerating: bool = van.active and van.engine_on and not van.overturned and not van.wrecked and van.throttle_load>0.2 and van.acceleration>0.5
	if accelerating and (previous_throttle<=0.2 or exhaust_cooldown==0):
		exhaust_puff_time = 0.22
		exhaust_cooldown = 0.9
		exhaust_bursts += 1
	previous_throttle = van.throttle_load
	exhaust.global_position = van.body.to_global(Vector3(-0.92,0.38,2.73))
	exhaust.emitting = accelerating and exhaust_puff_time>0 and not organic_mount
	for wheel in wheels:
		wheel.rotation.x = -van.wheel_distance/float(wheel.get_meta("fleet_radius",.46))
		wheel.rotation.y = van.steering*0.38 if "Front" in str(wheel.name) else 0.0
	var flash: bool = fmod(van.blink_time,1.0) < 0.5
	for side in [-1,1]:
		var signal_on: bool = flash and (van.hazards or van.indicator == side)
		lamps["head"+str(side)].albedo_color = Color("fff3be") if van.headlights else Color("77786e")
		lamps["front"+str(side)].albedo_color = Color("ffd04b") if signal_on else Color("7e421a")
		lamps["signal"+str(side)].albedo_color = Color("ffd04b") if signal_on else Color("7e421a")
		lamps["rear"+str(side)].albedo_color = Color("ff4540") if van.brake_load > 0 else Color("9b242c")
	# The cel-shaded world uses an explicit, inexpensive road illumination pool.
	var lit:bool=van.headlights and van.active
	headlight_update+=delta
	if not lit and not headlight_was_on:return
	if lit and headlight_was_on and headlight_update<.05:return
	headlight_update=0
	for material in get_parent().highway.art.cache.values():
		material.set_shader_parameter("headlight_position",van.global_position)
		material.set_shader_parameter("headlight_forward",-van.global_basis.z)
		material.set_shader_parameter("headlight_strength",1.0 if van.headlights and van.active else 0.0)
		material.set_shader_parameter("headlight_range",65.0 if van.high_beam else 35.0)
	headlight_was_on=lit
