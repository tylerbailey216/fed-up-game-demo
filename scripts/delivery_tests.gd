extends Node
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func snapshot(name:String) -> void:
	await get_tree().process_frame;await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/"+name+".png")

func drive_into_wall(game:Node) -> void:
	game.van.position=Vector3(330,.15,-75);game.van.rotation.y=-PI/2
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
	await frames(75) # Separated and stationary before the next distinct approach.
	check(not game.van.crash_contact_active,"A fresh approach rearms only after clearing previous contact")
	game.van.speed=10;game.van.planar_velocity=Vector3(10,0,0)
	Input.action_press("accelerate")
	for i in 360:
		await frames(1)
		if game.cargo.spilled:break
	Input.action_release("accelerate");await frames(60)

func collect_stage(game:Node,capture:bool=false) -> void:
	var cargo:Node=game.cargo
	cargo.actor.set_physics_process(false)
	# Isolate each pickup, without carrying/deposit actions or proximity to truck.
	cargo.actor.position=Vector3(420,.1,-75)
	for item in cargo.packages:
		if item.state=="loose":item.body.freeze=true;item.body.position=Vector3(420+int(item.id)*3,.4,-90)
	await frames(5)
	for item in cargo.packages:
		if item.state!="loose":continue
		var before:int=cargo.recovered
		cargo.actor.camera_view=0;cargo.actor.camera_angle=0
		if int(item.id)==0:
			cargo.actor.position=item.body.position-Vector3(2.1,.3,0);cargo.actor.velocity=Vector3.ZERO;cargo.actor.set_physics_process(true)
			Input.action_press("steer_right");Input.action_press("sprint");await frames(30)
			Input.action_release("steer_right");Input.action_release("sprint");cargo.actor.set_physics_process(false)
			check(cargo.actor.animation_speed>4,"Worker animation cadence follows actual sprint travel")
		else:
			cargo.actor.position=item.body.position-Vector3.UP*.3;await frames(3)
		cargo.actor.update_camera(1)
		check(item.state=="returning" and not item.body.visible,"Walk-over pickup immediately becomes a sparkle return")
		check(cargo.carrying.is_empty() and not cargo.actor.held.visible,"Automatic collection never leaves a box in the driver's hands")
		cargo.recover_package(item)
		if capture and int(item.id)==0:
			await frames(12);await snapshot("delivery-auto-pickup")
		await frames(120)
		check(item.state=="recovered" and cargo.recovered==before+1,"Repeated contact cannot collect the same package twice")
		check(item.body.get_parent()==game.van.body and item.body.visible,"Sparkles stow the original box in the truck")
		if int(item.id)==0:
			cargo.actor.position=cargo.checkpoint_position+Vector3.UP*.1;await frames(5)
			check(cargo.remaining_notice==cargo.quota-1 and str(cargo.quota-1) in cargo.popup,"Checkpoint updates exact remaining count after a partial recovery")
			if capture:
				game.get_window().size=Vector2i(720,1280);game.responsive_layout();cargo.actor.update_camera(1)
				await frames(3);await snapshot("delivery-incomplete-phone")
				game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	check(cargo.recovered==cargo.quota and cargo.load_restored and not cargo.complete,"Exact full load restores truck but does not finish before checkpoint")
	check(not game.van.wrecked and not game.van.cargo_open,"Full recovery repairs truck and closes rear doors")
	await frames(120)
	check(cargo.recovered==cargo.quota and cargo.spawned==cargo.quota,"Recovery has no continuing emissions or duplicate counts")

func check_solid_truck(game:Node) -> void:
	var actor:CharacterBody3D=game.cargo.actor
	game.van.position=Vector3(390,.15,-75);game.van.rotation.y=0
	actor.camera_angle=0;actor.set_physics_process(true)
	for side in [-1,1]:
		actor.position=game.van.position+Vector3(side*4,0,0);actor.velocity=Vector3.ZERO
		Input.action_press("steer_right" if side<0 else "steer_left");await frames(100)
		Input.action_release("steer_right" if side<0 else "steer_left")
		var local:Vector3=game.van.to_local(actor.position)
		check(local.x*side>1.5,"Worker is blocked by the solid truck side, including parked disabled truck")
	for side in [-1,1]:
		actor.position=game.van.position+Vector3(0,0,side*6);actor.velocity=Vector3.ZERO
		Input.action_press("brake_reverse" if side<0 else "accelerate");await frames(100)
		Input.action_release("brake_reverse" if side<0 else "accelerate")
		check(game.van.to_local(actor.position).z*side>2.9,"Worker cannot walk through the truck front or cargo rear")
	actor.set_physics_process(false)

func touch(game:Node,key:String,index:int,pressed:bool,offset:=Vector2.ZERO) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.pressed=pressed
	event.position=(game.touch_controls.regions[key].get_center()+offset)*game.touch_controls.size.x/720
	game.touch_controls._input(event)

func check_mobile_reverse(game:Node) -> void:
	game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(4)
	game.touch_controls.enabled=true;game.touch_controls.layout()
	game.van.position=Vector3(390,.15,-75);game.van.rotation.y=0
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.engine_on=true;game.van.parking_brake=false
	var begin:Vector3=game.van.position
	touch(game,"brake",2,true);await frames(120);touch(game,"brake",2,false)
	check(game.van.speed< -1 and game.van.position.z>begin.z+1,"Mobile BRAKE / REV actually reverses from rest: speed=%s" % game.van.speed)
	game.van.speed=4;game.van.planar_velocity=Vector3(0,0,-4)
	touch(game,"brake",2,true);await frames(180);touch(game,"brake",2,false)
	check(game.van.speed< -1,"Holding mobile brake stops forward travel, then reverses")
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
	touch(game,"stick",1,true,Vector2(0,75));await frames(120);touch(game,"stick",1,false)
	check(game.van.speed< -1,"Pulling mobile stick down reverses the truck")
	touch(game,"stick",1,true,Vector2(70,0));touch(game,"gas",2,true)
	check(Input.is_action_pressed("accelerate") and Input.is_action_pressed("steer_right"),"Two fingers steer and accelerate together")
	touch(game,"stick",1,false)
	check(Input.is_action_pressed("accelerate") and not Input.is_action_pressed("steer_right"),"Releasing steering preserves gas finger")
	game.touch_controls.release_inputs();game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
	game.get_window().size=Vector2i(1280,720);game.responsive_layout();await frames(4)

func check_finish(game:Node,capture:bool) -> void:
	var cargo:Node=game.cargo
	cargo.actor.position=game.van.position+Vector3(3.5,0,0);cargo.toggle_foot();await frames(5)
	check(not cargo.on_foot and game.van.engine_on,"After all returns, player can enter and drive the repaired truck")
	Input.action_press("accelerate");await frames(45);Input.action_release("accelerate")
	check(game.van.speed>1,"Repaired truck responds to gas")
	# Approach the actual painted bay along its road, using normal acceleration.
	game.van.position=cargo.checkpoint.to_global(Vector3(0,.15,30));game.van.rotation.y=cargo.checkpoint.rotation.y
	game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
	Input.action_press("accelerate")
	for i in 300:
		await frames(1)
		if cargo.checkpoint.to_local(game.van.position).z<3:break
	Input.action_release("accelerate")
	check(cargo.checkpoint.to_local(game.van.position).z<5,"Collection bay is physically reachable by driving its access road: checkpoint=%s heading=%s reached=%s local=%s speed=%s" % [cargo.checkpoint_position,cargo.checkpoint.rotation.y,game.van.position,cargo.checkpoint.to_local(game.van.position),game.van.speed])
	game.van.position=cargo.checkpoint_position+Vector3.UP*.15;game.van.speed=2;game.van.planar_velocity=Vector3(0,0,-2)
	await frames(35)
	check(not cargo.complete,"Rolling through collection zone cannot finish the demo")
	game.van.position=cargo.checkpoint_position+Vector3.UP*.15;game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	Input.action_press("handbrake");await frames(90);Input.action_release("handbrake")
	check(cargo.complete and not game.van.engine_on and game.van.parking_brake,"Full load and deliberate full stop complete this demo")
	var finished_at:Vector3=game.van.position
	game.van.engine_on=true;game.van.parking_brake=false;Input.action_press("accelerate");await frames(30);Input.action_release("accelerate")
	check(game.van.position.distance_to(finished_at)<.05 and not game.van.engine_on,"Demo finish cannot be bypassed by restarting ignition or holding gas")
	if capture:
		game.van.set_view(false);await frames(3);await snapshot("delivery-demo-complete")
		game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(3);await snapshot("delivery-complete-phone")
		game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	cargo.next_stage();await frames(15)
	check(not cargo.complete and cargo.stage_index==0 and cargo.quota==12 and cargo.packages.is_empty(),"Replay starts the demo cleanly, not a hidden next level")

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
	await check_walk_animation(game)
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
	await check_cameras(game)

func check_walk_animation(game:Node) -> void:
	var actor:Node=game.cargo.actor
	actor.held.hide();actor.camera_angle=0;actor.set_physics_process(false)
	for direction in ["front","back","left","right"]:
		var clip:String="walk_"+direction
		check(actor.frames[clip].size()==12,"Every direction has twelve drawn walk frames: "+direction)
		var textures:Dictionary={}
		var reference_scale:=0.0
		for frame in 12:
			actor.show_frame(clip,frame);textures[actor.shown_frame.region]=true
			if frame==0:reference_scale=actor.sprite.pixel_size
			check(is_equal_approx(reference_scale,actor.sprite.pixel_size),"Walk drawings keep fixed scale through leg extension")
		check(textures.size()==12,"Cycle advances through twelve separate atlas regions: "+direction)
	# Actual walking input visits every pose, also through the phone touch stick.
	for mobile in [false,true]:
		actor.position=Vector3(400,.08,-75);actor.velocity=Vector3.ZERO;actor.set_physics_process(true)
		if mobile:
			game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(4)
			game.touch_controls.enabled=true;game.touch_controls.layout();touch(game,"stick",4,true,Vector2(0,-75))
		else:Input.action_press("accelerate")
		var visited:Dictionary={}
		for frame in 70:
			await frames(1);visited[actor.shown_frame_index]=true
			check(actor.visual.position.is_zero_approx() and actor.visual.rotation.is_zero_approx(),"Walk movement is drawn in poses without whole-body bob/tilt")
		if mobile:touch(game,"stick",4,false);game.touch_controls.release_inputs()
		else:Input.action_release("accelerate")
		check(visited.size()==12,"Keyboard and mobile input both play the complete twelve-pose cycle")
		await frames(30)
		var stationary:float=actor.phase;await frames(20)
		check(absf(actor.phase-stationary)<.01,"Idle worker does not keep marching in place")
	game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	actor.set_physics_process(true)

func camera_clear(actor:Node,excluded:Array[RID]) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP,actor.camera.global_position)
	query.exclude=excluded
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func check_cameras(game:Node) -> void:
	var actor:Node=game.cargo.actor
	actor.set_physics_process(false);actor.position=Vector3(390,.1,-75);actor.camera_angle=0
	var blocker:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(10,4,.4);shape.shape=box;blocker.add_child(shape);game.add_child(blocker);blocker.position=Vector3(390,2,-71.5)
	await frames(3)
	actor.camera_view=0;actor.camera.global_position=actor.position+Vector3(0,4.4,6.2)
	for i in 60:actor.update_camera(.15);await frames(1)
	check(actor.camera.global_position.y>actor.position.y+6 and camera_clear(actor,[actor.get_rid()]),"Wall obstruction raises the foot camera and keeps worker visible")
	for mode in 3:
		actor.camera_view=mode;actor.update_camera(1)
		check(camera_clear(actor,[actor.get_rid()]),"Every foot camera preset keeps line of sight clear")
	var previous:int=actor.camera_view;game.toggle_camera()
	check(actor.camera_view==(previous+1)%3,"Camera button cycles close raised and overhead views")
	game.touch_controls.enabled=true;game.touch_controls.layout()
	var scale:float=game.touch_controls.size.x/720
	var h:float=game.touch_controls.size.y/scale
	var world_top:float=330 if h>=850 else (130 if h<480 else 250)
	var finger:=InputEventScreenTouch.new();finger.index=7;finger.pressed=true;finger.position=Vector2(400,(world_top+h-180)/2)*scale
	game.touch_controls._input(finger)
	var angle:float=actor.camera_angle
	var drag:=InputEventScreenDrag.new();drag.index=7;drag.relative=Vector2(40,0)*scale;drag.position=finger.position+drag.relative;game.touch_controls._input(drag)
	check(not is_equal_approx(actor.camera_angle,angle),"Swiping clear world space orbits the foot camera")
	finger.pressed=false;game.touch_controls._input(finger);game.touch_controls.release_inputs()
	blocker.queue_free();await frames(3)
	game.van.position=actor.position+Vector3(0,0,3.5);game.van.rotation.y=0
	await frames(3);actor.camera_angle=0;actor.camera_view=0;actor.update_camera(1)
	check(actor.camera.global_position.y>actor.position.y+6 and camera_clear(actor,[actor.get_rid()]),"Truck cannot hide the worker behind its body")
	actor.set_physics_process(true)

func run(game:Node,capture:bool) -> void:
	game.start_drive();await frames(90)
	await check_mobile_reverse(game)
	game.van.reset_vehicle();await frames(60)
	game.cargo.collision_count=0;game.cargo.damage=0;game.cargo.seen_collision=game.van.crash_serial
	game.van.crash_contact_active=false
	check(game.van.is_on_floor(),"Training spawn rests on road")
	check(game.highway.map_data.roads.size()>500 and game.traffic.cars.size()==8,"Mapped downtown and traffic exist")
	game.van.position=Vector3(260,.15,-75);game.van.rotation.y=-PI/2;game.van.speed=12
	Input.action_press("accelerate");await frames(240);Input.action_release("accelerate")
	check(game.highway.entered and game.van.position.x>285,"Actual construction-barrel gateway opens downtown: at=%s speed=%.2f impacts=%d" % [game.van.position,game.van.speed,game.cargo.collision_count])
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1,4,16);collision.shape=shape;wall.add_child(collision);game.add_child(wall);wall.position=Vector3(345,2,-75)
	game.cargo.collision_count=0;game.cargo.damage=0;game.cargo.seen_collision=game.van.crash_serial
	for impact in 3:
		await drive_into_wall(game)
		check(game.cargo.collision_count==impact+1,"Each distinct physical impact counts once")
		if impact<2:
			check(game.cargo.spawned==0 and not game.van.cargo_open and not game.van.wrecked,"First two impacts keep all packages secured and truck driveable")
		if impact==0 and game.cargo.collision_count!=1:
			print("DELIVERY TEST FAIL: sustained first crash counted ",game.cargo.collision_count," collisions")
			await game.quit_demo(1);return
	check(game.cargo.spilled and game.van.wrecked and game.cargo.on_foot,"Third collision disables truck and forces foot recovery")
	check(game.cargo.spawned==game.cargo.quota and game.cargo.quota==12,"Third impact releases exactly the full stage quota once")
	check(game.vehicle_visuals.doors.size()==2 and absf(game.vehicle_visuals.doors[0].rotation.y)>1,"Both physical rear doors open")
	var count:int=game.cargo.spawned
	await frames(360)
	check(game.cargo.spawned==count,"No time-based continuing package drops")
	check(game.cargo.actor.camera.is_current(),"On-foot camera takes control")
	var before:Vector3=game.cargo.actor.position
	Input.action_press("accelerate");await frames(30);Input.action_release("accelerate")
	check(game.cargo.actor.position.distance_to(before)>1,"Player can walk after truck disables")
	await check_worker(game)
	await check_solid_truck(game)
	# Incomplete arrival reports the exact outstanding amount and cannot finish.
	game.cargo.actor.position=game.cargo.checkpoint_position+Vector3.UP*.1;await frames(5)
	check(not game.cargo.complete and game.cargo.remaining_notice==game.cargo.quota and str(game.cargo.quota) in game.cargo.popup,"Early checkpoint popup gives exact missing count")
	await collect_stage(game,capture)
	await check_finish(game,capture)
	# A severe physical crash may tip the truck; it is still only one crash.
	shape.size=Vector3(1,4,100)
	game.van.position=Vector3(330,.15,-75);game.van.rotation.y=-PI/2+.55
	game.van.velocity=Vector3.ZERO;game.van.planar_velocity=-game.van.global_basis.z*34;game.van.speed=34
	await frames(600)
	check(game.cargo.collision_count==1 and not game.van.wrecked and game.cargo.spawned==0,"One severe crash cannot total the delivery truck or release cargo")
	if game.van.overturned:
		check(game.van.roll_settled,"Severe first crash settles for manual recovery")
		game.van.recover_upright();await frames(10)
	check(not game.van.wrecked and game.van.engine_on,"First severe crash remains recoverable with secured cargo")
	wall.queue_free()
	for screen in [Vector2i(720,1280),Vector2i(768,1024),Vector2i(1024,768),Vector2i(1280,720)]:
		game.get_window().size=screen;game.responsive_layout();await frames(4)
		check(game.menu.position.x>=0 and game.menu.position.x+game.menu.size.x<=game.get_window().content_scale_size.x+1,"Menu fits screen "+str(screen))
		if capture:await snapshot("responsive-%dx%d" % [screen.x,screen.y])
	print("DELIVERY TEST ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)

func run_motorway(game:Node) -> void:
	game.start_drive();await frames(90)
	check(game.van.is_on_floor(),"Motorway spawn rests on road")
	for impact in 3:
		if impact>0:
			Input.action_press("accelerate");await frames(180);Input.action_release("accelerate")
			game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;await frames(10)
		game.van.register_collision(10,4);await frames(15)
		check(game.cargo.spawned==(12 if impact==2 else 0),"Motorway also respects three-collision rule")
	await frames(30)
	check(game.cargo.on_foot and game.cargo.actor.is_on_floor(),"Motorway permits safe foot exit")
	await collect_stage(game)
	await check_finish(game,false)
	print("MOTORWAY DELIVERY ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)

