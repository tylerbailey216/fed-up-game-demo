extends Node
func run(game:Node) -> void:
	game.start_drive()
	var life:Node=game.city_life
	game.van.position=life.center-life.forward*22+Vector3.UP*.1
	game.van.rotation.y=atan2(-life.forward.x,-life.forward.z);game.van.set_view(false)
	for i in 90:await get_tree().physics_frame
	for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390)]:
		game.get_window().size=screen;game.responsive_layout()
		for i in 10:await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/city-life-%dx%d.png" % [screen.x,screen.y])
	game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	game.cargo.toggle_foot()
	game.cargo.actor.position=life.center+life.side*9;game.cargo.actor.camera_angle=atan2(-life.forward.x,-life.forward.z)
	for i in 2:
		var person:Node=life.citizens[i];person.position=game.cargo.actor.position+life.forward*4+life.side*(3 if i==0 else -3)
		person.set_physics_process(false);person.state="wait";person.facing=game.cargo.actor.camera_angle+PI;person.show_pose()
	for i in 45:await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png("res://docs/citizens-with-driver.png")
	var person:Node=life.citizens[0]
	person.set_physics_process(true)
	person.position=game.cargo.actor.position+life.forward*3;person.cooldown=0;person.react(life.side,8)
	for i in 24:await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png("res://docs/citizen-cartoon-bounce.png")
	for i in 240:await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png("res://docs/citizen-resumed-route.png")
	await game.quit_demo()
