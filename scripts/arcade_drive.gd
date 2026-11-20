extends RefCounted
## Delivery Mayhem only: screen direction requests travel, not steering lock.
## The CharacterBody still resolves terrain, collisions, jumps and damage.
const MAX_SPEED:=10.0 # About 22 mph, appropriate to a small city block.
const ACCELERATION:=8.0
const BRAKING:=14.0
const TURN_RATE:=3.3
const MOMENTUM_RESPONSE:=16.0

func update(van:CharacterBody3D,delta:float) -> float:
	var input:=Input.get_vector("steer_left","steer_right","accelerate","brake_reverse",.12)
	var strength:=input.length()
	var previous_speed:float=van.speed
	var previous_heading:float=van.rotation.y
	var target_speed:=0.0
	var turn_error:=0.0
	var powered:bool=van.engine_on and van.fuel_gallons>0 and not van.parking_brake
	van.cruise=false;van.reverse_delay=0
	if strength>.01 and powered:
		# BEARING=0: screen right is world +X, screen up is world -Z.
		var wanted:=Vector3(input.x,0,input.y).normalized()
		var heading:=atan2(-wanted.x,-wanted.z)
		turn_error=wrapf(heading-van.rotation.y,-PI,PI)
		# Brake into sharp turns, including a deliberate forward U-turn.
		# Heading response is independent of speed, so walls cannot lock steering.
		target_speed=MAX_SPEED*strength*lerpf(.22,1.0,pow(maxf(0,cos(turn_error)),.65))
		van.rotation.y+=clampf(turn_error,-TURN_RATE*delta,TURN_RATE*delta)
	var slowing:bool=target_speed<van.speed
	van.speed=move_toward(maxf(0,van.speed),target_speed,(BRAKING if slowing else ACCELERATION)*delta)
	if van.ground_kind=="grass":van.speed=move_toward(van.speed,0,delta*(.8+van.vegetation_contact*.75))
	var forward:Vector3=-van.global_basis.z
	var target_velocity:Vector3=forward*van.speed
	# Small, bounded momentum gives a truck feel without a highway turning circle.
	van.planar_velocity=van.planar_velocity.move_toward(target_velocity,(MOMENTUM_RESPONSE if strength>.01 else BRAKING+4)*delta)
	if strength<=.01 and van.planar_velocity.length()<.05:
		van.planar_velocity=Vector3.ZERO;van.speed=0
	van.yaw_rate=wrapf(van.rotation.y-previous_heading,-PI,PI)/delta
	van.acceleration=(van.speed-previous_speed)/delta
	van.steering=move_toward(van.steering,clampf(turn_error,-1,1) if strength>.01 else 0,delta*8)
	van.lateral_speed=van.planar_velocity.dot(van.global_basis.x)
	van.slip_angle=atan2(van.lateral_speed,maxf(.1,van.planar_velocity.dot(forward)))
	van.brake_load=1.0 if slowing or not powered else 0.0
	van.throttle_load=strength if powered else 0.0
	var turn_squeal:=clampf((absf(van.lateral_speed)-1.0)*.5,0,1)
	var stop_squeal:float=van.brake_load*clampf((-van.acceleration-4)/5,0,1)
	var squeal:float=maxf(turn_squeal,stop_squeal)*clampf((van.speed-3)/4,0,1)
	van.tire_squeal=move_toward(van.tire_squeal,squeal,delta*6)
	return van.throttle_load
