extends RefCounted
## Architectural ink, facade grids and stepped crowns; original procedural city.
const INK := Color("273346")
var world: Node3D

func box(pos: Vector3, size: Vector3, color: Color) -> void:
	world.block(world,pos,size,color)

func build(owner: Node3D, rng: RandomNumberGenerator) -> void:
	world = owner
	var palette := [Color("d2b58b"),Color("9eb9bd"),Color("d2c7ac"),Color("8fa9ba"),Color("bd977e"),Color("c2c6b5")]
	for i in 28:
		var angle := TAU*i/28.0+rng.randf_range(-0.025,0.025)
		var radius := rng.randf_range(345,550)
		var height := rng.randf_range(26,64)
		if cos(angle)*radius>255 and cos(angle)*radius<470 and sin(angle)*radius> -185 and sin(angle)*radius<85:
			continue
		building(Vector3(cos(angle)*radius,-6,sin(angle)*radius),rng.randf_range(15,27),rng.randf_range(15,25),height,palette[i%palette.size()],i%4)
	# A cluster inside the loop stays visible across the open park.
	for i in 15:
		var angle := TAU*i/15.0
		var radius := rng.randf_range(95,175)
		building(Vector3(cos(angle)*radius,-6,sin(angle)*radius),rng.randf_range(16,25),rng.randf_range(16,25),rng.randf_range(30,78),palette[i%palette.size()],i%4)
	var base := Vector3(80,-6,-95)
	building(base,30,28,88,Color("c6b38b"),2)
	building(base+Vector3(0,88,0),21,19,19,Color("c6b38b"),1)
	building(base+Vector3(0,107,0),12,11,17,Color("91acb6"),0)
	box(base+Vector3(0,135,0),Vector3(1.2,25,1.2),INK)

func building(base: Vector3, width: float, depth: float, height: float, color: Color, variant: int) -> void:
	world.block(world,base+Vector3(0,height/2,0),Vector3(width,height,depth),color,true)
	# Street-level podium and layered parapets avoid a plain extruded-box silhouette.
	world.block(world,base+Vector3(0,3.5,0),Vector3(width+3,7,depth+3),color.darkened(0.13),true)
	box(base+Vector3(0,7.2,0),Vector3(width+3.4,0.6,depth+3.4),INK)
	box(base+Vector3(0,height+0.8,0),Vector3(width*0.90,1.6,depth*0.90),color.lightened(0.13))
	# Corner ink beams and strong cornices define the architecture at a distance.
	for x in [-1,1]:
		for z in [-1,1]:
			box(base+Vector3(x*width/2,height/2,z*depth/2),Vector3(0.18,height,0.18),INK)
	for y in [0.5,height-0.5]:
		box(base+Vector3(0,y,0),Vector3(width+0.65,0.42,depth+0.65),INK)
		box(base+Vector3(0,y+0.5,0),Vector3(width+0.9,0.5,depth+0.9),color.lightened(0.10))
	var floors := int(height/4.8)
	var cols_x := maxi(2,int(width/4.2))
	var cols_z := maxi(2,int(depth/4.2))
	for floor_index in range(1,floors):
		var y := floor_index*4.8
		for side in [-1,1]:
			for col in cols_x:
				var x := (col-(cols_x-1)*0.5)*(width-3)/cols_x
				box(base+Vector3(x,y,side*(depth/2+0.16)),Vector3((width-3)/cols_x*0.53,2.6,0.13),INK)
				box(base+Vector3(x-0.22,y+0.35,side*(depth/2+0.24)),Vector3((width-3)/cols_x*0.28,1.65,0.08),Color("7197ac"))
			for col in cols_z:
				var z := (col-(cols_z-1)*0.5)*(depth-3)/cols_z
				box(base+Vector3(side*(width/2+0.16),y,z),Vector3(0.13,2.6,(depth-3)/cols_z*0.53),INK)
			if variant == 1 and floor_index % 3 == 0:
				box(base+Vector3(0,y-1.8,side*(depth/2+0.1)),Vector3(width,0.25,0.25),color.darkened(0.25))
	if variant == 2:
		box(base+Vector3(0,height+2,0),Vector3(width*0.72,4,depth*0.72),color.darkened(0.12))
		box(base+Vector3(0,height+4,0),Vector3(width*0.75,0.35,depth*0.75),INK)
		box(base+Vector3(0,height+8,0),Vector3(width*0.48,8,depth*0.48),color)
		box(base+Vector3(0,height+12,0),Vector3(width*0.50,0.4,depth*0.50),INK)
	if variant == 0:
		for side in [-1,1]:
			# Blue glass bays, restrained silver mullions and inset cap.
			box(base+Vector3(0,height*0.51,side*(depth/2+0.32)),Vector3(width*0.38,height*0.78,0.12),Color("548b9f"))
			for strip in 4:
				var x := (strip-1.5)*width*0.10
				box(base+Vector3(x,height*0.51,side*(depth/2+0.41)),Vector3(0.14,height*0.78,0.08),Color("b2c8c6"))
			for y in range(10,int(height-6),4):
				box(base+Vector3(0,y,side*(depth/2+0.42)),Vector3(width*0.38,0.12,0.10),INK)
	if variant == 3:
		box(base+Vector3(width*0.18,height+4,0),Vector3(0.5,8,0.5),INK)
