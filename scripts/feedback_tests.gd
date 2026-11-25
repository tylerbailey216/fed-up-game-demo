extends Node
## Opt-in presentation fixtures. Route-driving acceptance stays in arcade_tests.
## Fixtures below isolate actual contact/pickup/checkpoint/completion hooks.
var failures:Array[String]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func check(value:bool,message:String) -> void:
	if not value:failures.append(message);push_error("FEEDBACK TEST FAIL: "+message)

func frames(count:int) -> void:
	for i in count:await get_tree().physics_frame

func quiet(game:Node) -> void:
	game.touch_controls.release_inputs()
	game.traffic.set_physics_process(false);game.city_life.set_physics_process(false)
	for car in game.traffic.cars:
		car.set_physics_process(false);car.freeze=true;car.collision_layer=0;car.collision_mask=0
	for citizen in game.city_life.citizens:
		citizen.set_physics_process(false);citizen.collision_layer=0;citizen.collision_mask=0

func park(game:Node,at:Vector3) -> void:
	game.touch_controls.release_inputs();game.van.position=at+Vector3.UP*.15
	game.van.speed=0;game.van.velocity=Vector3.ZERO;game.van.planar_velocity=Vector3.ZERO
	game.van.parking_brake=true
	await frames(12)

func shot(game:Node,name:String,capture:bool) -> void:
	if not capture or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://tools/feedback-"+name+".png")

func run(game:Node,capture:=false) -> Array[String]:
	game.start_drive();quiet(game);await frames(20)
	var feedback:Node=game.gameplay_feedback
	var cargo:Node=game.cargo
	var saved_volume:float=game.master_volume
	var saved_dimensions:=Vector2i(game.get_viewport().get_visible_rect().size)
	var saved_preview:bool=game.dashboard.touch_preview
	game.master_volume=.7
	check(game.arcade and not game.zen and is_instance_valid(feedback),"Feedback fixture uses the compact arcade mode")
	await park(game,Vector3(110,0,110));feedback.reset()
	await check_bounds_and_audio(game)
	await check_actual_impact(game,capture)
	# Start another delivery through the existing replay reset. This isolates
	# cargo feedback from the physical-wall fixture without changing its rules.
	cargo.complete=true;cargo.next_stage();await frames(4)
	quiet(game);await park(game,Vector3(110,0,110));feedback.reset()
	await check_actual_recovery(game,capture)
	await check_actual_route_and_finish(game,capture)
	await check_report(game,capture)
	game.master_volume=saved_volume
	game.set_resolution(saved_dimensions);game.dashboard.touch_preview=saved_preview
	game.touch_controls.release_inputs();await frames(3)
	print("FEEDBACK TEST ","PASS" if failures.is_empty() else "FAIL: "+str(failures))
	return failures

func check_bounds_and_audio(game:Node) -> void:
	var feedback:Node=game.gameplay_feedback
	var energy:float=game.cargo.damage
	check(feedback.players.package_pickup.stream.resource_path=="res://assets/audio/loose_package.wav","Loose-package credit uses the user-supplied pickup recording")
	check(feedback.players.route_clear.stream.resource_path=="res://assets/audio/delivery_zone.mp3","Active delivery zones use the user-supplied zone recording")
	for i in 40:feedback.impact(game.van.position,Vector3.UP,1)
	check(feedback.live_count()<=feedback.CAPACITY and feedback.slots.size()==feedback.CAPACITY,"Repeated presentation bursts reuse a fixed particle pool")
	check(game.cargo.damage==energy and game.cargo.recovered==0,"Presentation APIs cannot award progress or apply truck damage")
	var before:Dictionary=feedback.stats();var clock:float=feedback.clock
	game.paused=true;get_tree().paused=true
	feedback.impact(game.van.position,Vector3.UP,1)
	feedback.pickup(game.van.position,1,game.cargo.quota)
	feedback.checkpoint(game.van.position,1,4);feedback.completed()
	await frames(8)
	check(feedback.clock==clock and feedback.stats()==before,"Pause freezes burst lifetimes and rejects new presentation/audio events")
	game.paused=false;get_tree().paused=false
	await frames(35)
	check(feedback.live_count()==0,"All brief comic impact pieces expire after leaving contact")
	feedback.reset();game.master_volume=0
	feedback.pickup(game.van.position,1,game.cargo.quota)
	feedback.checkpoint(game.van.position,1,4);feedback.completed();await frames(2)
	var silent:=true
	for key in feedback.audio_counts:
		if int(feedback.audio_counts[key])!=0:silent=false
	check(silent and feedback.pickup_count==1 and feedback.checkpoint_count==1 and feedback.completion_count==1,"Master mute suppresses all new cues while preserving visual confirmations")
	game.master_volume=.7;feedback.reset()
	feedback.pickup(game.van.position,1,game.cargo.quota)
	feedback.pickup(game.van.position,1,game.cargo.quota)
	feedback.checkpoint(game.van.position,1,4);feedback.checkpoint(game.van.position,1,4)
	feedback.completed();feedback.completed()
	check(feedback.pickup_count==1 and feedback.checkpoint_count==1 and feedback.completion_count==1,"Duplicate credited pickup, gate and completion calls stay single events")
	for key in ["package_pickup","route_clear","delivery_complete"]:
		check(int(feedback.audio_counts[key])==1,"An enabled unmuted event plays its authored "+str(key)+" cue exactly once")
		var player:AudioStreamPlayer=feedback.players[key]
		check(player.process_mode==Node.PROCESS_MODE_PAUSABLE and player.stream!=null,"Feedback sound respects pause and has an imported stream: "+str(key))
	feedback.reset()
	check(feedback.live_count()==0 and feedback.emitted==0 and feedback.pickup_pulse==0 and feedback.impact_count==0 and not feedback.finished,"Reset clears live effects, pulses, counters and completion latch")

func check_actual_impact(game:Node,capture:bool) -> void:
	var feedback:Node=game.gameplay_feedback
	var wall:=StaticBody3D.new();wall.position=Vector3(110,1.6,96);game.add_child(wall)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(14,3.2,.5);shape.shape=box;wall.add_child(shape)
	game.van.rotation.y=0;game.van.parking_brake=false
	var serial:int=game.van.collision_serial
	Input.action_press("accelerate")
	for i in 240:
		await frames(1)
		if feedback.impact_count>0:break
	game.touch_controls.release_inputs()
	check(game.van.collision_serial>serial and feedback.impact_count>0,"Real truck motion into a physical wall reaches the contact-feedback hook")
	check(feedback.pickup_count==0 and feedback.checkpoint_count==0 and feedback.completion_count==0,"A truck impact creates no delivery, route or pedestrian reward")
	check(feedback.live_count()>0 and feedback.live_count()<=feedback.CAPACITY,"Physical truck contact emits a restrained bounded burst")
	await shot(game,"impact",capture)
	wall.queue_free();await frames(4)

func check_actual_recovery(game:Node,capture:bool) -> void:
	var feedback:Node=game.gameplay_feedback;var cargo:Node=game.cargo
	cargo.damage=99;cargo.damage_hit(.18)
	# Park all loose boxes clear of the actor before bringing one into actual
	# contact range. No pickup API substitutes for walk-over contact credit.
	for item in cargo.packages:
		item.body.freeze=true;item.body.global_position=Vector3(145+int(item.id)*1.5,.3,145)
	await frames(20)
	check(cargo.spilled and cargo.on_foot and cargo.spawned==cargo.quota,"Depleted-energy recovery fixture uses the normal fixed-quota spill")
	cargo.actor.position=Vector3(124,.08,110);cargo.actor.velocity=Vector3.ZERO;cargo.pickup_previous=cargo.actor.position
	var first:Dictionary=cargo.packages[0]
	first.body.global_position=cargo.actor.position+Vector3.UP*.3;await frames(2)
	check(cargo.recovered==1 and feedback.pickup_count==1 and feedback.last_pickup_count==1,"Actual walk-over contact updates the package counter and feedback once")
	cargo.recover_package(first);feedback.pickup(first.body.global_position,cargo.recovered,cargo.quota)
	check(cargo.recovered==1 and feedback.pickup_count==1,"Repeated handling of the same package ID cannot duplicate credit or sound")
	await shot(game,"pickup",capture)
	for item in cargo.packages:
		if item.state!="loose":continue
		item.body.global_position=cargo.actor.position+Vector3.UP*.3;await frames(2)
	await frames(120)
	check(cargo.recovered==cargo.quota and cargo.load_restored and not game.van.wrecked,"All real pickup contacts retain repair and auto-return behavior")
	check(feedback.pickup_count==cargo.quota and feedback.last_pickup_count==cargo.quota and feedback.last_pickup_total==cargo.quota,"Every fixed manifest credit reaches the visible progress pulse exactly once")
	check(int(feedback.audio_counts.package_pickup)==cargo.recovered,"Every recovered package requests its cue; playback voices remain bounded")
	cargo.actor.position=game.van.position+game.van.global_basis.x*3.5;cargo.toggle_foot();await frames(2)
	check(not cargo.on_foot,"Presentation feedback preserves repaired truck re-entry")

func check_actual_route_and_finish(game:Node,capture:bool) -> void:
	var feedback:Node=game.gameplay_feedback;var cargo:Node=game.cargo;var route:Node=cargo.arcade_run
	# Gate-placement fixtures isolate hook wiring. The existing continuous-lap
	# test remains responsible for proving the route can actually be driven.
	for i in game.highway.route_points.size():
		await park(game,game.highway.route_points[i])
		check(route.route_index==i+1 and feedback.checkpoint_count==i+1,"Normal route update confirms ordered gate "+str(i+1)+" once")
		var previous:int=feedback.checkpoint_count;await frames(5)
		check(feedback.checkpoint_count==previous,"Remaining on a cleared marker never repeats its confirmation")
	await shot(game,"route",capture)
	var zone_cues:int=feedback.audio_counts.route_clear
	await park(game,cargo.checkpoint_position)
	check(int(feedback.audio_counts.route_clear)==zone_cues+1,"Driving into the active final bay plays its supplied zone cue")
	await frames(5)
	check(int(feedback.audio_counts.route_clear)==zone_cues+1,"Remaining inside the final bay does not repeat its sound")
	for i in 90:
		await frames(1)
		if cargo.complete:break
	check(cargo.complete and feedback.completion_count==1,"Stopped collection-bay update triggers one real completion confirmation")
	var report:Control=game.hud.get_node("DeliveryReport");report._process(0)
	check(report.visible and not report.replay.disabled and report.report_age<report.REVEAL_SECONDS,"Replay is available during the first report reveal")
	report.replay.pressed.emit();await frames(2)
	check(not cargo.complete and not report.visible and feedback.completion_count==0 and feedback.pickup_count==0,"Clicking replay immediately resets gameplay, report and feedback together")

func check_report(game:Node,capture:bool) -> void:
	var cargo:Node=game.cargo;var route:Node=cargo.arcade_run
	var report:Control=game.hud.get_node("DeliveryReport")
	# A controlled finished-result fixture verifies numeric display rather than
	# altering the gameplay timer, damage model or route-driving assertions.
	route.route_index=game.highway.route_points.size();route.refresh_marker()
	cargo.spilled=true;cargo.load_restored=true;cargo.recovered=4
	await park(game,cargo.checkpoint_position)
	route.elapsed=73.8;route.energy_used=42.3;cargo.checkpoint_hold=0
	cargo.update_checkpoint(1.21);report._process(0)
	check(report.animation_progress<1 and not report.replay.disabled,"Results count up without gating the replay button")
	await frames(3)
	var age:float=report.report_age
	game.paused=true;get_tree().paused=true;await frames(8)
	check(not report.visible and report.report_age==age,"Report reveal hides and freezes during pause")
	game.paused=false;get_tree().paused=false;report._process(0)
	check(report.report_age==age,"Resuming a report keeps its animation position")
	await frames(45)
	check(report.animation_progress==1 and report.report_age==report.REVEAL_SECONDS,"Report settles within its brief 0.62-second reveal")
	check(report.displayed_manifest==cargo.quota and report.displayed_seconds==73 and report.displayed_energy==42 and report.displayed_recovered==4,"Settled report statistics exactly match frozen round results")
	await check_report_layouts(game,capture)
	report.replay.pressed.emit();await frames(3)
	check(not cargo.complete and report.report_age==0 and not report.visible,"Replay after settled results clears the report for the next delivery")

func check_report_layouts(game:Node,capture:bool) -> void:
	for dimensions in [Vector2i(360,640),Vector2i(844,390),Vector2i(768,1024),Vector2i(1280,720)]:
		# A sized SubViewport validates all four production layouts even with the
		# headless display server, whose OS window size may remain unchanged.
		var viewport:=SubViewport.new();viewport.size=dimensions;viewport.disable_3d=true
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
		var panel:=preload("res://scripts/delivery_report.gd").new();panel.game=game
		panel.process_mode=Node.PROCESS_MODE_DISABLED;viewport.add_child(panel)
		panel._process(0);panel.report_age=panel.REVEAL_SECONDS;panel._process(0)
		var bounds:=Rect2(Vector2.ZERO,Vector2(dimensions))
		var plate:=Rect2(panel.position,panel.design*panel.scale)
		var button:Rect2=panel.replay.get_global_rect()
		check(bounds.grow(-12).encloses(plate) and plate.encloses(button),"Dispatch plate and replay stay inside "+str(dimensions))
		check(button.size.y>=40 and panel.replay.get_theme_font_size("font_size")*panel.scale.x>=17,"Replay keeps a usable touch target and readable text at "+str(dimensions))
		check(panel.compact==(dimensions==Vector2i(360,640)),"Phone result rows reflow without stretching at "+str(dimensions))
		viewport.queue_free()
		# Main's canvas scales through a 720-unit reference size. Check actual
		# screen pixels too, so an apparently large logical button cannot become
		# a tiny touch target on a high-density phone canvas.
		var aspect:float=float(dimensions.x)/dimensions.y
		var logical:=Vector2i(720,roundi(720/aspect)) if aspect<1.6 else Vector2i(roundi(720*aspect),720)
		var scaled_viewport:=SubViewport.new();scaled_viewport.size=logical;scaled_viewport.disable_3d=true
		scaled_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(scaled_viewport)
		var scaled_panel:=preload("res://scripts/delivery_report.gd").new();scaled_panel.game=game
		scaled_panel.process_mode=Node.PROCESS_MODE_DISABLED;scaled_viewport.add_child(scaled_panel)
		scaled_panel._process(0)
		var physical_scale:=float(dimensions.x)/logical.x
		check(scaled_panel.replay.get_global_rect().size.y*physical_scale>=40,"Scaled production canvas keeps a 40-pixel replay target at "+str(dimensions))
		check(scaled_panel.replay.get_theme_font_size("font_size")*scaled_panel.scale.x*physical_scale>=17,"Scaled production canvas keeps readable replay text at "+str(dimensions))
		scaled_viewport.queue_free()
		if capture and DisplayServer.get_name()!="headless":
			game.set_resolution(dimensions);game.dashboard.touch_preview=dimensions.x!=1280
			await frames(6);await shot(game,"report-%dx%d" % [dimensions.x,dimensions.y],true)
