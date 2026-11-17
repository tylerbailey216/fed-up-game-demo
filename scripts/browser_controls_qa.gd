extends Node
## Opt-in browser fixture; ordinary games never expose this telemetry/control.
var game:Node
var clock:=0.0

func reset() -> void:
	game.touch_controls.release_inputs();game.touch_controls.reverse_selected=false
	game.van.position=Vector3(390,.15,-75);game.van.rotation.y=0
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	game.van.engine_on=true;game.van.parking_brake=false;game.van.reverse_delay=0

func _ready() -> void:
	game.start_drive();reset()

func _physics_process(delta:float) -> void:
	clock+=delta
	if clock<.08:return
	clock=0
	var command:String=JavaScriptBridge.eval("window.fedupQACommand || ''")
	if not command.is_empty():
		JavaScriptBridge.eval("window.fedupQACommand=''")
		if command=="reset":reset()
		elif command=="no_msaa":game.get_viewport().msaa_3d=Viewport.MSAA_DISABLED
		elif command=="restore_msaa":game.get_viewport().msaa_3d=Viewport.MSAA_2X
		elif command=="half_resolution":game.get_viewport().scaling_3d_scale=.5
		elif command=="full_resolution":game.get_viewport().scaling_3d_scale=1.0
		elif command=="short_view":game.get_viewport().get_camera_3d().far=550
		elif command=="quiet_camera":game.cargo.actor.set_physics_process(false)
		elif command=="hide_hud":
			game.hud.hide();game.dashboard.set_process(false);game.touch_controls.set_process(false)
		elif command=="hide_world":game.highway.hide()
		elif command=="quiet_citizens":
			for person in game.city_life.citizens:person.set_physics_process(false)
		elif command=="quiet_traffic":
			game.traffic.set_physics_process(false)
			for car in game.traffic.cars:car.set_physics_process(false);car.freeze=true
		elif command=="quiet_audio":
			game.master_volume=0;game.audio_manager.set_process(false)
			for player in game.audio_manager.players.values():player.stop()
			for car in game.traffic.cars:car.horn_player.stop();car.impact_player.stop()
		elif command=="restore_audio":game.master_volume=.7;game.audio_manager.set_process(true)
		elif command=="hide_citizens":
			for person in game.city_life.citizens:person.hide();person.set_physics_process(false)
		elif command=="spill":
			reset()
			for i in 3:game.cargo.damage_hit(1)
			game.cargo.toggle_foot()
			game.cargo.actor.position=Vector3(400,.08,-75);game.cargo.actor.camera_angle=0
			game.cargo.pickup_previous=game.cargo.actor.position
			for item in game.cargo.packages:
				item.body.freeze=true;item.body.position=Vector3(400,.4,-79-float(item.id)*2.6)
		elif command=="city":
			game.van.position=game.city_life.center-game.city_life.forward*18
			game.van.rotation.y=atan2(-game.city_life.forward.x,-game.city_life.forward.z);game.van.set_view(false)
			if game.cargo.on_foot:
				game.cargo.actor.position=game.city_life.center+game.city_life.side*9
				game.cargo.actor.camera_angle=game.van.rotation.y
	var regions:Dictionary={}
	var size:Vector2=game.touch_controls.size;var scale:float=size.x/720
	for key in game.touch_controls.regions:
		var r:Rect2=game.touch_controls.regions[key]
		regions[key]=[r.position.x*scale/size.x,r.position.y*scale/size.y,r.size.x*scale/size.x,r.size.y*scale/size.y]
	var data:Dictionary={"build":JSON.parse_string(FileAccess.get_file_as_string("res://data/build_version.json")).state_id,"speed":game.van.speed,"position":[game.van.position.x,game.van.position.z],"on_foot":game.cargo.on_foot,"collected":game.cargo.recovered,"quota":game.cargo.quota,"restored":game.cargo.load_restored,"hands_empty":not game.cargo.actor.held.visible,"distance_to_truck":game.cargo.actor.position.distance_to(game.van.position),"reverse":game.touch_controls.reverse_selected,"regions":regions,"citizens":game.city_life.citizens.size(),"cars":game.traffic.cars.size()}
	data["physics_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	data["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000
	data["draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	data["primitives"]=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	JavaScriptBridge.eval("window.fedupQA="+JSON.stringify(data))
