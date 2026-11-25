extends Node
var failures:Array[String]=[]

func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error("ZEN ROADS TEST FAIL: "+message)

func run(game:Node) -> Array[String]:
	game.start_drive()
	for i in 25:await get_tree().physics_frame
	var world:Node=game.highway;var van:Node=game.van
	check(game.zen and game.outerbelt and world.return_roads.size()==4,"Four scenic returns exist only in expanded Zen")
	game.zen_connections.set_physics_process(false)
	game.traffic.set_physics_process(false)
	for car in game.traffic.cars:car.freeze=true;car.set_physics_process(false);car.collision_layer=0;car.collision_mask=0
	var total:=0.0
	var audit:=FileAccess.open("res://docs/zen-roads-smoke.json",FileAccess.WRITE)
	audit.store_string(JSON.stringify(world.map_data));audit.close()
	for road in world.return_roads:
		var points:Array[Vector3]=[]
		for id in road.nodes:points.append(world.road_points[id])
		var start:Vector3=points[0];var end:Vector3=points[-1]
		var before:=Vector3.ZERO;var after:=Vector3.ZERO
		for original in world.map_data.roads:
			if original.get("zen_return",false):continue
			if original.kind!="motorway" or original.ref!=road.ref:continue
			if original.nodes[-1]==road.nodes[0]:before=world.road_points[original.nodes[-2]]
			if original.nodes[0]==road.nodes[-1]:after=world.road_points[original.nodes[1]]
		check(before!=Vector3.ZERO and after!=Vector3.ZERO,"Return shares actual incoming and outgoing road nodes")
		check((start-before).normalized().dot((points[1]-start).normalized())>.995,"Incoming join follows existing carriageway tangent")
		check((after-end).normalized().dot((end-points[-2]).normalized())>.995,"Outgoing join follows existing carriageway tangent")
		for index in range(1,points.size()):
			total+=points[index-1].distance_to(points[index])
			var at:Vector3=(points[index-1]+points[index])*.5
			check(not world.outside_bounds(at),"Expanded boundary contains every new road segment")
			var right:=Vector3(-(points[index]-points[index-1]).z,0,(points[index]-points[index-1]).x).normalized()
			for offset in [-5.0,0.0,5.0]:
				var p:Vector3=at+right*offset
				var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.8,p-Vector3.UP*.8,1)
				query.exclude=[van.get_rid()]
				var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and absf(hit.position.y-p.y)<.08 and hit.normal.y>.98,"Both lanes have continuous physical deck support")
		# One initial setup, then every metre of the return and its two joins uses
		# normal simulator throttle, steering, suspension and collision resolution.
		if not "--zen-road-drive-test" in OS.get_cmdline_user_args():continue
		points.push_front(before);points.append(after)
		van.new_truck();van.position=before+Vector3.UP*.16
		van.rotation=Vector3(0,atan2(-(start-before).x,-(start-before).z),0)
		van.parking_brake=false;van.engine_on=true
		for i in 20:await get_tree().physics_frame
		var resets:int=van.reset_count;var target:=1;var max_error:=0.0
		van.cruise=false
		var stalled:=0
		for frame in 22000:
			await get_tree().physics_frame
			Input.action_press("accelerate",clampf((8.0-van.speed)*1.8+.22,0,1))
			while target<points.size()-1 and van.position.distance_to(points[target])<16:target+=1
			var delta:Vector3=points[target]-van.position;delta.y=0
			var angle:=wrapf(atan2(-delta.x,-delta.z)-van.rotation.y,-PI,PI)
			var steering:=clampf(angle*5.0,-1,1)
			Input.action_release("steer_left");Input.action_release("steer_right")
			Input.action_press("steer_left" if steering>0 else "steer_right",absf(steering))
			var lateral:=INF
			for segment in range(maxi(1,target-8),mini(points.size(),target+3)):
				lateral=minf(lateral,van.position.distance_to(Geometry3D.get_closest_point_to_segment(van.position,points[segment-1],points[segment])))
			max_error=maxf(max_error,lateral)
			stalled=stalled+1 if absf(van.speed)<.2 else 0
			if target==points.size()-1 and delta.length()<6:break
			if van.reset_count!=resets or van.overturned or lateral>10 or stalled>240:break
		check(target==points.size()-1 and van.position.distance_to(after)<7,"Entire return driven through both joins without teleporting: "+str(road.nodes[0])+" target "+str(target)+" error "+str(max_error)+" position "+str(van.position)+" speed "+str(van.speed)+" stunt "+str(van.stunts.active))
		check(van.reset_count==resets and not van.overturned,"Scenic drive needs no recovery or reset")
		print("ZEN RETURN ",road.nodes[0]," / target ",target," / maximum cross-track metres ",snappedf(max_error,.01))
		Input.action_release("steer_left");Input.action_release("steer_right");Input.action_release("accelerate");van.cruise=false
	check(total>6000,"Expansion adds at least six kilometres of actual road")
	print("ZEN ROADS ","PASS" if failures.is_empty() else "FAIL"," / added metres ",snappedf(total,.1))
	return failures

