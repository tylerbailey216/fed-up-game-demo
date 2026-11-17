extends RefCounted
## Reference models become two cached meshes: articulated body and live brakes.
var cache:Dictionary={}
var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/traffic_vehicles.json")).vehicles

func collect(node:Node,pose:Transform3D,axle:Vector3,kind:float,groups:Dictionary) -> void:
	if node is Node3D:pose=pose*node.transform
	if str(node.name).begins_with("WheelPivot"):
		axle=pose.origin;kind=1.0 if str(node.name).contains("Front") else 2.0
	if node is MeshInstance3D:
		for s in node.mesh.get_surface_count():
			var material:Material=node.mesh.surface_get_material(s)
			var brake:=str(material.resource_name).begins_with("Brake_Live")
			var tone:Color=material.albedo_color if material is StandardMaterial3D else Color.WHITE
			var surface:SurfaceTool=groups.brakes if brake else groups.body
			var arrays:Array=node.mesh.surface_get_arrays(s)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for step in indices.size() if not indices.is_empty() else vertices.size():
				var index:int=indices[step] if not indices.is_empty() else step
				surface.set_color(Color.WHITE if brake else tone)
				surface.set_uv(Vector2(axle.x,axle.z));surface.set_uv2(Vector2(kind,axle.y))
				surface.set_normal((pose.basis.inverse().transposed()*normals[index]).normalized())
				surface.add_vertex(pose*vertices[index])
	for child in node.get_children():collect(child,pose,axle,kind,groups)

func build(car:RigidBody3D,world:Node,kind:String) -> void:
	if not cache.has(kind):
		var scene:Node3D=load(definitions[kind].model).instantiate()
		var groups:Dictionary={"body":SurfaceTool.new(),"brakes":SurfaceTool.new()}
		for tool in groups.values():tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		collect(scene,Transform3D.IDENTITY,Vector3.ZERO,0.0,groups)
		cache[kind]={"body":groups.body.commit(),"brakes":groups.brakes.commit()};scene.free()
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/traffic_toon.gdshader")
	material.set_shader_parameter("use_vertex_color",true)
	var ink:=ShaderMaterial.new();ink.shader=preload("res://assets/shaders/traffic_ink.gdshader");material.next_pass=ink
	car.visual_material=material;world.art.cache["traffic_"+str(car.get_instance_id())]=material
	for pass_material in [material,ink]:
		pass_material.set_shader_parameter("wheel_roll",0.0);pass_material.set_shader_parameter("wheel_steer",0.0)
	car.brake_material=StandardMaterial3D.new();car.brake_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	car.brake_material.albedo_color=Color("8e2634")
	for key in ["body","brakes"]:
		var mesh:=MeshInstance3D.new();mesh.mesh=cache[kind][key]
		mesh.material_override=material if key=="body" else car.brake_material
		mesh.extra_cull_margin=.7;mesh.visibility_range_end=230;mesh.visibility_range_end_margin=16;car.add_child(mesh)
	for at in car.definition.wheels:
		var pivot:=Node3D.new();pivot.position=Vector3(at[0],at[1],at[2]);car.add_child(pivot);car.wheel_nodes.append(pivot)
