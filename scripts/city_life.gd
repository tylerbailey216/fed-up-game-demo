extends Node3D
## The entrance and mapped walking corridors share the supplied character cast.
var game:Node
var citizens:Array[CharacterBody3D]=[]
var side:=Vector3.RIGHT
var forward:=Vector3.FORWARD
var center:=Vector3.ZERO
var seen_impact:=0
var definitions:Dictionary
var selection_clock:=0.0
var active_count:=0

func add_citizen(at:Vector3,route:Array[Vector3],index:int) -> CharacterBody3D:
	var person:=preload("res://scripts/citizen.gd").new();person.district=self
	var keys:Array=definitions.keys();person.design_id=keys[index%keys.size()];person.definition=definitions[person.design_id]
	person.route=route;person.waypoint=(index%route.size()+1)%route.size();person.pace=.9+float(index%5)*.13
	if game.get("zen")==true:person.pace*=.9
	add_child(person);person.position=at+Vector3.UP*.2;person.last_position=person.position
	citizens.append(person);return person

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/citizens.json")).citizens
	var start:=Vector3(250,0,-75)
	forward=(game.highway.entry-start).normalized();side=Vector3(-forward.z,0,forward.x)
	center=start.lerp(game.highway.entry,.43)
	var streets:Node=game.highway.streets
	var loop:Array[Vector3]=streets.local_loop
	for i in range(1,4):
		var a:Vector3=loop[i];var b:Vector3=loop[(i+1)%4]
		var road:Node3D=game.highway.block(game.highway,(a+b)*.5+Vector3.UP*.013,Vector3(8,.02,a.distance_to(b)),Color("51515c"))
		road.rotation.y=atan2(-(b-a).x,-(b-a).z)
		var edge:Vector3=Vector3(-(b-a).z,0,(b-a).x).normalized()*5.3
		for sign_value in [-1,1]:streets.walkway(a+edge*sign_value,b+edge*sign_value,2.5,"city_loop")
	streets.island(center+side*16-forward*11,center+side*16+forward*11,4.2)
	streets.finish()
	for i in 8:
		var p:Vector3=center+forward*10+side*(-7+i*2)
		var stripe:Node3D=game.highway.block(game.highway,p+Vector3.UP*.029,Vector3(1,.02,2.5),Color("f3ebd8"))
		stripe.rotation.y=atan2(-forward.x,-forward.z)
	var kinds:Array=["taxi","compact","pickup","delivery-van","suv","scooter"]
	for i in 6:game.traffic.spawn_reference_car(kinds[i],loop,i%4,.16+float(i/4)*.55,4.3+float(i%3)*.4)
	game.traffic.make_signal(center+forward*5-side*7,"NS",atan2(-forward.x,-forward.z))
	for i in 16:
		var anchor:Vector3=start.lerp(game.highway.entry,.20+float(i/4)*.22)
		var route:Array[Vector3]=[anchor+side*9-forward*9,anchor+side*9+forward*9]
		if i%4>=2:route=[center+side*29-forward*18,center+side*29+forward*18]
		var at:Vector3=route[i%2].lerp(route[1-i%2],.12+float(i%4)*.20)
		add_citizen(at,route,i)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/city_population.json"))
	for path in data.walking_paths:
		var route:Array[Vector3]=[]
		for p in path:route.append(Vector3(p[0],0,p[1]))
		var outward:Array[Vector3]=route.duplicate();outward.reverse();route.append_array(outward.slice(1,-1))
		for i in 2:
			var index:int=i*route.size()/2;var person:=add_citizen(route[index],route,citizens.size());person.waypoint=(index+1)%route.size()
	game.highway.consolidate_boxes();select_nearby()

func select_nearby() -> void:
	var at:Vector3=game.cargo.player_position() if game.get("cargo") and game.cargo else game.van.position
	var ordered:Array=citizens.duplicate();ordered.sort_custom(func(a:Node3D,b:Node3D):return a.position.distance_squared_to(at)<b.position.distance_squared_to(at))
	active_count=0
	for person in ordered:
		var active:bool=person.state in ["tumble","recover"] or (active_count<24 and person.position.distance_squared_to(at)<190*190)
		person.simulation_active=active;person.visible=active
		if active:active_count+=1
		person.collision_layer=16 if active else 0

func _physics_process(delta:float) -> void:
	if not game.driving:return
	selection_clock+=delta
	if selection_clock>.25:selection_clock=0;select_nearby()
	if seen_impact!=game.van.collision_serial:
		seen_impact=game.van.collision_serial
		for person in citizens:
			if person.simulation_active and person.position.distance_squared_to(game.van.position)<18*18 and person.state in ["walk","wait"]:
				person.state="surprise";person.timer=0

