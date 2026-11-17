extends Node3D
## A short, batched comic-star burst that follows the truck even if it moves.
var cargo:Node
var item:Dictionary
var origin:=Vector3.ZERO
var elapsed:=0.0
var duration:=1.2
var stars:MultiMeshInstance3D

func _ready() -> void:
	origin=item.body.global_position+Vector3.UP*.4
	duration=clampf(.85+origin.distance_to(cargo.game.van.position)/90,1.0,1.8)
	var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a:=i*TAU/8;var b:=(i+1)*TAU/8
		mesh.add_vertex(Vector3.ZERO)
		mesh.add_vertex(Vector3(sin(a),cos(a),0)*(1 if i%2==0 else .25))
		mesh.add_vertex(Vector3(sin(b),cos(b),0)*(1 if (i+1)%2==0 else .25))
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=false
	stars=MultiMeshInstance3D.new();stars.multimesh=MultiMesh.new()
	stars.multimesh.transform_format=MultiMesh.TRANSFORM_3D;stars.multimesh.use_colors=true
	stars.multimesh.mesh=mesh.commit();stars.material_override=material;stars.multimesh.instance_count=9
	stars.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(stars)
	global_position=origin;update_stars(0)

func update_stars(t:float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var facing:=camera.global_basis if camera else Basis.IDENTITY
	for i in 9:
		var angle:=i*2.4+elapsed*(3 if i%2==0 else -3)
		var spread:float=(.2+sin(t*PI)*.7)*(1-float(i)/16)
		var offset:=Vector3(cos(angle)*spread,sin(angle)*spread,float(i)*-.06)
		var sparkle:float=(.11+.09*(.5+.5*sin(elapsed*20+i*2)))*(1-t*.6)
		stars.multimesh.set_instance_transform(i,Transform3D(facing.rotated(facing.z,angle*.4).scaled(Vector3.ONE*sparkle),offset))
		var color:Color=[Color("ffd044"),Color("fff6cf"),Color("bceff4"),Color("c398ee")][i%4]
		color.a=minf(1,(1-t)*6);stars.multimesh.set_instance_color(i,color)

func _physics_process(delta:float) -> void:
	if not cargo.game.driving:return
	elapsed+=delta
	var t:=minf(1,elapsed/duration)
	var target:Vector3=cargo.game.van.body.to_global(Vector3(0,1.7,2.55))
	var travel:=smoothstep(.12,1.0,t)
	global_position=origin.lerp(target,travel)+Vector3.UP*sin(travel*PI)*minf(6,1.5+origin.distance_to(target)*.12)
	update_stars(t)
	if t>=1:
		cargo.secure_package(item,"truck");queue_free()
