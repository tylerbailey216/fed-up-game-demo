extends Node
## Contact-driven integration checks. Fixtures never enter the shipping worlds.
var failures:Array[String]=[]
const ORIGIN:=Vector3(0,4,-600)

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func release_controls() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake"]:Input.action_release(action)

func shot(game:Node,name:String,captures:bool) -> void:
	if not captures:return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://docs/terrain-"+name+".png")

func tile(parent:Node3D,at:Vector3,size:Vector2,kind:String,color:Color) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=ORIGIN+at-Vector3.UP*.2
	body.set_meta("terrain_kind",kind);body.set_meta("surface_kind",kind);parent.add_child(body)
	var box:=BoxShape3D.new();box.size=Vector3(size.x,.4,size.y)
	var collision:=CollisionShape3D.new();collision.shape=box;body.add_child(collision)
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;visual.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1
	visual.material_override=material;body.add_child(visual)
	return body

func place(van:Node,at:Vector3) -> void:
	release_controls();van.new_truck();van.position=ORIGIN+at+Vector3.UP*.15;van.rotation=Vector3.ZERO
	van.set_view(false);await frames(18)

func kinds(effect:Node,kind:String) -> int:
	return effect.last_wheels.count(kind)

func run(game:Node,captures:=false) -> Array[String]:
	game.start_drive();release_controls();await frames(30)
	var van:Node=game.van;var effect:Node=game.terrain_particles
	var cargo_mode:int=game.cargo.process_mode;var traffic_mode:int=game.traffic.process_mode
	game.cargo.process_mode=Node.PROCESS_MODE_DISABLED;game.traffic.process_mode=Node.PROCESS_MODE_DISABLED
	var citizen_mode:int=game.city_life.process_mode if game.city_life else 0
	if game.city_life:game.city_life.process_mode=Node.PROCESS_MODE_DISABLED
	# The shipping spawn road must remain clean despite grass underneath its deck.
	van.new_truck();await frames(25);effect.clear();var before:int=effect.emitted
	van.speed=8;van.planar_velocity=-van.global_basis.z*8;await frames(36)
	check(kinds(effect,"asphalt")==4 and effect.emitted==before,"Shipping asphalt road emits no grass/dirt from the terrain below")
	var space:PhysicsDirectSpaceState3D=van.get_world_3d().direct_space_state
	var resolver:=preload("res://scripts/terrain_surface.gd")
	if not game.outerbelt:
		var start:=Vector3(250,0,-75);var forward:Vector3=(game.highway.entry-start).normalized()
		var side:=Vector3(-forward.z,0,forward.x);var center:Vector3=start.lerp(game.highway.entry,.16)
		for sample in [[0.0,"asphalt"],[8.3,"sidewalk"],[12.0,"grass"]]:
			var at:Vector3=center+side*sample[0]
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1);query.exclude=[van.get_rid()]
			var hit:=space.intersect_ray(query)
			check(resolver.kind(van,hit)==sample[1],"Shipping visual road / concrete sidewalk / grass resolve separately: "+sample[1])
		for at in game.highway.streets.island_centers:
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1);query.exclude=[van.get_rid()]
			check(resolver.kind(van,space.intersect_ray(query))=="grass","Raised green island tops emit grass, unlike their concrete bevels")
	else:
		var bridges:=0
		for at in game.highway.road_points:
			if at.y<5:continue
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.2,at-Vector3.UP*.2,1);query.exclude=[van.get_rid()]
			var hit:=space.intersect_ray(query)
			if hit.is_empty() or hit.normal.y<.9:continue
			check(resolver.kind(van,hit)=="asphalt","Elevated motorway deck never emits the grass beneath it")
			bridges+=1
			if bridges>=12:break
		check(bridges>=12,"Checked real elevated motorway contacts")
	var fixture:=Node3D.new();game.add_child(fixture)
	tile(fixture,Vector3(0,0,22.5),Vector2(32,25),"asphalt",Color("545661"))
	tile(fixture,Vector3(-8,0,0),Vector2(16,20),"asphalt",Color("545661"))
	tile(fixture,Vector3(8,0,0),Vector2(16,20),"grass",Color("79934f"))
	tile(fixture,Vector3(0,0,-25),Vector2(32,30),"grass",Color("79934f"))
	tile(fixture,Vector3(0,0,-65),Vector2(32,50),"asphalt",Color("545661"))
	var profile_tile:=tile(fixture,Vector3(40,0,0),Vector2(24,120),"grass",Color("79934f"))
	await frames(3);await place(van,Vector3(0,0,25));effect.clear()
	before=effect.emitted;van.speed=9;van.planar_velocity=Vector3(0,0,-9);Input.action_press("accelerate",.2)
	var split:=false;var grass:=false;var returned:=false;var grass_emitted:=before
	for i in 900:
		await frames(1)
		check(effect.live_count()<=effect.CAPACITY+effect.DUST_CAPACITY,"Terrain particle pool stays within its fixed capacity")
		if van.position.z>ORIGIN.z+12:
			check(effect.emitted==before,"Elevated asphalt fixture does not emit grass from the ground below")
		if kinds(effect,"grass")==2 and kinds(effect,"asphalt")==2:split=true
		if kinds(effect,"grass")==4:
			if not grass:
				for contact in van.surface_sampler.wheel_contacts:
					check(not contact.is_empty() and absf(contact.position.y-ORIGIN.y)<.03,"Each emitting tire is supported by the actual elevated surface")
			grass=true;grass_emitted=effect.emitted
			if i%60==0:await shot(game,"grass",captures)
		if grass and van.position.z<ORIGIN.z-46 and kinds(effect,"asphalt")==4:
			returned=true;break
	check(split and grass and returned,"Actual driving crosses asphalt, two grass tires, four grass tires, then asphalt")
	check(grass_emitted>before and effect.chips_emitted>0 and effect.dust_emitted>0,"Grass driving throws both cuttings/soil chips and a restrained dust puff")
	before=effect.emitted;await frames(20)
	check(effect.emitted==before,"New terrain spray stops immediately once all tires return to asphalt")
	release_controls();van.speed=0;van.planar_velocity=Vector3.ZERO;await frames(90)
	check(effect.live_count()==0,"World-space chips and dust expire completely after leaving the terrain")
	# The same resolver/emitter handles future material types using real colliders.
	var colors:Dictionary={"dirt":Color("9b734b"),"sand":Color("d9bc7c"),"water":Color("81c9d1"),"snow":Color("eef3e9")}
	var profile_material:=profile_tile.get_child(1).material_override as StandardMaterial3D
	for kind in colors:
		profile_tile.set_meta("terrain_kind",kind);profile_tile.set_meta("surface_kind",kind)
		profile_material.albedo_color=colors[kind]
		await place(van,Vector3(40,0,35));effect.clear();before=effect.emitted
		van.speed=22;van.planar_velocity=Vector3(0,0,-22);Input.action_press("accelerate",.1)
		for i in 120:
			await frames(1)
			check(effect.live_count()<=effect.CAPACITY+effect.DUST_CAPACITY,"Sustained "+kind+" spray cannot grow the pool")
		check(kinds(effect,kind)==4 and effect.emitted>before,"Actual "+kind+" contacts select the correct shared terrain profile")
		check(van.position.z<ORIGIN.z+15,"Terrain fixture test uses real vehicle movement")
		await shot(game,kind,captures)
	check(effect.emitted>effect.CAPACITY+effect.DUST_CAPACITY,"Long driving recycles the bounded pools across more emissions than available slots")
	profile_tile.set_meta("terrain_kind","grass");profile_tile.set_meta("surface_kind","grass")
	profile_material.albedo_color=Color("79934f")
	await place(van,Vector3(40,0,20));effect.clear();before=effect.emitted
	var marks_before:int=game.tire_marks.emitted
	van.speed=16;van.planar_velocity=Vector3(0,0,-16)
	Input.action_press("handbrake");Input.action_press("steer_left",.5);await frames(26);release_controls()
	check(game.tire_marks.emitted>marks_before and effect.emitted>before,"Grass drift preserves skid tracks while throwing terrain spray at the same time")
	await place(van,Vector3(40,0,-20));effect.clear();before=effect.emitted
	var start:Vector3=van.position;Input.action_press("brake_reverse");await frames(150);release_controls()
	check(van.speed< -1 and van.position.z>start.z+2 and effect.emitted>before,"Reverse driving kicks up terrain particles behind the actual direction of travel")
	van.speed=0;van.planar_velocity=Vector3.ZERO;van.velocity=Vector3.ZERO;await frames(12);before=effect.emitted
	await frames(90);check(effect.emitted==before and effect.live_count()==0,"Stationary tires neither create spray nor preserve expired particles")
	van.speed=8;van.planar_velocity=Vector3(0,0,-8);await frames(20)
	game.toggle_options();before=effect.emitted;var paused_clock:float=effect.clock;var live:int=effect.live_count()
	await frames(8)
	check(effect.emitted==before and effect.clock==paused_clock and effect.live_count()==live,"Pause freezes emission and the lifetime of existing terrain spray")
	game.toggle_options();await frames(4)
	# A physical upward departure, rather than fabricated wheel-contact records.
	van.velocity.y=5;await frames(16);before=effect.emitted
	check(not van.is_on_floor() and van.position.y>ORIGIN.y+.7,"Airborne test physically leaves the tire contact surface")
	await frames(15);check(effect.emitted==before,"Airborne tires cannot throw grass or dirt from a surface below them")
	await frames(75)
	van.speed=8;van.planar_velocity=Vector3(0,0,-8);await frames(12);before=effect.emitted
	van.reset_vehicle();await frames(12)
	check(effect.emitted==before and effect.live_count()==0,"Reset clears old spray and never bridges a teleport back to the road")
	release_controls();van.new_truck();effect.clear();fixture.queue_free()
	game.cargo.process_mode=cargo_mode;game.traffic.process_mode=traffic_mode
	if game.city_life:game.city_life.process_mode=citizen_mode
	await frames(5)
	print("TERRAIN emissions=",effect.emitted," chips=",effect.chips_emitted," dust=",effect.dust_emitted," pools=",effect.CAPACITY,"+",effect.DUST_CAPACITY)
	return failures
