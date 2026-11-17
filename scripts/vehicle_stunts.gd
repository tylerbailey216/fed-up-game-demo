extends RefCounted
## High-speed curb launch assist; ballistic flight and landings are rigid-body motion.
const MIN_SPEED:=22.0 # 49 mph total; a fast grazing pass is not a ramp hit.
const MIN_CROSSING_SPEED:=16.0
var van:Node
var active:=false
var cooldown:=0.0
var elapsed:=0.0
var air_time:=0.0
var peak_air_time:=0.0
var support_time:=0.0
var launch_serial:=0
var landing_serial:=0
var launch_speed:=0.0
var launch_vertical:=0.0
var launch_energy:=0.0
var last_landing_speed:=0.0
var seen_contact:=0
var braking:=false
var shadow_clock:=0.0
var shadow_height:=0.0

func scan_curb(delta:float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if active or cooldown>0 or van.overturned or van.wrecked or van.driver_on_foot or not van.active:return
	if van.speed<MIN_SPEED or not van.is_on_floor():return
	var motion:Vector3=van.planar_velocity
	if motion.length()<MIN_SPEED:return
	var heading:=motion.normalized();var side:Vector3=van.global_basis.x
	var space:PhysicsDirectSpaceState3D=van.get_world_3d().direct_space_state
	var best:Dictionary={};var crossing:=0.0;var side_sum:=0.0;var hits:=0
	# Short front-tire sweeps catch the bevel before floor snapping glues the cab up it.
	for x in [-.95,.95]:
		var from:Vector3=van.global_position+heading*2.05+side*x+Vector3.UP*.055
		var query:=PhysicsRayQueryParameters3D.create(from,from+heading*maxf(.85,motion.length()*delta+.65),1)
		query.exclude=[van.get_rid()]
		var hit:=space.intersect_ray(query)
		if hit.is_empty() or not hit.collider.is_in_group("raised_street_surface") or hit.normal.y<.45:continue
		var n:Vector3=Vector3(hit.normal.x,0,hit.normal.z).normalized()
		var closing:=maxf(0,-motion.dot(n))
		if closing<MIN_CROSSING_SPEED:continue
		var point:Vector3=hit.position+heading*.45
		var top_query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.65,point-Vector3.UP*.65,1);top_query.exclude=[van.get_rid()]
		var top:=space.intersect_ray(top_query)
		if top.is_empty() or not top.collider.is_in_group("raised_street_surface"):continue
		var rise:float=top.position.y-van.position.y
		if rise<.055 or rise>.38:continue
		side_sum+=x;hits+=1
		if closing>crossing:crossing=closing;best={"rise":rise,"normal":n,"side":x}
	if not best.is_empty():launch(float(best.rise),crossing,side_sum/maxi(1,hits))

func launch(rise:float,crossing:float,side:float) -> bool:
	if active or van.overturned or van.wrecked or van.driver_on_foot or van.speed<MIN_SPEED or crossing<MIN_CROSSING_SPEED:return false
	var incoming:Vector3=van.planar_velocity
	launch_speed=incoming.length()
	# The suspension/tire spreads a 16 cm bevel over an effective .95 m rise.
	# Redirect existing momentum upward; never add translational kinetic energy.
	launch_vertical=minf(5.8,crossing*sin(atan2(rise,.95)))
	if launch_vertical<2:return false
	var lift:=rise*.5
	var horizontal:=sqrt(maxf(0,incoming.length_squared()-launch_vertical*launch_vertical-19.62*lift))
	var outgoing:=incoming.normalized()*horizontal+Vector3.UP*launch_vertical
	launch_energy=outgoing.length_squared()+19.62*lift
	van.impact_engine_was_on=van.engine_on
	van.create_motion_body(true,true)
	van.roll_body.set_meta("stunt_motion",true)
	# Initialize the same front-up/rear-down pose that straddling the bevel imposes.
	var pose:Basis=van.global_basis*Basis(Vector3.RIGHT,atan2(rise,5.3))
	van.roll_body.global_transform=Transform3D(pose,van.global_position+Vector3.UP*(1.575+lift))
	van.roll_body.linear_velocity=outgoing
	van.roll_body.previous_linear=outgoing
	# Most front-axle pitch is cancelled by rear-axle/suspension loading.
	# A one-sided strike retains a small physical roll bias rather than a forced flip.
	van.roll_body.angular_velocity=van.global_basis*Vector3(launch_vertical*.045,van.yaw_rate,side*launch_vertical*.025)
	van.roll_body.linear_damp=.035;van.roll_body.angular_damp=.35
	van.roll_body.contact_monitor=true;van.roll_body.max_contacts_reported=12
	active=true;elapsed=0;air_time=0;peak_air_time=0;support_time=0;seen_contact=0;braking=false
	launch_serial+=1;cooldown=1.25
	van.tire_squeal=0;van.wall_timer=0;van.wall_ride_time=0;van.ground_tilt=Vector2.ZERO
	van.set_view(false);van.notify_driver("CURB JUMP / HOLD YOUR LINE")
	return true

func tick(delta:float) -> void:
	if not is_instance_valid(van.roll_body):active=false;return
	var rigid:RigidBody3D=van.roll_body
	elapsed+=delta
	var before:Vector3=van.position
	van.global_position=rigid.global_position-Vector3.UP*1.575
	var forward:Vector3=-rigid.global_basis.z
	if Vector2(forward.x,forward.z).length()>.25:van.rotation.y=atan2(-forward.x,-forward.z)
	van.planar_velocity=Vector3(rigid.linear_velocity.x,0,rigid.linear_velocity.z)
	van.velocity=rigid.linear_velocity
	van.speed=van.planar_velocity.dot(-van.global_basis.z)
	van.distance+=Vector2(van.position.x-before.x,van.position.z-before.z).length()
	van.wheel_distance+=van.speed*delta
	van.throttle_load=Input.get_action_strength("accelerate") if van.engine_on else 0
	var stage:=1+int(absf(van.speed)>5)+int(absf(van.speed)>11)+int(absf(van.speed)>18)+int(absf(van.speed)>26)
	van.rpm=move_toward(van.rpm,(780+absf(van.speed)*310/stage+van.throttle_load*380) if van.engine_on else 0,delta*2400)
	if van.engine_on and van.fuel_gallons>0:
		van.fuel_gallons=maxf(0,van.fuel_gallons-van.planar_velocity.length()*delta/1609.344/18.0-delta*.000025)
		if van.fuel_gallons==0:van.engine_on=false;van.cruise=false
	van.temperature_f=move_toward(van.temperature_f,175+van.throttle_load*20 if van.engine_on else 75,delta*(.6 if van.engine_on else .25))
	van.tire_squeal=0
	if not rigid.supported:
		air_time+=delta;peak_air_time=maxf(peak_air_time,air_time);support_time=0
	else:support_time+=delta
	consume_contact()
	# Braking a spinning wheel transfers a small, bounded nose-down impulse.
	var brake:bool=Input.is_action_pressed("brake_reverse") or Input.is_action_pressed("handbrake")
	if brake and not braking and not rigid.supported:
		rigid.apply_torque_impulse(-van.global_basis.x*rigid.mass*minf(.35,absf(van.speed)*.01))
	braking=brake
	if rigid.supported and brake:
		rigid.apply_central_force(-rigid.linear_velocity.normalized()*rigid.mass*5)
	update_shadow(delta)
	var up:float=rigid.global_basis.y.dot(Vector3.UP)
	# A truck wedged on a raised edge must still reach the normal recovery flow.
	var resting_tilt:bool=support_time>1.0 and up<=.98 and rigid.linear_velocity.length()<.3 and rigid.angular_velocity.length()<.15
	if up<.2 or resting_tilt:
		active=false;van.overturned=true;van.roll_time=0;van.roll_settled=false;van.roll_stable_time=0;van.flip_registered=false
		van.engine_on=false;van.cruise=false
		return
	if elapsed>.35 and support_time>.18 and rigid.global_basis.y.dot(Vector3.UP)>.98 and rigid.angular_velocity.length()<.65 and absf(rigid.linear_velocity.y)<.65:
		finish()

func update_shadow(delta:float) -> void:
	if not is_instance_valid(van.contact_shadow):return
	shadow_clock-=delta
	if shadow_clock<=0:
		shadow_clock=.05
		var query:=PhysicsRayQueryParameters3D.create(van.position+Vector3.UP,van.position-Vector3.UP*15,1)
		query.exclude=[van.get_rid()]
		if is_instance_valid(van.roll_body):query.exclude.append(van.roll_body.get_rid())
		var ground:Dictionary=van.get_world_3d().direct_space_state.intersect_ray(query)
		van.contact_shadow.visible=not ground.is_empty()
		if not ground.is_empty():shadow_height=ground.position.y
	van.contact_shadow.global_position=Vector3(van.position.x,shadow_height+.025,van.position.z)

func consume_contact() -> void:
	if not is_instance_valid(van.roll_body) or not van.roll_body.has_meta("stunt_motion"):return
	var rigid:Node=van.roll_body
	if rigid.contact_serial==seen_contact:return
	seen_contact=rigid.contact_serial
	if elapsed<.15:return
	var closing:float=rigid.contact_speed
	var landing:bool=rigid.contact_normal.y>.45
	if landing and closing>1:
		last_landing_speed=closing;landing_serial+=1
		van.surface_bump_serial+=1;van.surface_bump_strength=clampf(closing/9,.15,.85)
	if closing>=(3.2 if landing else .8):
		van.register_collision(launch_speed,closing)
		van.notify_driver("HARD LANDING / CHECK TRUCK ENERGY" if landing else "IMPACT / CHECK TRUCK ENERGY")

func finish() -> void:
	var motion:Vector3=van.roll_body.linear_velocity
	active=false;cooldown=1.25
	van.dispose_roll_body()
	van.velocity=motion;van.planar_velocity=Vector3(motion.x,0,motion.z)
	van.speed=van.planar_velocity.dot(-van.global_basis.z)
	van.surface_sampler.previous.clear();van.ground_tilt=Vector2.ZERO
	if is_instance_valid(van.contact_shadow):van.contact_shadow.position=Vector3(0,.025,0);van.contact_shadow.show()

func cancel() -> void:
	active=false;cooldown=.2;elapsed=0;air_time=0;support_time=0
	if is_instance_valid(van.contact_shadow):van.contact_shadow.position=Vector3(0,.025,0);van.contact_shadow.show()
