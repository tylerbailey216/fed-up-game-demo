extends RefCounted

func run(game: Node) -> void:
	var original_gps: bool=game.dashboard.show_gps
	var report := {"renderer":RenderingServer.get_video_adapter_name(),"samples":[]}
	var started := Time.get_ticks_usec()
	for i in 64:game.highway.nearest_road(game.van.position+Vector3(i,0,20))
	report.query_average_ms=(Time.get_ticks_usec()-started)/64000.0
	for cockpit in [false,true]:
		for gps in [true,false]:
			game.van.reset_vehicle()
			game.van.set_view(cockpit)
			game.dashboard.show_gps=gps
			Input.action_press("accelerate")
			for i in 30:await game.get_tree().process_frame
			var samples: Array[float]=[]
			var process_ms:=0.0
			var physics_ms:=0.0
			var draws:=0.0
			var previous:=Time.get_ticks_usec()
			for i in 240:
				await game.get_tree().process_frame
				var now:=Time.get_ticks_usec()
				samples.append((now-previous)/1000.0)
				previous=now
				process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
				physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
				draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			Input.action_release("accelerate")
			var total:=0.0
			var slow:=0
			for ms in samples:
				total+=ms
				if ms>33.34:slow+=1
			samples.sort()
			var result:Dictionary={"cockpit":cockpit,"gps":gps,"fps":240000.0/total,"p95_ms":samples[227],"worst_ms":samples[-1],"frames_over_33ms":slow,"cpu_process_ms":process_ms/240,"cpu_physics_ms":physics_ms/240,"draw_calls":draws/240}
			report.samples.append(result)
			print("MAP PROFILE ",JSON.stringify(result))
	var suffix:="baseline" if "--baseline" in OS.get_cmdline_user_args() else "optimized"
	var file:=FileAccess.open("res://docs/independence-performance-"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("ROAD QUERY average_ms=",report.query_average_ms)
	game.dashboard.show_gps=original_gps
