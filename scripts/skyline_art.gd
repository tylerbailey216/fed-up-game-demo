extends RefCounted
## Distant illustrated impostor backdrop; foreground remains 3D geometry.
func build(parent: Node3D) -> void:
	if not ResourceLoader.exists("res://assets/art/skyline_illustrated_v2.png"):
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 8:
		for slice_index in 12:
			var angle_a := TAU*(sector+slice_index/12.0)/8.0
			var angle_b := TAU*(sector+(slice_index+1)/12.0)/8.0
			var a := Vector3(cos(angle_a)*520,-6,sin(angle_a)*520)
			var b := Vector3(cos(angle_b)*520,-6,sin(angle_b)*520)
			var rise := Vector3(0,136,0)
			var u := slice_index/12.0
			var v := (slice_index+1)/12.0
			var vertices := [a,b,b+rise,a,b+rise,a+rise]
			var uvs := [Vector2(u,1),Vector2(v,1),Vector2(v,0),Vector2(u,1),Vector2(v,0),Vector2(u,0)]
			for i in 6:
				surface.set_uv(uvs[i])
				surface.add_vertex(vertices[i])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/skyline_art.gdshader")
	mat.set_shader_parameter("skyline",load("res://assets/art/skyline_illustrated_v2.png"))
	mesh.material_override = mat
	parent.add_child(mesh)
