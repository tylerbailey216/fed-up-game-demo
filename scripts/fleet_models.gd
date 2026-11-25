extends RefCounted
## Original editable comic meshes. One static color batch plus live wheel pivots.
var parts:Array[MeshInstance3D]=[]
var root:Node3D
var art:RefCounted
var leg_count:=0
const PURPLE=Color("6a39a0")
const ORANGE=Color("f78c2f")
const CREAM=Color("f3ebd8")
const INK=Color("202330")
const GOLD=Color("ffd044")

func shape(mesh:Mesh,at:Vector3,tone:Color,scale:=Vector3.ONE) -> MeshInstance3D:
	var part:=MeshInstance3D.new();part.mesh=mesh;part.position=at;part.scale=scale
	part.material_override=art.material(tone);root.add_child(part);parts.append(part);return part

func box(at:Vector3,size:Vector3,tone:Color) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size;return shape(mesh,at,tone)

func ball(at:Vector3,size:Vector3,tone:Color) -> void:
	var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=12;mesh.rings=6
	shape(mesh,at,tone,size)

func rod(a:Vector3,b:Vector3,radius:float,tone:Color) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=10
	var part:=shape(mesh,(a+b)*.5,tone);part.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))

func leg(at:Vector3,phase:float) -> void:
	var hip:=Node3D.new();hip.name="ReindeerLeg_%d" % leg_count;leg_count+=1;hip.position=at;hip.set_meta("gait_phase",phase);root.add_child(hip)
	var knee:=Node3D.new();knee.name="Knee";knee.position.y=-.27;hip.add_child(knee)
	for pair in [[hip,.27,.065],[knee,.23,.055]]:
		var segment:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=pair[2];mesh.bottom_radius=pair[2]*.8;mesh.height=pair[1];mesh.radial_segments=8
		segment.mesh=mesh;segment.position.y=-pair[1]*.5;segment.material_override=art.material(Color("9b6b42"),true);pair[0].add_child(segment)
	var hoof:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=8;mesh.rings=4
	hoof.mesh=mesh;hoof.scale=Vector3(.16,.17,.22);hoof.position=Vector3(0,-.25,-.03);hoof.material_override=art.material(INK,true);knee.add_child(hoof)

func wheel(x:float,z:float,index:int,steering:=true) -> void:
	var pivot:=Node3D.new();pivot.name="WheelPivot_%s_%d_%d" % ["Front" if steering else "Rear",index,1 if x>0 else 0]
	pivot.position=Vector3(x,.46,z);root.add_child(pivot)
	pivot.set_meta("fleet_base",pivot.position)
	var mesh:=CylinderMesh.new();mesh.top_radius=.46;mesh.bottom_radius=.46;mesh.height=.25;mesh.radial_segments=16
	var tire:=MeshInstance3D.new();tire.mesh=mesh;tire.rotation.z=PI/2;tire.material_override=art.material(INK,true);pivot.add_child(tire)
	var hub:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=.24;disc.bottom_radius=.24;disc.height=.27;disc.radial_segments=12
	hub.mesh=disc;hub.rotation.z=PI/2;hub.material_override=art.material(CREAM);pivot.add_child(hub)

func brand(at:Vector3,yaw:float) -> void:
	for i in 2:
		var label:=Label3D.new();label.text="Fed" if i==0 else "Up"
		label.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf");label.font_size=100;label.pixel_size=.009
		label.modulate=PURPLE if i==0 else ORANGE;label.outline_modulate=CREAM;label.outline_size=3
		label.position=at+Basis(Vector3.UP,yaw)*Vector3(-.35 if i==0 else .4,0,0);label.rotation.y=yaw;root.add_child(label)

func build(owner:Node3D,id:String,style:RefCounted) -> void:
	root=owner;art=style
	if id=="semi":semi()
	elif id=="tank":tank()
	else:sleigh()
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var arrays:Array=part.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var tone:Color=part.material_override.get_shader_parameter("base_color")
		for i in indices:
			tool.set_color(tone);tool.set_normal((part.basis.inverse().transposed()*normals[i]).normalized());tool.add_vertex(part.transform*vertices[i])
		part.queue_free()
	var visual:=MeshInstance3D.new();visual.mesh=tool.commit()
	var material:ShaderMaterial=art.material(Color.WHITE,true).duplicate();material.set_shader_parameter("use_vertex_color",true)
	visual.material_override=material;root.add_child(visual)

func semi() -> void:
	box(Vector3(0,.63,.25),Vector3(2.3,.35,6.1),INK)
	box(Vector3(0,1.35,-1.95),Vector3(2.3,1.4,1.7),PURPLE)
	box(Vector3(0,2.25,-1.4),Vector3(2.15,1.3,1.5),PURPLE)
	box(Vector3(0,2.1,-2.165),Vector3(1.95,.85,.045),Color("477caa"))
	box(Vector3(0,1.14,-2.82),Vector3(1.25,.7,.06),CREAM)
	for i in 6:box(Vector3(-.52+i*.21,1.14,-2.86),Vector3(.065,.6,.035),INK)
	box(Vector3(0,.65,-2.88),Vector3(2.4,.22,.16),CREAM)
	# Open cargo shell behind the live rear doors, rather than a solid back face.
	box(Vector3(0,.76,1.55),Vector3(2.35,.12,3.5),INK)
	box(Vector3(0,3.30,1.55),Vector3(2.35,.12,3.5),CREAM)
	box(Vector3(0,2.03,-.16),Vector3(2.35,2.65,.08),CREAM)
	for side in [-1,1]:box(Vector3(side*1.135,2.03,1.55),Vector3(.08,2.65,3.5),CREAM)
	box(Vector3(0,.95,1.55),Vector3(2.4,.35,3.52),PURPLE)
	box(Vector3(0,1.18,1.55),Vector3(2.4,.13,3.52),ORANGE)
	for side in [-1,1]:
		rod(Vector3(side*1.08,1.0,-.5),Vector3(side*1.08,3.15,-.5),.09,CREAM)
		# Glazed cab doors, handles, steps, chrome heat shields and fuel tanks.
		box(Vector3(side*1.085,2.26,-1.42),Vector3(.035,.68,.92),Color("477caa"))
		box(Vector3(side*1.105,2.26,-1.42),Vector3(.04,.05,.94),CREAM)
		box(Vector3(side*1.165,1.62,-1.45),Vector3(.05,.06,.27),CREAM)
		box(Vector3(side*1.18,.8,-1.25),Vector3(.3,.12,.72),CREAM)
		box(Vector3(side*1.24,2.3,-2.12),Vector3(.19,.42,.15),INK)
		rod(Vector3(side*1.02,2.16,-1.95),Vector3(side*1.24,2.3,-2.12),.035,CREAM)
		for y in [1.5,1.65,1.8,1.95]:box(Vector3(side*1.08,y,-.6),Vector3(.12,.04,.06),INK)
		rod(Vector3(side*1.0,.62,-.1),Vector3(side*1.0,.62,.65),.22,CREAM)
		box(Vector3(side*.89,1.15,-2.86),Vector3(.3,.26,.06),GOLD)
		box(Vector3(side*1.19,2.03,3.22),Vector3(.045,2.6,.08),Color("a9a5a8"))
		box(Vector3(side*1.19,3.34,1.55),Vector3(.05,.07,3.48),PURPLE)
		brand(Vector3(side*1.19,2.1,1.4),side*PI/2)
		for z in [-1.95,.0,2.4]:wheel(side*1.17,z,parts.size(),z< -1)
	# Real door pivots are used by the existing cargo-door animation.
	for side in [-1,1]:
		var door:=Node3D.new();door.name="RearDoorPivot_"+("L" if side<0 else "R");door.position=Vector3(side*1.15,0,3.32);root.add_child(door)
		var panel:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(1.12,2.45,.06);panel.mesh=mesh;panel.position=Vector3(-side*.56,2.03,0);panel.material_override=art.material(CREAM,true);door.add_child(panel)
		box(Vector3(side*.92,.83,3.35),Vector3(.17,.3,.06),Color("d74343"))
	for x in [-.8,-.4,0,.4,.8]:ball(Vector3(x,2.96,-1.6),Vector3(.16,.11,.18),ORANGE)
	for z in [.2,.8,1.4,2,2.6]:box(Vector3(0,3.362,z),Vector3(2.27,.025,.04),Color("d0c8b8"))

func tank() -> void:
	for side in [-1,1]:
		box(Vector3(side*1.05,.65,0),Vector3(.6,.85,4.8),INK)
		for i in 6:wheel(side*1.08,-1.8+i*.72,i,false)
		for i in 15:box(Vector3(side*1.05,1.1,-2.2+i*.31),Vector3(.65,.08,.14),Color("777582"))
	box(Vector3(0,1.2,.1),Vector3(2.3,.85,4.1),PURPLE)
	box(Vector3(0,1.7,.1),Vector3(1.8,.35,3.1),CREAM)
	ball(Vector3(0,2.06,.1),Vector3(1.8,.9,1.65),PURPLE)
	rod(Vector3(0,2.16,-.5),Vector3(0,2.16,-2.65),.15,ORANGE)
	ball(Vector3(0,2.16,-2.65),Vector3(.35,.35,.15),GOLD)
	box(Vector3(0,2.55,.1),Vector3(.8,.13,.8),GOLD)
	ball(Vector3(0,2.76,.15),Vector3(.35,.3,.35),ORANGE)
	box(Vector3(0,1.31,-1.99),Vector3(1.5,.44,.08),CREAM)
	for i in 6:box(Vector3(-.5+i*.2,1.3,-2.04),Vector3(.06,.29,.03),INK)
	for side in [-1,1]:
		ball(Vector3(side*.92,1.39,-1.97),Vector3(.26,.26,.13),GOLD)
		rod(Vector3(side*.7,1.1,-2.08),Vector3(side*.7,.88,-2.08),.065,GOLD)
		for z in [-1.65,-.8,.05,.9,1.75]:box(Vector3(side*1.35,.94,z),Vector3(.04,.17,.57),PURPLE)
		for z in [-.6,.4]:box(Vector3(side*.5,1.9,z),Vector3(.05,.07,.15),GOLD)
	for side in [-1,1]:brand(Vector3(side*1.16,1.43,.55),side*PI/2)
	for x in [-.5,.5]:
		box(Vector3(x,2,1.35),Vector3(.7,.65,.7),Color("bd9362"));box(Vector3(x,2.33,1.35),Vector3(.12,.02,.71),GOLD)

func sleigh() -> void:
	box(Vector3(0,.9,1.05),Vector3(2.2,.4,2.8),PURPLE)
	for side in [-1,1]:
		box(Vector3(side*1.03,1.35,1.05),Vector3(.16,.9,2.9),PURPLE)
		box(Vector3(side*1.13,1.7,1.05),Vector3(.12,.12,2.95),CREAM)
		for z in [.0,1.9]:rod(Vector3(side*.8,.15,z),Vector3(side*.8,.7,z),.07,GOLD)
		var points:=[Vector3(side*.85,.15,2.65),Vector3(side*.85,.15,-.65),Vector3(side*.85,.27,-.95),Vector3(side*.85,.55,-1.05),Vector3(side*.85,.72,-.9)]
		for i in points.size()-1:rod(points[i],points[i+1],.09,GOLD)
		brand(Vector3(side*1.13,1.36,1.1),side*PI/2)
		for z in [.1,1.9]:wheel(side*1.05,z,parts.size(),z<1)
	ball(Vector3(0,1.65,1.9),Vector3(1.4,1.5,1.1),ORANGE)
	for i in 3:box(Vector3(-.45+i*.45,2.1,1.9),Vector3(.38,.5,.45),CREAM if i%2 else PURPLE)
	# Seated chibi Santa: original simple 3D anatomy, outfit and beard.
	ball(Vector3(0,1.65,.3),Vector3(.9,1.1,.7),PURPLE)
	box(Vector3(0,1.55,-.03),Vector3(.9,.15,.12),ORANGE)
	ball(Vector3(0,2.38,.21),Vector3(.85,.82,.72),Color("eeb075"))
	ball(Vector3(0,2.17,-.08),Vector3(.78,.65,.3),CREAM)
	for side in [-1,1]:
		ball(Vector3(side*.16,2.42,-.13),Vector3(.08,.12,.06),INK)
		rod(Vector3(side*.34,1.9,.22),Vector3(side*.48,1.6,-.18),.13,PURPLE)
		ball(Vector3(side*.48,1.6,-.18),Vector3(.25,.25,.25),CREAM)
	var hat:=CylinderMesh.new();hat.top_radius=.05;hat.bottom_radius=.46;hat.height=.6;hat.radial_segments=12
	shape(hat,Vector3(0,2.93,.23),PURPLE);ball(Vector3(0,3.25,.23),Vector3(.2,.2,.2),CREAM)
	for side in [-1,1]:
		var at:=Vector3(side*.62,0,-1.8)
		ball(at+Vector3(0,.91,0),Vector3(.55,.65,1.0),Color("9b6b42"))
		ball(at+Vector3(0,1.35,-.43),Vector3(.48,.63,.46),Color("b47b49"))
		ball(at+Vector3(0,1.2,-.7),Vector3(.43,.3,.34),Color("c99b66"))
		for x in [-.14,.14]:
			for z in [-.3,.3]:
				leg(at+Vector3(x,.75,z),0.0 if x*z>0 else PI)
			rod(at+Vector3(x,1.58,-.4),at+Vector3(x*1.5,2.05,-.25),.035,CREAM)
			rod(at+Vector3(x*1.3,1.85,-.3),at+Vector3(x*2.3,1.93,-.3),.025,CREAM)
			ball(at+Vector3(x*1.55,1.4,-.57),Vector3(.07,.1,.07),INK)
		rod(at+Vector3(-.3,1.0,-.1),at+Vector3(.3,1.0,-.1),.05,PURPLE)
		ball(at+Vector3(0,.85,-.15),Vector3(.15,.15,.15),GOLD)
		rod(Vector3(side*.48,1.6,-.18),at+Vector3(0,1.0,.1),.018,GOLD)
