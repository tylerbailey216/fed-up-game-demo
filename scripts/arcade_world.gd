extends "res://scripts/highway.gd"
## A fictional, Cleveland-inspired delivery block. No large-map geometry loads here.
var is_arcade:=true
var is_downtown:=true
var entered:=true
var spawn_position:=Vector3(-28,.15,51.5)
var spawn_heading:=-PI/2
var delivery_position:=Vector3(2,0,51.5)
var delivery_heading:=-PI/2
var depot:=Vector3(2,0,63)
var entry:=Vector3(46,0,51.5)
var route_points:Array[Vector3]=[Vector3(46,0,35),Vector3(46,0,-40),Vector3(-40,0,-51.5),Vector3(-46,0,40)]
var street_paths:Array[Array]=[]
var streets:Node3D

func _ready() -> void:
	var floor_mesh:=block(self,Vector3(0,-.35,0),Vector3(600,.6,600),Color("7f9465"),true)
	floor_mesh.get_child(0).set_meta("terrain_kind","grass")
	streets=preload("res://scripts/street_surfaces.gd").new();streets.world=self;add_child(streets)
	road(Vector3(-46,0,51.5),Vector3(46,0,51.5),"Parcel Avenue")
	road(Vector3(46,0,51.5),Vector3(46,0,-51.5),"Mayhem Street")
	road(Vector3(46,0,-51.5),Vector3(-46,0,-51.5),"Tower Row")
	road(Vector3(-46,0,-51.5),Vector3(-46,0,51.5),"Depot Street")
	road(Vector3(-46,0,0),Vector3(46,0,0),"Cross Town")
	road(Vector3(0,0,-51.5),Vector3(0,0,51.5),"Public Lane")
	for path in street_paths:
		var a:Vector3=path[0];var b:Vector3=path[1]
		var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*8.5
		for sign_value in [-1,1]:streets.walkway(a+side*sign_value,b+side*sign_value,3.0,str(street_paths.find(path)))
	streets.island(Vector3(20,0,16),Vector3(20,0,30),7)
	streets.finish()
	for x in [-24,24]:
		for z in [-27,27]:
			if x==24 and z==27:continue # Pocket park in the southeast block.
			building(Vector3(x,0,z),Vector3(19,16+absf(x+z)*.18,22),Color("bba88c") if x<0 else Color("ab7863"))
	for i in 10:
		var x:float=-92+i*20
		building(Vector3(x,0,-91),Vector3(15,22+(i%4)*9,17),Color("819797") if i%2 else Color("a99b8d"))
	for x in [-79,79]:
		for z in [-30,15,50]:building(Vector3(x,0,z),Vector3(19,15+absf(z)*.2,26),Color("c3b698"))
	for p in [Vector3(20,0,19),Vector3(20,0,29),Vector3(-60,0,-35),Vector3(60,0,30),Vector3(-26,0,65),Vector3(26,0,-66),Vector3(63,0,-30)]:tree(p)
	for p in [Vector3(-65.8,0,35),Vector3(48.2,0,-35),Vector3(2.2,0,-42),Vector3(2.2,0,42)]:
		var lamp:=Node3D.new();lamp.position=p;add_child(lamp);build_lamp(lamp)
	for z in [-12,12]:
		for i in 7:block(self,Vector3(-5+i*1.6,.035,z),Vector3(.8,.025,3),Color("f3ebd8"))
	sign_at(Vector3(7,5,63),"FedUp / COLLECTION BAY",0)
	sign_at(Vector3(30,4,-62),"TOWER ROW / CLEVELAND",0)
	consolidate_boxes()

func road(a:Vector3,b:Vector3,title:String) -> void:
	var index:=street_paths.size();street_paths.append([a,b,title]);streets.index_road(a,b,14,str(index))
	var d:Vector3=b-a
	var deck:=block(self,(a+b)*.5-Vector3.UP*.3,Vector3(14,.6,d.length()+14),Color("51515c"),true)
	deck.rotation.y=atan2(-d.x,-d.z);deck.material_override=art.material(Color("51515c"),false,true)
	deck.get_child(0).set_meta("terrain_kind","asphalt")
	for i in int(d.length()/9):
		var p:=a+d.normalized()*(i*9+4)
		if absf(p.x)<9 and absf(p.z)<9:continue
		var dash:=block(self,p+Vector3.UP*.022,Vector3(.12,.025,3),Color("eed083"));dash.rotation.y=deck.rotation.y

func building(at:Vector3,dimensions:Vector3,tone:Color) -> void:
	block(self,at+Vector3.UP*dimensions.y*.5,dimensions,tone,true)
	block(self,at+Vector3.UP*(dimensions.y+.2),Vector3(dimensions.x+1,.6,dimensions.z+1),Color("3b3a48"))
	block(self,at+Vector3.UP*3,Vector3(dimensions.x+.4,.35,dimensions.z+.4),Color("eee0c3"))
	for floor_index in range(1,int(dimensions.y/3)):
		for s in [-1,1]:
			block(self,at+Vector3(0,4+floor_index*2.6,s*(dimensions.z*.5+.04)),Vector3(dimensions.x-2,1.35,.1),Color("365463"))
			block(self,at+Vector3(s*(dimensions.x*.5+.04),4+floor_index*2.6,0),Vector3(.1,1.35,dimensions.z-2),Color("365463"))
	for s in [-1,1]:
		block(self,at+Vector3(0,1.55,s*(dimensions.z*.5+.06)),Vector3(dimensions.x-3,2.5,.12),Color("29434c"))
		var awning:=block(self,at+Vector3(0,3.2,s*(dimensions.z*.5+.75)),Vector3(dimensions.x-1,.22,1.7),Color("6a39a0"));awning.rotation.x=s*.12

func tree(at:Vector3) -> void:
	tree_collision(at,.28,3.2);block(self,at+Vector3.UP*1.6,Vector3(.45,3.2,.45),Color("65503a"))
	var leaf:=SphereMesh.new();leaf.radial_segments=7;leaf.rings=3
	var poses:Array[Transform3D]=[]
	for i in 5:poses.append(Transform3D(Basis().scaled(Vector3(2.7,3,2.5)),at+Vector3(cos(i*TAU/5)*1.35,4.6+float(i%2)*.8,sin(i*TAU/5)*1.35)))
	batch_mesh(leaf,poses,Color("638443"),true)

func sign_at(at:Vector3,value:String,yaw:float) -> void:
	block(self,at,Vector3(13,1.8,.22),Color("253b3d"),true)
	for s in [-1,1]:block(self,at+Vector3(s*5,-at.y*.5,0),Vector3(.13,at.y,.13),Color("353441"),true)
	var label:=Label3D.new();label.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf");label.text=value;label.font_size=60;label.pixel_size=.014;label.position=at+Vector3(0,0,.15);label.rotation.y=yaw;label.modulate=Color("ffe0a0");add_child(label)

func nearest_road(at:Vector3) -> Dictionary:
	var result:Dictionary={"name":"Delivery Mayhem","point":spawn_position,"distance":INF}
	for path in street_paths:
		var p:=Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),Vector2(path[0].x,path[0].z),Vector2(path[1].x,path[1].z))
		var d:=p.distance_to(Vector2(at.x,at.z))
		if d<result.distance:result={"name":path[2],"point":Vector3(p.x,0,p.y),"distance":d}
	return result

func has_road_near(at:Vector3,distance:=7.0) -> bool:
	return nearest_road(at).distance<distance

func outside_bounds(at:Vector3) -> bool:
	return not at.is_finite() or absf(at.x)>240 or absf(at.z)>240 or at.y< -4 or at.y>100

func map_point(at:Vector3,rect:Rect2) -> Vector2:
	return rect.position+Vector2(16,32)+(Vector2(at.x,at.z)+Vector2(68,72))/Vector2(136,144)*(rect.size-Vector2(32,52))

func draw_map(canvas:Control,rect:Rect2,at:Vector3) -> void:
	for path in street_paths:canvas.draw_line(map_point(path[0],rect),map_point(path[1],rect),Color("899c9e"),3,true)
	canvas.draw_circle(map_point(at,rect),4,Color("70e5e0"))
