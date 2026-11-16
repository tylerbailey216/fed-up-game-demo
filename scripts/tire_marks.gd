extends Node3D
## Fixed-size world-space strip pool. Flat-surface contact is checked per tire.
const CAPACITY := 2048
const LIFETIME := 7.0
var van: Node
var clock := 0.0
var emitted := 0
var cursor := 0
var births: PackedFloat32Array = []
var previous: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var connected: Array[bool] = [false,false,false,false]
var seen_reset := -1
var seen_recovery := -1
var marks: MultiMesh
var material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	marks = MultiMesh.new()
	marks.transform_format = MultiMesh.TRANSFORM_3D
	marks.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	marks.mesh = plane
	marks.instance_count = CAPACITY
	births.resize(CAPACITY)
	births.fill(-1000)
	for i in CAPACITY:
		marks.set_instance_custom_data(i,Color(-1000,0,0,0))
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/tire_marks.gdshader")
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = marks
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func live_count() -> int:
	var count := 0
	for born in births:
		if clock-born<LIFETIME:
			count += 1
	return count

func _physics_process(delta: float) -> void:
	if not van.active:
		return
	clock += delta
	material.set_shader_parameter("mark_clock",clock)
	if seen_reset!=van.reset_count or seen_recovery!=van.offroad_recoveries:
		connected.fill(false)
		seen_reset = van.reset_count
		seen_recovery = van.offroad_recoveries
	if van.overturned or not van.is_on_floor() or absf(van.speed)<2 or van.tire_squeal<0.12:
		connected.fill(false)
		return
	var index := 0
	for z in [-1.52,1.52]:
		for x in [-1.14,1.14]:
			var start: Vector3 = van.to_global(Vector3(x,0.7,z))
			var query := PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*1.4)
			query.exclude = [van.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.normal.y<0.97 or not hit.collider is StaticBody3D:
				connected[index] = false
				index += 1
				continue
			var point: Vector3 = hit.position+hit.normal*0.014
			if connected[index]:
				var gap := point-previous[index]
				var length := gap.length()
				if length>=0.16 and length<2.0:
					var along := gap/length
					var across: Vector3 = hit.normal.cross(along).normalized()
					var basis := Basis(across,hit.normal,along).scaled(Vector3(0.28,1,length))
					marks.set_instance_transform(cursor,Transform3D(basis,(point+previous[index])*0.5))
					marks.set_instance_custom_data(cursor,Color(clock,clampf(van.tire_squeal*0.6,0.17,0.52),0,0))
					births[cursor] = clock
					cursor = (cursor+1)%CAPACITY
					emitted += 1
					previous[index] = point
				elif length>=2.0:
					previous[index] = point
			else:
				previous[index] = point
			connected[index] = true
			index += 1
