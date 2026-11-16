extends Node
## Local fictional-route navigation; no online map/GPS service or mission scoring.
const RADIUS := 260.0
const DESTINATIONS := ["North Loop", "City View", "South Loop", "Start / Service"]
var target_index := 0
var enabled := true
var arrived := false
var remaining_m := 0.0
var eta_seconds := 0.0
var progress := 0.0
var target_progress := PI/2
var location_world: Node3D

func select_target(index: int) -> void:
	target_index = posmod(index,DESTINATIONS.size())
	target_progress = fposmod((target_index+1)*PI/2,TAU)
	enabled = true
	arrived = false

func update_position(pos: Vector3, signed_speed: float) -> void:
	if location_world:
		remaining_m = 0
		eta_seconds = -1
		return
	progress = fposmod(-atan2(pos.z,pos.x),TAU)
	if not enabled:
		return
	var gap := fposmod(target_progress-progress,TAU)
	remaining_m = gap*RADIUS
	if minf(gap,TAU-gap)*RADIUS < 16:
		arrived = true
	if arrived:
		remaining_m = 0
	eta_seconds = remaining_m/maxf(signed_speed,0.1) if signed_speed > 0.5 else -1

func next_target() -> void:
	if location_world:
		var vehicle: Node = location_world.get_parent().get("van")
		vehicle.notify_driver(location_world.nearest_road(vehicle.position).name.strip_edges())
		return
	select_target(target_index+1)

func guidance() -> String:
	if location_world:
		return "Cleveland / Public Square" if location_world.get("is_downtown") else "Independence / free exploration"
	if not enabled:
		return "Navigation off"
	if arrived:
		return "Arrived: "+DESTINATIONS[target_index]
	return "Follow Metro Loop - gentle left"
