extends Node3D
## Bounded, procedural tire spray. Reuses the vehicle's 20 Hz wheel probes.
const CAPACITY:=384
const DUST_CAPACITY:=96
const CHIP_LIFE:=.85
const DUST_LIFE:=1.0
const PROFILES:Dictionary={
	"grass":{"color":Color("759540"),"dust":Color("9b855e"),"density":2.8,"size":Vector2(.075,.24)},
	"dirt":{"color":Color("9b734b"),"dust":Color("b99a72"),"density":3.8,"size":Vector2(.13,.12)},
	"sand":{"color":Color("d9bc7c"),"dust":Color("e0c991"),"density":4.2,"size":Vector2(.07,.075)},
	"water":{"color":Color("81c9d1"),"dust":Color("bfe5e3"),"density":4.0,"size":Vector2(.065,.23)},
	"snow":{"color":Color("eef3e9"),"dust":Color("d7e6e8"),"density":3.5,"size":Vector2(.14,.13)}
}
var van:Node
var clock:=0.0
var emitted:=0
var chips_emitted:=0
var dust_emitted:=0
var last_wheels:Array[String]=["","","",""]
var chips:MultiMesh
var dust:MultiMesh
var chip_material:ShaderMaterial
var dust_material:ShaderMaterial
var chip_births:=PackedFloat32Array()
var dust_births:=PackedFloat32Array()
var chip_cursor:=0
var dust_cursor:=0
var previous:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var connected:Array[bool]=[false,false,false,false]
var carry:Array[float]=[0.0,0.0,0.0,0.0]
var seen_sample:=-1
var seen_reset:=-1
var seen_recovery:=-1
var rng:=RandomNumberGenerator.new()

func batch(capacity:int,shader:Shader) -> MultiMeshInstance3D:
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true;multi.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;multi.mesh=quad;multi.instance_count=capacity
	# Update the whole pool's bound around the truck; emitted debris travels < 8 m.
	multi.custom_aabb=AABB(Vector3(-64,-16,-64),Vector3(128,48,128))
	for i in capacity:multi.set_instance_custom_data(i,Color(-1000,0,0,0))
	var node:=MultiMeshInstance3D.new();node.multimesh=multi
	var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);return node

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE;rng.seed=44125
	var pieces:=batch(CAPACITY,preload("res://assets/shaders/terrain_chips.gdshader"))
	chips=pieces.multimesh;chip_material=pieces.material_override
	var puffs:=batch(DUST_CAPACITY,preload("res://assets/shaders/terrain_dust.gdshader"))
	dust=puffs.multimesh;dust_material=puffs.material_override
	chip_births.resize(CAPACITY);chip_births.fill(-1000)
	dust_births.resize(DUST_CAPACITY);dust_births.fill(-1000)

func clear() -> void:
	connected.fill(false);carry.fill(0);last_wheels.fill("")
	chip_births.fill(-1000);dust_births.fill(-1000)
	for i in CAPACITY:chips.set_instance_custom_data(i,Color(-1000,0,0,0))
	for i in DUST_CAPACITY:dust.set_instance_custom_data(i,Color(-1000,0,0,0))

func live_count() -> int:
	var count:=0
	for born in chip_births:
		if clock-born<CHIP_LIFE:count+=1
	for born in dust_births:
		if clock-born<DUST_LIFE:count+=1
	return count

func _physics_process(delta:float) -> void:
	if not van.active:return
	clock+=delta;chip_material.set_shader_parameter("spray_clock",clock);dust_material.set_shader_parameter("spray_clock",clock)
	if seen_reset!=van.reset_count or seen_recovery!=van.offroad_recoveries:
		clear();seen_reset=van.reset_count;seen_recovery=van.offroad_recoveries
		seen_sample=van.surface_sampler.sample_serial
		return
	if van.driver_on_foot or van.wrecked or van.overturned or van.stunts.active or not van.is_on_floor() or van.planar_velocity.length()<1.0:
		connected.fill(false);carry.fill(0);last_wheels.fill("");return
	if seen_sample==van.surface_sampler.sample_serial:return
	seen_sample=van.surface_sampler.sample_serial
	# Bounds only; instance positions stay in world space and never follow the van.
	var bound:=AABB(van.position-Vector3(64,16,64),Vector3(128,48,128))
	chips.custom_aabb=bound;dust.custom_aabb=bound
	var contacts:Array=van.surface_sampler.wheel_contacts
	for i in 4:
		var hit:Dictionary=contacts[i] if contacts.size()==4 else {}
		var kind:String=hit.get("kind","")
		if last_wheels[i]!=kind:connected[i]=false;carry[i]=0
		last_wheels[i]=kind
		if not PROFILES.has(kind):connected[i]=false;carry[i]=0;continue
		var point:Vector3=hit.position
		if connected[i]:
			var gap:=point.distance_to(previous[i])
			# Never bridge a teleport, level change, or a wheel losing contact.
			if gap<3.6:
				var profile:Dictionary=PROFILES[kind]
				carry[i]+=gap*profile.density
				var amount:=mini(5,int(carry[i]));carry[i]=minf(1,carry[i]-amount)
				for j in amount:
					var at:Vector3=previous[i].lerp(point,float(j+1)/amount)
					emit_piece(at,hit.normal,kind,profile)
				if amount>0 and (kind!="grass" or i%2==0):emit_puff(point,hit.normal,kind,profile)
			else:carry[i]=0
		previous[i]=point;connected[i]=true

func throw_velocity(normal:Vector3,scale:float) -> Vector3:
	var speed:float=van.planar_velocity.length()
	var direction:Vector3=van.planar_velocity.normalized()
	var across:Vector3=normal.cross(direction).normalized()
	return van.planar_velocity*.10-direction*(.7+speed*.075)*scale+across*rng.randf_range(-1.6,1.6)*scale+normal*rng.randf_range(.65,1.5+minf(speed,32)*.055)*scale

func emit_piece(at:Vector3,normal:Vector3,kind:String,profile:Dictionary) -> void:
	var color:Color=profile.color
	var size:Vector2=profile.size*rng.randf_range(.7,1.3)
	if kind=="grass" and rng.randf()<.30:color=Color("8d6b42");size=Vector2(.11,.10)
	color=color.darkened(rng.randf_range(0,.18));color.a=1
	var pose:=Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf_range(-PI,PI),rng.randf_range(-PI,PI)))*Basis.from_scale(Vector3(size.x,size.y,1))
	chips.set_instance_transform(chip_cursor,Transform3D(pose,at+normal*.045))
	chips.set_instance_color(chip_cursor,color)
	var v:=throw_velocity(normal,1.0)
	chips.set_instance_custom_data(chip_cursor,Color(clock,v.x,v.y,v.z))
	chip_births[chip_cursor]=clock;chip_cursor=(chip_cursor+1)%CAPACITY;chips_emitted+=1;emitted+=1

func emit_puff(at:Vector3,normal:Vector3,kind:String,profile:Dictionary) -> void:
	var size:float=rng.randf_range(.26,.48)*(1.0+minf(van.planar_velocity.length(),35)*.018)
	if kind=="water":size*=.65
	dust.set_instance_transform(dust_cursor,Transform3D(Basis.IDENTITY.scaled(Vector3(size,size,1)),at+normal*.12))
	dust.set_instance_color(dust_cursor,profile.dust)
	var v:=throw_velocity(normal,.32);v.y=maxf(.25,v.y)
	dust.set_instance_custom_data(dust_cursor,Color(clock,v.x,v.y,v.z))
	dust_births[dust_cursor]=clock;dust_cursor=(dust_cursor+1)%DUST_CAPACITY;dust_emitted+=1;emitted+=1
