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
var load_restored:=false
var checkpoint:Node3D
var checkpoint_position:=Vector3.ZERO
var checkpoint_hold:=0.0
var checkpoint_inside:=false
var remaining_notice:=0
var popup:=""
var popup_time:=0.0
var safety:=preload("res://scripts/package_safety.gd").new()
var pickup_previous:=Vector3.ZERO

func pause_packages(value:bool) -> void:
	for item in packages:
		if is_instance_valid(item.body): item.body.freeze=value or item.state!="loose"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	stages=JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	quota=int(stages[stage_index].packages)
	actor=preload("res://scripts/delivery_worker.gd").new();actor.game=game;add_child(actor);actor.set_enabled(false)
	game.van.delivery_collision_rules=true
	seen_collision=game.van.crash_serial
	safety.cargo=self
	build_checkpoint()

func build_checkpoint() -> void:
	checkpoint=Node3D.new();add_child(checkpoint)
	if game.outerbelt:
		var road:Dictionary=game.highway.nearest_road(game.highway.spawn_position-game.van.global_basis.z*140)
		checkpoint_position=road.point
		checkpoint.rotation.y=game.highway.spawn_heading
	else:
		# A dedicated stop bay on the wide training-to-Superior Avenue access road.
		var start:=Vector3(250,0,-75)
		checkpoint_position=start.lerp(game.highway.entry,.40)
		var direction:Vector3=(game.highway.entry-start).normalized()
		checkpoint.rotation.y=atan2(-direction.x,-direction.z)
	checkpoint.position=checkpoint_position
	var art:Node=game.highway
	for side in [-1,1]:
		art.block(checkpoint,Vector3(side*5.8,.055,0),Vector3(.16,.045,15),Color("ffd044"))
		for z in [-7,7]:
			art.block(checkpoint,Vector3(side*5.8,1.35,z),Vector3(.18,2.7,.18),Color("272034"))
			art.block(checkpoint,Vector3(side*5.8,2.55,z),Vector3(.36,.2,.36),Color("ffd044"))
	for z in [-7,7]:
		art.block(checkpoint,Vector3(0,.06,z),Vector3(11.5,.05,.35),Color("fff1d2"))
	var sign:=Label3D.new();sign.text="FedUp / COLLECTION\nFULL STOP TO FINISH";sign.font_size=56;sign.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
	sign.pixel_size=.009;sign.outline_size=10;sign.modulate=Color("ffd044")
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.position=Vector3(0,4.8,0);checkpoint.add_child(sign)

func show_popup(message:String) -> void:
	popup=message;popup_time=4.5;game.van.notify_driver(message.replace("\n"," / "))

func remaining_packages() -> int:
	var count:=0
	for item in packages:
		if item.state!="loose":count+=1
	return maxi(0,quota-count)

func player_position() -> Vector3:
	return actor.global_position if on_foot else game.van.global_position

func spill() -> void:
	if spilled or collision_count<3:return
	spilled=true;game.van.cargo_open=true
	for i in quota:drop_package()
	game.van.notify_driver("TRUCK DISABLED / Recover %d packages" % quota)

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
	else:game.van.notify_driver("LOW TRUCK ENERGY / LOAD SECURED" if collision_count==2 else "TRUCK DAMAGED / LOAD SECURED")

func next_stage() -> void:
	if not complete:return
	for item in packages:
		if is_instance_valid(item.body):item.body.queue_free()
	packages.clear();carrying={};actor.held.hide();actor.set_enabled(false)
	on_foot=false;game.van.driver_on_foot=false
	stage_index=0 # This demo ends at the first collection point; replay starts fresh.
	quota=int(stages[stage_index].packages)
	spilled=false;complete=false;recovered=0;spawned=0;damage=0;collision_count=0;load_restored=false
	checkpoint_hold=0;checkpoint_inside=false;popup_time=0
	safety.ready=false;safety.clock=0;safety.rescued=0;safety.audit_clock=0;safety.index=0
	game.van.cargo_open=false;game.van.new_truck();seen_collision=game.van.crash_serial
	game.van.active=true
	game.van.notify_driver("STAGE %d / %s / %d PACKAGES" % [stage_index+1,stages[stage_index].name,quota])

func toggle_foot() -> void:
	if on_foot:
		if game.van.wrecked:
			show_popup("TRUCK DISABLED / %d PACKAGES LEFT" % remaining_packages() if remaining_packages()>0 else "PACKAGES RETURNING / PLEASE WAIT")
			return
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
			# Exit at road level, never on a wall/vehicle roof selected by the ray.
			if not hit.collider is StaticBody3D or hit.position.y>game.van.position.y+.65:continue
			at=hit.position+Vector3.UP*.08
			var capsule:=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.7
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.9);query.collision_mask=1|8
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():found=true;break
		if found:break
	if not found:game.van.notify_driver("No safe space beside truck - recover it first");return
	on_foot=true;game.van.driver_on_foot=true;game.van.parking_brake=true;game.van.engine_on=false;game.van.set_view(false)
	actor.global_position=at;safe_foot_position=at;actor.velocity=Vector3.ZERO;actor.set_enabled(true)
	actor.camera_angle=game.van.rotation.y;actor.facing=actor.camera_angle;actor.look_ahead=Vector3.ZERO;actor.update_camera(1)
	pickup_previous=actor.global_position
	game.van.notify_driver("ON FOOT - WASD move / Shift run / X enter truck")

func interact() -> void:
	if not complete:toggle_foot()

func secure_package(item:Dictionary,target:String) -> void:
	if item.state!="returning":return
	item.state="recovered"
	if is_instance_valid(item.body):
		var body:RigidBody3D=item.body
		body.freeze=true;body.collision_layer=0;body.collision_mask=0
		var slot:int=item.id
		if target=="truck":
			body.reparent(game.van.body,false)
			body.position=Vector3(-.5+(slot%2)*.9,.92+floori(slot/6.0)*.53,2.05-(floori(slot/2.0)%3)*.6)
		else:
			body.position=game.highway.depot+Vector3(-1.4+(slot%5)*.65,.28+floori(slot/10.0)*.52,-1.0+(floori(slot/5.0)%2)*.6)
		body.rotation=Vector3.ZERO;body.show()

func recover_package(item:Dictionary) -> void:
	if item.state!="loose":return
	item.state="returning"
	# Credit contact immediately. The star flight is presentation, never a
	# second pickup or a requirement to approach the rear of the truck.
	recovered+=1
	item.body.freeze=true;item.body.collision_layer=0;item.body.collision_mask=0;item.body.hide()
	var effect:=preload("res://scripts/package_return.gd").new();effect.cargo=self;effect.item=item;add_child(effect)

func restore_load() -> void:
	load_restored=true;damage=0
	var van:Node=game.van
	if van.overturned:van.recover_upright()
	van.wrecked=false;van.flip_count=0;van.engine_on=not on_foot;van.cruise=false
	van.cargo_open=false;van.speed=0;van.velocity=Vector3.ZERO;van.planar_velocity=Vector3.ZERO
	van.crash_contact_active=true;van.crash_origin=van.position;van.crash_clear_time=0
	show_popup("ALL %d SECURED / TRUCK READY\nENTER TRUCK, THEN STOP AT COLLECTION" % quota)

func update_checkpoint(delta:float) -> void:
	var at:Vector3=checkpoint.to_local(player_position())
	var inside:bool=absf(at.x)<5.5 and absf(at.z)<7 and absf(at.y)<3
	if inside and not checkpoint_inside and not complete:
		remaining_notice=remaining_packages()
		if remaining_notice>0:show_popup("COLLECTION INCOMPLETE\n%d MORE PACKAGES TO COLLECT" % remaining_notice)
		elif not load_restored:show_popup("PACKAGES RETURNING / WAIT FOR THE LOAD")
		else:show_popup("COLLECTION POINT / STOP THE TRUCK")
	if not inside and checkpoint_inside and popup.begins_with("COLLECTION"):popup_time=0
	checkpoint_inside=inside
	if complete:return
	if not inside or on_foot or not load_restored or absf(game.van.speed)>.35:
		checkpoint_hold=0;return
	checkpoint_hold+=delta
	if checkpoint_hold>=1.2:
		complete=true;game.van.parking_brake=true;game.van.engine_on=false
		game.van.delivery_complete=true
		game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
		show_popup("DEMO COMPLETE!\nALL %d PACKAGES DELIVERED" % quota)

func _physics_process(delta:float) -> void:
	if not game.driving:return
	popup_time=maxf(0,popup_time-delta)
	armed=game.outerbelt or game.highway.entered
	if seen_collision!=game.van.crash_serial:
		seen_collision=game.van.crash_serial
		if armed:damage_hit(game.van.collision_level)
	if game.van.wrecked and not on_foot and (not game.van.overturned or game.van.roll_settled):toggle_foot()
	var at:=player_position()
	if on_foot:
		if actor.is_on_floor():safe_foot_position=actor.position
	safety.update(delta)
	for item in packages:
		if item.state!="loose" or not is_instance_valid(item.body):continue
		var body:RigidBody3D=item.body
		# Contact-range pickup; the 60 Hz step cannot skip a box at sprint speed.
		var start:Vector3=pickup_previous if pickup_previous.distance_to(at)<2 else at
		var near:=Geometry2D.get_closest_point_to_segment(Vector2(body.global_position.x,body.global_position.z),Vector2(start.x,start.z),Vector2(at.x,at.z))
		if on_foot and near.distance_to(Vector2(body.global_position.x,body.global_position.z))<1.15 and absf(at.y-body.global_position.y)<1.8:recover_package(item)
	pickup_previous=at
	if spilled and recovered==quota and not load_restored:restore_load()
	update_checkpoint(delta)

func objective() -> String:
	if complete:return "DEMO COMPLETE / ALL %d DELIVERED" % quota
	if load_restored:return "LOAD SECURED / ENTER TRUCK" if on_foot else "STOP AT GOLD COLLECTION BAY / GPS"
	if not armed:return "TRAINING / Push past orange barrels to enter downtown"
	if not spilled:return "STAGE %d / %d PACKAGES SECURED" % [stage_index+1,quota]
	return "WALK OVER BOXES / %d LEFT / %d SECURED" % [remaining_packages(),recovered]
