extends RefCounted
## Preserve package identities and physical bumps, while preventing a lost load
## from becoming impossible to finish. One audit per 0.08 s spreads query cost.
var cargo:Node
var origin:=Vector3.ZERO
var ready:=false
var clock:=0.0
var audit_clock:=0.0
var index:=0
var rescued:=0
const MAX_DISTANCE:=70.0

func update(delta:float) -> void:
	if not cargo.spilled or cargo.load_restored:return
	clock+=delta
	if not ready:
		if not cargo.on_foot:return
		origin=cargo.safe_foot_position;ready=true
	audit_clock+=delta
	if audit_clock<.08 or cargo.packages.is_empty():return
	audit_clock=0
	var item:Dictionary=cargo.packages[index%cargo.packages.size()];index+=1
	if item.state!="loose" or not is_instance_valid(item.body):return
	var elapsed:float=clock-float(item.get("audit_at",clock))
	item.audit_at=clock
	audit(item,maxf(elapsed,.08))

func nearest() -> Dictionary:
	var result:Dictionary={};var distance:=INF
	for item in cargo.packages:
		if item.state!="loose" or not is_instance_valid(item.body):continue
		var gap:float=cargo.player_position().distance_squared_to(item.body.global_position)
		if gap<distance:distance=gap;result=item
	return result

func audit(item:Dictionary,elapsed:float) -> void:
	if not ready or item.state!="loose" or not is_instance_valid(item.body):return
	var body:RigidBody3D=item.body
	var gap:=body.global_position-origin
	var lost:bool=not body.global_position.is_finite() or gap.y< -2 or Vector2(gap.x,gap.z).length()>MAX_DISTANCE
	var support:Dictionary={}
	if body.global_position.is_finite():
		var ray:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*.6,body.global_position-Vector3.UP*1.5,1)
		ray.exclude=[body.get_rid()]
		support=cargo.get_world_3d().direct_space_state.intersect_ray(ray)
	var riding:bool=not support.is_empty() and support.collider.is_in_group("traffic_vehicle")
	# Roof heights vary across the reference fleet, including overlapping loads.
	if not riding:
		for car in cargo.game.traffic.cars:
			if car.freeze or body.position.distance_squared_to(car.position)>100:continue
			var local:Vector3=car.to_local(body.global_position)
			var height:float=float(car.definition.get("height",1.5))
			if absf(local.x)<car.body_width*.5+.4 and absf(local.z)<car.body_length*.5+.4 and local.y>maxf(.9,height*.65) and local.y<height+1.2:
				riding=true;break
	item.carrier_time=float(item.get("carrier_time",0))+elapsed if riding else 0.0
	var stranded:bool=body.linear_velocity.length()<.6 and (absf(gap.y)>1.65 or support.is_empty())
	item.stranded_time=float(item.get("stranded_time",0))+elapsed if stranded else 0.0
	if lost or float(item.carrier_time)>.75 or float(item.stranded_time)>2.0:
		var spot:=recovery_spot(int(item.id),body.get_rid())
		if spot.is_empty():return # A passing vehicle may temporarily occupy the safe spot.
		body.global_position=spot.position+Vector3.UP*.32
		body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO;body.rotation=Vector3.ZERO;body.sleeping=false
		item.carrier_time=0.0;item.stranded_time=0.0;item.rescues=int(item.get("rescues",0))+1
		rescued+=1
		cargo.game.van.notify_driver("BOX %02d RETURNED TO SAFE GROUND / FOLLOW GOLD MARKER" % (int(item.id)+1))

func static_floor(at:Vector3) -> Dictionary:
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*2,1)
	ray.exclude=[cargo.game.van.get_rid()]
	if is_instance_valid(cargo.game.van.roll_body):ray.exclude.append(cargo.game.van.roll_body.get_rid())
	for car in cargo.game.traffic.cars:
		if is_instance_valid(car):ray.exclude.append(car.get_rid())
	var hit:Dictionary=cargo.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y<.92 or absf(hit.position.y-origin.y)>.55:return {}
	return hit

func recovery_spot(id:int,body:RID) -> Dictionary:
	var space:PhysicsDirectSpaceState3D=cargo.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.7
	for attempt in 32:
		var angle:float=(id+attempt)*2.399963
		var radius:float=2.8+float((id+attempt)%3)*1.3 if attempt<20 else 1.2+float(attempt%3)*.4
		var candidate:=origin+Vector3(cos(angle),0,sin(angle))*radius
		var ground:=static_floor(candidate)
		if ground.is_empty() or static_floor(origin.lerp(candidate,.5)).is_empty():continue
		candidate=ground.position
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|8
		query.exclude=[cargo.actor.get_rid(),body]
		query.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*.95)
		if not space.intersect_shape(query,1).is_empty():continue
		query.transform.origin=origin+Vector3.UP*.95;query.motion=candidate-origin
		var sweep:PackedFloat32Array=space.cast_motion(query)
		if sweep[0]<.99:continue
		var box:=BoxShape3D.new();box.size=Vector3(.9,.8,.9)
		query.shape=box;query.motion=Vector3.ZERO;query.transform.origin=candidate+Vector3.UP*.55;query.collision_mask=1|4|8
		if space.intersect_shape(query,1).is_empty():return {"position":candidate}
	return {}
