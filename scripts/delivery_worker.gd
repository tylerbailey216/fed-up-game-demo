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
var camera_view:=0
var camera_zoom:=1.0
var camera_rig:=preload("res://scripts/camera_rig.gd").new()
var frames:Dictionary={}
var shown_frame:AtlasTexture
var facing:=0.0
var facing_direction:="back"
var shown_animation:=""
var shown_frame_index:=0
var frame_registration:Dictionary={}
var animation_speed:=0.0
var running_animation:=false
const WALK_STRIDE:=2.8
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
	# Twelve independently drawn poses per direction. Register a shared floor
	# and head pivot; never normalize/stretch individual frames to their bounds.
	var walk_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/worker_walk.json"))
	for direction in walk_data.directions:
		var clip:Dictionary=walk_data.directions[direction]
		var texture:Texture2D=load(clip.texture)
		var animation:String="walk_"+direction;frames[animation]=[]
		for pose in clip.frames:
			var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.filter_clip=true
			var region:Array=pose.region;atlas.region=Rect2(region[0],region[1],region[2],region[3])
			frames[animation].append(atlas)
			var pivot:Array=pose.pivot
			frame_registration[atlas.get_instance_id()]={"pixel_size":2.0/float(clip.height),"offset":Vector2(region[2]/2.0-(pivot[0]-region[0]),region[3]/2.0+(pivot[1]-region[1]-region[3]))}
	sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.18
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position.y=.025;visual.add_child(sprite)
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
	shown_frame_index=posmod(index,frames[animation].size())
	var texture:AtlasTexture=frames[animation][shown_frame_index]
	if texture==shown_frame:return
	shown_frame=texture;sprite.texture=texture
	var registration:Dictionary=frame_registration.get(texture.get_instance_id(),{})
	sprite.pixel_size=registration.get("pixel_size",2.0/texture.region.size.y)
	sprite.offset=registration.get("offset",Vector2(0,texture.region.size.y/2))

func set_enabled(value:bool) -> void:
	enabled=value;visible=value;visual.visible=value;set_physics_process(value)
	collision_layer=2 if value else 0;collision_mask=(1|8) if value else 0
	if value:camera.make_current();update_camera(1.0)

func update_camera(weight:float) -> void:
	var offsets:Array[Vector3]=[Vector3(0,4.4,6.2),Vector3(0,8,8),Vector3(0,13,2)]
	var offset:=Basis(Vector3.UP,camera_angle)*offsets[camera_view]*camera_zoom
	var focus:=global_position+Vector3.UP*1.0
	var excluded:Array[RID]=[get_rid()]
	var space:=get_world_3d().direct_space_state
	var desired:=global_position+offset
	var safe:=camera_rig.resolve(space,focus,desired,excluded)
	if safe.distance_to(desired)>.3:
		# Prefer an overhead view when the truck or a wall hides the worker.
		var overhead:=camera_rig.resolve(space,focus,global_position+Basis(Vector3.UP,camera_angle)*Vector3(0,13,1),excluded)
		if overhead.distance_to(focus)>safe.distance_to(focus):safe=overhead
	var smoothed:=camera.global_position.lerp(safe,weight)
	camera.global_position=camera_rig.resolve(space,focus,smoothed,excluded)
	camera.look_at(focus)

func cycle_camera() -> void:
	camera_view=(camera_view+1)%3

func orbit_camera(amount:float) -> void:
	camera_angle=wrapf(camera_angle+amount,-PI,PI)

func update_illustration(moving:bool,_running:bool) -> void:
	var relative:=wrapf(facing-camera_angle,-PI,PI)
	var angle:=absf(relative)
	facing_direction="back" if angle<PI/4 else ("front" if angle>3*PI/4 else ("left" if relative>0 else "right"))
	sprite.flip_h=false
	if not held.visible:
		var animation: String="walk_"+facing_direction
		var frame:=int(phase/TAU*frames[animation].size()) if moving else (11 if facing_direction=="back" else 2)
		show_frame(animation,frame)
		return
	# Carrying poses are retained for artwork review; normal pickups auto-return.
	var frame:=int(phase/TAU*4) if moving else 1
	if facing_direction in ["front","back"]:
		show_frame("carry_"+facing_direction,frame)
	else:
		show_frame("carry",frame);sprite.flip_h=facing_direction=="left"

func _physics_process(delta:float) -> void:
	if not enabled or not game.driving:return
	if Input.is_physical_key_pressed(KEY_Q):orbit_camera(delta*1.6)
	if Input.is_physical_key_pressed(KEY_E):orbit_camera(-delta*1.6)
	var input:=Vector2(Input.get_axis("steer_left","steer_right"),Input.get_axis("accelerate","brake_reverse")).limit_length()
	var direction:=Basis(Vector3.UP,camera_angle)*Vector3(input.x,0,input.y)
	var running:=Input.is_action_pressed("sprint")
	var speed:=6.5 if running else 4.2
	if held.visible:speed*=.78
	velocity.x=move_toward(velocity.x,direction.x*speed,delta*24)
	velocity.z=move_toward(velocity.z,direction.z*speed,delta*24)
	velocity.y-=9.81*delta;move_and_slide()
	if direction.length()>.1:facing=atan2(-direction.x,-direction.z)
	# Drive cadence from real travel, so feet stop cycling when blocked by a wall.
	animation_speed=Vector2(get_position_delta().x,get_position_delta().z).length()/delta
	running_animation=running
	update_camera(1-exp(-9*delta))
	if global_position.y< -5:global_position=game.cargo.safe_foot_position;velocity=Vector3.ZERO

func _process(delta:float) -> void:
	if not enabled or not game.driving:return
	phase=fmod(phase+delta*animation_speed*TAU/WALK_STRIDE,TAU)
	# All joint motion, weight shifts and foot lifts are in the drawings.
	visual.position=Vector3.ZERO;visual.rotation=Vector3.ZERO
	update_illustration(animation_speed>.15,running_animation)
