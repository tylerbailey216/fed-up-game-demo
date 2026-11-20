extends Node
## Opt-in qa=zen fixture. Menu clicks and crossings still use real controls.
var game:Node
var clock:=0.0
var approached:=false

func _ready() -> void:
	JavaScriptBridge.eval("window.fedupQA=null;window.fedupQACommand=''")

func quiet_population() -> void:
	game.traffic.set_physics_process(false)
	if game.city_life:game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0;car.collision_mask=0
	if game.city_life:
		for citizen in game.city_life.citizens:
			citizen.set_physics_process(false);citizen.collision_layer=0;citizen.collision_mask=0

func rect(control:Control,dimensions:Vector2) -> Array:
	var value:Rect2=control.get_global_rect()
	return [value.position.x/dimensions.x,value.position.y/dimensions.y,value.size.x/dimensions.x,value.size.y/dimensions.y]

func _physics_process(delta:float) -> void:
	clock+=delta
	if clock<.1:return
	clock=0
	var command:String=JavaScriptBridge.eval("window.fedupQACommand || ''")
	if not command.is_empty():
		JavaScriptBridge.eval("window.fedupQACommand=''")
		match command:
			"quiet":quiet_population()
			"prepare":
				game.touch_controls.release_inputs();game.van.new_truck();game.van.parking_brake=false
			"approach":
				if not approached and is_instance_valid(game.zen_connections) and not game.zen_connections.geometry.is_empty():
					approached=true;quiet_population();game.touch_controls.release_inputs()
					var connections:Node=game.zen_connections;var vehicle:Node=game.van
					# One setup on the mapped approach. No fixture position changes
					# occur while the player drives through the signed connection.
					vehicle.position=connections.approach_position;vehicle.rotation=Vector3(0,float(connections.geometry.exit.heading),0)
					vehicle.speed=0;vehicle.velocity=Vector3.ZERO;vehicle.planar_velocity=Vector3.ZERO
					vehicle.engine_on=true;vehicle.parking_brake=false;vehicle.cruise=false
					connections.previous_valid=false;connections.cooldown=.35
	var dimensions:Vector2=game.touch_controls.size
	var regions:Dictionary={}
	for key in game.touch_controls.regions:
		var area:Rect2=game.touch_controls.regions[key];var scale:float=dimensions.x/720
		regions[key]=[area.position.x*scale/dimensions.x,area.position.y*scale/dimensions.y,area.size.x*scale/dimensions.x,area.size.y*scale/dimensions.y]
	var cargo:Node=game.cargo;var van:Node=game.van
	var data:Dictionary={"mode":"zen" if game.zen else "arcade","zone":"motorway" if game.outerbelt else "city","instance":get_instance_id(),"driving":game.driving,"menu":game.menu.visible,"regions":regions,"menu_regions":{"start":rect(game.start_button,dimensions),"mode":rect(game.map_button,dimensions)},"menu_start":game.start_button.text,"cars":game.traffic.cars.size(),"citizens":game.city_life.citizens.size() if game.city_life else 0,"mission_empty":cargo.checkpoint==null and cargo.arcade_run==null and cargo.packages.is_empty() and not cargo.spilled and not cargo.complete,"spawned":cargo.spawned,"complete":cargo.complete,"on_foot":cargo.on_foot,"speed":van.speed,"truck":[van.position.x,van.position.y,van.position.z],"heading":van.rotation.y,"velocity":[van.planar_velocity.x,van.planar_velocity.z],"engine":van.engine_on,"fuel":van.fuel_gallons,"distance":van.distance,"cockpit":van.cockpit,"camera_yaw":van.camera_orbit,"camera_pitch":van.camera_pitch,"stick":[game.touch_controls.stick.x,game.touch_controls.stick.y],"fingers":game.touch_controls.fingers,"inputs":[Input.get_action_strength("accelerate"),Input.get_action_strength("brake_reverse"),Input.get_action_strength("steer_left"),Input.get_action_strength("steer_right")],"approached":approached,"status":game.dashboard.status_message(),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000}
	if cargo.on_foot:data["actor"]=[cargo.actor.position.x,cargo.actor.position.y,cargo.actor.position.z]
	data["can_enter"]=cargo.can_enter_truck();data["camera_high"]=van.camera_high
	if is_instance_valid(game.zen_connections):
		data["exit"]=[game.zen_connections.exit_position.x,game.zen_connections.exit_position.y,game.zen_connections.exit_position.z]
		data["signed_exit"]=(van.position-game.zen_connections.exit_position).dot(game.zen_connections.exit_forward)
	JavaScriptBridge.eval("window.fedupQA="+JSON.stringify(data))
