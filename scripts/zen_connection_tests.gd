extends Node
## Both boundaries are crossed using real simulator input, never gate teleports.
var failures:Array[String]=[]

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("ZEN CONNECTION TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func run(game:Node) -> void:
	var stage:=int(get_tree().get_meta("zen_connection_stage",0))
	var start_motorway:bool="--outerbelt" in OS.get_cmdline_user_args()
	var expected_motorway:bool=start_motorway if stage%2==0 else not start_motorway
	check(game.zen and not game.arcade and game.outerbelt==expected_motorway,"One Zen mode retains its identity through both connected zones")
	if stage==0:game.start_drive()
	await frames(5)
	check(game.driving and not game.menu.visible and game.cargo.checkpoint==null,"Arrival resumes free driving without a new mission or menu")
	check(game.traffic.cars.size()>0,"The current Zen zone contains physical traffic")
	var gate:Node=game.zen_connections
	if stage>0:
		var expected:Dictionary=preload("res://scripts/zen_connections.gd").arrival_for("motorway" if game.outerbelt else "city")
		check(game.van.position.distance_to(expected.position)<5,"Arrival is on its correct receiving carriageway")
		check(absf(game.van.fuel_gallons-14.2)<.06 and game.van.distance>=12345,"Fuel and driven distance carry between zones")
		check(game.van.headlights and not game.van.cockpit and absf(game.van.camera_orbit-.4)<.01,"Vehicle functions and selected camera carry between zones")
		check(game.van.is_on_floor() or absf(game.van.position.y-expected.position.y)<.3,"Arrival remains supported by the destination road")
	if stage==2:
		print("ZEN CONNECTION TEST PASS: both road gates driven with real gas input; state, lane, support and mode preserved")
		await game.quit_demo(0 if failures.is_empty() else 1);return
	var road:Dictionary=gate.geometry.exit
	var center:Vector3=gate.exit_position;var forward:Vector3=gate.exit_forward
	check(gate.crossed_gate(center-forward*2,center+forward*2),"Correct forward road crossing is accepted")
	check(not gate.crossed_gate(center+forward*2,center-forward*2),"Wrong-way travel cannot switch zones")
	check(not gate.crossed_gate(center-forward*2+Vector3.UP*5,center+forward*2+Vector3.UP*5),"A different road level cannot switch zones")
	check(not gate.crossed_gate(center-forward*2+road.right*30,center+forward*2+road.right*30),"Adjacent terrain cannot switch zones")
	if game.outerbelt:
		check(not gate.crossed_gate(center-forward*2-road.right*3.6,center+forward*2-road.right*3.6),"Left through lane stays on Open Road for the north scenic loop")
	# Set up once on the approach lane. Every meter to the gate uses normal gas,
	# collision, suspension and barrier code. Never place the truck at the gate.
	game.van.position=gate.approach_position;game.van.rotation=Vector3(0,float(road.heading),0)
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	game.van.fuel_gallons=14.2;game.van.distance=12345;game.van.engine_on=true;game.van.parking_brake=false
	game.van.headlights=true;game.van.set_view(false);game.van.camera_orbit=.4
	gate.cooldown=0;gate.previous_valid=false
	await frames(30)
	check(game.van.is_on_floor(),"Gate approach has a real supporting road surface")
	if not failures.is_empty():await game.quit_demo(1);return
	get_tree().set_meta("zen_connection_stage",stage+1)
	Input.action_press("accelerate")
	for frame in 750:
		await frames(1)
		if game.switching_location:
			Input.action_release("accelerate");return
	Input.action_release("accelerate")
	push_error("ZEN CONNECTION TEST FAIL: normal gas could not cross the road gateway at "+str(game.van.position))
	await game.quit_demo(1)
