extends MultiMeshInstance3D
## A bounded cloud of actual six-armed 3D flakes; one instanced draw, no billboards.
const COUNT:=72
var game:Node
var falling:=false
var clock:=0.0
var seeds:Array[Vector4]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm in 6:
		var angle:float=arm*TAU/6
		add_branch(tool,Vector3.ZERO,Vector3(cos(angle),0,sin(angle))*.5,.065)
		for side in [-1,1]:
			var anchor:=Vector3(cos(angle),0,sin(angle))*.28
			add_branch(tool,anchor,anchor+Vector3(cos(angle+side*.85),0,sin(angle+side*.85))*.20,.032)
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=tool.commit();multimesh.instance_count=COUNT
	var material:=StandardMaterial3D.new();material.albedo_color=Color("e6f7ff");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override=material
	var rng:=RandomNumberGenerator.new();rng.seed=584
	for i in COUNT:seeds.append(Vector4(rng.randf_range(-4,4),rng.randf_range(0,7),rng.randf_range(-4.25,4.25),rng.randf_range(.18,.38)))
	custom_aabb=AABB(Vector3(-5,-3,-7),Vector3(10,12,12));hide()

func add_branch(tool:SurfaceTool,a:Vector3,b:Vector3,width:float) -> void:
	var box:=BoxMesh.new();box.size=Vector3(width,.045,a.distance_to(b))
	var orientation:=Basis(Vector3.UP,-atan2(b.z-a.z,b.x-a.x)+PI/2)
	var transform:=Transform3D(orientation,(a+b)*.5)
	tool.append_from(box,0,transform)

func _process(delta:float) -> void:
	falling=game.flight.effects_active()
	visible=falling
	if not falling:clock=0;return
	clock+=delta
	global_position=game.van.to_global(game.van.vehicle_center)
	# World-aligned falling trajectories do not rotate with a steering turn.
	for i in COUNT:
		var s:=seeds[i];var phase:float=i*.71
		var at:=Vector3(s.x+sin(clock*.7+phase)*.32,fposmod(s.y-clock*(.8+s.w*2),7)-1.6,s.z+cos(clock*.6+phase)*.25)
		var rotation:=Basis.from_euler(Vector3(clock*.5+phase,clock*.7+phase,sin(clock+phase)*.6))
		multimesh.set_instance_transform(i,Transform3D(rotation.scaled(Vector3.ONE*s.w),at))
