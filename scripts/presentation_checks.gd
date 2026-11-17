extends Node

func run(game:Node) -> void:
	if "--foot-access-review" in OS.get_cmdline_user_args():
		var review:=preload("res://scripts/foot_access_review.gd").new();add_child(review)
		await review.run(game);return
	if "--walk-review" in OS.get_cmdline_user_args():
		var review:=preload("res://scripts/walk_presentation.gd").new();add_child(review)
		await review.run(game);return
	if "--recovery-review" in OS.get_cmdline_user_args():
		await recovery_review(game);return
	if not "--baseline" in OS.get_cmdline_user_args():
		for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390)]:
			game.get_window().size=screen;game.responsive_layout()
			for i in 10:await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/menu-finished-%dx%d.png" % [screen.x,screen.y])
		game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	game.start_drive()
	game.van.camera_manual=true
	game.van.set_view(false)
	var baseline:bool="--baseline" in OS.get_cmdline_user_args()
	var report:Dictionary={"renderer":RenderingServer.get_video_adapter_name(),"baseline":baseline,"samples":[]}
	for setting in [
		["gateway",Vector3(260,.15,-75),Vector3(235,9,-88),Vector3(1030,40,-75)],
		["square",Vector3(1000,.15,-75),Vector3(950,35,-165),Vector3(1040,80,70)],
		["worker",Vector3(1020,.15,-75),Vector3(1000,2.3,-88),Vector3(1000,1.1,-95)]]:
		game.van.position=setting[1];game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
		game.van.camera.global_position=setting[2];game.van.camera.look_at(setting[3])
		if setting[0]=="worker":
			game.cargo.toggle_foot()
			game.cargo.actor.position=Vector3(1000,.1,-95)
			game.cargo.actor.set_physics_process(false)
			game.cargo.actor.show_frame("turn",0)
			game.cargo.actor.camera.global_position=setting[2];game.cargo.actor.camera.look_at(setting[3])
		for i in 35:await get_tree().process_frame
		var samples:Array[float]=[];var previous:=Time.get_ticks_usec();var calls:=0.0;var primitives:=0.0;var physics:=0.0
		for i in 120:
			await get_tree().process_frame
			var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
			calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		var total:=0.0
		for sample in samples:total+=sample
		samples.sort()
		var result:Dictionary={"view":setting[0],"fps":120000/total,"p95_ms":samples[113],"worst_ms":samples[-1],"draw_calls":calls/120,"primitives":primitives/120,"physics_ms":physics/120}
		report.samples.append(result);print("PRESENTATION PROFILE ",JSON.stringify(result))
		get_viewport().get_texture().get_image().save_png("res://docs/presentation-"+setting[0]+("-baseline" if baseline else "-current")+".png")
		if setting[0]=="worker" and not baseline:
			var actor:Node=game.cargo.actor
			actor.camera_angle=0
			actor.camera.global_position=actor.position+Vector3(0,2.2,5.4);actor.camera.look_at(actor.position+Vector3.UP)
			for direction in [["back",0.0],["front",PI],["left",PI/2],["right",-PI/2]]:
				for carrying in [false,true]:
					actor.held.visible=carrying;actor.facing=direction[1];actor.phase=0
					actor.update_illustration(true,false)
					for i in 3:await get_tree().process_frame
					get_viewport().get_texture().get_image().save_png("res://docs/worker-"+direction[0]+("-carry" if carrying else "-walk")+".png")
			actor.held.hide()
			game.van.position=actor.position+Vector3(0,0,3.5);game.van.rotation.y=0
			for i in 5:await get_tree().process_frame
			actor.camera_angle=0;actor.camera_view=0;actor.update_illustration(false,false);actor.update_camera(1)
			for i in 3:await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/camera-truck-obstruction.png")
			actor.camera_angle=PI/2
			for mode in 3:
				actor.camera_view=mode;actor.update_illustration(false,false);actor.update_camera(1)
				for i in 3:await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("res://docs/camera-on-foot-%d.png" % mode)
	game.cargo.on_foot=false;game.cargo.actor.set_enabled(false);game.van.driver_on_foot=false
	game.van.position=Vector3(260,.15,0);game.van.rotation.y=0;game.van.camera_manual=false
	game.van.camera_high=false;game.van.set_view(false)
	for mode in 2:
		game.van.camera_high=bool(mode)
		for i in 60:await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://docs/camera-driving-%d.png" % mode)
	var file:=FileAccess.open("res://docs/presentation-profile-"+("baseline" if baseline else "current")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	await game.quit_demo()

func recovery_review(game:Node) -> void:
	game.start_drive();game.van.set_view(false)
	game.van.position=game.cargo.checkpoint_position+Vector3(18,.15,0)
	game.van.rotation.y=0;game.highway.entered=true
	for i in 3:game.cargo.damage_hit(1)
	for i in 90:await get_tree().physics_frame
	var actor:Node=game.cargo.actor
	actor.set_physics_process(false);actor.camera_angle=.45;actor.camera_view=0
	for item in game.cargo.packages:
		item.body.freeze=true;item.body.position=game.van.position+Vector3(4+int(item.id)*1.4,.4,3)
	actor.position=game.van.position+Vector3(4,.1,3);actor.update_camera(1)
	for i in 12:await get_tree().physics_frame
	await save_recovery_frame("recovery-stars-desktop")
	for i in 130:await get_tree().physics_frame
	for screen in [Vector2i(720,1280),Vector2i(844,390)]:
		game.get_window().size=screen;game.responsive_layout()
		actor.position=game.cargo.checkpoint_position+Vector3.UP*.1;actor.update_camera(1)
		game.cargo.checkpoint_inside=false
		for i in 4:await get_tree().physics_frame
		await save_recovery_frame("recovery-missing-%dx%d" % [screen.x,screen.y])
	for item in game.cargo.packages:game.cargo.recover_package(item)
	for i in 150:await get_tree().physics_frame
	actor.position=game.van.position+Vector3(3.5,0,0);game.cargo.toggle_foot()
	game.van.position=game.cargo.checkpoint_position+Vector3.UP*.15
	game.van.rotation.y=game.cargo.checkpoint.rotation.y;game.van.speed=0;game.van.planar_velocity=Vector3.ZERO
	for i in 85:await get_tree().physics_frame
	for screen in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390)]:
		game.get_window().size=screen;game.responsive_layout()
		for i in 4:await get_tree().physics_frame
		await save_recovery_frame("recovery-finish-%dx%d" % [screen.x,screen.y])
	await game.quit_demo()

func save_recovery_frame(name:String) -> void:
	await get_tree().process_frame;await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/"+name+".png")
