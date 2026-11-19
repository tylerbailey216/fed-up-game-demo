extends Node
var failures:Array[String]=[]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("ARCADE TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func park(game:Node,at:Vector3) -> void:
	game.van.position=at+Vector3.UP*.15;game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
	game.van.parking_brake=true
	await frames(12)

func drive_route(game:Node) -> void:
	for point in game.highway.route_points:await park(game,point)

func run(game:Node,capture:=false) -> void:
	game.start_drive();var cargo:Node=game.cargo;var run_state:Node=cargo.arcade_run
	check(game.arcade and not game.outerbelt,"Dedicated compact world selected")
	check(game.traffic.cars.size()==10 and game.city_life.citizens.size()==16,"Bounded live traffic and existing citizen cast")
	check(not game.van.cockpit and game.van.camera_high and is_instance_valid(game.fixed_camera),"Arcade starts in the stable elevated map view")
	var cameras:=preload("res://scripts/fixed_camera_tests.gd").new();add_child(cameras)
	failures.append_array(await cameras.run(game,capture))
	game.traffic.set_physics_process(false);game.city_life.set_physics_process(false)
	for car in game.traffic.cars:car.freeze=true
	for person in game.city_life.citizens:person.set_physics_process(false)
	await check_surfaces(game)
	game.van.parking_brake=false;var before:Vector3=game.van.position
	Input.action_press("accelerate");await frames(140);Input.action_release("accelerate")
	check(game.van.position.distance_to(before)>5 and game.van.is_on_floor(),"Actual driving input moves the truck along the compact road")
	await park(game,cargo.checkpoint_position);await frames(85)
	check(not cargo.complete and run_state.route_index==0,"Bay cannot skip the route")
	await park(game,game.highway.route_points[2]);check(run_state.route_index==0,"Wrong-order gate does not count")
	cargo.on_foot=true;await park(game,game.highway.route_points[0]);check(run_state.route_index==0,"On-foot gate visits do not count");cargo.on_foot=false
	await drive_route(game);check(run_state.route_finished(),"All ordered route gates count")
	await park(game,cargo.checkpoint_position);game.van.speed=2;cargo.update_checkpoint(.5)
	check(not cargo.complete,"A moving truck cannot finish")
	game.van.speed=0;await frames(85)
	check(cargo.complete and not cargo.spilled and cargo.spawned==0,"Clean delivery finishes with the original manifest")
	check(game.van.delivery_complete and not game.van.engine_on,"Completed run safely stops truck")
	if capture:await capture_layouts(game,"report")
	cargo.next_stage();await frames(5)
	check(not cargo.complete and not game.van.delivery_complete and run_state.route_index==0 and run_state.energy_used==0,"Replay resets mission, gates, report and vehicle lock")
	await park(game,game.highway.spawn_position)
	for i in 5:cargo.damage_hit(.18)
	check(not cargo.spilled and cargo.damage<100 and cargo.packages.is_empty(),"Several small bumps do not spill the load")
	cargo.damage=99;cargo.spill();check(not cargo.spilled,"Spill refuses a nonempty energy bar")
	cargo.damage_hit(.18);await frames(20)
	check(cargo.spilled and cargo.spawned==cargo.quota and cargo.on_foot,"Energy depletion spills the fixed manifest and exits truck")
	cargo.spill();cargo.damage_hit(1);await frames(30)
	check(cargo.packages.size()==cargo.quota,"No repeat or continuous spills")
	# Real walk-over collection path, with the same animation/credit flow as play.
	for item in cargo.packages:
		if item.state!="loose":continue
		item.body.freeze=true;item.body.global_position=cargo.actor.global_position+Vector3.UP*.3
		await frames(2)
	await frames(110)
	check(cargo.recovered==cargo.quota and cargo.load_restored and not game.van.wrecked,"Walk-over contact repairs the truck after the fixed load is recovered")
	check(not cargo.actor.held.visible,"No carrying/deposit step")
	cargo.actor.position=game.van.position+game.van.global_basis.x*3.5;cargo.toggle_foot();await frames(2)
	check(not cargo.on_foot,"Desktop re-entry works beside repaired truck")
	await drive_route(game);await park(game,cargo.checkpoint_position);await frames(85)
	check(cargo.complete and run_state.energy_used>0,"Recovery run completes with a report")
	if capture:await capture_layouts(game,"recovery")
	cargo.next_stage();await frames(8)
	check(cargo.packages.is_empty() and cargo.spawned==0 and cargo.recovered==0 and cargo.damage==0 and not cargo.on_foot,"Recovery replay clears packages and restores manifest")
	if capture:await capture_layouts(game,"drive")
	print("ARCADE TEST PASS" if failures.is_empty() else "ARCADE TEST FAIL: "+str(failures))
	await game.quit_demo(0 if failures.is_empty() else 1)

func check_surfaces(game:Node) -> void:
	await frames(3)
	var excluded:Array[RID]=[game.van.get_rid()]
	for car in game.traffic.cars:excluded.append(car.get_rid())
	var space:PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	for path in game.highway.street_paths:
		for i in 11:
			var at:Vector3=path[0].lerp(path[1],i/10.0)
			var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP,1);ray.exclude=excluded
			var hit:=space.intersect_ray(ray)
			check(not hit.is_empty() and absf(hit.position.y)<.02 and hit.normal.y>.99,"Every arcade road has a continuous physical ground surface")
	for sample in [[Vector3(-37.5,0,25),"sidewalk",.16],[Vector3(20,0,25),"grass",.16]]:
		var ray:=PhysicsRayQueryParameters3D.create(sample[0]+Vector3.UP*2,sample[0]-Vector3.UP,1);ray.exclude=excluded
		var hit:=space.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y-float(sample[2]))<.02 and preload("res://scripts/terrain_surface.gd").kind(game.van,hit)==sample[1],"Raised sidewalk/park height and per-wheel terrain identities survive the compact world")

func capture_layouts(game:Node,suffix:String) -> void:
	for dimensions in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390),Vector2i(768,1024)]:
		game.set_resolution(dimensions);game.dashboard.touch_preview=dimensions.x!=1280
		await frames(15)
		if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png("res://tools/arcade-%s-%dx%d.png" % [suffix,dimensions.x,dimensions.y])
