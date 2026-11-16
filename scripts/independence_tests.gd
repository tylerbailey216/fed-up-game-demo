extends Node

func run(game: Node,capture: bool) -> void:
	var world: Node3D = game.highway
	game.start_drive()
	game.van.set_view(false)
	for i in 24: await get_tree().physics_frame
	if "--safety" in OS.get_cmdline_user_args():
		await preload("res://scripts/road_safety_tests.gd").new().run(game)
		await game.quit_demo()
		return
	if "--profile" in OS.get_cmdline_user_args():
		await preload("res://scripts/map_profile.gd").new().run(game)
		await game.quit_demo()
		return
	assert(world.road_points.size()>1000,"Real mapped geometry loaded")
	assert(world.map_data.buildings.size()>50,"Mapped building footprints loaded")
	assert(game.traffic.cars.is_empty(),"Fictional district excluded from geographic map")
	var checked := 0
	var bridge_checked := 0
	for road in world.map_data.roads:
		if road.kind not in ["motorway","motorway_link","primary"]:continue
		for i in range(1,road.nodes.size(),7):
			var p: Vector3 = world.road_points[road.nodes[i-1]].lerp(world.road_points[road.nodes[i]],0.43)
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.3)
			ray.exclude=[game.van.get_rid()]
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			assert(not hit.is_empty(),"Mapped asphalt must have collision at %s" % p)
			assert(hit.normal.y>0.7,"Road surface must face upward")
			checked+=1
			if road.bridge:bridge_checked+=1
	assert(bridge_checked>10,"Elevated crossing decks checked")
	assert(game.van.is_on_floor(),"Spawn settles onto mapped freeway")
	assert(game.van.offroad_recoveries==0)
	if not capture:
		for i in 36:
			var probe:Vector3=world.road_points[(i*251)%world.road_points.size()]+Vector3(9,0,-6)
			var expected:=INF
			for p in world.road_points:expected=minf(expected,p.distance_to(probe))
			assert(absf(world.nearest_road(probe).distance-expected)<0.01,"Indexed nearest-road matches exhaustive result")
			assert(world.has_road_near(probe)==(expected<7),"Local safety query matches exhaustive result")
	if capture:
		await capture_views(game)
		await game.quit_demo()
		return
	# Continuous input-driven freeway traversal, including grade changes and joins.
	var route: Array=world.map_data.test_route
	assert(route.size()>100,"Connected freeway test route")
	game.van.position=world.road_points[route[0]]+Vector3.UP*0.15
	var direction:Vector3=world.road_points[route[1]]-world.road_points[route[0]]
	game.van.rotation.y=atan2(-direction.x,-direction.z)
	var target:=1
	var max_gap:=0.0
	for frame in 9000:
		while target<route.size()-1 and Vector2(game.van.position.x-world.road_points[route[target]].x,game.van.position.z-world.road_points[route[target]].z).length()<16:
			target+=1
		var aim:Vector3=world.road_points[route[target]]-game.van.position
		if target==route.size()-1 and Vector2(aim.x,aim.z).length()<16:break
		var error:=wrapf(atan2(-aim.x,-aim.z)-game.van.rotation.y,-PI,PI)
		var turn:=clampf(error*3,-1,1)
		Input.action_press("steer_left",maxf(turn,0))
		Input.action_press("steer_right",maxf(-turn,0))
		Input.action_press("accelerate",clampf((18-game.van.speed)*0.6,0,1))
		var nearby:Vector3=world.road_points[route[maxi(0,target-1)]]
		max_gap=maxf(max_gap,absf(game.van.position.y-nearby.y))
		await get_tree().physics_frame
	for action in ["accelerate","steer_left","steer_right"]:Input.action_release(action)
	print("TRAVERSE: target %d/%d pos %s target %s speed %.2f collisions %d flips %d recovery %d" % [target,route.size(),game.van.position,world.road_points[route[target]],game.van.speed,game.van.collision_serial,game.van.flip_count,game.van.offroad_recoveries])
	assert(target==route.size()-1,"Truck drives connected freeway to end")
	assert(game.van.offroad_recoveries==0,"Continuous freeway drive needs no rescue")
	assert(not game.van.overturned,"No false crash on road joins")
	assert(max_gap<2,"Truck follows road elevations through approaches")
	print("CONTINUOUS I-480: %.0fm, %d samples, max elevation gap %.2fm" % [game.van.distance,route.size(),max_gap])
	game.van.speed=0
	game.van.velocity=Vector3.ZERO
	# Follow connected eastbound freeway samples through approaches and bridge seams.
	var traveled := 0.0
	var previous: Vector3 = game.van.position
	for road in world.map_data.roads:
		if road.ref!="I 480":continue
		if world.road_points[road.nodes[-1]].x<world.road_points[road.nodes[0]].x:continue
		for i in range(1,road.nodes.size(),5):
			var p: Vector3 = world.road_points[road.nodes[i-1]].lerp(world.road_points[road.nodes[i]],0.43)
			game.van.position=p+Vector3.UP*0.13
			game.van.speed=0
			game.van.velocity=Vector3.ZERO
			for frame in 6:await get_tree().physics_frame
			if absf(game.van.position.y-p.y)>=0.3:
				print("DECK FAIL road %s sample %s truck %s" % [road.id,p,game.van.position])
			assert(absf(game.van.position.y-p.y)<0.3,"Freeway deck supports truck")
			traveled+=p.distance_to(previous)
			previous=p
	game.van.reset_vehicle()
	for i in 8:await get_tree().physics_frame
	var spawn:Vector3=game.van.position
	Input.action_press("accelerate")
	for i in 240:await get_tree().physics_frame
	Input.action_release("accelerate")
	assert(game.van.position.distance_to(spawn)>15,"Playable truck moves on real road")
	assert(game.van.offroad_recoveries==0,"No old 500m boundary on new map")
	game.van.position.x=980
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(game.van.offroad_recoveries==1,"Geographic boundary recovers truck")
	print("INDEPENDENCE PASS: %d surface rays, %d bridge rays; %.0fm mapped sampling; acceleration, map boundary, reset" % [checked,bridge_checked,traveled])
	await game.quit_demo()

func capture_views(game: Node) -> void:
	game.dashboard.show_gps=true
	game.van.reset_vehicle()
	game.van.notice_time=0
	for i in 10:await get_tree().physics_frame
	game.van.camera_manual=true
	game.van.camera.global_position=Vector3(300,700,650)
	game.van.camera.look_at(Vector3(0,8,0))
	game.van.camera.far=4000
	game.hud.hide()
	await get_tree().create_timer(1).timeout
	game.get_viewport().get_texture().get_image().save_png("res://docs/independence-overview.png")
	game.hud.show()
	game.van.set_view(false)
	game.van.camera_manual=false
	await get_tree().create_timer(0.5).timeout
	game.get_viewport().get_texture().get_image().save_png("res://docs/independence-drive.png")
	game.van.set_view(true)
	game.dashboard.expanded_map=true
	await get_tree().create_timer(0.4).timeout
	game.get_viewport().get_texture().get_image().save_png("res://docs/independence-map.png")
	game.return_to_menu()
	await get_tree().create_timer(0.3).timeout
	game.get_viewport().get_texture().get_image().save_png("res://docs/independence-menu.png")
	print("INDEPENDENCE CAPTURE PASS: spawn, road/bridge rays, overview, chase, cockpit/map")
