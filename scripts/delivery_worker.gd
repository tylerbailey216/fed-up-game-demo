extends CharacterBody3D
## Original 3D interpretation of the supplied chibi character and sprite reference.
var game:Node
var enabled:=false
var camera:Camera3D
var visual:Node3D
var arms:Array[Node3D]=[]
var legs:Array[Node3D]=[]
var held:Node3D
var phase:=0.0
var camera_angle:=0.45
var art:=preload("res://scripts/art_style.gd").new()

func piece(parent:Node3D,at:Vector3,size:Vector3,color:String,round_shape:=false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	if round_shape:
		var sphere:=SphereMesh.new();sphere.radial_segments=12;sphere.rings=6;node.mesh=sphere;node.scale=size
	else:
		var box:=BoxMesh.new();box.size=size;node.mesh=box
	node.position=at;node.material_override=art.material(Color(color),true);parent.add_child(node);return node

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.65;collision.shape=capsule;collision.position.y=.825;add_child(collision)
	visual=Node3D.new();add_child(visual)
	piece(visual,Vector3(0,.92,0),Vector3(.56,.58,.34),"6a3190")
	piece(visual,Vector3(0,1.08,-.025),Vector3(.59,.25,.37),"efeada")
	for side in [-1,1]:
		piece(visual,Vector3(side*.24,.99,-.20),Vector3(.055,.38,.025),"f79422")
		piece(visual,Vector3(side*.16,.85,-.20),Vector3(.15,.11,.025),"8d55aa")
		var arm:=Node3D.new();arm.position=Vector3(side*.36,1.12,0);visual.add_child(arm);arms.append(arm)
		piece(arm,Vector3(0,-.10,0),Vector3(.23,.25,.28),"682c8b",true)
		piece(arm,Vector3(0,-.28,0),Vector3(.25,.32,.26),"dd9334",true)
		var leg:=Node3D.new();leg.position=Vector3(side*.17,.67,0);visual.add_child(leg);legs.append(leg)
		piece(leg,Vector3(0,-.17,0),Vector3(.24,.36,.28),"68348a")
		piece(leg,Vector3(0,-.48,-.07),Vector3(.30,.21,.43),"95632f",true)
	piece(visual,Vector3(0,1.47,0),Vector3(.83,.78,.68),"e6a13e",true)
	for side in [-1,1]:
		piece(visual,Vector3(side*.40,1.46,0),Vector3(.15,.22,.15),"d38b30",true)
		piece(visual,Vector3(side*.17,1.50,-.31),Vector3(.06,.13,.035),"211625",true)
	piece(visual,Vector3(0,1.83,.015),Vector3(.88,.38,.74),"5d2786",true)
	piece(visual,Vector3(0,1.83,-.35),Vector3(.62,.23,.065),"f4f0df")
	piece(visual,Vector3(0,1.75,-.37),Vector3(.97,.065,.50),"61268d",true)
	piece(visual,Vector3(0,1.79,-.48),Vector3(.83,.027,.19),"f89923")
	var logo:=Label3D.new();logo.text="FedUp";logo.font_size=42;logo.pixel_size=.006;logo.modulate=Color("6b328b");logo.position=Vector3(0,1.84,-.39);logo.rotation.y=PI;visual.add_child(logo)
	held=Node3D.new();held.position=Vector3(0,.94,-.48);visual.add_child(held)
	preload("res://scripts/package_visual.gd").build(held,.38,art)
	held.hide();visual.hide()
	camera=Camera3D.new();camera.fov=62;camera.near=.15;camera.far=900;add_child(camera)
	set_physics_process(false)

func set_enabled(value:bool) -> void:
	enabled=value;visible=value;visual.visible=value;set_physics_process(value)
	collision_layer=2 if value else 0;collision_mask=1 if value else 0
	if value:camera.make_current();update_camera(1.0)

func update_camera(weight:float) -> void:
	var offset:=Basis(Vector3.UP,camera_angle)*Vector3(0,5.4,7)
	camera.global_position=camera.global_position.lerp(global_position+offset,weight)
	camera.look_at(global_position+Vector3.UP*1.0)

func _physics_process(delta:float) -> void:
	if not enabled or not game.driving:return
	var input:=Vector2(Input.get_axis("steer_left","steer_right"),Input.get_axis("accelerate","brake_reverse"))
	input=input.limit_length()
	var direction:=Basis(Vector3.UP,camera_angle)*Vector3(input.x,0,input.y)
	var speed:=6.5 if Input.is_action_pressed("sprint") else 4.2
	if held.visible:speed*=.78
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*24)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*24)
	velocity.y-=9.81*delta;move_and_slide()
	if direction.length()>.1:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),delta*12)
	var moving:=Vector2(velocity.x,velocity.z).length()>.15
	phase+=delta*(12 if speed>5 else 8)
	for i in 2:
		legs[i].rotation.x=sin(phase+i*PI)*.55 if moving else 0.0
		arms[i].rotation.x=-1.05 if held.visible else (-sin(phase+i*PI)*.55 if moving else 0.0)
	visual.position.y=absf(sin(phase))*.035 if moving else sin(Time.get_ticks_msec()*.002)*.008
	update_camera(1-exp(-9*delta))
	if global_position.y< -5:global_position=game.cargo.safe_foot_position;velocity=Vector3.ZERO
