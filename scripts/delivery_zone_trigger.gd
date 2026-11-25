extends RefCounted
## Vehicle centre must reach the visible zone's halfway plane, from either end.
## Latch until exit; a swept crossing catches a fast physics step without an aura.
var reached:=false
var previous:=Vector3.ZERO
var previous_valid:=false

func reset() -> void:
	reached=false;previous_valid=false

func update(at:Vector3,half_width:float,half_length:float,height:float,eligible:=true) -> bool:
	if not eligible:reset();return false
	var inside:bool=absf(at.x)<half_width and absf(at.z)<half_length and absf(at.y)<height
	var midpoint:bool=absf(at.z)<.0001
	if previous_valid and previous.distance_squared_to(at)<16 and previous.z*at.z<=0 and absf(previous.z-at.z)>.0001:
		var crossing:=previous.lerp(at,previous.z/(previous.z-at.z))
		midpoint=absf(crossing.x)<half_width and absf(crossing.y)<height
	previous=at;previous_valid=true
	if not inside:reached=false;return false
	if reached or not midpoint:return false
	reached=true
	return true
