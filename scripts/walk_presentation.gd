extends Node
## Fixed-step, real-input footage for reviewing each direction at normal speed.
func run(game:Node) -> void:
	game.start_drive();game.van.position=Vector3(350,.15,-30);game.van.speed=0
	game.cargo.toggle_foot()
	var actor:Node=game.cargo.actor
	actor.camera_angle=0;actor.camera_view=0;actor.camera_zoom=.8
	for layout in [["desktop",Vector2i(960,540)],["phone",Vector2i(540,960)]]:
		game.get_window().size=layout[1];game.responsive_layout()
		var folder:String="res://tools/userdata/walk-preview/"+layout[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var index:=0
		for direction in [["front","brake_reverse"],["back","accelerate"],["left","steer_left"],["right","steer_right"]]:
			actor.position=Vector3(370,.08,-20);actor.velocity=Vector3.ZERO;actor.phase=0
			actor.update_camera(1)
			Input.action_press(direction[1])
			for frame in 96:
				await RenderingServer.frame_post_draw
				if frame%2==0:
					get_viewport().get_texture().get_image().save_png(folder+"/%04d.png" % index);index+=1
			Input.action_release(direction[1])
			for frame in 15:await get_tree().physics_frame
		print("WALK REVIEW ",layout[0]," captured ",index," frames at 30 fps")
	await game.quit_demo()
