extends Node
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func snapshot(name:String) -> void:
	await get_tree().process_frame;await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/"+name+".png")

func collect_stage(game:Node) -> void:
	game.cargo.actor.set_physics_process(false)
	game.cargo.actor.position=game.van.position+Vector3(3,0,0);await frames(20)
	for item in game.cargo.packages:
		if item.state!="loose":continue
		item.body.freeze=true
		game.cargo.actor.position=item.body.position;await frames(20)
		check(item.state=="carried","Walking to each fixed parcel picks it up")
		var before:int=game.cargo.recovered
		game.cargo.actor.position=game.van.to_global(Vector3(0,.1,3.6));await frames(35)
		check(item.state=="carried" and game.cargo.recovered==before and game.cargo.actor.held.visible,"Package stays in hands even inside the return zone until player confirms")
		game.cargo.interact();await frames(20)
		check(item.state=="recovered" and game.cargo.recovered==before+1 and is_instance_valid(item.body),"Explicit return stows the existing package once")
		check(item.body.get_parent()==game.van.body and item.body.visible,"Returned package is visible in the cargo bay")
	check(game.cargo.recovered==game.cargo.quota and game.cargo.complete,"Stage completes at its exact package quota")
	check(not game.van.cargo_open,"Cargo doors close on completion")

func walk_route(game:Node,begin:Vector3,end:Vector3) -> void:
	var actor:CharacterBody3D=game.cargo.actor
	actor.camera_angle=0;actor.global_position=begin;actor.velocity=Vector3.ZERO
	await frames(5)
	var direction:Vector3=(end-begin).normalized()
	var strengths:Dictionary={"steer_left":maxf(0,-direction.x),"steer_right":maxf(0,direction.x),"accelerate":maxf(0,-direction.z),"brake_reverse":maxf(0,direction.z)}
	for action in strengths:
		if strengths[action]>0:Input.action_press(action,strengths[action])
	await frames(ceili((begin.distance_to(end)+.4)/4.2*60))
	for action in strengths:Input.action_release(action)
	check((actor.global_position-begin).dot(direction)>begin.distance_to(end)-.3,"Input-driven worker crosses flat road/path without getting stuck: %s -> %s, reached %s" % [begin,end,actor.global_position])
	check(actor.is_on_floor(),"Worker stays grounded across road/path")
	await frames(15)

func check_worker(game:Node) -> void:
	var actor:CharacterBody3D=game.cargo.actor
	await walk_route(game,Vector3(262,.08,-75),Vector3(287,.08,-75))
	await walk_route(game,Vector3(287,.08,-75),Vector3(262,.08,-75))
	# Cross the mapped Public Square footway from grass to grass, both ways.
	var center:=Vector3(984.24,.08,-82.875)
	var side:=Vector3(-29.25,0,18.32).normalized()*4
	await walk_route(game,center-side,center+side)
	await walk_route(game,center+side,center-side)
	for offset in [0.0,PI,-PI/2,PI/2]:
		actor.facing=actor.camera_angle+offset;actor.update_illustration(true,false)
		var expected:String="back" if offset==0 else ("front" if offset==PI else ("right" if offset<0 else "left"))
		check(actor.facing_direction==expected,"Movement faces correct camera-relative direction: "+expected)
		if expected in ["front","back"]:check(actor.shown_animation=="walk_"+expected,"Up/down use actual front/back walking frames")
	actor.held.show();actor.facing=actor.camera_angle;actor.update_illustration(true,false)
	check(actor.shown_animation=="carry_back","Walking away carries package in rear-facing art")
	actor.facing=actor.camera_angle+PI;actor.update_illustration(true,false)
	check(actor.shown_animation=="carry_front","Walking toward camera carries package in front-facing art")
	actor.held.hide();actor.camera_angle=PI/2;actor.facing=0;actor.update_illustration(true,false)
	check(actor.facing_direction=="right","Facing follows camera rotation")

func run(game:Node,capture:bool) -> void:
	game.start_drive();await frames(90)
	check(game.van.is_on_floor(),"Training spawn rests on road")
	check(game.highway.map_data.roads.size()>500 and game.traffic.cars.size()==8,"Mapped downtown and traffic exist")
	game.van.position=Vector3(260,.15,-75);game.van.rotation.y=-PI/2;game.van.speed=12
	Input.action_press("accelerate");await frames(240);Input.action_release("accelerate")
	check(game.highway.entered and game.van.position.x>285,"Actual construction-barrel gateway opens downtown: at=%s speed=%.2f impacts=%d" % [game.van.position,game.van.speed,game.cargo.collision_count])
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1,4,16);collision.shape=shape;wall.add_child(collision);game.add_child(wall);wall.position=Vector3(345,2,-75)
	for impact in 3:
		game.van.position=Vector3(330,.15,-75);game.van.rotation.y=-PI/2;game.van.speed=10;game.van.planar_velocity=Vector3(10,0,0)
		await frames(150)
		check(game.cargo.collision_count==impact+1,"Each distinct physical impact counts once")
		if impact<2:
			check(game.cargo.spawned==0 and not game.van.cargo_open and not game.van.wrecked,"First two impacts keep all packages secured and truck driveable")
	check(game.cargo.spilled and game.van.wrecked and game.cargo.on_foot,"Third collision disables truck and forces foot recovery")
	check(game.cargo.spawned==game.cargo.quota and game.cargo.quota==12,"Third impact releases exactly the full stage quota once")
	check(game.vehicle_visuals.doors.size()==2 and absf(game.vehicle_visuals.doors[0].rotation.y)>1,"Both physical rear doors open")
	wall.queue_free()
	var count:int=game.cargo.spawned
	await frames(360)
	check(game.cargo.spawned==count,"No time-based continuing package drops")
	check(game.cargo.actor.camera.is_current(),"On-foot camera takes control")
	var before:Vector3=game.cargo.actor.position
	Input.action_press("accelerate");await frames(30);Input.action_release("accelerate")
	check(game.cargo.actor.position.distance_to(before)>1,"Player can walk after truck disables")
	await check_worker(game)
	# Reject remote returns and preserve carried state instead of teleporting cargo.
	game.cargo.actor.set_physics_process(false)
	var loose:Dictionary=game.cargo.packages[0]
	game.cargo.actor.position=loose.body.position;await frames(20)
	game.cargo.actor.position=Vector3(400,.1,-75)
	var recovered_before:int=game.cargo.recovered
	game.cargo.deposit();await frames(30)
	check(not game.cargo.carrying.is_empty() and game.cargo.recovered==recovered_before,"Remote return cannot teleport package back to truck")
	game.cargo.actor.position=game.highway.depot+Vector3(0,.1,0)
	var confirm:=InputEventKey.new();confirm.keycode=KEY_F;confirm.pressed=true;game._unhandled_key_input(confirm);await frames(30)
	check(loose.state=="recovered" and game.cargo.recovered==recovered_before+1 and loose.body.visible,"F returns carried package at the depot")
	await collect_stage(game)
	if capture:
		game.cargo.actor.position=Vector3(1000,.1,-75);game.cargo.actor.update_camera(1)
		await snapshot("delivery-worker")
	for stage in [1,2]:
		game.cargo.next_stage();await frames(30)
		check(game.cargo.quota==[12,16,20][stage] and game.cargo.spawned==0,"Next stage has its own larger fixed quota")
		Input.action_press("accelerate");await frames(120);Input.action_release("accelerate")
		check(game.cargo.spawned==0 and not game.cargo.spilled,"Driving again never leaks packages")
		game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.position=Vector3(390,.15,-75)
		for impact in 3:
			game.van.collision_cooldown=0;game.van.register_collision(10,4);await frames(15)
			check(game.cargo.spawned==(game.cargo.quota if impact==2 else 0),"All stages spill only on their third collision")
		await frames(20);await collect_stage(game)
	for screen in [Vector2i(720,1280),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1280,720)]:
		game.get_window().size=screen;game.responsive_layout();await frames(4)
		check(game.menu.position.x>=0 and game.menu.position.x+game.menu.size.x<=game.get_window().content_scale_size.x+1,"Menu fits screen "+str(screen))
		if capture:await snapshot("responsive-%dx%d" % [screen.x,screen.y])
	game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(4)
	game.cargo.on_foot=false;game.touch_controls.enabled=true;game.touch_controls.layout()
	var steer:=InputEventScreenTouch.new();steer.index=1;steer.pressed=true;steer.position=game.touch_controls.regions.stick.get_center()+Vector2(70,0);game.touch_controls._input(steer)
	var gas:=InputEventScreenTouch.new();gas.index=2;gas.pressed=true;gas.position=game.touch_controls.regions.gas.get_center();game.touch_controls._input(gas)
	check(Input.is_action_pressed("accelerate") and Input.is_action_pressed("steer_right"),"Two fingers steer and accelerate together")
	steer.pressed=false;game.touch_controls._input(steer)
	check(Input.is_action_pressed("accelerate") and not Input.is_action_pressed("steer_right"),"Releasing steering preserves gas finger")
	game.touch_controls.release_inputs()
	print("DELIVERY TEST ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)

func run_motorway(game:Node) -> void:
	game.start_drive();await frames(90)
	check(game.van.is_on_floor(),"Motorway spawn rests on road")
	for impact in 3:
		game.van.collision_cooldown=0;game.van.register_collision(10,4);await frames(15)
		check(game.cargo.spawned==(12 if impact==2 else 0),"Motorway also respects three-collision rule")
	await frames(30)
	check(game.cargo.on_foot and game.cargo.actor.is_on_floor(),"Motorway permits safe foot exit")
	print("MOTORWAY DELIVERY ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)
