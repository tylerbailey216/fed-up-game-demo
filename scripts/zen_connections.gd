extends Node3D
## Signed drive-through zone connections on the existing mapped carriageways.
## The game reloads one zone; this node never loads a second world or moves roads.
const CITY_OFFSET:=Vector3(1000,0,-75)
const FONT=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var game:Node
var destination:=""
var destination_label:=""
var sign_title:=""
var exit_position:=Vector3.ZERO
var exit_forward:=Vector3.FORWARD
var exit_half_width:=5.0
var approach_position:=Vector3.ZERO
var arrival:Dictionary={}
var geometry:Dictionary={}
var previous_position:=Vector3.ZERO
var previous_valid:=false
var cooldown:=.35
var traveling:=false
var approach_announced:=false

static func corridor(zone:String,receiving:=false,initial:=false) -> Dictionary:
	# Ontario has separate one-way approaches at the southeast edge. The I-77
	# pair likewise stays on its own carriageway, between intact edge barriers.
	var city:=zone=="city"
	var target:Vector3
	var wanted:Vector3
	if city:
		target=Vector3(1540,0,358) if receiving else Vector3(1628,0,432)
		wanted=Vector3(-.858,0,-.515) if receiving else Vector3(.858,0,.515)
		if initial:target=Vector3(1125,0,0);wanted=Vector3(-.55,0,-.84)
	else:
		target=Vector3(293,8,-1010) if receiving else Vector3(314,8,-1040)
		wanted=Vector3.BACK if receiving else Vector3.FORWARD
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/cleveland.json" if city else "res://assets/maps/independence.json"))
	var result:Dictionary={}
	var best:=INF
	for road in data.roads:
		if city:
			if road.foot or road.name!="Ontario Street" or float(road.width)<14:continue
		elif road.ref!="I 77" or road.kind!="motorway":continue
		var points:Array[Vector3]=[]
		if city:
			for p in road.points:points.append(Vector3(p[0],0,p[1])+CITY_OFFSET)
		else:
			for index in road.nodes:
				var p:Array=data.points[int(index)];points.append(Vector3(p[0],p[1],p[2]))
		for i in range(1,points.size()):
			var a:Vector3=points[i-1];var b:Vector3=points[i]
			var forward:Vector3=(b-a)*Vector3(1,0,1)
			if forward.length_squared()<.01:continue
			forward=forward.normalized()
			if forward.dot(wanted)<.8:continue
			var point:=Geometry3D.get_closest_point_to_segment(target,a,b)
			var score:=point.distance_squared_to(target)
			if score>=best:continue
			best=score
			# Runtime motorway decks add 2 m to the nominal mapped width.
			var width:float=float(road.width)+(0.0 if city else 2.0)
			result={"point":point,"forward":forward,"right":Vector3(-forward.z,0,forward.x),"width":width,"heading":atan2(-forward.x,-forward.z),"road_id":str(road.id),"road_name":str(road.name),"kind":"city_street" if city else str(road.kind),"a":a,"b":b}
	return result

static func arrival_for(zone:String) -> Dictionary:
	var road:=corridor(zone,true)
	if road.is_empty():return {}
	# Right lane, clear of the median/outer rails. Start beyond the other
	# direction's trigger and head away, so a load cannot immediately bounce back.
	return {"position":road.point+road.right*1.8+Vector3.UP*.16,"heading":road.heading,"forward":road.forward,"speed_cap":14.0 if zone=="city" else 25.0,"road_id":road.road_id,"road_name":road.road_name}

static func initial_city_spawn() -> Dictionary:
	var road:=corridor("city",true,true)
	if road.is_empty():return {}
	return {"position":road.point+road.right*1.8+Vector3.UP*.16,"heading":road.heading,"forward":road.forward,"road_id":road.road_id,"road_name":road.road_name}

static func geometry_for(zone:String) -> Dictionary:
	var road:=corridor(zone)
	if road.is_empty():return {}
	return {"zone":zone,"destination":"motorway" if zone=="city" else "city","exit":road,"approach":road.point-road.forward*28+road.right*1.8+Vector3.UP*.16,"arrival":arrival_for(zone),"destination_arrival":arrival_for("motorway" if zone=="city" else "city")}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	if not is_instance_valid(game) or not bool(game.get("zen")):return
	var zone:="motorway" if bool(game.get("outerbelt")) else "city"
	geometry=geometry_for(zone)
	if geometry.is_empty():return
	var road:Dictionary=geometry.exit
	destination=geometry.destination
	destination_label="INDEPENDENCE / I-77" if zone=="city" else "CLEVELAND / PUBLIC SQUARE"
	sign_title="OPEN ROAD" if zone=="city" else "CITY STREETS"
	exit_position=road.point;exit_forward=road.forward
	exit_half_width=float(road.width)*.5-.65
	approach_position=geometry.approach
	arrival=geometry.destination_arrival
	var start:Dictionary=initial_city_spawn() if zone=="city" else {"position":game.highway.spawn_position,"heading":game.highway.spawn_heading}
	if zone=="city":
		# This applies on receiving loads too: a later manual reset must never
		# send Zen driving back to the old training ring or announce its mission.
		game.highway.entered=true
		if not start.is_empty():game.highway.spawn_position=start.position;game.highway.spawn_heading=float(start.heading)
	if not get_tree().has_meta("zen_transfer"):
		if not start.is_empty():
			game.van.position=start.position;game.van.rotation=Vector3(0,float(start.heading),0)
			game.van.safe_position=start.position;game.van.safe_heading=float(start.heading)
	build_gateway(road)

func guidance() -> String:
	if destination.is_empty():return "ZEN DRIVE / EXPLORE AT YOUR OWN PACE"
	var distance:float=game.van.global_position.distance_to(exit_position)
	var route:="ONTARIO ST" if destination=="motorway" else "I-77 NORTH"
	return "%s / FOLLOW %s / %.2f MI" % [sign_title,route,distance/1609.344]

func _physics_process(delta:float) -> void:
	if destination.is_empty() or traveling or not is_instance_valid(game):return
	cooldown=maxf(0,cooldown-delta)
	var van:CharacterBody3D=game.van
	var allowed:bool=bool(game.get("zen")) and game.driving and van.active and not game.cargo.on_foot and not van.overturned and not van.stunts.active
	if not allowed:previous_valid=false;return
	var current:Vector3=van.global_position
	var signed_distance:float=(current-exit_position).dot(exit_forward)
	var side:Vector3=Vector3(-exit_forward.z,0,exit_forward.x)
	var lateral:float=absf((current-exit_position).dot(side))
	if not approach_announced and signed_distance< -12 and signed_distance> -95 and lateral<exit_half_width+4:
		approach_announced=true
		van.notify_driver(sign_title+" / CONTINUE AHEAD TO "+destination_label)
	if cooldown<=0 and previous_valid and crossed_gate(previous_position,current):
		traveling=true
		# Scene reload must run outside the physics query/contact callback.
		game.call_deferred("travel_zen",destination,arrival)
	previous_position=current;previous_valid=true

func crossed_gate(from:Vector3,to:Vector3) -> bool:
	# Plane crossing catches a fast truck without a narrow Area3D overlap. It
	# rejects wrong-way travel, another road level, and explicit fixture teleports.
	var movement:=to-from
	if movement.length_squared()>400 or movement.dot(exit_forward)<=.01:return false
	var before:float=(from-exit_position).dot(exit_forward)
	var after:float=(to-exit_position).dot(exit_forward)
	if before>=0 or after<0:return false
	var hit:=from.lerp(to,-before/(after-before))
	var side:=Vector3(-exit_forward.z,0,exit_forward.x)
	return absf((hit-exit_position).dot(side))<exit_half_width and absf(hit.y-exit_position.y)<2.0

func box(parent:Node3D,at:Vector3,size:Vector3,color:String) -> MeshInstance3D:
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
	visual.mesh=mesh;visual.position=at;visual.material_override=game.highway.art.material(Color(color))
	visual.visibility_range_end=350;parent.add_child(visual)
	return visual

func sign_text(parent:Node3D,text:String,at:Vector3,size:int,color:String) -> void:
	var label:=Label3D.new();label.text=text;label.font=FONT;label.font_size=size;label.pixel_size=.021
	label.position=at;label.modulate=Color(color);label.outline_modulate=Color("10121e");label.outline_size=5
	parent.add_child(label)

func build_gateway(road:Dictionary) -> void:
	var frame:=Node3D.new();frame.position=exit_position;frame.rotation.y=float(road.heading);add_child(frame)
	var width:float=float(road.width)
	# All structure clears the complete existing deck. No barrier is removed,
	# and neither a trigger nor a guide adds a collider across a traffic lane.
	for side in [-1,1]:
		box(frame,Vector3(side*(width*.5+1.25),3.6,0),Vector3(.24,7.2,.24),"383444")
		box(frame,Vector3(side*(width*.5+1.25),.32,0),Vector3(.65,.64,.65),"c5b99e")
	box(frame,Vector3(0,6.5,0),Vector3(width+3.1,2.65,.24),"10121e")
	box(frame,Vector3(0,6.5,.14),Vector3(width+2.75,2.3,.06),"ffd044")
	box(frame,Vector3(0,6.5,.18),Vector3(width+2.5,2.05,.06),"352743")
	box(frame,Vector3(0,5.72,.225),Vector3(width+2.45,.36,.025),"6a39a0")
	sign_text(frame,sign_title,Vector3(0,7.08,.25),52,"ffd044")
	sign_text(frame,destination_label,Vector3(0,6.34,.25),34,"f3ebd8")
	sign_text(frame,"ZEN DRIVE / CONTINUE AHEAD",Vector3(0,5.74,.255),23,"f3ebd8")
	# Two low arrow rows follow the lane directions, painted above the actual
	# road deck. Local +Z is behind this forward-facing gateway.
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for distance in [12.0,24.0,36.0]:
		for lane in [-1.8,1.8]:
			var points:Array[Vector3]=[Vector3(lane-1.1,.045,distance+.8),Vector3(lane,.045,distance-.6),Vector3(lane+1.1,.045,distance+.8),Vector3(lane-1.1,.045,distance+1.35),Vector3(lane,.045,distance-.05),Vector3(lane+1.1,.045,distance+1.35)]
			for index in [0,1,3,1,4,3,1,2,4,2,5,4]:tool.set_normal(Vector3.UP);tool.add_vertex(points[index])
	var guide:=MeshInstance3D.new();guide.mesh=tool.commit();guide.material_override=game.highway.art.material(Color("ffd044"));guide.visibility_range_end=160;frame.add_child(guide)
