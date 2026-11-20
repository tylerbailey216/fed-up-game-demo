extends "res://scripts/traffic_district.gd"
## Physical ambient traffic on the four actual, one-way mapped mainlines.
## Open extract endpoints use quiet off-camera recycling, never a return U-turn.
const CARS_PER_ROUTE:=3
const RECYCLE_CLEARANCE:=300.0 # Vehicle artwork already culls at 230 m.
const END_BUFFER:=24.0
var routes:Array[Dictionary]=[]
var recycled:=0
var endpoint_waits:=0
var recycle_clock:=0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	disabled_world=false;entered=true;ns_light="GREEN";ew_light="GREEN"
	build_routes()
	var kinds:Array=city_art.definitions.keys()
	kinds.erase("scooter") # The supplied road vehicles remain unchanged.
	for route_index in routes.size():
		var route:Dictionary=routes[route_index]
		for slot in CARS_PER_ROUTE:
			var sample:=sample_distance(route.points,route.length*(.18+slot*.27))
			var kind:String=kinds[(route_index*CARS_PER_ROUTE+slot)%kinds.size()]
			var car:=spawn_reference_car(kind,route.points,sample.edge,sample.fraction,9.0)
			# The city Zen cap is intentionally lower than open-road flow.
			car.cruise_speed=8.0+float(slot)*.5
			car.freeze=true;car.set_meta("ambient_route",route_index)
			car.set_meta("endpoint_waiting",false)

func build_routes() -> void:
	# Stitch by shared OSM node IDs, preserving each one-way ordering. Only the
	# continuous I-480 / I-77 carriageways belong here; ramps remain player roads.
	var roads:Array=[];var incoming:Dictionary={};var from_node:Dictionary={}
	for road in highway.map_data.roads:
		if road.kind!="motorway" or not road.oneway or road.ref not in ["I 480","I 77"]:continue
		var index:=roads.size();roads.append(road)
		from_node[int(road.nodes[0])]=index
		incoming[int(road.nodes[-1])]=true
	var visited:Dictionary={}
	for index in roads.size():
		var road:Dictionary=roads[index]
		if incoming.has(int(road.nodes[0])):continue
		var nodes:Array[int]=[];var offsets:Array[float]=[];var current:int=index
		while not visited.has(current):
			visited[current]=true
			var section:Dictionary=roads[current]
			var lanes:=maxi(1,int(section.lanes))
			# Match independence.gd's markings. The rightmost lane centre follows
			# changes in carriageway width, with a wide shoulder outside it.
			var offset:float=float(section.width)*float(lanes-1)/(2.0*lanes)
			for raw in section.nodes:
				var id:=int(raw)
				if not nodes.is_empty() and nodes[-1]==id:
					offsets[-1]=minf(offsets[-1],offset);continue
				nodes.append(id);offsets.append(offset)
			var last:=int(section.nodes[-1])
			if not from_node.has(last):break
			var next:int=from_node[last]
			if roads[next].ref!=road.ref:break
			current=next
		var raw_points:Array[Vector3]=[]
		for n in nodes.size():
			var at:Vector3=highway.road_points[nodes[n]]
			var direction:Vector3=highway.road_points[nodes[mini(n+1,nodes.size()-1)]]-highway.road_points[nodes[maxi(n-1,0)]]
			var right:=Vector3(-direction.z,0,direction.x).normalized()
			raw_points.append(at+right*offsets[n])
		var points:=simplify_lane(raw_points)
		var length:=0.0
		for n in range(1,points.size()):length+=points[n-1].distance_to(points[n])
		if length>500:routes.append({"name":road.ref,"points":points,"length":length,"source_nodes":nodes})

func simplify_lane(raw:Array[Vector3]) -> Array[Vector3]:
	# Avoid the city car's 6 m waypoint threshold consuming dense map samples.
	# Every retained chord stays within 40 cm of the original lane and grade.
	var points:Array[Vector3]=[]
	if raw.is_empty():return points
	points.append(raw[0]);var start:=0
	while start<raw.size()-1:
		var end:=start+1
		while end<raw.size()-1:
			var proposed:=end+1
			if raw[start].distance_to(raw[proposed])>32:break
			var safe:=true
			for i in range(start+1,proposed):
				if raw[i].distance_to(Geometry3D.get_closest_point_to_segment(raw[i],raw[start],raw[proposed]))>.4:safe=false;break
			if not safe:break
			end=proposed
		points.append(raw[end]);start=end
	return points

func sample_distance(points:Array[Vector3],distance:float) -> Dictionary:
	var remaining:=distance
	for edge in range(points.size()-1):
		var length:=points[edge].distance_to(points[edge+1])
		if remaining<=length:return {"edge":edge,"fraction":clampf(remaining/maxf(.01,length),0,1)}
		remaining-=length
	return {"edge":points.size()-2,"fraction":.9}

func terminal_approach(car:RigidBody3D) -> bool:
	return car.waypoint>=maxi(1,car.route.size()-8)

func signal_speed_limit(car:RigidBody3D) -> float:
	# Freeways have no artificial traffic lights; retained APIs still give the
	# existing car controller its physical following/braking and horn behavior.
	var limit:float=car.cruise_speed
	if terminal_approach(car):
		var remaining:float=car.position.distance_to(car.route[-1])
		limit=minf(limit,sqrt(maxf(0,2.0*3.0*(remaining-END_BUFFER))))
	return calm_speed_limit(car,limit)

func in_city(_pos:Vector3) -> bool:
	return false

func focus_position() -> Vector3:
	return game.cargo.player_position() if game.get("cargo") and game.cargo else game.van.position

func try_recycle(car:RigidBody3D,focus:Vector3) -> bool:
	if car.position.distance_squared_to(focus)<RECYCLE_CLEARANCE*RECYCLE_CLEARANCE:return false
	var route:Dictionary=routes[int(car.get_meta("ambient_route"))]
	var points:Array[Vector3]=route.points
	for distance in [35.0,65.0,95.0,125.0]:
		var sample:=sample_distance(points,distance)
		var at:Vector3=points[sample.edge].lerp(points[sample.edge+1],sample.fraction)+Vector3.UP*.08
		if at.distance_squared_to(focus)<RECYCLE_CLEARANCE*RECYCLE_CLEARANCE:continue
		var direction:Vector3=points[sample.edge+1]-points[sample.edge]
		var heading:=atan2(-direction.x,-direction.z)
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.7,at-Vector3.UP*1.0,1);ray.exclude=[car.get_rid()]
		var floor_hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if floor_hit.is_empty() or not floor_hit.collider is StaticBody3D or floor_hit.normal.y<.95:continue
		at.y=floor_hit.position.y+.12
		var hull:=BoxShape3D.new();hull.size=Vector3(car.body_width+.4,float(car.definition.get("height",1.8)),car.body_length+.6)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=hull
		query.transform=Transform3D(Basis(Vector3.UP,heading),at+Vector3.UP*(hull.size.y*.5+.12))
		query.collision_mask=1|2|8|16;query.exclude=[car.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		car.freeze=true;car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO
		car.global_transform=Transform3D(Basis(Vector3.UP,heading),at)
		car.waypoint=sample.edge+1;car.blocked_time=0;car.horn_cooldown=1
		car.set_meta("endpoint_waiting",false);car.visible=true;car.sleeping=false;car.freeze=false
		car.set_physics_process(true)
		car.horn_player.stop();car.impact_player.stop();recycled+=1
		return true
	return false

func _physics_process(delta:float) -> void:
	var active:bool=game.driving and game.van.active
	running=active
	if not active:
		for car in cars:
			car.freeze=true;car.horn_player.stop();car.impact_player.stop()
		return
	var focus:=focus_position()
	recycle_clock+=delta;var audit:bool=recycle_clock>=.5
	if audit:recycle_clock=0
	for car in cars:
		var terminal:=terminal_approach(car)
		var below_world:bool=car.position.y< -8
		if audit and (terminal or below_world) and try_recycle(car,focus):continue
		# Guard before traffic_car's modulo waypoint advance. A nearby endpoint
		# car waits on its current lane instead of popping away or turning around.
		if terminal and car.waypoint==car.route.size()-1 and car.position.distance_to(car.route[-1])<9:
			if not car.get_meta("endpoint_waiting",false):endpoint_waits+=1
			car.set_meta("endpoint_waiting",true)
		if below_world:car.set_meta("endpoint_waiting",true);car.visible=false
		# An endpoint car remains a pushable physical body. Retire only its route
		# controller if a player shove reaches the final modulo waypoint.
		car.set_physics_process(not bool(car.get_meta("endpoint_waiting",false)))
		car.freeze=below_world
