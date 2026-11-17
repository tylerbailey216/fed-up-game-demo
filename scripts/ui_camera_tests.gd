extends Node
## Reproduce recovered-but-previously-flipped state and actual camera gestures.
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame
func capture(name:String,enabled:bool) -> void:
	if not enabled:return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ui-"+name+".png")
func touch(game:Node,key:String,index:int,pressed:bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.pressed=pressed
	event.position=game.touch_controls.regions[key].get_center()*game.touch_controls.size.x/720
	game.touch_controls._input(event)

func run(game:Node,captures:=false) -> Array[String]:
	var van:Node=game.van;var cargo:Node=game.cargo;var dashboard:Node=game.dashboard
	van.set_physics_process(false);cargo.set_physics_process(false)
	van.position=game.city_life.center-game.city_life.forward*18+Vector3.UP*.08
	van.rotation.y=atan2(-game.city_life.forward.x,-game.city_life.forward.z);van.set_view(false)
	for screen in [Vector2i(1280,720),Vector2i(720,1228),Vector2i(768,1024),Vector2i(844,390)]:
		game.get_window().size=screen;dashboard.touch_preview=screen.x==844;game.responsive_layout();await frames(5)
		# This is the exact lingering state in the supplied screenshot.
		van.flip_count=2;van.overturned=false;van.wrecked=false;cargo.complete=false;cargo.on_foot=false
		game.update_hud(0,"N",0);await frames(2)
		if dashboard.compact_layout():
			game.touch_controls.layout()
			var regions:Dictionary=game.touch_controls.regions
			var keys:=["gas","brake","stick","hand","gear","camera","map","options","exit"]
			var bounds:=Rect2(Vector2.ZERO,Vector2(720,dashboard.size.y*720/dashboard.size.x))
			for i in keys.size():
				check(bounds.encloses(regions[keys[i]]),"Touch control inside viewport: "+keys[i]+str(screen))
				for j in range(i+1,keys.size()):check(not regions[keys[i]].intersects(regions[keys[j]]),"No overlapping touch controls: "+keys[i]+" / "+keys[j]+str(screen))
			check(not dashboard.compact_map_rect().intersects(regions.camera),"GPS does not cover camera control")
			var scene:Rect2=preload("res://scripts/hud_layout.gd").scene_rect(bounds.size.y)
			if bounds.size.y>1100:check(scene.size.y/bounds.size.y>=.60,"Portrait clear driving corridor keeps at least sixty percent of screen height")
		van.set_view(true);game.update_hud(0,"N",0);await frames(2)
		await capture("illustrated-%dx%d" % [screen.x,screen.y],captures)
		van.set_view(false);game.update_hud(0,"N",0)
		check(not game.recovery_panel.visible and not game.recovery_back.visible,"A previously rolled, now-upright truck has no recovery overlay: "+str(screen))
		await capture("upright-%dx%d" % [screen.x,screen.y],captures)
		van.overturned=true;van.roll_settled=false;game.update_hud(0,"ROLLED",0);await frames(2)
		check(game.recovery_panel.visible and game.upright_button.disabled,"A current rollover shows only its settling prompt")
		var rect:Rect2=game.recovery_back.get_global_rect()
		check(rect.size.x*rect.size.y/(game.hud.size.x*game.hud.size.y)<.10,"Recovery footprint stays below ten percent of the viewport")
		check(Rect2(Vector2.ZERO,game.hud.size).encloses(rect),"Recovery strip fits completely inside viewport")
		if dashboard.compact_layout():
			game.touch_controls.layout()
			for key in ["gas","brake","stick","hand"]:
				var control:Rect2=game.touch_controls.regions[key]
				var scale:float=game.touch_controls.size.x/720
				check(not rect.intersects(Rect2(control.position*scale,control.size*scale)),"Recovery strip leaves "+key+" unobstructed")
		await capture("settling-%dx%d" % [screen.x,screen.y],captures)
		van.roll_settled=true;game.update_hud(0,"ROLLED",0);await frames(2)
		check(not game.upright_button.disabled,"Settled recovery remains available")
		await capture("recover-%dx%d" % [screen.x,screen.y],captures)
		van.overturned=false;game.update_hud(0,"N",0)
		cargo.popup_last_at=-10000;cargo.remaining_notice=12;cargo.show_popup("COLLECTION INCOMPLETE\n12 MORE PACKAGES TO COLLECT")
		game.update_hud(0,"N",0);await frames(2)
		check(dashboard.status_message().contains("12 PACKAGES LEFT"),"Incomplete delivery keeps the exact missing count in its compact status line")
		check(not game.recovery_back.visible,"Delivery toast adds no gameplay panel")
		await capture("message-%dx%d" % [screen.x,screen.y],captures)
		cargo.complete=true;cargo.popup_time=0;game.update_hud(0,"P",0);await frames(2)
		check(game.new_truck_button.visible,"Route completion retains a compact replay action")
		check(game.recovery_back.get_global_rect().size.y<=120*game.recovery_panel.scale.y,"Completion cannot inherit an oversized container height")
		await capture("complete-%dx%d" % [screen.x,screen.y],captures)
		cargo.complete=false
	# Entry instructions persist after notices expire and follow the real gate.
	cargo.on_foot=true;van.wrecked=false;van.notice_time=0;cargo.popup_time=0
	cargo.actor.position=van.position+Vector3(3.5,0,0)
	check(cargo.can_enter_truck() and cargo.entry_instruction().contains("PRESS X"),"Nearby available truck shows X entry instruction")
	check(cargo.entry_instruction(true).contains("TAP ENTER"),"Touch entry instruction names the visible ENTER button")
	dashboard.touch_preview=false
	check(dashboard.touch_input() or dashboard.status_message().contains("PRESS X"),"Narrow desktop windows retain keyboard instructions rather than implying a touch device")
	game.get_window().size=Vector2i(1280,720);dashboard.touch_preview=false;game.responsive_layout();game.update_hud(0,"N",0);await frames(3)
	await capture("truck-entry-ready",captures)
	cargo.actor.position=van.position+Vector3(20,0,0)
	check(not cargo.can_enter_truck() and cargo.entry_instruction().contains("20 m"),"Far truck shows distance without implying immediate entry")
	van.wrecked=true
	check(not cargo.can_enter_truck() and cargo.entry_instruction().contains("REPAIR"),"Disabled truck explains the recovery requirement")
	cargo.on_foot=false
	van.flip_count=0;van.overturned=false;van.roll_settled=false;van.wrecked=false
	dashboard.touch_preview=false;game.get_window().size=Vector2i(1280,720);game.responsive_layout()
	van.reset_vehicle();van.set_physics_process(true);cargo.set_physics_process(true);await frames(5)
	# Both previously frozen early-return paths must retire ordinary notices.
	van.driver_on_foot=true;van.notify_driver("ON FOOT TIMER CHECK");van.notice_time=.15;await frames(20)
	check(van.notice_time==0,"Driving notices expire while the driver is on foot")
	van.driver_on_foot=false;cargo.set_physics_process(false);van.wrecked=true
	van.notify_driver("DISABLED TIMER CHECK");van.notice_time=.15;await frames(20)
	check(van.notice_time==0,"Driving notices expire while the truck is disabled")
	van.wrecked=false;cargo.set_physics_process(true);van.engine_on=true
	cargo.show_popup("ONE DELIVERY MESSAGE");await frames(70);var remaining:float=cargo.popup_time
	cargo.show_popup("ONE DELIVERY MESSAGE")
	check(cargo.popup_time<=remaining+.01,"Repeating the same message cannot renew its countdown")
	await frames(95)
	check(cargo.popup_time==0,"Mission notification expires and yields to the normal objective")

	# Actual multitouch sequence: a world swipe must not steal an active pedal.
	game.get_window().size=Vector2i(720,1280);game.responsive_layout();await frames(4)
	game.touch_controls.enabled=true;game.touch_controls.layout();van.set_view(true);van.camera_high=false
	touch(game,"gas",31,true)
	var finger:=InputEventScreenTouch.new();finger.index=32;finger.pressed=true
	var scale:float=game.touch_controls.size.x/720
	finger.position=Vector2(400,600)*scale;game.touch_controls._input(finger)
	var drag:=InputEventScreenDrag.new();drag.index=32;drag.relative=Vector2(80,45)*scale;drag.position=finger.position+drag.relative
	game.touch_controls._input(drag);await frames(5)
	check(not van.cockpit and absf(van.camera_orbit)>.4 and van.camera_pitch>.1,"Driving world swipe exits cockpit and orbits/tilts the truck camera")
	finger.pressed=false;game.touch_controls._input(finger)
	check(Input.is_action_pressed("accelerate"),"Releasing the camera swipe preserves the gas finger")
	touch(game,"gas",31,false)
	var preset:bool=van.camera_high
	touch(game,"camera",33,true);game.touch_controls._process(.6);touch(game,"camera",33,false)
	check(van.camera_orbit==0 and van.camera_pitch==0 and van.camera_high==preset,"Holding CAMERA recenters without cycling the preset")
	touch(game,"camera",34,true);touch(game,"camera",34,false)
	check(van.camera_high!=preset,"A short CAMERA tap still cycles the driving view")
	# Swiping the GPS is not a world gesture.
	var before:float=van.camera_orbit
	finger.index=35;finger.pressed=true;finger.position=game.dashboard.compact_map_rect().get_center()*scale
	game.touch_controls._input(finger);drag.index=35;game.touch_controls._input(drag)
	check(van.camera_orbit==before,"Dragging the GPS does not orbit the camera")
	finger.pressed=false;game.touch_controls._input(finger);game.touch_controls.release_inputs()

	game.get_window().size=Vector2i(1280,720);game.responsive_layout();await frames(4);van.set_view(false)
	for mouse_button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var press:=InputEventMouseButton.new();press.button_index=mouse_button;press.pressed=true;press.position=Vector2(640,380)
		game._input(press)
		var mouse:=InputEventMouseMotion.new();mouse.position=Vector2(700,410);mouse.relative=Vector2(60,30)
		before=van.camera_orbit;game._input(mouse)
		check(not is_equal_approx(before,van.camera_orbit) and van.camera_pitch>0,"Desktop mouse drag orbits and tilts the driving camera")
		press.pressed=false;game._input(press)
	var gps:bool=dashboard.show_gps
	var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_G;game._unhandled_key_input(key)
	check(van.camera_orbit==0 and van.camera_pitch==0 and dashboard.show_gps==gps,"G recenters the truck without toggling GPS")
	van.orbit_camera(PI*.5,.3);await frames(45)
	check(van.camera.global_position.is_finite() and van.camera.global_position.y>van.position.y+2.5,"Orbit remains a finite elevated view of the truck")
	await capture("truck-orbit",captures)
	van.recenter_camera();van.reset_vehicle();van.speed=0;van.planar_velocity=Vector3.ZERO
	cargo.popup_time=0;van.notice_time=0;game.update_hud(0,"N",0)
	return failures

