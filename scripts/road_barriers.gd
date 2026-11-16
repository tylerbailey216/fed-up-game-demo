extends Node3D
## Low-speed containment and energy-limited breakaway guardrail sections.
## Tuning is for the game, not a road safety engineering model.
const TRUCK_MASS := 3200.0
const SECTION_MASS := 250.0
const YIELD_ENERGY := 450000.0
const BREAK_ENERGY := 800000.0
var world: Node3D
var sections: Array[Dictionary] = []
var groups: Dictionary = {}
var debris: Array[RigidBody3D] = []
var breaks := 0

func _ready() -> void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/independence_safety.json"))
	for section in data.barriers:build_section(section)
	for key in groups:
		var group:Dictionary=groups[key]
		var instance:=MultiMeshInstance3D.new()
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=BoxMesh.new()
		multi.instance_count=group.transforms.size()
		for i in group.transforms.size():multi.set_instance_transform(i,group.transforms[i])
		instance.multimesh=multi
		instance.material_override=world.art.material(Color("c5c4b5") if group.kind=="concrete" else Color("9ca9af"))
		instance.visibility_range_end=800
		add_child(instance)
		group.instance=instance

func add_visual(transform: Transform3D,kind: String) -> Array:
	var cell:=Vector2i(floori(transform.origin.x/128),floori(transform.origin.z/128))
	var key:=kind+str(cell)
	if not groups.has(key):groups[key]={"kind":kind,"transforms":[]}
	var index:int=groups[key].transforms.size()
	groups[key].transforms.append(transform)
	return [key,index]

func build_section(data: Dictionary) -> void:
	var a:=Vector3(data.a[0],data.a[1],data.a[2])
	var b:=Vector3(data.b[0],data.b[1],data.b[2])
	var direction:Vector3=b-a
	var length:float=direction.length()+0.1 # overlap joints; no thin unprotected seams
	var basis:=Basis.looking_at(-direction.normalized(),Vector3.UP)
	var frame:=Transform3D(basis,(a+b)*0.5)
	var concrete:bool=data.kind=="concrete"
	var size:=Vector3(0.65,1.15,length) if concrete else Vector3(0.22,0.8,length)
	var offset:=Vector3.UP*(0.575 if concrete else 0.8)
	var body:=StaticBody3D.new()
	body.transform=frame.translated_local(offset)
	body.set_meta("barrier_kind",data.kind)
	body.set_meta("section_index",sections.size())
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	add_child(body)
	var visuals:Array=[]
	visuals.append(add_visual(Transform3D(basis.scaled_local(size),body.position),data.kind))
	if not concrete:
		for z in [-length*0.32,length*0.32]:
			visuals.append(add_visual(Transform3D(basis.scaled_local(Vector3(0.14,1,0.14)),frame*Vector3(0,0.45,z)),data.kind))
	sections.append({"body":body,"frame":frame,"size":size,"visuals":visuals,"kind":data.kind,"broken":false})

func try_break(body: StaticBody3D,incoming: Vector3,normal: Vector3,hit: Vector3) -> Vector3:
	var section:Dictionary=sections[int(body.get_meta("section_index"))]
	var closing:=maxf(0,-incoming.dot(normal))
	var energy:=0.5*TRUCK_MASS*closing*closing
	if section.kind!="steel" or section.broken or incoming.length()<22 or energy<BREAK_ENERGY:
		return incoming
	section.broken=true
	breaks+=1
	body.set_deferred("collision_layer",0)
	body.set_deferred("collision_mask",0)
	for entry in section.visuals:
		var instance:MultiMeshInstance3D=groups[entry[0]].instance
		var hidden:=instance.multimesh.get_instance_transform(entry[1])
		hidden.basis=Basis().scaled(Vector3.ZERO)
		instance.multimesh.set_instance_transform(entry[1],hidden)
	# Work spent yielding anchors is removed from the inward kinetic energy.
	# The remaining normal momentum is exchanged with a physical loose section.
	var after_yield:=sqrt(maxf(0,closing*closing-2*YIELD_ENERGY/TRUCK_MASS))
	var local_hit:Vector3=body.global_basis.inverse()*(hit-body.global_position)
	var local_normal:Vector3=body.global_basis.inverse()*(-normal)
	var lever:=local_hit.cross(local_normal)
	var size:Vector3=section.size
	var inertia:=Vector3(size.y*size.y+size.z*size.z,size.x*size.x+size.z*size.z,size.x*size.x+size.y*size.y)*SECTION_MASS/12
	var angular_inverse_mass:=lever.x*lever.x/inertia.x+lever.y*lever.y/inertia.y+lever.z*lever.z/inertia.z
	var impulse:=after_yield/(1/TRUCK_MASS+1/SECTION_MASS+angular_inverse_mass)
	var loose:=RigidBody3D.new()
	loose.mass=SECTION_MASS
	loose.continuous_cd=true
	loose.linear_damp=0.4
	loose.angular_damp=0.7
	loose.process_mode=Node.PROCESS_MODE_PAUSABLE
	loose.transform=body.transform
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=section.size
	shape.shape=box
	loose.add_child(shape)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=section.size
	visual.mesh=mesh
	visual.material_override=world.art.material(Color("9ca9af"))
	loose.add_child(visual)
	add_child(loose)
	loose.apply_impulse(-normal*impulse,hit-loose.global_position)
	debris.append(loose)
	if debris.size()>24:
		var old:RigidBody3D=debris.pop_front()
		if is_instance_valid(old):old.queue_free()
	var outgoing:=incoming.slide(normal)-normal*maxf(0,after_yield-impulse/TRUCK_MASS)
	section.energy_before=0.5*TRUCK_MASS*incoming.length_squared()
	section.energy_after=0.5*TRUCK_MASS*outgoing.length_squared()+0.5*impulse*impulse*(1/SECTION_MASS+angular_inverse_mass)
	return outgoing

func pause_debris(paused: bool) -> void:
	for body in debris:
		if not is_instance_valid(body):continue
		if paused and not body.freeze:
			body.set_meta("held_linear",body.linear_velocity)
			body.set_meta("held_angular",body.angular_velocity)
			body.freeze=true
		elif not paused and body.freeze:
			body.freeze=false
			body.linear_velocity=body.get_meta("held_linear",Vector3.ZERO)
			body.angular_velocity=body.get_meta("held_angular",Vector3.ZERO)
