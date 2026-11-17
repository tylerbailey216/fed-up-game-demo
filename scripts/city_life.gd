extends Node3D
## A populated entrance block plus citizens on mapped Public Square paths.
var game:Node
var citizens:Array[CharacterBody3D]=[]
var side:=Vector3.RIGHT
var forward:=Vector3.FORWARD
var center:=Vector3.ZERO
var seen_impact:=0
var definitions:Dictionary

func strip(a:Vector3,b:Vector3,width:float,color:Color) -> void:
	var node:MeshInstance3D=game.highway.block(self,(a+b)*.5+Vector3.UP*.035,Vector3(width,.035,a.distance_to(b)),color)
	var delta:=b-a;node.rotation.y=atan2(-delta.x,-delta.z)

func add_citizen(at:Vector3,route:Array[Vector3],index:int) -> CharacterBody3D:
	var person:=preload("res://scripts/citizen.gd").new();person.district=self
	person.definition=definitions["commuter" if index%2==0 else "office-alien"]
	person.route=route;person.waypoint=index%route.size();person.pace=.95+float(index%4)*.16
	add_child(person);person.position=at+Vector3.UP*.08;person.last_position=person.position
	citizens.append(person);return person

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/citizens.json")).citizens
	var start:=Vector3(250,0,-75)
	forward=(game.highway.entry-start).normalized();side=Vector3(-forward.z,0,forward.x)
	center=start.lerp(game.highway.entry,.43)
	# A small connected local block is visible before the player reaches the
	# far larger mapped district. Ground collision remains the existing slab.
	for offset in [-1,1]:strip(start+forward*48+side*float(offset)*9,game.highway.entry+side*float(offset)*9,2.5,Color("c6bda5"))
	var loop:Array[Vector3]=[center-forward*38-side*1.8,center+forward*38-side*1.8,center+forward*38+side*24,center-forward*38+side*24]
	for i in range(1,4):strip(loop[i],loop[(i+1)%4],8,Color("51515c"))
	for i in 8:
		strip(center+forward*12+side*(-8+i*2.2)-forward*1.2,center+forward*12+side*(-8+i*2.2)+forward*1.2,1.0,Color("f3ebd8"))
	for i in 6:
		game.traffic.make_barrel(center+side*(16+float(i%2)*2)+forward*(float(i/2)*4-7)+Vector3.UP*.65)
	for i in 6:
		var car:=preload("res://scripts/traffic_car.gd").new();car.district=game.traffic
		car.route=loop.duplicate();car.waypoint=(i%4+1)%4
		car.position=loop[i%4].lerp(loop[(i%4+1)%4],.18+float(i/4)*.45)+Vector3.UP*.06
		var direction:Vector3=car.route[car.waypoint]-car.position
		car.rotation.y=atan2(-direction.x,-direction.z);car.cruise_speed=4.2+float(i%3)*.5
		game.traffic.add_child(car);game.traffic.build_car(car,[Color("7548a2"),Color("e69c42"),Color("66a3a6")][i%3],i)
		game.traffic.cars.append(car)
	game.traffic.make_signal(center+forward*8-side*7,"NS",atan2(-forward.x,-forward.z))
	for i in 12:
		var anchor:Vector3=start.lerp(game.highway.entry,.24 if i<4 else (.48 if i<8 else .8))
		# The left frontage is a solid mapped building. Use the open sidewalk
		# and plaza side, crossing the local street instead of routing through it.
		var route:Array[Vector3]=[anchor+side*9-forward*22,anchor+side*9+forward*12,anchor+side*31+forward*12,anchor+side*31-forward*22]
		if i%4==0:
			strip(route[0],route[3],2,Color("c6bda5"));strip(route[2],route[3],2,Color("c6bda5"))
		var at:Vector3=route[i%4].lerp(route[(i+1)%4],.2)
		add_citizen(at,route,i)
	# A known mapped footway near Public Square, shared with walking tests.
	var plaza:=Vector3(984.24,0,-82.875);var direction:=Vector3(-29.25,0,18.32).normalized()
	for i in 4:
		var route:Array[Vector3]=[plaza-direction*12,plaza+direction*12]
		add_citizen(route[i%2].lerp(route[(i+1)%2],.15+float(i/2)*.25),route,i)
	game.highway.consolidate_boxes()

func _physics_process(_delta:float) -> void:
	if not game.driving:return
	if seen_impact!=game.van.collision_serial:
		seen_impact=game.van.collision_serial
		for person in citizens:
			if person.position.distance_squared_to(game.van.position)<18*18 and person.state in ["walk","wait"]:
				person.state="surprise";person.timer=0
