extends Node
var failures:Array[String]=[]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func snapshot(name:String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/"+name+".png")

func run(game:Node,capture:bool) -> void:
	game.start_drive()
	await frames(90)
	check(game.van.is_on_floor(),"Training spawn rests on road")
	check(game.highway.map_data.roads.size()>500,"Downtown has mapped streets")
	check(game.traffic.cars.size()==8,"Downtown has live traffic")
	game.van.position=Vector3(260,.15,-75);game.van.rotation.y=-PI/2;game.van.speed=12
	Input.action_press("accelerate")
	await frames(240)
	Input.action_release("accelerate")
	check(game.highway.entered,"Drive through construction barrels opens downtown")
	check(game.van.position.x>285,"Gateway can be crossed by vehicle")
	# Exercise a real moderate-speed impact on a clear connector test obstacle.
	game.van.position=Vector3(330,.15,-75);game.van.rotation.y=-PI/2;game.van.speed=10;game.van.planar_velocity=Vector3(10,0,0)
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1,4,16);collision.shape=shape;wall.add_child(collision);game.add_child(wall);wall.position=Vector3(345,2,-75)
	await frames(150)
	check(game.cargo.spilled and game.van.cargo_open,"First collision releases cargo and opens rear doors")
	check(game.cargo.spawned>=6,"First impact ejects multiple physical boxes")
	check(game.vehicle_visuals.doors.size()==2,"Truck model has two independent door pivots")
	if game.vehicle_visuals.doors.size()==2:check(absf(game.vehicle_visuals.doors[0].rotation.y)>1,"Rear doors animate open")
	wall.queue_free()
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
	game.van.position=Vector3(1000,.15,-75)
	var resets:int=game.van.offroad_recoveries
	await frames(8)
	check(game.van.offroad_recoveries==resets,"Downtown coordinates remain inside world bounds")
	if capture:
		game.van.set_view(false)
		await frames(45)
		await snapshot("cleveland-delivery")
	# Disable truck and verify automatic safe exit plus genuine foot controls.
	game.van.position=Vector3(390,.15,-75);game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
	game.cargo.damage_hit(4)
	await frames(20)
	check(game.van.wrecked and game.cargo.on_foot,"Damage disables engine and moves player on foot")
	check(game.cargo.actor.camera.is_current(),"On-foot camera takes control")
	check(game.cargo.spawned==12,"All remaining loose cargo becomes recoverable")
	var before:Vector3=game.cargo.actor.position
	Input.action_press("accelerate");await frames(30);Input.action_release("accelerate")
	check(game.cargo.actor.position.distance_to(before)>1,"Player can walk after vehicle is disabled")
	game.cargo.actor.set_physics_process(false)
	for item in game.cargo.packages:
		if item.state!="loose":continue
		item.body.freeze=true
		game.cargo.actor.position=item.body.position
		await frames(20)
		check(item.state=="carried","Walking to box picks it up")
		game.cargo.actor.position=game.van.position+Vector3(3,0,0)
		await frames(20)
	check(game.cargo.recovered==12 and game.cargo.complete,"All packages can be returned to disabled truck")
	check(not game.van.cargo_open,"Rear doors close when collection is complete")
	if capture:
		game.cargo.actor.position=Vector3(1010,.1,-60);game.cargo.actor.update_camera(1)
		await snapshot("delivery-worker")
	# Native viewport changes test camera projection and UI reflow without stretch.
	for screen in [Vector2i(720,1280),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1280,720)]:
		game.get_window().size=screen;game.responsive_layout();await frames(4)
		check(game.menu.position.x>=0 and game.menu.position.x+game.menu.size.x<=game.get_window().content_scale_size.x+1,"Menu fits screen "+str(screen))
		if capture:await snapshot("responsive-%dx%d" % [screen.x,screen.y])
	game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(4)
	game.cargo.on_foot=false;game.touch_controls.enabled=true;game.touch_controls.layout()
	var steer:=InputEventScreenTouch.new();steer.index=1;steer.pressed=true;steer.position=game.touch_controls.regions.stick.get_center()+Vector2(70,0)
	game.touch_controls._input(steer)
	var gas:=InputEventScreenTouch.new();gas.index=2;gas.pressed=true;gas.position=game.touch_controls.regions.gas.get_center()
	game.touch_controls._input(gas)
	check(Input.is_action_pressed("accelerate") and Input.is_action_pressed("steer_right"),"Two fingers steer and accelerate together")
	steer.pressed=false;game.touch_controls._input(steer)
	check(Input.is_action_pressed("accelerate") and not Input.is_action_pressed("steer_right"),"Releasing steering preserves pedal finger")
	game.touch_controls.release_inputs()
	print("DELIVERY TEST ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)

func run_motorway(game:Node) -> void:
	game.start_drive();await frames(90)
	check(game.van.is_on_floor(),"Motorway spawn rests on road")
	game.van.register_collision(10,4);await frames(30)
	check(game.cargo.spilled and game.van.cargo_open,"Motorway collision releases cargo")
	game.cargo.damage_hit(4);await frames(30)
	check(game.cargo.on_foot and game.cargo.actor.is_on_floor(),"Motorway damage permits a safe foot exit")
	print("MOTORWAY DELIVERY ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)
