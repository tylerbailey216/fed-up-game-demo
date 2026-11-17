extends Node
func run(game:Node) -> void:
	game.start_drive();game.van.position=Vector3(320,.15,9);game.van.rotation.y=game.cargo.checkpoint.rotation.y
	game.van.set_view(false)
	while game.cargo.damage<100:game.cargo.damage_hit(1)
	for frame in 70:await get_tree().physics_frame
	var actor:Node=game.cargo.actor
	actor.set_physics_process(false);actor.position=Vector3(332,.08,22);actor.camera_zoom=1
	actor.velocity=Vector3.ZERO;actor.facing=game.van.rotation.y;actor.camera_angle=actor.facing;actor.camera_pitch=0
	var forward:Vector3=-game.van.global_basis.z;var side:Vector3=game.van.global_basis.x
	for item in game.cargo.packages:
		item.body.freeze=true;item.body.position=actor.position+forward*(10+floori(int(item.id)/4.0)*6)+side*((int(item.id)%4)-1.5)*3+Vector3.UP*.3
	for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390)]:
		game.get_window().size=screen;game.responsive_layout()
		for mode in 3:
			actor.camera_view=mode;actor.update_camera(1);actor.update_illustration(false,false)
			for frame in 4:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/foot-access-%d-%dx%d.png" % [mode,screen.x,screen.y])
		actor.camera_view=0;actor.camera_angle=wrapf(actor.facing+PI,-PI,PI);actor.update_camera(1)
		for frame in 4:await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/foot-guide-behind-%dx%d.png" % [screen.x,screen.y])
		actor.recenter_camera()
	await game.quit_demo()
