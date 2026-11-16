extends RefCounted
## Shared original comic materials. No screen-space/depth-buffer dependency.
const TOON = preload("res://assets/shaders/toon.gdshader")
const INK = preload("res://assets/shaders/ink.gdshader")
var cache: Dictionary = {}

func material(color: Color, outlined := false, road := false) -> ShaderMaterial:
	var key := str(color)+str(outlined)+str(road)
	if cache.has(key):
		return cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("asphalt",road)
	if outlined:
		var edge := ShaderMaterial.new()
		edge.shader = INK
		mat.next_pass = edge
	cache[key] = mat
	return mat

func apply_to_model(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.get_active_material(surface)
			if source is StandardMaterial3D:
				node.set_surface_override_material(surface,material(source.albedo_color,true))
	for child in node.get_children():
		apply_to_model(child)
