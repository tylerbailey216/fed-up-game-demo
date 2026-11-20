extends "res://scripts/traffic_district.gd"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for z in [-80.5,-77,-73.5,-70]:make_barrel(Vector3(270,.65,z))
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_population.json"))
	var kinds:Array=city_art.definitions.keys()
	for n in data.traffic_routes.size():
		var route:Array[Vector3]=[]
		for p in data.traffic_routes[n]:route.append(Vector3(p[0],0,p[1]))
		for i in 8:spawn_reference_car(kinds[(n*8+i)%kinds.size()],route,i*route.size()/8,.22,6.0+float(i%3)*.6)
	highway.consolidate_boxes()
	for location in [Vector3(920,0,-170),Vector3(1160,0,95)]:
		make_signal(location,"NS",0)
	update_signals()

func in_city(pos:Vector3) -> bool:
	return pos.x>300

func _physics_process(delta:float) -> void:
	var active:bool=game.driving
	var focus:Vector3=game.cargo.player_position() if game.get("cargo") and game.cargo else game.van.position
	for car in cars:
		var nearby:bool=car.position.distance_squared_to(focus)<250*250
		var simulate:bool=active and nearby
		if car.freeze==simulate:car.freeze=not simulate
		car.visible=nearby;car.collision_layer=1 if nearby else 0
	for barrel in barrels:
		if barrel.freeze==active:barrel.freeze=not active
	if not active:return
	entered=highway.entered
	phase_time+=delta
	ns_light="GREEN" if fmod(phase_time,24)<12 else "RED";ew_light="RED" if ns_light=="GREEN" else "GREEN"
	for lamp in lamps:
		var state:String=ns_light if lamp.axis=="NS" else ew_light
		var color:Color={"RED":Color("ff4e42"),"AMBER":Color("ffc844"),"GREEN":Color("68e48b")}[lamp.state]
		lamp.material.albedo_color=color if state==lamp.state else color.darkened(.86)

func signal_speed_limit(car:RigidBody3D) -> float:
	if game.get("city_life") and is_instance_valid(game.city_life):
		var gap:Vector3=game.city_life.center+game.city_life.forward*12-car.position
		var forward:Vector3=-car.global_basis.z
		if ns_light=="RED" and gap.dot(forward)>6 and gap.dot(forward)<23 and absf(gap.dot(car.global_basis.x))<6:return calm_speed_limit(car,maxf(0,gap.dot(forward)-7)*.5)
	for point in [Vector3(920,0,-170),Vector3(1160,0,95)]:
		var gap:Vector3=point-car.position;var forward:Vector3=-car.global_basis.z
		if ns_light=="RED" and gap.dot(forward)>7 and gap.dot(forward)<22 and absf(gap.dot(car.global_basis.x))<5:return calm_speed_limit(car,maxf(0,gap.dot(forward)-8)*.5)
	return calm_speed_limit(car,30.0)
