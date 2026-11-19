extends Node
## Exercise player-facing camera behavior, including the actual input paths.
var failures:Array[String]=[]
const Layout=preload("res://scripts/hud_layout.gd")

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("FIXED CAMERA TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func same_basis(a:Basis,b:Basis) -> bool:
	return a.x.dot(b.x)>.999 and a.y.dot(b.y)>.999 and a.z.dot(b.z)>.999

func scene_rect(game:Node) -> Rect2:
	var size:Vector2=game.dashboard.size
	if game.dashboard.compact_layout():
		var factor:float=size.x/720
		var area:Rect2=Layout.scene_rect(size.y/factor)
		return Rect2(area.position*factor,area.size*factor)
	var scale:float=minf(size.x/1280,size.y/720)
	return Rect2((size-Vector2(1280,720)*scale)*.5+Vector2(0,145)*scale,Vector2(1280,380)*scale)

func visible_point(game:Node,camera:Camera3D,point:Vector3,label:String) -> void:
	check(not camera.is_position_behind(point) and scene_rect(game).grow(3).has_point(camera.unproject_position(point)),label)

func hidden_ancestor(node:Node,world:Node) -> bool:
	if node.has_meta("camera_cover"):
		var cover:Node3D=node.get_meta("camera_cover")
		if is_instance_valid(cover) and not cover.is_visible_in_tree():return true
	while node and node!=world:
		if node is Node3D and not node.is_visible_in_tree():return true
		node=node.get_parent()
	return false

func visible_line(game:Node,camera:Camera3D,target:Vector3,label:String) -> void:
	var excluded:Array[RID]=[game.van.get_rid(),game.cargo.actor.get_rid()]
	var space:PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	# Invisible cutaways retain their solid colliders. Look past those colliders
	# to verify that a second, still-visible facade is not hiding the player.
	for attempt in 16:
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,target,1);query.exclude=excluded
		var hit:Dictionary=space.intersect_ray(query)
		if hit.is_empty():return
		if not hidden_ancestor(hit.collider,game.highway):
			check(false,label+" / visible obstruction "+str(hit.collider.name));return
		excluded.append(hit.collider.get_rid())
	check(false,label+" / excessive overlapping facades")

func touch(game:Node,key:String,index:int,pressed:bool,offset:=Vector2.ZERO) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.pressed=pressed
	event.position=(game.touch_controls.regions[key].get_center()+offset)*game.touch_controls.size.x/720
	game.touch_controls._input(event)

func key_event(code:Key,pressed:bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)

func capture(name:String,enabled:bool) -> void:
	if not enabled or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/fixed-camera-"+name+".png")

func run(game:Node,captures:=false) -> Array[String]:
	var fixed:Node=game.fixed_camera;var van:Node=game.van;var cargo:Node=game.cargo;var actor:Node=cargo.actor
	check(game.arcade and is_instance_valid(fixed),"Compact arcade owns a fixed camera")
	if not is_instance_valid(fixed):return failures
	var saved:Dictionary={"size":game.get_window().size,"preview":game.dashboard.touch_preview,"preset":fixed.preset,"van_transform":van.transform,"van_physics":van.is_physics_processing(),"active":van.active,"speed":van.speed,"velocity":van.velocity,"planar":van.planar_velocity,"foot":cargo.on_foot,"cargo_physics":cargo.is_physics_processing(),"actor_transform":actor.transform,"actor_enabled":actor.enabled,"actor_physics":actor.is_physics_processing(),"actor_velocity":actor.velocity,"body_visible":van.body.visible,"overturned":van.overturned,"traffic_physics":game.traffic.is_physics_processing(),"life_physics":game.city_life.is_physics_processing()}
	for field in ["engine_on","parking_brake","cockpit","camera_high","camera_orbit","camera_pitch","camera_zoom","camera_manual"]:saved["van_"+field]=van.get(field)
	for field in ["camera_angle","camera_view","camera_zoom","camera_pitch","facing","look_ahead"]:saved["actor_"+field]=actor.get(field)
	var population:Array[Dictionary]=[]
	game.touch_controls.release_inputs();van.set_physics_process(false);cargo.set_physics_process(false)
	game.traffic.set_physics_process(false);game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		population.append({"node":car,"physics":car.is_physics_processing(),"layer":car.collision_layer,"freeze":car.freeze})
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0
	for person in game.city_life.citizens:
		population.append({"node":person,"physics":person.is_physics_processing(),"layer":person.collision_layer})
		person.set_physics_process(false);person.collision_layer=0
	cargo.on_foot=false;actor.set_enabled(false);van.driver_on_foot=false;van.active=true
	game.set_resolution(Vector2i(1280,720));game.dashboard.touch_preview=false;game.update_hud(0,"N",van.distance);await frames(4)
	van.position=Vector3(0,.15,25);van.speed=0;van.velocity=Vector3.ZERO;van.planar_velocity=Vector3.ZERO
	fixed.recenter();fixed.update_camera(0)
	var reference:Basis=van.camera.global_basis
	var bearing:Vector2=Vector2(van.camera.global_position.x-van.position.x,van.camera.global_position.z-van.position.z).normalized()
	for heading in [0.0,PI/2,PI,-PI/2]:
		van.rotation=Vector3(0,heading,0);fixed.update_camera(0)
		var current:=Vector2(van.camera.global_position.x-van.position.x,van.camera.global_position.z-van.position.z).normalized()
		check(current.dot(bearing)>.999 and same_basis(reference,van.camera.global_basis),"Truck heading cannot rotate the world camera: "+str(heading))
	van.overturned=true;van.rotation=Vector3(.4,.7,1.2);fixed.update_camera(0)
	check(same_basis(reference,van.camera.global_basis),"Truck rollover cannot roll or spin the camera")
	van.overturned=false;van.rotation=Vector3.ZERO
	var close:float=van.camera.global_position.distance_to(van.position)
	game.toggle_camera();fixed.update_camera(0)
	check(fixed.preset==1 and absf(van.camera.global_position.distance_to(van.position)-close)>2 and same_basis(reference,van.camera.global_basis),"VIEW selects a different distance with the same stable angle")
	game.toggle_camera();fixed.update_camera(0);check(fixed.preset==0,"Two useful views cycle back to the default")
	await check_inputs(game,reference)
	# Use normal exit so the test catches a truck-heading override of foot input.
	van.position=Vector3(0,.15,25);van.rotation=Vector3(0,-PI/2,0);cargo.toggle_foot();actor.set_physics_process(false);fixed.update_camera(0)
	check(cargo.on_foot and actor.camera.is_current(),"Leaving truck selects the fixed foot camera")
	check(is_equal_approx(actor.camera_angle,PI/4) and same_basis(reference,actor.camera.global_basis),"Foot camera and movement keep the same world bearing after exit")
	await check_walking(game)
	var cutaways_seen:=0
	for dimensions in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(844,390),Vector2i(768,1024)]:
		game.set_resolution(dimensions);game.dashboard.touch_preview=dimensions.x!=1280;game.update_hud(0,"ON FOOT",van.distance);await frames(4)
		for mode in 2:
			fixed.preset=mode
			cargo.on_foot=false;van.driver_on_foot=false;van.position=Vector3(0,.15,25);fixed.update_camera(0);game.update_hud(0,"N",van.distance)
			visible_point(game,van.camera,van.position+Vector3.UP*1.5,"Truck remains in clear gameplay area "+str(dimensions)+" / "+str(mode))
			for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:visible_point(game,van.camera,van.position+direction*5+Vector3.UP*.1,"Nearby driving ground is visible "+str(dimensions))
			await capture("truck-%dx%d-view%d" % [dimensions.x,dimensions.y,mode],captures)
			cargo.on_foot=true;van.driver_on_foot=true;actor.camera.make_current()
			game.update_hud(0,"ON FOOT",van.distance)
			for point in [Vector3(-36,.2,-40),Vector3(-12,.2,-14),Vector3(12,.2,-40),Vector3(36,.2,-14),Vector3(-36,.2,14),Vector3(-12,.2,40)]:
				actor.position=point;actor.velocity=Vector3.ZERO;fixed.update_camera(0)
				visible_point(game,actor.camera,point,"Worker feet stay clear of HUD at building corners "+str(dimensions))
				visible_point(game,actor.camera,point+Vector3.UP*1.9,"Worker head stays clear of HUD "+str(dimensions))
				for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:visible_point(game,actor.camera,point+direction*3+Vector3.UP*.3,"Nearby pickup ground stays on screen "+str(dimensions))
				visible_line(game,actor.camera,point+Vector3.UP,"Building facades cannot conceal worker at "+str(point))
				cutaways_seen+=int(game.highway.cutaway_count)
		game.update_hud(0,"ON FOOT",van.distance);await capture("foot-%dx%d" % [dimensions.x,dimensions.y],captures)
	check(cutaways_seen>0,"Facade cutaways activate near obstructing buildings")
	# The hidden decorative facade must keep its physical building footprint.
	var wall_ray:=PhysicsRayQueryParameters3D.create(Vector3(-40,2,-27),Vector3(-24,2,-27),1)
	check(not game.get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty(),"Camera cutaways preserve solid buildings")
	await check_truck_cutaway(game)
	actor.position=van.position+van.global_basis.x*3.5;cargo.toggle_foot();fixed.update_camera(0)
	check(not cargo.on_foot and van.camera.is_current() and same_basis(reference,van.camera.global_basis),"Re-entering truck preserves the stable world view")
	game.touch_controls.release_inputs();actor.set_enabled(false)
	cargo.on_foot=saved.foot;van.driver_on_foot=saved.foot;van.transform=saved.van_transform;van.speed=saved.speed;van.velocity=saved.velocity;van.planar_velocity=saved.planar;van.overturned=saved.overturned;van.active=saved.active
	actor.transform=saved.actor_transform;actor.velocity=saved.actor_velocity;actor.set_enabled(saved.actor_enabled);actor.set_physics_process(saved.actor_physics)
	for field in ["engine_on","parking_brake","cockpit","camera_high","camera_orbit","camera_pitch","camera_zoom","camera_manual"]:van.set(field,saved["van_"+field])
	for field in ["camera_angle","camera_view","camera_zoom","camera_pitch","facing","look_ahead"]:actor.set(field,saved["actor_"+field])
	van.set_physics_process(saved.van_physics);cargo.set_physics_process(saved.cargo_physics)
	game.traffic.set_physics_process(saved.traffic_physics);game.city_life.set_physics_process(saved.life_physics)
	for entry in population:
		entry.node.set_physics_process(entry.physics);entry.node.collision_layer=entry.layer
		if entry.has("freeze"):entry.node.freeze=entry.freeze
	game.set_resolution(saved.size);game.dashboard.touch_preview=saved.preview;fixed.preset=saved.preset;fixed.update_camera(0);van.body.visible=saved.body_visible;game.update_hud(0,"ON FOOT" if cargo.on_foot else "N",van.distance)
	print("FIXED CAMERA TEST PASS" if failures.is_empty() else "FIXED CAMERA TEST FAIL: "+str(failures))
	return failures

func check_inputs(game:Node,reference:Basis) -> void:
	var fixed:Node=game.fixed_camera;var van:Node=game.van
	var distance:float=van.camera.global_position.distance_to(van.position)
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var press:=InputEventMouseButton.new();press.button_index=button;press.pressed=true;press.position=Vector2(640,350);game._input(press)
		var motion:=InputEventMouseMotion.new();motion.position=Vector2(720,390);motion.relative=Vector2(160,100);game._input(motion)
		press.pressed=false;game._input(press)
	for button in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var wheel:=InputEventMouseButton.new();wheel.button_index=button;wheel.pressed=true;wheel.position=Vector2(640,350);game._input(wheel)
	fixed.update_camera(0)
	check(same_basis(reference,van.camera.global_basis) and fixed.preset==0 and is_equal_approx(distance,van.camera.global_position.distance_to(van.position)),"Mouse drags and wheel cannot disturb the arcade view")
	game.set_resolution(Vector2i(720,1280));game.dashboard.touch_preview=true;game.update_hud(0,"N",van.distance);await frames(4)
	game.touch_controls.enabled=true;game.touch_controls.layout()
	fixed.update_camera(0);var phone_basis:Basis=van.camera.global_basis
	touch(game,"gas",51,true);touch(game,"stick",52,true,Vector2(55,0))
	var scale:float=game.touch_controls.size.x/720
	var point:Vector2=Layout.scene_rect(game.touch_controls.size.y/scale).get_center()*scale
	var finger:=InputEventScreenTouch.new();finger.index=53;finger.pressed=true;finger.position=point;game.touch_controls._input(finger)
	var drag:=InputEventScreenDrag.new();drag.index=53;drag.relative=Vector2(170,110)*scale;drag.position=point+drag.relative;game.touch_controls._input(drag)
	finger.pressed=false;game.touch_controls._input(finger);fixed.update_camera(0)
	check(Input.is_action_pressed("accelerate") and Input.is_action_pressed("steer_right"),"Touching the scene does not steal gas or steering fingers")
	check(same_basis(phone_basis,van.camera.global_basis) and fixed.preset==0,"World swipes cannot orbit or tilt the fixed camera")
	touch(game,"gas",51,false);touch(game,"stick",52,false)
	touch(game,"camera",54,true);touch(game,"camera",54,false);check(fixed.preset==1,"Mobile VIEW selects the second stable distance")
	touch(game,"camera",55,true);game.touch_controls._process(.6);touch(game,"camera",55,false)
	check(fixed.preset==0,"Holding VIEW restores the default fixed view")
	game.touch_controls.release_inputs();game.set_resolution(Vector2i(1280,720));game.dashboard.touch_preview=false;game.update_hud(0,"N",van.distance);await frames(4)
	fixed.update_camera(0)

func check_walking(game:Node) -> void:
	var actor:Node=game.cargo.actor;var fixed:Node=game.fixed_camera
	for action in ["accelerate","brake_reverse","steer_left","steer_right"]:
		# The parked truck remains solid at z=25; use the opposite road segment.
		actor.position=Vector3(0,.2,-25);actor.velocity=Vector3.ZERO;actor.set_physics_process(true);await frames(6)
		var begin:Vector3=actor.position
		Input.action_press(action);await frames(32);Input.action_release(action);actor.set_physics_process(false);fixed.update_camera(0)
		var movement:Vector2=actor.camera.unproject_position(actor.position+Vector3.UP)-actor.camera.unproject_position(begin+Vector3.UP)
		var desired:Vector2={"accelerate":Vector2.UP,"brake_reverse":Vector2.DOWN,"steer_left":Vector2.LEFT,"steer_right":Vector2.RIGHT}[action]
		check(movement.length()>3 and movement.normalized().dot(desired)>.8,"Walking input follows screen direction: %s / pixels=%s travel=%s" % [action,movement,actor.position-begin])
		check(actor.animation_speed>.5,"Screen-relative walking uses moving animation frames: "+action)
	actor.position=Vector3(0,.2,-25);actor.velocity=Vector3.ZERO;actor.set_physics_process(true)
	var bearing:float=actor.camera_angle
	for code in [KEY_Q,KEY_E]:key_event(code,true);await frames(12);key_event(code,false)
	actor.set_physics_process(false);fixed.update_camera(0)
	check(is_equal_approx(actor.camera_angle,bearing),"Q/E cannot turn the fixed walking movement basis")
	actor.facing=-PI/2;actor.recenter_camera();fixed.update_camera(0)
	check(is_equal_approx(actor.camera_angle,PI/4) and fixed.preset==0,"Foot recenter keeps world bearing instead of turning toward the worker")

func check_truck_cutaway(game:Node) -> void:
	var van:Node=game.van;var actor:Node=game.cargo.actor;var fixed:Node=game.fixed_camera
	van.position=Vector3(0,.15,25);van.rotation=Vector3.ZERO;fixed.recenter()
	var occlusions:=0
	for offset in [Vector3(0,0,-2.9),Vector3(-1.5,0,-2.6),Vector3(-1.6,0,0)]:
		actor.position=van.position+offset;fixed.update_camera(0)
		var ray:=PhysicsRayQueryParameters3D.create(actor.camera.global_position,actor.position+Vector3.UP,1);ray.exclude=[actor.get_rid()]
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider==van:
			occlusions+=1;check(not van.body.visible,"A truck blocking the worker becomes a visual cutaway")
	check(occlusions>0,"Truck cutaway test reproduces actual truck occlusion")
	var ray:=PhysicsRayQueryParameters3D.create(van.position+Vector3(-4,1.5,0),van.position+Vector3(4,1.5,0),1);ray.exclude=[actor.get_rid()]
	var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider==van,"Transparent truck remains a solid object")
	actor.position=van.position+Vector3(9,0,0);fixed.update_camera(0)
	check(van.body.visible,"Truck artwork returns when it stops obscuring the worker")
