extends Node3D
## Brief, pooled delivery feedback. Zen remains quiet; no physics/mission rules.
## Package stars remain owned by package_return.gd; pickups add sound/HUD pulse only.
const CAPACITY:=128
const MAX_LIFE:=.44
const INK:=Color("10121e")
const GOLD:=Color("ffd044")
const PURPLE:=Color("c995ff")
const CREAM:=Color("f3ebd8")
var game:Node
var particles:MultiMesh
var slots:Array[Dictionary]=[]
var cursor:=0
var clock:=0.0
var seen_collision:=0
var seen_reset:=-1
var pickup_cooldown:=0.0
var pickup_pulse:=0.0
var last_pickup_count:=0
var last_pickup_total:=0
var last_checkpoint:=0
var finished:=false
var impact_count:=0
var pickup_count:=0
var checkpoint_count:=0
var completion_count:=0
var emitted:=0
var max_live:=0
var players:Dictionary={}
var audio_counts:Dictionary={"package_pickup":0,"route_clear":0,"delivery_complete":0}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	# A single mesh and draw batch for every burst, with inked four-point stars.
	# Opaque geometry avoids transparent overdraw and custom shader variants.
	particles=MultiMesh.new();particles.transform_format=MultiMesh.TRANSFORM_3D
	particles.use_colors=true;particles.mesh=star_mesh();particles.instance_count=CAPACITY
	var node:=MultiMeshInstance3D.new();node.multimesh=particles
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=material;add_child(node)
	for i in CAPACITY:slots.append({"born":-1000.0});hide_slot(i)
	for sound in audio_counts:
		var player:=AudioStreamPlayer.new()
		var paths:Dictionary={"package_pickup":"loose_package.wav","route_clear":"delivery_zone.mp3"}
		var path:String="res://assets/audio/"+str(paths.get(sound,sound+".wav"))
		if ResourceLoader.exists(path):player.stream=load(path)
		player.max_polyphony=8
		player.process_mode=Node.PROCESS_MODE_PAUSABLE
		add_child(player);players[sound]=player
	reset()

func star_mesh() -> ArrayMesh:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	var points:Array[Vector3]=[]
	for i in 8:
		var angle:float=float(i)*TAU/8
		var radius:float=.5 if i%2==0 else .12
		points.append(Vector3(cos(angle)*radius,sin(angle)*radius,0))
	for i in 8:
		var a:Vector3=points[i];var b:Vector3=points[(i+1)%8]
		for vertex in [Vector3.ZERO,a*.72,b*.72]:vertices.append(vertex);colors.append(Color.WHITE)
		# Two triangles make the narrow dark outline without a second surface.
		for vertex in [a*.72,a,b,a*.72,b,b*.72]:vertices.append(vertex);colors.append(INK)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func hide_slot(index:int) -> void:
	particles.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))

func reset() -> void:
	for i in slots.size():slots[i]={"born":-1000.0};hide_slot(i)
	cursor=0;pickup_cooldown=0;pickup_pulse=0;last_pickup_count=0;last_pickup_total=0
	last_checkpoint=0;finished=false
	impact_count=0;pickup_count=0;checkpoint_count=0;completion_count=0;emitted=0;max_live=0
	for key in audio_counts:audio_counts[key]=0
	for player in players.values():player.stop()
	if is_instance_valid(game) and is_instance_valid(game.van):
		seen_collision=game.van.collision_serial;seen_reset=game.van.reset_count

func enabled() -> bool:
	return is_instance_valid(game) and not game.zen and game.driving and is_instance_valid(game.van) and game.van.active and not get_tree().paused

func master_volume() -> float:
	return clampf(float(game.master_volume),0,1) if is_instance_valid(game) else 0.0

func cue(sound:String,gain:float,pitch:=1.0) -> void:
	if not enabled() or master_volume()<=.001 or not players.has(sound):return
	var player:AudioStreamPlayer=players[sound]
	if not player.stream:return
	player.set_meta("feedback_gain",gain);player.volume_db=linear_to_db(maxf(.0001,gain*master_volume()))
	player.pitch_scale=pitch;player.play();audio_counts[sound]=int(audio_counts[sound])+1

func burst(at:Vector3,normal:Vector3,amount:int,strength:float,color:Color) -> void:
	if not enabled() or not at.is_finite():return
	var outward:Vector3=normal.normalized() if normal.length_squared()>.001 else Vector3.UP
	for i in mini(amount,24):
		# The golden angle is deterministic and distributes a small readable fan.
		var angle:float=float(emitted)*2.399963
		var radial:=Vector3(cos(angle),.45+float(i%3)*.16,sin(angle))
		var velocity:Vector3=(radial*.75+outward*.7)*strength
		var tint:Color=PURPLE if i%4==0 else (CREAM if i%4==1 else color)
		# World-sized inked pieces remain legible from the fixed elevated phone
		# view; their short lifetime and small fan keep the roadway readable.
		slots[cursor]={"born":clock,"at":to_local(at),"velocity":velocity,"size":.55+float(i%3)*.08,"life":.32+float(i%3)*.05}
		particles.set_instance_color(cursor,tint);cursor=(cursor+1)%CAPACITY;emitted+=1
	particles.custom_aabb=AABB(to_local(at)-Vector3(12,8,12),Vector3(24,20,24))
	max_live=maxi(max_live,live_count())

func impact(at:Vector3,normal:Vector3,severity:float) -> void:
	if not enabled() or severity<.18:return
	impact_count+=1
	burst(at,normal,6+roundi(clampf(severity,0,1)*8),1.3+severity*2.0,GOLD)
	# Existing game_audio.gd owns the truck's bump/scrape/crash sound and reaction.

func pickup(_at:Vector3,count:int,total:int) -> void:
	if not enabled() or count<=last_pickup_count:return
	last_pickup_count=count;last_pickup_total=total;pickup_count+=1;pickup_pulse=.22
	# Every credited box requests the supplied cue; max_polyphony bounds voices.
	cue("package_pickup",.55)

func delivery_zone() -> void:
	cue("route_clear",.58)

func checkpoint(at:Vector3,index:int,total:int) -> void:
	if not enabled() or index<=last_checkpoint:return
	last_checkpoint=index;checkpoint_count+=1
	burst(at+Vector3.UP*.45,Vector3.UP,14,2.0,PURPLE)
	delivery_zone()

func completed() -> void:
	if not enabled() or finished:return
	finished=true;completion_count+=1
	burst(game.van.global_position+Vector3.UP*2.2,Vector3.UP,20,2.5,GOLD)
	cue("delivery_complete",.65)

func live_count() -> int:
	var count:=0
	for slot in slots:
		if clock-float(slot.born)<float(slot.get("life",0.0)):count+=1
	return count

func stats() -> Dictionary:
	return {"capacity":CAPACITY,"live":live_count(),"peak_live":max_live,"max_life":MAX_LIFE,"impacts":impact_count,"pickups":pickup_count,"checkpoints":checkpoint_count,"completions":completion_count,"emitted":emitted,"audio":audio_counts.duplicate()}

func _physics_process(delta:float) -> void:
	clock+=delta;pickup_cooldown=maxf(0,pickup_cooldown-delta);pickup_pulse=maxf(0,pickup_pulse-delta)
	if not is_instance_valid(game) or not is_instance_valid(game.van):return
	if seen_reset!=game.van.reset_count:reset()
	if seen_collision!=game.van.collision_serial:
		seen_collision=game.van.collision_serial
		if enabled() and not game.van.driver_on_foot:
			# Use the actual physics contact. Citizen reactions never enter this path.
			for i in game.van.get_slide_collision_count():
				var contact:KinematicCollision3D=game.van.get_slide_collision(i)
				if absf(contact.get_normal().y)>.4:continue
				if contact.get_collider() is CharacterBody3D:continue
				impact(contact.get_position(),contact.get_normal(),game.van.collision_level);break
	for i in slots.size():
		var slot:Dictionary=slots[i];var age:float=clock-float(slot.born)
		var life:float=float(slot.get("life",0.0))
		if age<0 or age>=life:
			if slot.has("at"):hide_slot(i);slots[i]={"born":-1000.0}
			continue
		var at:Vector3=slot.at+slot.velocity*age+Vector3.DOWN*age*age*1.7
		var scale:float=float(slot.size)*(1.0-age/life)
		particles.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(scale,scale,scale)),at))

func _process(_delta:float) -> void:
	for player in players.values():
		if not enabled():player.stop();continue
		player.volume_db=linear_to_db(maxf(.0001,float(player.get_meta("feedback_gain",.5))*master_volume()))

func _exit_tree() -> void:
	for player in players.values():player.stop();player.stream=null
