extends Node
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("FLEET TEST FAIL: "+message)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func run(game:Node) -> void:
	var step:=int(get_tree().get_meta("fleet_step",0))
	if step==0:
		var ledger:=preload("res://scripts/delivery_ledger.gd").new()
		var progress:=preload("res://scripts/fleet_progress.gd").new();progress.persistent=false
		check(progress.unlocked("truck") and not progress.unlocked("semi") and not progress.choose("tank") and not progress.choose("invalid"),"Locked and unknown vehicles cannot be selected")
		for delivery in 5:
			ledger.begin(12,"test-%d" % delivery);ledger.lose_load()
			check(not ledger.recover(100) and ledger.receipt(true,true).is_empty(),"Missing cargo cannot create a receipt")
			for id in 12:check(ledger.recover(id) and not ledger.recover(id),"Package identity is credited exactly once")
			ledger.lose_load();check(ledger.ready(),"Repeated spill signal cannot lose recovered cargo again")
			check(ledger.receipt(false,true).is_empty() and ledger.receipt(true,false).is_empty(),"Route and stopped truck required")
			var receipt:=ledger.receipt(true,true)
			check(progress.award(receipt) and not progress.award(receipt) and ledger.receipt(true,true).is_empty(),"Repeated receipt cannot grant duplicate delivery")
			check(progress.unlocked("semi") and progress.unlocked("tank")== (delivery>=2) and progress.unlocked("sleigh")== (delivery>=4),"Milestone unlock thresholds")
		progress.persistent=true;progress.path="user://fleet_test_only.cfg";progress.choose("sleigh")
		var restored:=preload("res://scripts/fleet_progress.gd").new();restored.path=progress.path;restored.load_progress()
		check(restored.selected=="sleigh" and restored.deliveries==5 and not restored.award({"job_id":"test-4","packages":12}),"Saved selection and receipt deduplication survive reload")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	game.start_drive()
	await frames(3)
	check(game.vehicle_id==["truck","semi","tank","sleigh"][step],"Selected vehicle survives scene reload")
	check(game.vehicle_visuals.wheels.size()>=4,"Playable model has live rolling wheels")
	var driving:=preload("res://scripts/arcade_driving_tests.gd").new();add_child(driving)
	var before:int=game.fleet.deliveries
	failures.append_array(await driving.run(game,false))
	check(game.fleet.deliveries==before+1,"Actual route completion awards exactly one career delivery")
	if step==3:
		game.van.new_truck();game.van.parking_brake=false
		await frames(15)
		var ground:float=game.van.position.y
		game.flight.toggle();await frames(150)
		check(game.flight.enabled and game.van.position.y>ground+2.5 and game.van.position.y<ground+5,"Sleigh lifts into bounded collision-aware flight")
		game.flight.toggle();var target:float=game.flight.target_y;game.flight.toggle()
		check(not game.flight.enabled and game.flight.target_y==target,"Repeated flight input cannot stack altitude during landing")
		await frames(210)
		check(not game.flight.enabled and not game.flight.landing and game.van.is_on_floor(),"Sleigh physically lands and restores ground driving")
		game.flight.toggle();await frames(90)
	game.cargo.damage_hit(1);game.cargo.damage_hit(1)
	check(not game.cargo.spilled and not game.van.wrecked,"Surviving energy secures cargo for every vehicle")
	game.cargo.damage_hit(1);await frames(20)
	check(game.cargo.spilled and game.cargo.spawned==12 and game.cargo.on_foot and not game.flight.enabled,"Energy depletion spills one manifest, exits and cancels flight")
	for item in game.cargo.packages:
		game.cargo.recover_package(item);game.cargo.recover_package(item)
	await frames(120)
	check(game.cargo.recovered==12 and game.cargo.ledger.ready() and game.cargo.load_restored and not game.van.wrecked,"All fleet vehicles retain immediate one-time pickup and repair")
	if not failures.is_empty():await game.quit_demo(1);return
	if step<3:
		get_tree().set_meta("fleet_step",step+1)
		get_tree().set_meta("fleet_fixture",{"deliveries":5,"selected":["truck","semi","tank","sleigh"][step+1]})
		get_tree().reload_current_scene();return
	print("FLEET TEST PASS: receipts, unlock/save round trip, all four real-input route laps, sleigh lift and landing")
	await game.quit_demo()
