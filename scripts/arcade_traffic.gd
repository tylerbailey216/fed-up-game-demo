extends "res://scripts/downtown_traffic.gd"
## Existing force-driven cars, with a bounded population on the small block.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var clockwise:Array[Vector3]=[Vector3(-48,0,53.5),Vector3(48,0,53.5),Vector3(48,0,-53.5),Vector3(-48,0,-53.5)]
	var counter:Array[Vector3]=[Vector3(-44,0,-49.5),Vector3(44,0,-49.5),Vector3(44,0,49.5),Vector3(-44,0,49.5)]
	var kinds:Array=city_art.definitions.keys()
	for i in 8:spawn_reference_car(kinds[i],clockwise if i%2==0 else counter,(i/2)%4,.45,5.6+float(i%3)*.4)
	var crossing:Array[Vector3]=[Vector3(-44,0,2),Vector3(44,0,2),Vector3(44,0,-49.5),Vector3(-44,0,-49.5)]
	for i in 2:spawn_reference_car(kinds[8+i],crossing,i*2,.35,6)
	for x in [12,17]:make_barrel(Vector3(x,.65,-5))
	make_signal(Vector3(-8,0,8),"NS",0)
	make_signal(Vector3(8,0,-8),"EW",PI/2)
	highway.consolidate_boxes();update_signals()

func in_city(_pos:Vector3) -> bool:
	return true

func signal_speed_limit(car:RigidBody3D) -> float:
	var axis:String="NS" if absf(car.global_basis.z.z)>.7 else "EW"
	var red:bool=(ns_light if axis=="NS" else ew_light)=="RED"
	var gap:Vector3=Vector3.ZERO-car.position
	var ahead:float=gap.dot(-car.global_basis.z)
	if red and ahead>6 and ahead<23 and absf(gap.dot(car.global_basis.x))<5:return maxf(0,ahead-8)*.5
	return 30
