extends Node

func run(game:Node) -> void:
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
	var file:=FileAccess.open("res://docs/presentation-profile-"+("baseline" if baseline else "current")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	await game.quit_demo()
