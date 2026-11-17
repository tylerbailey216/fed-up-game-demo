extends CharacterBody3D
## Lightweight, indestructible citizen with drawn gait and recovery poses.
var district:Node
var definition:Dictionary
var route:Array[Vector3]=[]
var waypoint:=0
var sprite:Sprite3D
var clips:Dictionary={}
var facing:=0.0
var phase:=0.0
var state:="walk"
var timer:=0.0
var cooldown:=0.0
var blocked:=0.0
var bounce_count:=0
var hits:=0
var recoveries:=0
var pace:=1.2
var shown:AtlasTexture
var last_position:=Vector3.ZERO
var design_id:=""
var simulation_active:=true
static var atlas_cache:Dictionary={}
var ground_clock:=0.0
var ground_height:=0.0
var path_blocked:=false

func walk_motion(movement:Vector3,delta:float) -> void:
	# Known footway navigation needs a floor/wall check, not a full character
	# floor solver for every civilian on every frame. Reactions still use it.
	ground_clock-=delta
	if ground_clock<=0:
		ground_clock=.1
		var space:PhysicsDirectSpaceState3D=get_world_3d().direct_space_state
		var next:Vector3=position+movement*.12
		var ray:=PhysicsRayQueryParameters3D.create(next+Vector3.UP*.5,next-Vector3.UP*.8,1)
		ray.exclude=[get_rid()]
		var floor_hit:Dictionary=space.intersect_ray(ray)
		path_blocked=floor_hit.is_empty() or absf(floor_hit.position.y-position.y)>.34
		if not path_blocked:ground_height=floor_hit.position.y+.025
		if not movement.is_zero_approx():
			ray.from=position+Vector3.UP*.65;ray.to=ray.from+movement.normalized()*(.4+movement.length()*.12)
			path_blocked=path_blocked or not space.intersect_ray(ray).is_empty()
	if not path_blocked:position+=movement*delta
	position.y=move_toward(position.y,ground_height,delta*2.5)
	velocity=movement if not path_blocked else Vector3.ZERO

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	collision_layer=16;collision_mask=1|8
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.3;capsule.height=float(definition.world_height)*.85
	collision.shape=capsule;collision.position.y=capsule.height*.5;add_child(collision)
	var texture:Texture2D=load(definition.texture)
	if atlas_cache.has(definition.texture):clips=atlas_cache[definition.texture]
	for key in definition.clips if clips.is_empty() else []:
		clips[key]=[]
		for drawing in definition.clips[key].frames:
			var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.filter_clip=true
			var r:Array=drawing.region;atlas.region=Rect2(r[0],r[1],r[2],r[3]);clips[key].append(atlas)
	atlas_cache[definition.texture]=clips
	sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.shaded=false
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.2
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(sprite)
	var shadow:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(.9,.6);shadow.mesh=plane;shadow.position.y=.025
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/contact_shadow.gdshader");shadow.material_override=material;add_child(shadow)
	last_position=position

func react(push:Vector3,strength:float) -> void:
	if cooldown>0 or state in ["tumble","recover"]:return
	hits+=1;state="tumble";timer=0;bounce_count=0;cooldown=4
	var direction:=Vector3(push.x,0,push.z).normalized()
	if direction.is_zero_approx():direction=Vector3.RIGHT
	velocity=direction*clampf(strength*.8,3,10)+Vector3.UP*clampf(4+strength*.2,4,7)

func check_contacts() -> void:
	if cooldown>0:return
	var vehicles:Array=[district.game.van]
	vehicles.append_array(district.game.traffic.cars)
	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or global_position.distance_squared_to(vehicle.global_position)>42:continue
		var speed:Vector3=vehicle.planar_velocity if vehicle==district.game.van else vehicle.linear_velocity
		var local:Vector3=vehicle.to_local(global_position)
		var width:float=1.35 if vehicle==district.game.van else vehicle.body_width*.5+.3
		var length:float=3.6 if vehicle==district.game.van else vehicle.body_length*.5+.3
		if absf(local.x)<width and absf(local.z)<length and speed.length()>1.2:
			react(speed+global_position-vehicle.global_position,speed.length());return
	for barrel in district.game.traffic.barrels:
		if global_position.distance_squared_to(barrel.global_position)<1.3 and barrel.linear_velocity.length()>2:
			react(barrel.linear_velocity,barrel.linear_velocity.length());return

func show_pose() -> void:
	var camera:=get_viewport().get_camera_3d()
	if not camera:return
	var relative:=wrapf(facing-camera.global_rotation.y,-PI,PI)
	var direction:="back" if absf(relative)<PI/4 else ("front" if absf(relative)>3*PI/4 else ("left" if relative>0 else "right"))
	var clip:="walk" if state in ["walk","wait"] else state
	var key:=clip+"_"+direction
	var index:=int(phase/TAU*12)%12 if state=="walk" else 2
	index=mini(index,clips[key].size()-1)
	var atlas:AtlasTexture=clips[key][index]
	if shown!=atlas:
		shown=atlas;sprite.texture=atlas
		var data:Dictionary=definition.clips[key];var pose:Dictionary=data.frames[index];var r:Array=pose.region;var pivot:Array=pose.pivot
		sprite.pixel_size=float(definition.world_height)/float(data.height)
		sprite.offset=Vector2(float(r[2])*.5-(float(pivot[0])-float(r[0])),float(pivot[1])-float(r[1])-float(r[3])*.5)
	# A tucked reaction drawing accompanies cartoon physical tumbling; normal
	# locomotion gets its articulated movement entirely from the twelve drawings.
	sprite.rotation.z=sin(timer*9)*.6 if state=="tumble" else 0.0

func _physics_process(delta:float) -> void:
	if not district.game.driving:return
	if not simulation_active and state not in ["tumble","recover"]:return
	cooldown=maxf(0,cooldown-delta);timer+=delta
	check_contacts()
	if state=="tumble":
		velocity.y-=13*delta;velocity.x*=exp(-1.3*delta);velocity.z*=exp(-1.3*delta)
		move_and_slide()
		if timer>5 or position.y< -3:
			position=route[(waypoint+route.size()-1)%route.size()]+Vector3.UP*.08
			state="recover";timer=0;velocity=Vector3.ZERO
		elif is_on_floor() and timer>.3:
			if bounce_count==0:velocity.y=2.6;bounce_count+=1
			else:state="recover";timer=0;velocity=Vector3.ZERO
	elif state=="recover":
		if timer>1.2:state="walk";timer=0;recoveries+=1;cooldown=1.5
	elif state=="surprise":
		if timer>.65:state="walk";timer=0
	else:
		var gap:=route[waypoint]-position;gap.y=0
		if gap.length()<.6:waypoint=(waypoint+1)%route.size();gap=route[waypoint]-position;gap.y=0
		state="walk"
		var movement:=gap.normalized()*pace if state=="walk" else Vector3.ZERO
		if movement.length()>.1:facing=atan2(-movement.x,-movement.z)
		walk_motion(movement,delta)
		var traveled:=Vector2(position.x-last_position.x,position.z-last_position.z).length()
		if state=="walk":phase=fmod(phase+traveled*TAU/float(definition.get("stride",1.08)),TAU)
		blocked=blocked+delta if state=="walk" and traveled<.001 else 0.0
		if blocked>3 or global_position.y< -2:
			# Resume on the known sidewalk, without abandoning the route forever.
			position=route[(waypoint+route.size()-1)%route.size()]+Vector3.UP*.1;velocity=Vector3.ZERO;blocked=0
	last_position=position;show_pose()
