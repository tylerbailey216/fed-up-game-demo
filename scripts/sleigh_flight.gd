extends RefCounted
## Low-altitude, collision-aware hover flight. Shared horizontal mode controls.
var game:Node
var enabled:=false
var landing:=false
var target_y:=0.0

func effects_active() -> bool:
	return game!=null and game.vehicle_id=="sleigh" and game.driving and not game.van.wrecked and not game.van.overturned and not game.van.driver_on_foot and (enabled or landing)

func cancel() -> void:
	enabled=false;landing=false
	if game and game.van:game.van.floor_snap_length=.24
	if game and game.van and game.van.contact_shadow:game.van.contact_shadow.position=Vector3(0,.025,0)

func toggle() -> void:
	if game.vehicle_id!="sleigh" or not game.driving or game.paused:return
	var van:Node=game.van
	if van.wrecked or van.overturned or van.driver_on_foot or van.delivery_complete or van.stunts.active:return
	if landing or (not enabled and not van.is_on_floor()):
		van.notify_driver("WAIT FOR THE SLEIGH TO LAND BEFORE TAKEOFF");return
	if enabled:
		enabled=false;landing=true
		van.notify_driver("SLEIGH / LANDING")
	else:
		enabled=true;landing=false;target_y=van.position.y+4.0
		van.notify_driver("SLEIGH / FLIGHT / V OR LAND TO TOUCH DOWN")

func vertical(delta:float) -> bool:
	var van:Node=game.van
	if game.vehicle_id!="sleigh" or van.wrecked or van.overturned or van.driver_on_foot:
		enabled=false;landing=false;return false
	if not enabled and not landing:return false
	if enabled and (not van.engine_on or van.fuel_gallons<=0):
		enabled=false;landing=true;van.notify_driver("FLIGHT POWER OFF / LANDING")
	van.floor_snap_length=0 if enabled else .24
	if enabled:
		van.velocity.y=move_toward(van.velocity.y,clampf((target_y-van.position.y)*2,-2,3),delta*5)
	else:
		van.velocity.y=move_toward(van.velocity.y,-2,delta*5)
		if van.is_on_floor():
			landing=false;van.velocity.y=0
			if van.contact_shadow:van.contact_shadow.position=Vector3(0,.025,0)
	return true
