extends Node
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func shot(game:Node,name:String,captures:bool) -> void:
	if not captures:return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://docs/stunt-"+name+".png")
func run(game:Node,captures:=false) -> Array[String]:
	game.start_drive();await frames(30)
	var van:Node=game.van;var origin:=Vector3(0,4,-600)
	var cargo_active:bool=game.cargo.is_physics_processing()
	game.cargo.set_physics_process(false)
	var fixture:=Node3D.new();game.add_child(fixture)
	var floor_body:=StaticBody3D.new();fixture.add_child(floor_body)
	var box:=BoxShape3D.new();box.size=Vector3(130,.4,400)
	var collision:=CollisionShape3D.new();collision.shape=box;floor_body.add_child(collision);floor_body.position=origin-Vector3.UP*.2
	var deck:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;deck.mesh=mesh;deck.material_override=game.highway.art.material(Color("545661"));floor_body.add_child(deck)
	var curb:=preload("res://scripts/street_surfaces.gd").new();curb.world=game.highway;fixture.add_child(curb)
	curb.raised(origin+Vector3(-45,0,0),origin+Vector3(45,0,0),12);curb.finish()
	await frames(5)
	for start_speed in [5.0,18.0,24.0,34.0]:
		van.new_truck();van.position=origin+Vector3(0,.15,12);van.rotation.y=0
		await frames(20)
		var serial:int=van.stunts.launch_serial
		van.speed=start_speed;van.planar_velocity=Vector3(0,0,-start_speed)
		Input.action_press("accelerate")
		var height:=0.0;var launch_frame:=-1;var tilt:=0.0
		for i in 360:
			await frames(1);height=maxf(height,van.position.y-origin.y)
			if van.stunts.launch_serial>serial and launch_frame<0:
				launch_frame=i;Input.action_release("accelerate")
				check(van.stunts.launch_energy<=van.stunts.launch_speed*van.stunts.launch_speed+.02,"Curb launch redirects speed rather than adding a rocket impulse")
				check(not van.overturned,"Takeoff itself is not a rollover")
				check(not van.recover_upright(),"Ordinary airtime cannot be reset with recovery")
			if is_instance_valid(van.roll_body):tilt=maxf(tilt,acos(clampf(van.roll_body.global_basis.y.y,-1,1)))
			if launch_frame>=0 and i-launch_frame==20:await shot(game,"air-%d" % start_speed,captures)
			if start_speed<22 and van.position.z<origin.z+2:break
			if launch_frame>=0 and not van.stunts.active:
				if van.overturned:await frames(300)
				break
		Input.action_release("accelerate")
		print("CURB speed=",start_speed," launch=",launch_frame," height=",height," airtime=",van.stunts.air_time," landing=",van.stunts.last_landing_speed," tilt=",rad_to_deg(tilt)," roll=",van.overturned," speed_after=",van.speed)
		if start_speed<22:
			check(launch_frame<0 and height<.4,"Low/moderate speed curb stays a grounded suspension bump")
		else:
			check(launch_frame>=0 and height>.45 and height<3.2 and van.stunts.air_time>.25,"High-speed physical curb creates bounded measurable airtime")
			check(van.stunts.launch_serial==serial+1,"One curb crossing cannot retrigger a series of launches")
			await shot(game,"land-%d" % start_speed,captures)
	# A fast, shallow glancing pass should not behave like a perpendicular ramp.
	van.new_truck();van.position=origin+Vector3(-25,.15,9)
	var grazing:=Vector3(.985,0,-.17).normalized();van.rotation.y=atan2(-grazing.x,-grazing.z)
	await frames(20)
	var grazing_serial:int=van.stunts.launch_serial
	van.speed=34;van.planar_velocity=grazing*34;await frames(55)
	check(van.stunts.launch_serial==grazing_serial,"High road speed with shallow curb crossing does not force a jump")
	# The shipping Cleveland sidewalk geometry must trigger the same path.
	if not game.outerbelt:
		van.new_truck()
		var start:=Vector3(250,0,-75);var direction:Vector3=(game.highway.entry-start).normalized()
		var side:=Vector3(-direction.z,0,direction.x);var at:Vector3=start.lerp(game.highway.entry,.16)+side*8.3
		van.position=at-side*6+Vector3.UP*.15;van.rotation.y=atan2(-side.x,-side.z);await frames(20)
		var serial:int=van.stunts.launch_serial;var marks:int=game.tire_marks.emitted
		van.speed=28;van.planar_velocity=side*28;Input.action_press("accelerate")
		for i in 40:
			await frames(1)
			if van.stunts.active:break
		Input.action_release("accelerate")
		check(van.stunts.launch_serial==serial+1 and van.stunts.active,"The actual downtown entrance curb launches at high crossing speed")
		if van.stunts.active:
			game.cargo.toggle_foot();check(not game.cargo.on_foot,"Player cannot exit into the air during a curb jump")
			game.toggle_options();var pose:Transform3D=van.roll_body.global_transform;var elapsed:float=van.stunts.elapsed
			await frames(8);check(van.roll_body.global_transform==pose and van.stunts.elapsed==elapsed,"Pause freezes curb flight and its timer")
			game.toggle_options();await frames(18)
			check(game.tire_marks.emitted==marks,"Airborne tires cannot draw floating skid marks")
			await shot(game,"city-curb-air",captures);await frames(75);await shot(game,"city-curb-land",captures)
	# Actual landings from controlled physical initial conditions, not outcome switches.
	for config in [[22.0,.55,0.0,0.0],[29.0,1.4,-.35,-.4],[29.0,1.4,-.4,-.5]]:
		van.new_truck();van.position=origin+Vector3(25,.15,55);van.rotation.y=0;await frames(10)
		van.speed=config[0];van.planar_velocity=Vector3(0,0,-config[0]);van.stunts.launch(.16,config[0],0)
		van.roll_body.global_transform=Transform3D(Basis(Vector3.RIGHT,config[2]),origin+Vector3(25,1.575+config[1],55))
		van.roll_body.linear_velocity=Vector3(0,-sqrt(19.62*config[1]),-config[0]);van.roll_body.previous_linear=van.roll_body.linear_velocity
		van.roll_body.angular_velocity=Vector3(config[3],0,0)
		var minimum:=1.0;var forward_angle:=0.0
		for i in 420:
			await frames(1)
			if is_instance_valid(van.roll_body):
				minimum=minf(minimum,van.roll_body.global_basis.y.y)
				forward_angle+=minf(0,van.roll_body.angular_velocity.x)/60
			if not van.stunts.active and not van.overturned:break
			if van.roll_settled:break
		print("LANDING config=",config," min_up=",minimum," forward_degrees=",rad_to_deg(forward_angle)," flipped=",van.flip_count," active=",van.stunts.active)
		check(van.position.is_finite(),"Landing/tumble remains finite")
		if config[2]==0:check(minimum>.98 and not van.overturned and van.engine_on and van.speed>5,"Flat landing returns to driving upright with momentum")
		elif config[2]>-.38:check(minimum<0 and rad_to_deg(forward_angle)<-120 and rad_to_deg(forward_angle)>-300,"Nose-first impact can physically tumble forward onto the roof")
		else:check(minimum<-.9 and rad_to_deg(forward_angle)<-300,"Steeper contact can produce a full forward flip")
		await shot(game,"outcome-%d" % config[0],captures)
	# A real hard landing drains life; the fixed cargo quota still spills only at zero.
	van.new_truck();van.position=origin+Vector3(-25,.15,55);van.rotation.y=0;await frames(20)
	if not game.outerbelt:game.highway.entered=true
	game.cargo.damage=99;game.cargo.seen_collision=van.crash_serial;game.cargo.set_physics_process(true)
	van.speed=26;van.planar_velocity=Vector3(0,0,-26);van.stunts.launch(.16,26,0)
	van.roll_body.global_transform=Transform3D(Basis.IDENTITY,origin+Vector3(-25,2.975,55))
	van.roll_body.linear_velocity=Vector3(0,-5.24,-26);van.roll_body.previous_linear=van.roll_body.linear_velocity
	for i in 180:
		await frames(1)
		if game.cargo.on_foot:break
	check(game.cargo.damage==100 and van.wrecked and game.cargo.spawned==game.cargo.quota,"Hard landing depletes remaining life and releases the fixed load exactly once")
	check(game.cargo.on_foot and not van.stunts.active,"Disabled truck completes its landing before safely placing driver on foot")
	var spawned:int=game.cargo.spawned;await frames(30)
	check(game.cargo.spawned==spawned,"Landing/bouncing does not create extra package drops")
	game.cargo.complete=true;game.cargo.next_stage()
	van.new_truck();fixture.queue_free();game.cargo.seen_collision=van.crash_serial;game.cargo.set_physics_process(cargo_active)
	await frames(5)
	return failures
