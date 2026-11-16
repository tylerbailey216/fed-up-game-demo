extends Node3D
const TOTAL:=12
var game:Node
var actor:CharacterBody3D
var packages:Array[Dictionary]=[]
var spilled:=false
var recovered:=0
var spawned:=0
var damage:=0.0
var on_foot:=false
var carrying:Dictionary={}
var seen_collision:=0
var release_time:=0.0
var last_drop:=Vector3.ZERO
var safe_foot_position:=Vector3.ZERO
var complete:=false
var armed:=false
var pickup_cooldown:=0.0

func pause_packages(value:bool) -> void:
	for item in packages:
		if is_instance_valid(item.body): item.body.freeze=value

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	actor=preload("res://scripts/delivery_worker.gd").new();actor.game=game;add_child(actor);actor.set_enabled(false)
	seen_collision=game.van.collision_serial

func player_position() -> Vector3:
	return actor.global_position if on_foot else game.van.global_position

func spill() -> void:
	if spilled:return
	spilled=true;game.van.cargo_open=true;last_drop=game.van.position
	for i in 6:drop_package()
	game.van.notify_driver("LOAD SPILLED! Recover packages - drive slowly or exit with X")

func drop_package() -> void:
	if spawned>=TOTAL:return
	var van:Node=game.van
	var body:=RigidBody3D.new();body.mass=4;body.continuous_cd=true;body.linear_damp=.6;body.angular_damp=.8
	body.process_mode=Node.PROCESS_MODE_PAUSABLE
	# Packages do not collide with the player; collection happens before contact.
	body.collision_layer=4;body.collision_mask=1|4
	var physics:=PhysicsMaterial.new();physics.friction=.7;physics.bounce=.18;body.physics_material_override=physics
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.6,.51,.48);shape.shape=box;body.add_child(shape)
	preload("res://scripts/package_visual.gd").build(body,.6,game.highway.art)
	add_child(body)
	var fan:float=float(spawned%6)/5.0*2-1
	body.global_position=van.body.to_global(Vector3(fan*.7,1.2,3.05+float(spawned%3)*.45))
	body.linear_velocity=van.planar_velocity*.65+van.global_basis*Vector3(fan*7,3.5+float(spawned%3),6)
	body.angular_velocity=Vector3(1+fan,fan*3,fan*2)
	packages.append({"body":body,"state":"loose","id":spawned})
	spawned+=1

func damage_hit(level:float) -> void:
	damage=clampf(damage+maxf(4,level*32),0,100)
	if damage>=100:
		game.van.wrecked=true;game.van.engine_on=false
		game.van.notify_driver("TRUCK DISABLED - finish collecting on foot")

func toggle_foot() -> void:
	if on_foot:
		if game.van.wrecked:game.van.notify_driver("Truck disabled - return packages to truck or purple depot");return
		if actor.position.distance_to(game.van.position)>5:game.van.notify_driver("Get closer to the truck to enter");return
		deposit()
		on_foot=false;actor.set_enabled(false);game.van.driver_on_foot=false;game.van.parking_brake=false;game.van.engine_on=true;game.van.set_view(false)
		return
	if absf(game.van.speed)>1 and not game.van.wrecked:game.van.notify_driver("Stop before leaving the truck");return
	if game.van.overturned and not game.van.roll_settled:game.van.notify_driver("Wait for the truck to settle");return
	var at:Vector3=game.van.position+game.van.global_basis.x*3.5
	var found:=false
	for radius in [3.5,5.0,7.0,10.0]:
		for i in 12:
			var probe:Vector3=game.van.position+Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*radius
			var ray:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*4,probe-Vector3.UP*8)
			ray.exclude=[game.van.get_rid()]
			if is_instance_valid(game.van.roll_body):ray.exclude.append(game.van.roll_body.get_rid())
			var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.85:continue
			at=hit.position+Vector3.UP*.08
			var capsule:=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.7
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.9);query.collision_mask=1
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():found=true;break
		if found:break
	if not found:game.van.notify_driver("No safe space beside truck - recover it first");return
	on_foot=true;game.van.driver_on_foot=true;game.van.parking_brake=true;game.van.engine_on=false;game.van.set_view(false)
	actor.global_position=at;safe_foot_position=at;actor.velocity=Vector3.ZERO;actor.set_enabled(true)
	game.van.notify_driver("ON FOOT - WASD move / Shift run / X enter truck")

func deposit() -> void:
	if carrying.is_empty():return
	carrying.state="recovered";carrying={};recovered+=1;actor.held.hide()
	game.van.notify_driver("Package secured - %d / %d" % [recovered,TOTAL])

func recover_package(item:Dictionary) -> void:
	if item.state!="loose":return
	if is_instance_valid(item.body):item.body.queue_free()
	item.body=null
	if on_foot:
		item.state="carried";carrying=item;actor.held.show()
	else:
		item.state="recovered";recovered+=1
	pickup_cooldown=.25

func _physics_process(delta:float) -> void:
	if not game.driving:return
	armed=game.outerbelt or game.highway.entered
	if seen_collision!=game.van.collision_serial:
		seen_collision=game.van.collision_serial
		if armed:damage_hit(game.van.collision_level);spill()
	if spilled and spawned<TOTAL:
		release_time+=delta
		if game.van.position.distance_to(last_drop)>45 or release_time>5 or game.van.wrecked or on_foot:
			drop_package();last_drop=game.van.position;release_time=0
	if game.van.wrecked and not on_foot and (not game.van.overturned or game.van.roll_settled):toggle_foot()
	pickup_cooldown=maxf(0,pickup_cooldown-delta)
	var at:=player_position()
	if on_foot:
		if actor.is_on_floor():safe_foot_position=actor.position
		if not carrying.is_empty() and (at.distance_to(game.van.position)<4.5 or (not game.outerbelt and at.distance_to(game.highway.depot)<4.5)):deposit()
	for item in packages:
		if item.state!="loose" or not is_instance_valid(item.body):continue
		var body:RigidBody3D=item.body
		if body.position.y< -4 or body.position.x>1740 or body.position.x< -1300 or absf(body.position.z)>1200:
			body.position=game.van.safe_position+Vector3(4,1,0);body.linear_velocity=Vector3.ZERO
		if pickup_cooldown>0 or (on_foot and not carrying.is_empty()):continue
		if at.distance_to(body.position)<(2 if on_foot else 3.2) and (on_foot or absf(game.van.speed)<6):recover_package(item)
	if recovered==TOTAL and not complete:
		complete=true;game.van.cargo_open=false;game.van.notify_driver("ALL 12 PACKAGES RECOVERED - delivery saved!")

func objective() -> String:
	if complete:return "DELIVERY SAVED / 12 OF 12 RECOVERED"
	if not armed:return "TRAINING / Push past orange barrels to enter downtown"
	if not spilled:return "LOAD SECURED / Truck condition %d%%" % roundi(100-damage)
	if on_foot and not carrying.is_empty():return "CARRYING PACKAGE / Return to truck or purple depot"
	return "RECOVER PACKAGES %d / %d / %s" % [recovered,TOTAL,"ON FOOT" if on_foot else "DRIVE SLOWLY TO COLLECT"]
