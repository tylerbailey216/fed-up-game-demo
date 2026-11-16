extends CharacterBody3D
## Finished inked character sprites prepared from the supplied character sheet.
var game:Node
var enabled:=false
var camera:Camera3D
var visual:Node3D
var sprite:Sprite3D
var held:Node3D
var phase:=0.0
var camera_angle:=0.45
var frames:Dictionary={}
var shown_frame:AtlasTexture
var facing:=0.0
var facing_direction:="back"
var shown_animation:=""
const SHEET=preload("res://assets/art/presentation/worker-animations.png")
const AXIAL_SHEET=preload("res://assets/art/presentation/worker-front-back.png")
const REGIONS={
	"turn":[Rect2(104,31,151,278),Rect2(344,31,157,278),Rect2(570,31,136,278),Rect2(774,31,177,278),Rect2(1005,31,159,278),Rect2(1224,31,165,278)],
	"idle":[Rect2(43,330,121,194),Rect2(194,330,124,194)],
	"walk":[Rect2(366,330,124,194),Rect2(491,330,126,194),Rect2(613,330,126,194),Rect2(739,330,125,194)],
	"run":[Rect2(885,330,139,194),Rect2(1024,330,129,194),Rect2(1153,330,149,194),Rect2(1301,330,141,194)],
	"carry":[Rect2(21,560,140,196),Rect2(164,560,148,196)],
	"hold":[Rect2(781,560,119,196)]}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8;collision.shape=capsule;collision.position.y=.9;add_child(collision)
	visual=Node3D.new();add_child(visual)
	for animation in REGIONS:
		frames[animation]=[]
		for region in REGIONS[animation]:
			var texture:=AtlasTexture.new();texture.atlas=SHEET;texture.region=region;texture.filter_clip=true;frames[animation].append(texture)
	# Equal body scale and baseline across all front/back locomotion frames.
	var centers:Array=[[180,472.5,784,1100],[166,471.5,786,1099],[183,473,786,1100],[166,471.5,784.5,1099.5]]
	for row in 4:
		var animation:String=["walk_front","walk_back","carry_front","carry_back"][row]
		frames[animation]=[]
		for column in 4:
			var texture:=AtlasTexture.new();texture.atlas=AXIAL_SHEET
			texture.region=Rect2(centers[row][column]-100,floori(row*AXIAL_SHEET.get_height()/4.0)+12,200,288)
			texture.filter_clip=true;frames[animation].append(texture)
	sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.18
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position.y=1.0;visual.add_child(sprite)
	show_frame("turn",4)
	# Visibility is the shared carrying state; the illustration already contains its parcel.
	held=Node3D.new();visual.add_child(held);held.hide()
	var shadow:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(1.2,.72);shadow.mesh=plane;shadow.position.y=.025
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/contact_shadow.gdshader");shadow.material_override=material;visual.add_child(shadow)
	visual.hide()
	camera=Camera3D.new();camera.fov=62;camera.near=.15;camera.far=1400;add_child(camera)
	set_physics_process(false)

func show_frame(animation:String,index:int) -> void:
	shown_animation=animation
	var texture:AtlasTexture=frames[animation][index%frames[animation].size()]
	if texture==shown_frame:return
	shown_frame=texture;sprite.texture=texture;sprite.pixel_size=2.0/texture.region.size.y

func set_enabled(value:bool) -> void:
	enabled=value;visible=value;visual.visible=value;set_physics_process(value)
	collision_layer=2 if value else 0;collision_mask=1 if value else 0
	if value:camera.make_current();update_camera(1.0)

func update_camera(weight:float) -> void:
	var offset:=Basis(Vector3.UP,camera_angle)*Vector3(0,4.4,6.2)
	camera.global_position=camera.global_position.lerp(global_position+offset,weight)
	camera.look_at(global_position+Vector3.UP*1.0)

func update_illustration(moving:bool,running:bool) -> void:
	var relative:=wrapf(facing-camera_angle,-PI,PI)
	var angle:=absf(relative)
	facing_direction="back" if angle<PI/4 else ("front" if angle>3*PI/4 else ("left" if relative>0 else "right"))
	sprite.flip_h=false
	var frame:=int(phase/TAU*4) if moving else 1
	if facing_direction in ["front","back"]:
		if moving or held.visible:show_frame(("carry_" if held.visible else "walk_")+facing_direction,frame)
		else:show_frame("turn",0 if facing_direction=="front" else 4)
	elif moving or held.visible:
		show_frame("carry" if held.visible else ("run" if running else "walk"),frame)
		sprite.flip_h=facing_direction=="left"
	else:
		show_frame("turn",2);sprite.flip_h=facing_direction=="right"

func _physics_process(delta:float) -> void:
	if not enabled or not game.driving:return
	var input:=Vector2(Input.get_axis("steer_left","steer_right"),Input.get_axis("accelerate","brake_reverse")).limit_length()
	var direction:=Basis(Vector3.UP,camera_angle)*Vector3(input.x,0,input.y)
	var running:=Input.is_action_pressed("sprint")
	var speed:=6.5 if running else 4.2
	if held.visible:speed*=.78
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*24)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*24)
	velocity.y-=9.81*delta;move_and_slide()
	if direction.length()>.1:facing=atan2(-direction.x,-direction.z)
	var moving:=Vector2(velocity.x,velocity.z).length()>.15
	phase+=delta*(TAU*2.7 if running else TAU*1.8)
	update_illustration(moving,running)
	update_camera(1-exp(-9*delta))
	if global_position.y< -5:global_position=game.cargo.safe_foot_position;velocity=Vector3.ZERO
