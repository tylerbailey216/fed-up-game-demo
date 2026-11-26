extends "res://scripts/art_style.gd"
## Dedicated fleet finish; city/environment materials retain their existing look.
func material(color:Color,outlined:=false,road:=false) -> ShaderMaterial:
	var mat:ShaderMaterial=super.material(color,outlined,road)
	mat.shader=preload("res://assets/shaders/fleet_illustrated.gdshader")
	if outlined:mat.next_pass.set_shader_parameter("width_pixels",2.5)
	return mat

func apply_to_model(node:Node) -> void:
	var palette:Dictionary={"Paint_WarmWhite":Color("f3ebd8"),"Brand_Purple":Color("6a39a0"),"Brand_Orange":Color("f78c2f"),"Glass_GraphicBlue":Color("77b6d5"),"Metal_Silver":Color("aea7b2"),"Outline_Charcoal":Color("10121e")}
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source:Material=node.get_active_material(surface)
			if source is StandardMaterial3D:
				var tone:Color=source.albedo_color
				for key in palette:
					if source.resource_name.begins_with(key):tone=palette[key];break
				node.set_surface_override_material(surface,material(tone,true))
	for child in node.get_children():apply_to_model(child)

func rounded_box(size:Vector3,radius:float) -> ArrayMesh:
	# A rounded cuboid with fixed bevel rings and smooth bevel normals. Shared
	# faces stay broad/flat; corners keep the garage's manufactured cartoon shape.
	var half:=size*.5;var r:=minf(radius,minf(half.x,minf(half.y,half.z))*.8)
	var core:=half-Vector3.ONE*r
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u:=(axis+1)%3;var v:=(axis+2)%3
		var us:Array[float]=[-half[u],-core[u]-r*.5,-core[u],core[u],core[u]+r*.5,half[u]]
		var vs:Array[float]=[-half[v],-core[v]-r*.5,-core[v],core[v],core[v]+r*.5,half[v]]
		for sign_value in [-1,1]:
			for i in 5:
				for j in 5:
					var vertices:Array[Vector3]=[];var normals:Array[Vector3]=[]
					for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
						var p:=Vector3.ZERO;p[axis]=half[axis]*sign_value;p[u]=us[corner.x];p[v]=vs[corner.y]
						var anchor:=p.clamp(-core,core);var n:Vector3=(p-anchor).normalized()
						vertices.append(anchor+n*r);normals.append(n)
					for k in ([0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]):
						tool.set_normal(normals[k]);tool.add_vertex(vertices[k])
	return tool.commit()
