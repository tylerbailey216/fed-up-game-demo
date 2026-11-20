extends Node
## Zen retains the simulator and physical world without a mandatory delivery.
var failures:Array[String]=[]
var start_transform:=Transform3D.IDENTITY

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("ZEN TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func release() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake","sprint"]:Input.action_release(action)

func prepare(game:Node) -> void:
	release();game.touch_controls.release_inputs()
	game.van.new_truck();game.van.transform=start_transform
	game.van.active=true;game.van.parking_brake=false;game.van.engine_on=true
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	await frames(20)

func check_peaceful(game:Node) -> void:
	var cargo:Node=game.cargo
	check(game.zen and not game.arcade and is_instance_valid(cargo.zen_drive),"Zen uses its own exploration policy")
	check(cargo.checkpoint==null and cargo.arcade_run==null,"Zen creates no collection bay or timed arcade route")
	check(not cargo.complete and not cargo.spilled and cargo.packages.is_empty() and cargo.remaining_packages()==0,"Free driving starts without a package requirement")
	check(cargo.objective().begins_with("ZEN DRIVE") and cargo.popup_time==0,"The normal objective is an unpressured driving hint")
	var resets:int=game.van.reset_count
	cargo.build_checkpoint();cargo.update_checkpoint(10);cargo.next_stage()
	check(cargo.checkpoint==null and not cargo.complete and not game.van.delivery_complete and game.van.reset_count==resets,"Mission entry points cannot add a finish or reset Zen")

func run(game:Node,captures:=false) -> Array[String]:
	game.start_drive();await frames(25)
	start_transform=game.van.transform
	check_peaceful(game)
	var cargo:Node=game.cargo;var van:Node=game.van
	# The actual population remains active before isolated control checks.
	check(game.traffic.cars.size()>0,"Both Zen sceneries retain live vehicles")
	if not game.outerbelt:
		check(game.traffic.cars.size()>0 and is_instance_valid(game.city_life) and game.city_life.citizens.size()>0,"Zen city retains live vehicles and the supplied citizen cast")
	var car_positions:Array[Vector3]=[]
	for car in game.traffic.cars:
		car_positions.append(car.position);check(car.cruise_speed<=(9.0 if game.outerbelt else 5.5),"Zen traffic uses the quieter pace appropriate to this scenery")
	await frames(100)
	var moved:=false
	for index in game.traffic.cars.size():moved=moved or game.traffic.cars[index].position.distance_to(car_positions[index])>.2
	check(moved,"Zen traffic remains simulated instead of becoming scenery")
	if game.outerbelt:
		check(game.traffic.routes.size()==4 and game.traffic.cars.size()==12,"Open Road uses four actual mainlines and a bounded twelve-car pool")
		for car in game.traffic.cars:
			var query:=PhysicsRayQueryParameters3D.create(car.position+Vector3.UP*.5,car.position-Vector3.UP*1.2,1)
			query.exclude=[car.get_rid()]
			var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider is StaticBody3D and hit.normal.y>.85,"Open-road cars stay supported on actual elevated decks")
	var traffic_active:bool=game.traffic.is_physics_processing();var life_active:bool=game.city_life.is_physics_processing() if game.city_life else false
	var population:Array[Dictionary]=[]
	game.traffic.set_physics_process(false)
	if game.city_life:game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		population.append({"node":car,"physics":car.is_physics_processing(),"layer":car.collision_layer,"mask":car.collision_mask,"freeze":car.freeze})
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0;car.collision_mask=0
	if game.city_life:
		for citizen in game.city_life.citizens:
			population.append({"node":citizen,"physics":citizen.is_physics_processing(),"layer":citizen.collision_layer,"mask":citizen.collision_mask})
			citizen.set_physics_process(false);citizen.collision_layer=0;citizen.collision_mask=0
	await check_controls(game)
	await check_collision_policy(game)
	await check_service(game)
	await check_walking(game)
	if captures:await capture_layouts(game)
	check(game.zen and not game.arcade and cargo.checkpoint==null and not cargo.complete,"Zen policy survives driving, service and walking in this scenery")
	release();game.traffic.set_physics_process(traffic_active)
	if game.city_life:game.city_life.set_physics_process(life_active)
	for item in population:
		item.node.set_physics_process(item.physics);item.node.collision_layer=item.layer;item.node.collision_mask=item.mask
		if item.has("freeze"):item.node.freeze=item.freeze
	print("ZEN TEST PASS" if failures.is_empty() else "ZEN TEST FAIL: "+str(failures))
	return failures

func check_controls(game:Node) -> void:
	await prepare(game)
	var van:Node=game.van;var begin:Vector3=van.position;var forward:Vector3=-van.global_basis.z
	Input.action_press("accelerate");await frames(120);Input.action_release("accelerate")
	check(van.speed>3 and (van.position-begin).dot(forward)>3,"Actual gas input drives the Zen simulator forward")
	await frames(45)
	check(van.speed>2,"Zen keeps simulator coasting rather than arcade release braking")
	Input.action_press("brake_reverse");await frames(210)
	check(van.speed< -1,"Holding brake stops and selects actual simulator reverse")
	begin=van.position;await frames(60);Input.action_release("brake_reverse")
	check((van.position-begin).dot(forward)< -1,"Reverse input produces real backwards movement")
	Input.action_press("handbrake");await frames(80);Input.action_release("handbrake")
	van.set_view(true);check(van.cockpit,"Zen retains the illustrated cockpit view")
	van.orbit_camera(.45,.1);await frames(10)
	check(not van.cockpit and absf(van.camera_orbit)>.3,"Zen retains free truck orbit outside the cockpit")

func check_collision_policy(game:Node) -> void:
	await prepare(game)
	var cargo:Node=game.cargo;var van:Node=game.van
	for impact in 8:cargo.damage_hit(1)
	cargo.damage=100;cargo.spill();cargo.drop_package();await frames(3)
	check(cargo.damage==0 and not cargo.spilled and cargo.packages.is_empty() and cargo.spawned==0 and not van.wrecked,"Even cumulative or direct damage calls cannot force a Zen cargo quest")
	var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10,6,.6);collision.shape=box;wall.add_child(collision)
	game.add_child(wall);wall.position=van.position-van.global_basis.z*12+Vector3.UP*3;wall.rotation.y=van.rotation.y
	await frames(4);var serial:int=van.crash_serial;var begin:Vector3=van.position
	Input.action_press("accelerate");await frames(245);Input.action_release("accelerate")
	check(van.crash_serial>serial and van.position.distance_to(begin)<14,"An actual low-speed wall contact remains solid and registers collision effects")
	check(not cargo.on_foot and not cargo.spilled and not van.wrecked and cargo.damage==0 and cargo.popup_time==0,"A physical collision leaves Zen free from forced collection or exit prompts")
	wall.queue_free();await frames(4)

func check_service(game:Node) -> void:
	await prepare(game)
	var van:Node=game.van;var cargo:Node=game.cargo
	van.engine_on=false;van.parking_brake=true;await frames(30)
	check(not van.engine_on and van.parking_brake,"Zen service respects deliberate ignition and parking controls")
	var before:Vector3=van.position
	check(cargo.zen_drive.service() and van.engine_on and van.parking_brake and van.position.distance_to(before)<.2,"Explicit service restores the same upright truck without moving it or clearing its parking brake")
	van.parking_brake=false;van.fuel_gallons=0;van.engine_on=false;await frames(5)
	check(van.fuel_gallons>0 and van.engine_on,"An empty tank does not permanently strand a Zen drive")
	van.wrecked=true;van.engine_on=false;await frames(5)
	check(not van.wrecked and van.engine_on and not cargo.on_foot,"Unexpected damage disable repairs without forcing the worker outside")
	await prepare(game)
	van.wall_normal=van.global_basis.x;van.planar_velocity=-van.global_basis.z*10
	var started:bool=van.begin_rollover(28,20,1)
	check(started,"Rollover setup starts the existing physical collision response")
	for frame in 1200:
		await frames(1)
		if not van.overturned:break
	await frames(30)
	check(not van.overturned and not van.wrecked and van.engine_on and not cargo.on_foot and cargo.packages.is_empty(),"A settled physical rollover returns to driving without a mandatory delivery failure")

func check_walking(game:Node) -> void:
	await prepare(game)
	var cargo:Node=game.cargo;var van:Node=game.van
	cargo.toggle_foot();await frames(5)
	check(cargo.on_foot and cargo.actor.enabled and cargo.actor.camera.is_current(),"Zen permits walking with the same playable worker")
	var begin:Vector3=cargo.actor.position;Input.action_press("accelerate");await frames(35);Input.action_release("accelerate")
	check(cargo.actor.position.distance_to(begin)>1,"The worker responds to actual walking input without packages")
	cargo.actor.position=van.position+van.global_basis.x*3.5;cargo.actor.velocity=Vector3.ZERO
	var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_X;game._unhandled_key_input(event);await frames(5)
	check(not cargo.on_foot and van.engine_on and not van.driver_on_foot,"X re-enters the Zen truck without any collection gate")
	van.notice_time=0;cargo.popup_time=0
	check(game.dashboard.status_message().begins_with("ZEN DRIVE") and not game.recovery_panel.visible,"Normal Zen HUD has no mandatory stage or lingering completion panel")

func capture_layouts(game:Node) -> void:
	var dimensions:Vector2i=game.get_window().size;var preview:bool=game.dashboard.touch_preview
	for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390),Vector2i(768,1024)]:
		game.set_resolution(screen);game.dashboard.touch_preview=screen.x!=1280;game.update_hud(0,"N",game.van.distance);await frames(5)
		check(not game.recovery_panel.visible and game.cargo.checkpoint==null,"Zen layout remains free of mandatory mission panels: "+str(screen))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/zen-%s-%dx%d.png" % ["road" if game.outerbelt else "city",screen.x,screen.y])
	game.set_resolution(dimensions);game.dashboard.touch_preview=preview;game.update_hud(0,"N",game.van.distance)
