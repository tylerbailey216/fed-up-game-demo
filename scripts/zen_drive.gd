extends RefCounted
## Unpressured exploration keeps the real truck/traffic physics and worker.
## Collision effects remain; cargo objectives and permanent damage do not.
var cargo:Node
var settled_time:=0.0
var repairs:=0

func update(delta:float) -> void:
	var van:Node=cargo.game.van
	cargo.damage=0;van.delivery_complete=false
	if van.overturned:
		settled_time=settled_time+delta if van.roll_settled else 0.0
		# Let physical tumbling finish; recovery never erases a moving jump.
		if settled_time>=1.5:service(true)
		return
	settled_time=0
	if van.wrecked:service(true)
	elif van.fuel_gallons<=0 and not cargo.on_foot:service(true)

func collision(_severity:float) -> void:
	cargo.collision_count+=1 # Diagnostic only; Zen never starts a package quest.
	cargo.damage=0

func service(automatic:=false) -> bool:
	var van:Node=cargo.game.van
	if van.stunts.active:
		van.notify_driver("LET THE TRUCK LAND / SERVICE IS READY")
		return false
	if van.overturned and not van.roll_settled:
		van.notify_driver("LET THE TRUCK SETTLE / SERVICE IS READY")
		return false
	# Recover the existing truck near its current road, preserving scenery and
	# position during ordinary service. Its collision shapes are never removed.
	var parking:bool=van.parking_brake
	var resume_engine:bool=not cargo.on_foot and (not automatic or not van.overturned or van.impact_engine_was_on)
	van.wrecked=false
	if van.overturned and not van.recover_upright():return false
	van.flip_count=0;van.cargo_open=false;van.delivery_complete=false
	van.fuel_gallons=van.TANK_GALLONS;van.engine_on=resume_engine;van.parking_brake=parking
	van.cruise=false;cargo.damage=0;settled_time=0;repairs+=1
	van.notify_driver("ZEN SERVICE / READY WHEN YOU ARE")
	return true

func objective() -> String:
	if cargo.on_foot:return cargo.entry_instruction(cargo.game.dashboard.touch_input())
	return "ZEN DRIVE / "+cargo.game.zen_connections.guidance() if is_instance_valid(cargo.game.get("zen_connections")) else "ZEN DRIVE / TAKE YOUR TIME"
