extends Node
## Actual rear view, rendered at low resolution and a reduced update cadence.
var van: CharacterBody3D
var dashboard: Control
var viewport: SubViewport
var camera: Camera3D
var frame := 0

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(224,320)
	viewport.world_3d = get_viewport().world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.near = 0.25
	camera.far = 950
	camera.fov = 56
	viewport.add_child(camera)
	dashboard.mirror_texture = viewport.get_texture()

func _process(_delta: float) -> void:
	frame += 1
	if not van.active or not van.cockpit or dashboard.compact_layout() or not dashboard.show_mirror or frame % 4 != 0:
		return
	camera.global_transform = van.global_transform * Transform3D(Basis(Vector3.UP,PI),Vector3(-1.6,2.25,-1.4))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
