extends Node3D

const RADIUS := 260.0
const SEGMENTS := 240
var art := preload("res://scripts/art_style.gd").new()
var boxes: Array[MeshInstance3D] = []
var training_mode := false
var shrub_grid:Dictionary={}

func tree_collision(at:Vector3,radius:=.30,height:=2.5) -> void:
	var body:=StaticBody3D.new();body.position=at+Vector3.UP*height*.5;body.add_to_group("street_tree")
	var shape:=CollisionShape3D.new();var trunk:=CylinderShape3D.new();trunk.radius=radius;trunk.height=height
	shape.shape=trunk;body.add_child(shape);add_child(body)

func register_shrub(at:Vector3,radius:float) -> void:
	var cell:=Vector2i(floori(at.x/8),floori(at.z/8))
	if not shrub_grid.has(cell):shrub_grid[cell]=[]
	shrub_grid[cell].append(Vector3(at.x,at.z,radius))

func vegetation_strength(at:Vector3) -> float:
	var cell:=Vector2i(floori(at.x/8),floori(at.z/8));var strength:=0.0
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			for shrub in shrub_grid.get(Vector2i(x,z),[]):
				strength=maxf(strength,clampf((shrub.z+1.0-Vector2(at.x,at.z).distance_to(Vector2(shrub.x,shrub.y)))/1.5,0,1))
	return strength

func material(color: Color) -> Material:
	return art.material(color)

func block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color)
	mesh.position = pos
	parent.add_child(mesh)
	boxes.append(mesh)
	if solid:
		var collider := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		collider.add_child(shape)
		mesh.add_child(collider)
	return mesh

func _ready() -> void:
	# Grass is now drivable at the road collision elevation. Its visible surface
	# sits slightly below asphalt to avoid coplanar flicker at road edges.
	var terrain := block(self,Vector3(325 if training_mode else 0,-0.34,0),Vector3(2850 if training_mode else 2200,0.6,2200),Color("7f9465"),true)
	var terrain_body := terrain.get_child(0) as StaticBody3D
	terrain_body.set_meta("surface_kind","grass")
	(terrain_body.get_child(0) as CollisionShape3D).position.y = 0.04
	var length := TAU * RADIUS / SEGMENTS
	for i in SEGMENTS:
		var angle := TAU * i / SEGMENTS
		var segment := Node3D.new()
		segment.position = Vector3(cos(angle)*RADIUS, 0, sin(angle)*RADIUS)
		segment.rotation.y = -angle
		add_child(segment)
		var deck := block(segment, Vector3(0,-0.3,0), Vector3(15.5,0.6,length+0.15), Color("51515c"), true)
		deck.material_override = art.material(Color("51515c"),false,true)
		for side in [-1,1]:
			# Optional live-city exit: retain the loop lanes, open only outer rail.
			if side==1 and i in [228,229,230]:
				continue
			block(segment, Vector3(side*7.7,0.55,0), Vector3(0.4,1.1,length+0.15), Color("d7c7a1"), true)
			block(segment,Vector3(side*7.7,1.12,0),Vector3(0.44,0.035,length+0.16),Color("282b38"))
			block(segment,Vector3(side*7.47,0.16,0),Vector3(0.045,0.055,length+0.12),Color("69645d"))
			block(segment, Vector3(side*6.5,0.015,0), Vector3(0.15,0.025,length+0.05), Color("f3bc37"))
			if i % 3 == 0:
				block(segment,Vector3(side*7.46,0.75,0),Vector3(0.03,0.11,0.28),Color("f9dd93"))
			if i % 2 == 0:
				block(segment,Vector3(side*7.465,0.6,length*0.44),Vector3(0.025,0.92,0.025),Color("887f70"))
		if i % 2 == 0:
			for lane in [-1.8,1.8]:
				block(segment, Vector3(lane,0.025,0), Vector3(0.13,0.025,3.0), Color("f8f0d8"))
		if i % 10 == 0 and i not in [228,229,230]:
			build_lamp(segment)
		if i % 60 == 18:
			build_gantry(segment)
		if i in [36,116,196]:
			build_overpass(segment)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7126
	if not training_mode:
		preload("res://scripts/city_art.gd").new().build(self,rng)
		preload("res://scripts/skyline_art.gd").new().build(self)
	build_greenery(rng)
	build_clouds(rng)
	consolidate_boxes()

func consolidate_boxes() -> void:
	# Retain independent collision but draw thousands of facade/road details in batches.
	var groups: Dictionary = {}
	for box in boxes:
		var mat := box.material_override
		if not groups.has(mat):
			groups[mat] = []
		var transform := box.global_transform
		transform.basis = transform.basis.scaled_local(box.mesh.size)
		groups[mat].append(transform)
		for child in box.get_children():
			if child is StaticBody3D:
				child.reparent(self,true)
		box.queue_free()
	boxes.clear()
	for mat in groups:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[mat])
		var instance := batch_mesh(mesh,transforms,Color.WHITE)
		instance.material_override = mat

func batch_boxes(transforms: Array[Transform3D], color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	batch_mesh(mesh,transforms,color)

func batch_mesh(mesh: Mesh, transforms: Array[Transform3D], color: Color, outlined := false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = art.material(color,outlined)
	add_child(instance)
	return instance

func build_greenery(rng: RandomNumberGenerator) -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var highlights: Array[Transform3D] = []
	var midtones: Array[Transform3D] = []
	var shrubs: Array[Transform3D] = []
	for i in 600:
		var angle := TAU*i/300.0
		var radius := 273.0 if i < 300 else 247.0
		var pos := Vector3(cos(angle)*radius,-0.8+rng.randf_range(-0.4,0.4),sin(angle)*radius)
		if pos.x>248 and pos.z>-90 and pos.z< -60:
			continue
		var scale := rng.randf_range(1.5,2.4)
		shrubs.append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(scale,scale*0.8,scale)),pos))
		register_shrub(pos,scale*.8)
	for i in 180:
		var angle := TAU*i/180.0
		var radius := 280.0+rng.randf_range(0,13)
		if i % 2 == 0:
			radius = 237.0-rng.randf_range(0,8)
		var pos := Vector3(cos(angle)*radius,-2,sin(angle)*radius)
		if pos.x>248 and pos.z>-170 and pos.z<70:
			continue
		trunks.append(Transform3D(Basis().scaled(Vector3(0.55,8,0.55)),pos))
		tree_collision(Vector3(pos.x,0,pos.z),.29,2.2)
		var scale := rng.randf_range(2.6,3.8)
		var center := pos+Vector3(0,5.7,0)
		crowns.append(Transform3D(Basis().scaled(Vector3(scale,scale*1.1,scale)),center))
		for lobe in 21:
			var theta := lobe*2.39996
			var y := 1.0-2.0*lobe/21.0
			var ring := sqrt(maxf(0,1-y*y))
			var offset := Vector3(cos(theta)*ring,y*1.15,sin(theta)*ring)*scale*0.85
			var leaf_size := rng.randf_range(0.85,1.5)
			var transform := Transform3D(Basis(Vector3.UP,theta).scaled(Vector3(leaf_size,leaf_size*0.8,leaf_size)),center+offset)
			if lobe % 3 == 0:
				highlights.append(transform)
			else:
				midtones.append(transform)
	batch_boxes(trunks,Color("554232"))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	batch_foliage(sphere,crowns,Color("35562c"),true,650)
	batch_foliage(sphere,midtones,Color("739539"),true,210)
	batch_foliage(sphere,highlights,Color("b1c453"),false,210)
	batch_foliage(sphere,shrubs,Color("78973c"),true,300)
	for color in [Color("35562c"),Color("739539"),Color("b1c453"),Color("78973c")]:
		art.material(color,color != Color("b1c453")).set_shader_parameter("leaf_sway",0.06)

func batch_foliage(mesh:Mesh,transforms:Array[Transform3D],color:Color,outlined:bool,distance:float) -> void:
	var chunks:Dictionary={}
	for transform in transforms:
		var cell:=Vector2i(floori(transform.origin.x/96),floori(transform.origin.z/96))
		if not chunks.has(cell):chunks[cell]=[]
		chunks[cell].append(transform)
	for cell in chunks:
		var origin:=Vector3(cell.x*96,0,cell.y*96)
		var typed:Array[Transform3D]=[]
		for transform in chunks[cell]:
			var local:Transform3D=transform;local.origin-=origin;typed.append(local)
		var instance:=batch_mesh(mesh,typed,color,outlined)
		instance.position=origin
		instance.visibility_range_end=distance
		instance.visibility_range_end_margin=30

func build_clouds(rng: RandomNumberGenerator) -> void:
	var clouds: Array[Transform3D] = []
	for i in 12:
		var angle := TAU*i/12.0
		var pos := Vector3(cos(angle)*800,rng.randf_range(140,200),sin(angle)*800)
		var tangent := Vector3(-sin(angle),0,cos(angle))
		for puff in 7:
			var t := (puff-3)*17.0
			var high := 8.0+sin(puff*1.7)*5.0
			clouds.append(Transform3D(Basis().scaled(Vector3(23,high,23)),pos+tangent*t+Vector3(0,high*0.4,0)))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var cloud_batch := batch_mesh(sphere,clouds,Color("fff8ea"))
	cloud_batch.material_override = art.material(Color("fff8ea")).duplicate()
	cloud_batch.material_override.set_shader_parameter("shade_strength",0.18)
	cloud_batch.material_override.set_shader_parameter("distant_haze",false)

func build_lamp(segment: Node3D) -> void:
	block(segment,Vector3(8.8,4.6,0),Vector3(0.16,9.2,0.16),Color("252c3b"),true)
	var arm := block(segment,Vector3(7.5,9.35,0),Vector3(2.7,0.12,0.13),Color("252c3b"))
	arm.rotation.z = -0.12
	block(segment,Vector3(6.25,9.45,0),Vector3(0.8,0.17,0.35),Color("252c3b"))
	block(segment,Vector3(6.25,9.35,0),Vector3(0.6,0.035,0.25),Color("ffe8a2"))

func build_gantry(segment: Node3D) -> void:
	var ink := Color("252c3b")
	for side in [-1,1]:
		block(segment,Vector3(side*8.5,3.5,0),Vector3(0.24,7.0,0.24),ink,true)
	for y in [6.7,7.4]:
		block(segment,Vector3(0,y,0),Vector3(17.3,0.16,0.16),ink)
	for x in range(-8,9,2):
		var brace := block(segment,Vector3(x,7.05,0),Vector3(2.05,0.10,0.10),ink)
		brace.rotation.z = 0.32 if x%4 == 0 else -0.32
	for side in [-1,1]:
		var x: float = side*3.35
		block(segment,Vector3(x,6.14,0.06),Vector3(5.6,2.05,0.19),ink)
		block(segment,Vector3(x,6.14,0.17),Vector3(5.43,1.90,0.04),Color("f5f0d3"))
		block(segment,Vector3(x,6.14,0.20),Vector3(5.28,1.76,0.04),Color("17634e"))
		var label := Label3D.new()
		label.text = "METRO LOOP\nFREE DRIVE  ↓" if side == -1 else "CITY CENTER\nKEEP LEFT  ↓"
		label.font_size = 52
		label.pixel_size = 0.008
		label.position = Vector3(x,6.17,0.24)
		label.outline_size = 1
		segment.add_child(label)

func build_overpass(segment: Node3D) -> void:
	# Decorative crossing, with >6 m clear headroom; supports stay outside rails.
	block(segment,Vector3(0,7.5,0),Vector3(42,0.75,8),Color("696f70"))
	for side in [-1,1]:
		block(segment,Vector3(side*13,0.7,0),Vector3(1.3,13,4.8),Color("b4b5aa"))
		block(segment,Vector3(0,8.3,side*4),Vector3(42,1.1,0.35),Color("d8d2bb"))
		block(segment,Vector3(0,7.05,side*2.7),Vector3(42,0.35,0.3),Color("33414f"))
