extends Node3D
## Raised, chamfered sidewalks with matching visible and physical geometry.
const HEIGHT:=.16
const BEVEL:=.28
var world:Node
var roads:Array[Dictionary]=[]
var road_grid:Dictionary={}
var surfaces:Dictionary={}
var faces:Dictionary={}
var island_centers:Array[Vector3]=[]
var audit_edges:Array[Dictionary]=[]
var meshes:Array[MeshInstance3D]=[]
var local_loop:Array[Vector3]=[]

func index_road(a:Vector3,b:Vector3,width:float,id:String) -> void:
	if a.distance_to(b)<.05:return
	var item:Dictionary={"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"width":width,"id":id}
	var index:=roads.size();roads.append(item)
	var low:Vector2=item.a.min(item.b)-Vector2.ONE*(width*.5+4)
	var high:Vector2=item.a.max(item.b)+Vector2.ONE*(width*.5+4)
	for x in range(floori(low.x/64),floori(high.x/64)+1):
		for z in range(floori(low.y/64),floori(high.y/64)+1):
			var cell:=Vector2i(x,z)
			if not road_grid.has(cell):road_grid[cell]=[]
			road_grid[cell].append(index)

func on_road(at:Vector3,exclude:="",margin:=0.0) -> bool:
	var p:=Vector2(at.x,at.z);var cell:=Vector2i(floori(p.x/64),floori(p.y/64))
	for index in road_grid.get(cell,[]):
		var road:Dictionary=roads[index]
		if road.id==exclude:continue
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.b))<road.width*.5+margin:return true
	return false

func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	if (b-a).cross(c-a).y>0:var swap:=b;b=c;c=swap
	var center:Vector3=(a+b+c)/3
	var cell:=Vector2i(floori(center.x/96),floori(center.z/96));var origin:=Vector3(cell.x*96,0,cell.y*96)
	if not surfaces.has(cell):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[cell]=tool;faces[cell]=PackedVector3Array()
	for p in [a,b,c]:surfaces[cell].set_color(color);surfaces[cell].add_vertex(p-origin)
	var collision:PackedVector3Array=faces[cell];collision.append_array(PackedVector3Array([a-origin,b-origin,c-origin]));faces[cell]=collision

func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color) -> void:
	triangle(a,b,c,color);triangle(a,c,d,color)

func raised(a:Vector3,b:Vector3,width:float,color:=Color("c9bfaa")) -> void:
	if a.distance_to(b)<.08:return
	var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*width*.5
	var inset:=side.normalized()*minf(BEVEL,width*.22)
	var up:=Vector3.UP*HEIGHT
	var direction:Vector3=(b-a).normalized()*minf(BEVEL,a.distance_to(b)*.2)
	var p:=a+direction;var q:=b-direction
	quad(p-side+inset+up,q-side+inset+up,q+side-inset+up,p+side-inset+up,color)
	quad(a-side,b-side,q-side+inset+up,p-side+inset+up,Color("e2d1ad"))
	quad(p+side-inset+up,q+side-inset+up,b+side,a+side,Color("e2d1ad"))
	# End ramps avoid an invisible vertical lip at a crossing or segment end.
	quad(a-side,a+side,a+side-inset+direction+up,a-side+inset+direction+up,Color("d9c8a7"))
	quad(b-side+inset-direction+up,b+side-inset-direction+up,b+side,b-side,Color("d9c8a7"))
	if audit_edges.size()<40:audit_edges.append({"center":(a+b)*.5,"side":side.normalized(),"width":width})

func walkway(a:Vector3,b:Vector3,width:float,exclude:="",color:=Color("c9bfaa")) -> void:
	var count:=maxi(1,ceili(a.distance_to(b)/4.0))
	var running:=false;var start:=a;var end:=a
	for i in count:
		var p:Vector3=a.lerp(b,float(i)/count);var q:Vector3=a.lerp(b,float(i+1)/count)
		if on_road((p+q)*.5,exclude,.25):
			if running:raised(start,end,width,color);running=false
			continue
		if not running:start=p;running=true
		end=q
	if running:raised(start,end,width,color)

func build() -> void:
	for road in world.map_data.roads:
		if road.foot:continue
		for i in range(1,road.points.size()):
			var a:Array=road.points[i-1];var b:Array=road.points[i]
			index_road(Vector3(a[0],0,a[1])+world.OFFSET,Vector3(b[0],0,b[1])+world.OFFSET,road.width,str(road.id))
	index_road(Vector3(250,0,-75),world.entry,14,"training_exit")
	var start:=Vector3(250,0,-75);var forward:Vector3=(world.entry-start).normalized()
	var local_side:=Vector3(-forward.z,0,forward.x);var center:Vector3=start.lerp(world.entry,.43)
	local_loop=[center-forward*30-local_side*1.8,center+forward*30-local_side*1.8,center+forward*30+local_side*24,center-forward*30+local_side*24]
	for i in range(1,4):index_road(local_loop[i],local_loop[(i+1)%4],8,"city_loop")
	for road in world.map_data.roads:
		for i in range(1,road.points.size()):
			var av:Array=road.points[i-1];var bv:Array=road.points[i]
			var a:Vector3=Vector3(av[0],0,av[1])+world.OFFSET;var b:Vector3=Vector3(bv[0],0,bv[1])+world.OFFSET
			if road.foot:walkway(a,b,maxf(1.3,road.width))
			else:
				var side:Vector3=Vector3(-(b-a).z,0,(b-a).x).normalized()*(road.width*.5+1.1)
				for sign_value in [-1,1]:walkway(a+side*sign_value,b+side*sign_value,2.2,str(road.id))
	var a:=Vector3(250,0,-75);var b:Vector3=world.entry;var side:=Vector3(-(b-a).z,0,(b-a).x).normalized()*8.3
	for sign_value in [-1,1]:walkway(a+side*sign_value,b+side*sign_value,2.6,"training_exit")
	finish()

func island(a:Vector3,b:Vector3,width:float) -> void:
	raised(a,b,width,Color("829b60"));island_centers.append((a+b)*.5)

func finish() -> void:
	if surfaces.is_empty():return
	var material:ShaderMaterial=world.art.material(Color.WHITE).duplicate();material.set_shader_parameter("use_vertex_color",true)
	world.art.cache["curb_"+str(material.get_instance_id())]=material
	for cell in surfaces:
		var origin:=Vector3(cell.x*96,0,cell.y*96)
		var tool:SurfaceTool=surfaces[cell];tool.generate_normals()
		var visual:=MeshInstance3D.new();visual.mesh=tool.commit();visual.material_override=material;visual.position=origin
		visual.visibility_range_end=330;visual.visibility_range_end_margin=24;add_child(visual);meshes.append(visual)
		var body:=StaticBody3D.new();body.position=origin;body.set_meta("surface_kind","sidewalk");body.add_to_group("raised_street_surface")
		var shape:=CollisionShape3D.new();var mesh:=ConcavePolygonShape3D.new();mesh.backface_collision=true;mesh.set_faces(faces[cell]);shape.shape=mesh;body.add_child(shape);add_child(body)
	surfaces.clear();faces.clear()
