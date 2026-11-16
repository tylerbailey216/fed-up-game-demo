extends Node3D
var stages:Array=[]
var stage_index:=0
var quota:=12
var collision_count:=0
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
var safe_foot_position:=Vector3.ZERO
var complete:=false
var armed:=false
var pickup_cooldown:=0.0

func pause_packages(value:bool) -> void:
	for item in packages:
		if is_instance_valid(item.body): item.body.freeze=value

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	stages=JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	quota=int(stages[stage_index].packages)
	actor=preload("res://scripts/delivery_worker.gd").new();actor.game=game;add_child(actor);actor.set_enabled(false)
	game.van.delivery_collision_rules=true
	seen_collision=game.van.crash_serial

func player_position() -> Vector3:
	return actor.global_position if on_foot else game.van.global_position

func spill() -> void:
	if spilled or collision_count<3:return
	spilled=true;game.van.cargo_open=true
	for i in quota:drop_package()
	game.van.notify_driver("THIRD COLLISION - TRUCK DISABLED / Recover %d packages" % quota)

func drop_package() -> void:
	if not spilled or spawned>=quota:return
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
	var row:float=floorf(spawned/6.0)
	body.global_position=van.body.to_global(Vector3(fan*.7,1.2+row*.56,3.05+float(spawned%3)*.54))
	body.linear_velocity=van.planar_velocity*.5+van.global_basis*Vector3(fan*(5+row),3.5+float(spawned%3),5+row*1.6)
	body.angular_velocity=Vector3(1+fan,fan*3,fan*2)
	packages.append({"body":body,"state":"loose","id":spawned})
	spawned+=1

func damage_hit(_level:float) -> void:
	if spilled or complete:return
	collision_count+=1
	damage=minf(100,collision_count/3.0*100)
	if collision_count==3:
		game.van.wrecked=true;game.van.engine_on=false;game.van.cruise=false
		spill()
	else:game.van.notify_driver("COLLISION %d / 3 - LOAD SECURED" % collision_count)

func next_stage() -> void:
	if not complete:return
	for item in packages:
		if is_instance_valid(item.body):item.body.queue_free()
	packages.clear();carrying={};actor.held.hide();actor.set_enabled(false)
	on_foot=false;game.van.driver_on_foot=false
	stage_index=(stage_index+1)%stages.size()
	quota=int(stages[stage_index].packages)
	spilled=false;complete=false;recovered=0;spawned=0;damage=0;collision_count=0;pickup_cooldown=0
	game.van.cargo_open=false;game.van.new_truck();seen_collision=game.van.crash_serial
	game.van.notify_driver("STAGE %d / %s / %d PACKAGES" % [stage_index+1,stages[stage_index].name,quota])

func toggle_foot() -> void:
	if on_foot:
		if not carrying.is_empty():game.van.notify_driver("Return your package first / F at truck rear or purple depot");return
		if game.van.wrecked:game.van.notify_driver("Truck disabled - return packages to truck or purple depot");return
		if actor.position.distance_to(game.van.position)>5:game.van.notify_driver("Get closer to the truck to enter");return
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

func return_target() -> String:
	if not on_foot:return ""
	var rear:Vector3=game.van.to_global(Vector3(0,0,3.6))
	var offset:Vector3=actor.global_position-rear
	if Vector2(offset.x,offset.z).length()<2.3 and absf(offset.y)<3:return "truck"
	if not game.outerbelt and actor.global_position.distance_to(game.highway.depot)<3.8:return "depot"
	return ""

func interact() -> void:
	if on_foot and not carrying.is_empty():deposit()
	else:toggle_foot()

func secure_package(item:Dictionary,target:String) -> void:
	item.state="recovered"
	if is_instance_valid(item.body):
		var body:RigidBody3D=item.body
		body.freeze=true;body.collision_layer=0;body.collision_mask=0
		var slot:=recovered
		if target=="truck":
			body.reparent(game.van.body,false)
			body.position=Vector3(-.5+(slot%2)*.9,.92+floori(slot/6.0)*.53,2.05-(floori(slot/2.0)%3)*.6)
		else:
			body.position=game.highway.depot+Vector3(-1.4+(slot%5)*.65,.28+floori(slot/10.0)*.52,-1.0+(floori(slot/5.0)%2)*.6)
		body.rotation=Vector3.ZERO;body.show()
	recovered+=1

func deposit() -> void:
	if carrying.is_empty():return
	var target:=return_target()
	if target.is_empty():game.van.notify_driver("Carry package to the open truck rear or purple depot / F to return");return
	secure_package(carrying,target);carrying={};actor.held.hide();pickup_cooldown=.4
	game.van.notify_driver("Package secured - %d / %d" % [recovered,quota])

func recover_package(item:Dictionary) -> void:
	if item.state!="loose":return
	if on_foot:
		if is_instance_valid(item.body):
			item.body.freeze=true;item.body.collision_layer=0;item.body.collision_mask=0;item.body.hide()
		item.state="carried";carrying=item;actor.held.show()
	else:
		secure_package(item,"truck")
	pickup_cooldown=.25

func _physics_process(delta:float) -> void:
	if not game.driving:return
	armed=game.outerbelt or game.highway.entered
	if seen_collision!=game.van.crash_serial:
		seen_collision=game.van.crash_serial
		if armed:damage_hit(game.van.collision_level)
	if game.van.wrecked and not on_foot and (not game.van.overturned or game.van.roll_settled):toggle_foot()
	pickup_cooldown=maxf(0,pickup_cooldown-delta)
	var at:=player_position()
	if on_foot:
		if actor.is_on_floor():safe_foot_position=actor.position
	for item in packages:
		if item.state!="loose" or not is_instance_valid(item.body):continue
		var body:RigidBody3D=item.body
		if body.position.y< -4 or body.position.x>1740 or body.position.x< -1300 or absf(body.position.z)>1200:
			body.position=game.van.safe_position+Vector3(4,1,0);body.linear_velocity=Vector3.ZERO
		if pickup_cooldown>0 or (on_foot and not carrying.is_empty()):continue
		if at.distance_to(body.position)<(2 if on_foot else 3.2) and (on_foot or absf(game.van.speed)<6):recover_package(item)
	if spilled and recovered==quota and not complete:
		complete=true;game.van.cargo_open=false;game.van.notify_driver("STAGE %d COMPLETE / ALL %d PACKAGES SECURED" % [stage_index+1,quota])

func objective() -> String:
	if complete:return "STAGE %d COMPLETE / %d OF %d RECOVERED" % [stage_index+1,recovered,quota]
	if not armed:return "TRAINING / Push past orange barrels to enter downtown"
	if not spilled:return "STAGE %d / %d PACKAGES SECURED / COLLISIONS %d OF 3" % [stage_index+1,quota,collision_count]
	if on_foot and not carrying.is_empty():return "CARRYING PACKAGE / F or RETURN to stow" if not return_target().is_empty() else "CARRYING PACKAGE / Walk to truck rear or purple depot"
	return "STAGE %d / RECOVER %d OF %d / ON FOOT" % [stage_index+1,recovered,quota]
