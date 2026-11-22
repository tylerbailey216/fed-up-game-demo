extends Node
## Opt-in visual evidence only. Never loaded during normal play.
func run(game:Node) -> void:
	game.start_drive()
	if not game.arcade and not game.outerbelt:
		game.van.position=Vector3(1000,.15,-75);game.van.rotation.y=0
	game.van.set_view(not game.arcade and not game.outerbelt)
	game.van.parking_brake=true
	for i in 30:await get_tree().physics_frame
	game.van.set_physics_process(false);game.traffic.set_physics_process(false)
	for car in game.traffic.cars:car.freeze=true;car.set_physics_process(false)
	if game.city_life:
		game.city_life.set_physics_process(false)
		for person in game.city_life.citizens:person.set_physics_process(false)
	var zone:String="arcade" if game.arcade else ("open-road" if game.outerbelt else "city")
	var pass_name:String="before" if "--before" in OS.get_cmdline_user_args() else "after"
	for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390)]:
		game.get_window().size=screen;game.responsive_layout()
		for i in 18:await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png("res://docs/art-review-%s-%s-%dx%d.png" % [pass_name,zone,screen.x,screen.y])
		print("ART REVIEW ",zone," ",screen," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," triangles=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if game.arcade:
		game.fixed_camera.set_process(false);game.cargo.toggle_foot()
		var actor:Node=game.cargo.actor
		actor.set_physics_process(false);actor.position=Vector3(107.5,.08,110)
		actor.camera_angle=0;actor.facing=PI;actor.update_illustration(false,false)
		actor.camera.current=true;actor.camera.fov=45
		actor.camera.global_position=Vector3(110,2,116);actor.camera.look_at(Vector3(110,1,110))
		for i in 3:
			var person:Node=game.city_life.citizens[[0,3,4][i]]
			person.position=Vector3(109.2+float(i)*1.65,.08,110);person.visible=true
			person.state="wait";person.facing=PI;person.show_pose()
		game.get_window().size=Vector2i(1280,720);game.responsive_layout();game.hud.hide()
		for i in 8:await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png("res://docs/art-review-%s-cast-1280x720.png" % pass_name)
		game.highway.restore_cutaways()
		actor.camera.global_position=Vector3(-11,7,-3)
		actor.camera.look_at(Vector3(-24,2.2,-16))
		for i in 8:await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png("res://docs/art-review-%s-storefront-1280x720.png" % pass_name)
	if game.outerbelt:
		# A separate inspection camera checks the formerly black industrial
		# facades; gameplay cameras and controls are never changed by this tool.
		var building:Dictionary=game.highway.map_data.buildings[0]
		var center:=Vector3.ZERO
		for p in building.polygon:center+=Vector3(p[0],0,p[1])
		center/=building.polygon.size()
		var span:=10.0
		for p in building.polygon:span=maxf(span,center.distance_to(Vector3(p[0],0,p[1])))
		game.get_window().size=Vector2i(1280,720);game.responsive_layout();game.hud.hide()
		game.van.camera_manual=true;game.van.camera.global_position=center+Vector3(span*1.7,maxf(span,float(building.height)*1.5),span*1.7)
		game.van.camera.look_at(center+Vector3.UP*float(building.height)*.4)
		for i in 8:await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png("res://docs/art-review-%s-facade-1280x720.png" % pass_name)
	await game.quit_demo()
