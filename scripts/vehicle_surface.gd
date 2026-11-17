extends RefCounted
## Four contact probes provide curb/surface feedback without awarding damage.
var van:Node
var clock:=0.0
var cooldown:=0.0
var previous:PackedFloat32Array=PackedFloat32Array()
var previous_brush:=0.0

func update(delta:float) -> void:
	van.stunts.scan_curb(delta)
	cooldown=maxf(0,cooldown-delta);clock+=delta
	if clock<.05:return
	clock=0
	if van.overturned or van.wrecked or van.stunts.active:
		van.ground_tilt=Vector2.ZERO;previous.clear();return
	var levels:=PackedFloat32Array();var sidewalk:=0
	var space:PhysicsDirectSpaceState3D=van.get_world_3d().direct_space_state
	for z in [-1.52,1.52]:
		for x in [-1.0,1.0]:
			var at:Vector3=van.to_global(Vector3(x,.9,z))
			var query:=PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*1.7,1);query.exclude=[van.get_rid()]
			var hit:Dictionary=space.intersect_ray(query)
			var height:float=van.position.y
			if not hit.is_empty() and hit.collider is StaticBody3D and absf(hit.position.y-van.position.y)<.7:
				height=hit.position.y
				if hit.collider.get_meta("surface_kind","")=="sidewalk":sidewalk+=1
			levels.append(height)
	var front:float=(levels[0]+levels[1])*.5;var rear:float=(levels[2]+levels[3])*.5
	var left:float=(levels[0]+levels[2])*.5;var right:float=(levels[1]+levels[3])*.5
	van.ground_tilt=Vector2(clampf(atan2(front-rear,3.04),-.09,.09),clampf(atan2(left-right,2.0),-.09,.09))
	if previous.size()==4 and cooldown==0 and absf(van.speed)>.8 and van.is_on_floor():
		var change:=0.0
		for i in 4:change=maxf(change,absf(levels[i]-previous[i]))
		if change>.045 and change<.55:
			van.surface_bump_strength=clampf(change*2+absf(van.speed)*.008,.10,.5)
			van.surface_bump_serial+=1;cooldown=.14
	previous=levels
	van.ground_kind="sidewalk" if sidewalk>=2 else ("asphalt" if van.on_known_road(van.position) else "grass")
	var world:Node=van.location_world
	van.vegetation_contact=world.vegetation_strength(van.position) if world and world.has_method("vegetation_strength") else 0.0
	if world and (van.vegetation_contact>0 or previous_brush>0):
		for material in world.art.cache.values():
			var sway:Variant=material.get_shader_parameter("leaf_sway")
			if sway!=null and float(sway)>0:
				material.set_shader_parameter("brush_position",van.position)
				material.set_shader_parameter("brush_strength",van.vegetation_contact)
	previous_brush=van.vegetation_contact
