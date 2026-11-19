extends "res://scripts/city_life.gd"
## The same supplied human/alien cast and nonlethal reactions, in a smaller space.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/citizens.json")).citizens
	center=Vector3.ZERO;forward=Vector3.FORWARD;side=Vector3.RIGHT
	var routes:Array[Array]=[[Vector3(-36,0,40),Vector3(-36,0,12)],[Vector3(36,0,-40),Vector3(36,0,-12)],[Vector3(-30,0,-42),Vector3(-10,0,-42)],[Vector3(12,0,42),Vector3(32,0,42)],[Vector3(-10,0,10),Vector3(10,0,10)],[Vector3(10,0,-10),Vector3(-10,0,-10)],[Vector3(57,0,25),Vector3(57,0,-25)],[Vector3(-57,0,-25),Vector3(-57,0,25)]]
	for n in routes.size():
		var route:Array[Vector3]=[];route.assign(routes[n])
		for i in 2:add_citizen(route[0].lerp(route[1],.2+i*.5),route,n*2+i)
	select_nearby()
