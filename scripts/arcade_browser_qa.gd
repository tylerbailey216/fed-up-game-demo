extends Node
## Opt-in fixture: qa=arcade. Never loaded in ordinary games.
var game:Node
var clock:=0.0
var seen_crash:=-1
var last_crash:Dictionary={}

func _ready() -> void:
	game.start_drive()

func park(at:Vector3) -> void:
	game.touch_controls.release_inputs();game.van.position=at+Vector3.UP*.15
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO;game.van.parking_brake=true

func quiet_population() -> void:
	game.traffic.set_physics_process(false);game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0;car.collision_mask=0
	for citizen in game.city_life.citizens:
		citizen.set_physics_process(false);citizen.collision_layer=0;citizen.collision_mask=0

func _physics_process(delta:float) -> void:
	if game.van.crash_serial!=seen_crash:
		seen_crash=game.van.crash_serial
		var contacts:Array=[]
		for i in game.van.get_slide_collision_count():
			var contact:KinematicCollision3D=game.van.get_slide_collision(i)
			for j in contact.get_collision_count():
				var collider:Object=contact.get_collider(j)
				contacts.append({"at":contact.get_position(j),"normal":contact.get_normal(j),"body":str(collider),"surface":collider.get_meta("surface_kind","") if collider else ""})
		last_crash={"truck":game.van.position,"contacts":contacts}
	clock+=delta
	if clock<.1:return
	clock=0
	var cargo:Node=game.cargo;var run_state:Node=cargo.arcade_run
	var command:String=JavaScriptBridge.eval("window.fedupQACommand || ''")
	if not command.is_empty():
		JavaScriptBridge.eval("window.fedupQACommand=''")
		match command:
			"quiet":
				quiet_population()
			"curb":
				game.touch_controls.release_inputs();cargo.complete=true;cargo.next_stage();quiet_population()
				game.van.position=Vector3(-47,.15,25);game.van.rotation.y=PI/2;game.van.parking_brake=false
				game.van.speed=0;game.van.planar_velocity=Vector3.ZERO;game.van.velocity=Vector3.ZERO
				seen_crash=game.van.crash_serial;last_crash={}
			"impact":
				game.gameplay_feedback.impact(game.van.position-game.van.global_basis.z*3.3+Vector3.UP,Vector3.BACK,.65)
			"lap":
				# One reset before the lap; all subsequent travel uses real controls.
				game.touch_controls.release_inputs();cargo.complete=true;cargo.next_stage()
				quiet_population();game.van.parking_brake=false
			"drive":game.van.parking_brake=false
			"fixed_pause":game.fixed_camera.set_process(false)
			"fixed_resume":game.fixed_camera.set_process(true)
			"park":park(game.highway.spawn_position)
			"wrong_gate":park(game.highway.route_points[2])
			"gate":park(run_state.target())
			"bay":park(cargo.checkpoint_position)
			"spill":
				park(Vector3(110,0,110))
				while cargo.damage<100:cargo.damage_hit(1)
			"line":
				cargo.actor.camera_angle=game.fixed_camera.BEARING;cargo.actor.facing=cargo.actor.camera_angle
				cargo.actor.position=game.van.position+Vector3(18,.08,-18);cargo.actor.velocity=Vector3.ZERO
				cargo.pickup_previous=cargo.actor.position
				for item in cargo.packages:
					# The QA-only spill is on clear open terrain.
					item.body.freeze=true;item.body.position=cargo.actor.position-Basis(Vector3.UP,game.fixed_camera.BEARING).z*(4+item.id*2.6)+Vector3.UP*.3
			"enter":
				cargo.actor.position=game.van.position+game.van.global_basis.x*3.5;cargo.toggle_foot()
	var dimensions:Vector2=game.touch_controls.size
	var regions:Dictionary={}
	var report:Control=game.hud.get_node("DeliveryReport")
	var button_rect:Rect2=report.replay.get_global_rect()
	regions["replay"]=[button_rect.position.x/dimensions.x,button_rect.position.y/dimensions.y,button_rect.size.x/dimensions.x,button_rect.size.y/dimensions.y]
	for key in game.touch_controls.regions:
		var rect:Rect2=game.touch_controls.regions[key];var scale:float=dimensions.x/720
		regions[key]=[rect.position.x*scale/dimensions.x,rect.position.y*scale/dimensions.y,rect.size.x*scale/dimensions.x,rect.size.y*scale/dimensions.y]
	var data:Dictionary={"arcade":game.arcade,"route":run_state.route_index,"route_total":game.highway.route_points.size(),"complete":cargo.complete,"speed":game.van.speed,"on_foot":cargo.on_foot,"collected":cargo.recovered,"restored":cargo.load_restored,"spawned":cargo.spawned,"energy":game.dashboard.energy_fraction(),"regions":regions,"cars":game.traffic.cars.size(),"citizens":game.city_life.citizens.size(),"camera_yaw":game.van.camera_orbit,"camera_pitch":game.van.camera_pitch,"elapsed":run_state.elapsed,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
	data["feedback"]=game.gameplay_feedback.stats()
	data["report"]={"progress":report.animation_progress,"age":report.report_age,"manifest":report.displayed_manifest,"energy":report.displayed_energy,"recovered":report.displayed_recovered}
	data["pickup_pulse"]=game.dashboard.pickup_pulse
	var camera:Camera3D=get_viewport().get_camera_3d()
	data["view_rotation"]=[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z]
	data["view_preset"]=game.fixed_camera.preset;data["cutaways"]=game.highway.cutaway_count
	data["cutaway_ms"]=game.highway.cutaway_audit_us/1000.0
	data["process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000
	data["truck"]=[game.van.position.x,game.van.position.y,game.van.position.z]
	data["heading"]=game.van.rotation.y;data["velocity"]=[game.van.planar_velocity.x,game.van.planar_velocity.z]
	data["lap_corners"]=[[46,51.5],[46,-51.5],[-46,-51.5],[-46,51.5]]
	data["bay"]=[cargo.checkpoint_position.x,cargo.checkpoint_position.z]
	data["crashes"]=game.van.crash_serial;data["resets"]=game.van.reset_count;data["offroad"]=game.van.offroad_recoveries
	data["last_crash"]=last_crash
	data["stick"]=[game.touch_controls.stick.x,game.touch_controls.stick.y]
	data["fingers"]=game.touch_controls.fingers
	data["move_input"]=[Input.get_axis("steer_left","steer_right"),Input.get_axis("accelerate","brake_reverse")]
	if cargo.on_foot:
		data["actor"]=[cargo.actor.position.x,cargo.actor.position.y,cargo.actor.position.z]
		data["walk_angle"]=cargo.actor.camera_angle
		data["walk_input"]=[Input.get_axis("steer_left","steer_right"),Input.get_axis("accelerate","brake_reverse")]
		data["loose"]=[]
		for item in cargo.packages:
			if item.state=="loose":data.loose.append({"id":item.id,"at":[item.body.global_position.x,item.body.global_position.y,item.body.global_position.z],"rescues":int(item.get("rescues",0))})
	JavaScriptBridge.eval("window.fedupQA="+JSON.stringify(data))
