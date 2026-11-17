extends "res://scripts/traffic_district.gd"

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for z in [-80.5,-77,-73.5,-70]:make_barrel(Vector3(270,.65,z))
	var points:Array=highway.map_data.traffic_route
	if points.size()<5:return
	var route:Array[Vector3]=[]
	for i in points.size():
		var a:Vector3=Vector3(points[i][0],0,points[i][1])+highway.OFFSET
		var b:Vector3=Vector3(points[(i+1)%points.size()][0],0,points[(i+1)%points.size()][1])+highway.OFFSET
		var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*1.45
		route.append(a+side)
	for i in 8:
		var car:=Car.new();car.district=self;car.route=route.duplicate();car.waypoint=(i*route.size()/8+1)%route.size()
		var index:int=(car.waypoint-1+route.size())%route.size()
		car.position=route[index]+Vector3.UP*.06
		var direction:Vector3=route[car.waypoint]-car.position
		car.rotation.y=atan2(-direction.x,-direction.z);car.cruise_speed=6.5+float(i%3)
		add_child(car);build_car(car,[Color("ad4e58"),Color("3b8ca2"),Color("d9b957"),Color("d6cbb8")][i%4],i);cars.append(car)
	highway.consolidate_boxes()
	for location in [Vector3(920,0,-170),Vector3(1160,0,95)]:
		make_signal(location,"NS",0)
	update_signals()

func in_city(pos:Vector3) -> bool:
	return pos.x>300

func _physics_process(delta:float) -> void:
	var active:bool=game.driving
	for car in cars:
		if car.freeze==active:car.freeze=not active
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
		if ns_light=="RED" and gap.dot(forward)>6 and gap.dot(forward)<23 and absf(gap.dot(car.global_basis.x))<6:return maxf(0,gap.dot(forward)-7)*.5
	for point in [Vector3(920,0,-170),Vector3(1160,0,95)]:
		var gap:Vector3=point-car.position;var forward:Vector3=-car.global_basis.z
		if ns_light=="RED" and gap.dot(forward)>7 and gap.dot(forward)<22 and absf(gap.dot(car.global_basis.x))<5:return maxf(0,gap.dot(forward)-8)*.5
	return 30.0
