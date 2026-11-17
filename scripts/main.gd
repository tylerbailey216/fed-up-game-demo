extends Node3D

const Highway = preload("res://scripts/highway.gd")
const Van = preload("res://scripts/van.gd")
const Cockpit = preload("res://scripts/cockpit.gd")
const DrivingTests = preload("res://scripts/driving_tests.gd")
var highway: Node3D
var van: CharacterBody3D
var menu: PanelContainer
var hud: Control
var menu_title: Label
var start_button: Button
var driving := false
var paused := false
var dashboard: Control
var menu_art: Control
var navigation: Node
var audio_manager: Node
var options: PanelContainer
var options_was_paused := false
var master_volume := 0.7
var nature_volume := 0.5
var vehicle_visuals: Node
var local_options := ConfigFile.new()
var shutting_down := false
var hud_shortcuts: HBoxContainer
var camera_shortcut: Button
var recovery_panel: Control
var recovery_back:Panel
var recovery_status: Label
var upright_button: Button
var new_truck_button: Button
var traffic: Node3D
var tire_marks: Node3D
var outerbelt := false
var map_button: Button
var switching_location := false
var cargo: Node3D
var touch_controls: Node
var legacy_test := false
var city_life:Node3D
var camera_drag_button:=0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(quit_demo)
	get_window().size_changed.connect(responsive_layout)
	responsive_layout()
	configure_input()
	var args := OS.get_cmdline_user_args()
	for flag in ["--driving-test","--crash-test","--traffic-test","--traffic-capture","--offroad-test","--offroad-capture","--handling-test","--handling-capture","--smoke-test"]:
		if flag in args: legacy_test = true
	outerbelt = bool(get_tree().get_meta("outerbelt")) if get_tree().has_meta("outerbelt") else ("--outerbelt" in args or "--outerbelt-test" in args or "--outerbelt-capture" in args)
	highway = preload("res://scripts/independence.gd").new() if outerbelt else (Highway.new() if legacy_test else preload("res://scripts/downtown.gd").new())
	add_child(highway)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://assets/shaders/sky.gdshader")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dce8f3")
	settings.ambient_light_energy = 0.3
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.light_energy = 0.8
	add_child(sun)
	van = Van.new()
	van.location_world = null if legacy_test else highway
	van.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(van)
	build_van()
	vehicle_visuals = preload("res://scripts/vehicle_visuals.gd").new()
	vehicle_visuals.van = van
	vehicle_visuals.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(vehicle_visuals)
	tire_marks = preload("res://scripts/tire_marks.gd").new()
	tire_marks.van = van
	add_child(tire_marks)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(3.1,6.0)
	shadow.mesh = shadow_mesh
	shadow.position.y = 0.025
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://assets/shaders/contact_shadow.gdshader")
	shadow.material_override = shadow_material
	van.add_child(shadow)
	van.contact_shadow=shadow
	van.reset_vehicle()
	traffic = preload("res://scripts/downtown_traffic.gd").new() if not outerbelt and not legacy_test else preload("res://scripts/traffic_district.gd").new()
	traffic.game = self
	traffic.highway = highway
	traffic.disabled_world = outerbelt
	add_child(traffic)
	if not outerbelt and not legacy_test:
		city_life=preload("res://scripts/city_life.gd").new();city_life.game=self;add_child(city_life)
	van.telemetry.connect(update_hud)
	navigation = preload("res://scripts/navigation.gd").new()
	navigation.location_world = null if legacy_test else highway
	add_child(navigation)
	local_options.load("user://driver_options.cfg")
	master_volume = clampf(float(local_options.get_value("audio","master",0.7)),0,1)
	nature_volume = clampf(float(local_options.get_value("audio","nature",0.5)),0,1)
	if not legacy_test and not "--outerbelt-test" in args:
		cargo = preload("res://scripts/cargo_gameplay.gd").new()
		cargo.game = self
		add_child(cargo)
	build_ui()
	responsive_layout()
	audio_manager = preload("res://scripts/game_audio.gd").new()
	audio_manager.van = van
	audio_manager.master_volume = master_volume
	audio_manager.nature_volume = nature_volume
	audio_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio_manager)
	if "--browser-controls-qa" in args and OS.has_feature("web"):
		var fixture:=preload("res://scripts/browser_controls_qa.gd").new();fixture.game=self;add_child(fixture)
	if "--presentation-check" in args:
		var review:=preload("res://scripts/presentation_checks.gd").new()
		add_child(review)
		await review.run(self)
		return
	if "--stunt-test" in args:
		var jump_tests:=preload("res://scripts/stunt_tests.gd").new();add_child(jump_tests)
		var failed:Array[String]=await jump_tests.run(self,"--stunt-capture" in args)
		print("STUNT TEST PASS" if failed.is_empty() else "STUNT TEST FAIL: "+str(failed))
		await quit_demo(0 if failed.is_empty() else 1);return
	if "--delivery-test" in args or "--delivery-capture" in args:
		var tests:=preload("res://scripts/delivery_tests.gd").new()
		add_child(tests)
		if outerbelt:await tests.run_motorway(self)
		else:await tests.run(self,"--delivery-capture" in args)
		return
	if bool(get_tree().get_meta("start_selected_location",false)):
		get_tree().remove_meta("start_selected_location")
		start_drive()
	if "--location-switch-test" in args:
		var stage := int(get_tree().get_meta("switch_test_stage",0))
		var expected := (stage%2==0) if "--outerbelt" in args else (stage%2==1)
		assert(outerbelt==expected,"Location switching overrides launch arguments")
		assert(map_button.text.contains("Public Square" if outerbelt else "Independence"),"Alternate map has a visible named Drive button")
		if stage>0:
			assert(driving and van.active and not menu.visible,"Selecting map button starts its drive")
		if stage<2:
			get_tree().set_meta("switch_test_stage",stage+1)
			map_button.pressed.emit()
			return
		print("LOCATION SWITCH PASS: actual menu button signals in both directions, automatic driving, launch argument override")
		await quit_demo()
		return
	if "--outerbelt-test" in OS.get_cmdline_user_args() or "--outerbelt-capture" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/independence_tests.gd").new()
		add_child(tests)
		await tests.run(self,"--outerbelt-capture" in OS.get_cmdline_user_args())
	if "--smoke-test" in OS.get_cmdline_user_args():
		await smoke_test()
	if "--driving-test" in OS.get_cmdline_user_args():
		var tests := DrivingTests.new()
		add_child(tests)
		await tests.run(self)
	if "--crash-test" in OS.get_cmdline_user_args():
		var tests := DrivingTests.new()
		add_child(tests)
		await tests.run_crash(self)
		await quit_demo(1 if tests.failed else 0)
	if "--traffic-test" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/traffic_tests.gd").new()
		add_child(tests)
		await tests.run(self)
	if "--offroad-test" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/offroad_tests.gd").new()
		add_child(tests)
		await tests.run(self)
	if "--handling-test" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/handling_tests.gd").new()
		add_child(tests)
		await tests.run(self)
	if "--handling-capture" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/handling_tests.gd").new()
		add_child(tests)
		await tests.capture(self)
	if "--offroad-capture" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/offroad_tests.gd").new()
		add_child(tests)
		await tests.capture(self)
	if "--traffic-capture" in OS.get_cmdline_user_args():
		var tests := preload("res://scripts/traffic_tests.gd").new()
		add_child(tests)
		await tests.capture(self)
	if "--capture" in OS.get_cmdline_user_args():
		start_drive()
		van.camera_manual = true
		van.set_view("--cockpit" in OS.get_cmdline_user_args())
		if "--cockpit" in OS.get_cmdline_user_args():
			van.set_view(true)
		await get_tree().create_timer(2.0).timeout
		var filename := "cockpit.png" if van.cockpit else "first-playable.png"
		get_viewport().get_texture().get_image().save_png("res://docs/"+filename)
		if "--visual-pass" in OS.get_cmdline_user_args():
			van.set_view(true)
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/cockpit.png")
			van.hazards = true
			van.headlights = true
			van.blink_time = 0.05
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/dashboard-functions.png")
			van.hazards = false
			van.headlights = false
			dashboard.expanded_map = true
			await get_tree().create_timer(0.2).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/gps-map.png")
			dashboard.expanded_map = false
			toggle_options()
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/dashboard-options.png")
			options.tabs.current_tab = 2
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/audio-options.png")
			options.tabs.current_tab = 1
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/vehicle-options.png")
			options.tabs.current_tab = 0
			toggle_options()
			van.set_view(false)
			van.camera.position = Vector3(6,3.7,7)
			van.camera.look_at(van.position+Vector3(0,1.6,0))
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/van-detail.png")
			van.camera.position = Vector3(6,3.4,-7)
			van.camera.look_at(van.position+Vector3(0,1.6,0))
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/van-front.png")
			van.set_view(true)
			var angle := TAU*196.0/240.0+0.09
			van.position = Vector3(cos(angle)*260,0.02,sin(angle)*260)
			van.rotation.y = -angle
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/overpass-cockpit.png")
			await record_render_sample()
			DisplayServer.window_set_size(Vector2i(1920,1080))
			await get_tree().create_timer(0.7).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/polished-1080.png")
			DisplayServer.window_set_size(Vector2i(1280,720))
			van.reset_vehicle()
			van.camera_manual = false
			van.set_view(false)
			van.speed = 20.0
			Input.action_press("accelerate")
			Input.action_press("steer_left",0.9)
			for frame in 45:
				await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/drift-turn.png")
			Input.action_release("accelerate")
			Input.action_release("steer_left")
			for crash in 3:
				van.reset_vehicle()
				await get_tree().create_timer(0.1).timeout
				van.rotation.y = -PI/4
				van.speed = 34.0
				await get_tree().create_timer(6.0).timeout
				if crash<2:
					van.recover_upright()
			get_viewport().get_texture().get_image().save_png("res://docs/rollover-totalled.png")
			van.recover_upright()
			await get_tree().create_timer(2.5).timeout
			get_viewport().get_texture().get_image().save_png("res://docs/hood-smoke.png")
			van.new_truck()
			van.set_view(false)
			van.camera_manual = true
			van.camera.position = Vector3(-5,2.2,5)
			van.camera.look_at(van.position+Vector3(0,1.5,0))
			van.speed = 4.0
			Input.action_press("accelerate")
			for frame in 12:
				await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/acceleration-exhaust.png")
			Input.action_release("accelerate")
			van.reset_vehicle()
			van.camera_manual = false
			van.set_view(false)
			van.position.x = 264.0
			van.rotation.y = -0.32
			van.speed = 30.0
			for frame in 32:
				await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://docs/barrier-climb.png")
			van.new_truck()
		return_to_menu()
		await get_tree().create_timer(0.2).timeout
		get_viewport().get_texture().get_image().save_png("res://docs/menu.png")
		await quit_demo()

func record_render_sample() -> void:
	var timings: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		timings.append((now-previous)/1000.0)
		previous = now
	var total := 0.0
	for timing in timings:
		total += timing
	timings.sort()
	var report := "Static cockpit render sample, 1280x720, Intel UHD 620, Compatibility, 2x MSAA, mirror updates every 4 frames.\n120 frame sample, average FPS %.1f, p95 frame time %.2f ms.\nDraw calls in final sampled frame: %d\nThis is a short stationary sample, not a driving or low-end hardware benchmark.\n" % [120000.0/total,timings[113],int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
	var file := FileAccess.open("res://docs/RENDER_SAMPLE.txt",FileAccess.WRITE)
	file.store_string(report)
	print(report)

func configure_input() -> void:
	var bindings := {
		"accelerate": [KEY_W,KEY_UP], "brake_reverse": [KEY_S,KEY_DOWN],
		"steer_left": [KEY_A,KEY_LEFT], "steer_right": [KEY_D,KEY_RIGHT],
		"handbrake": [KEY_SPACE], "sprint": [KEY_SHIFT]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func build_van() -> void:
	var body := Node3D.new()
	van.add_child(body)
	van.body = body
	# The road hull has rounded corners for handling. Pedestrians meet the full
	# illustrated box body, including its rear corners, also when rolled over.
	var pedestrian_hull:=StaticBody3D.new();pedestrian_hull.collision_layer=8;pedestrian_hull.collision_mask=0
	var pedestrian_shape:=CollisionShape3D.new();var pedestrian_box:=BoxShape3D.new()
	pedestrian_box.size=Vector3(2.5,3.15,5.5);pedestrian_shape.shape=pedestrian_box;pedestrian_shape.position.y=1.575
	pedestrian_hull.add_child(pedestrian_shape);body.add_child(pedestrian_hull)
	if ResourceLoader.exists("res://assets/models/fedup_van.glb"):
		var model: PackedScene = load("res://assets/models/fedup_van.glb")
		var visual := model.instantiate()
		body.add_child(visual)
		highway.art.apply_to_model(visual)
		for side in [-1,1]:
			add_brand(body,Vector3(side*1.18,2.12,0.63),side*PI/2,100,0.009)
		for pivot in visual.find_children("RearDoorPivot_*","Node3D",true,false):
			var rear:=Label3D.new();rear.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf");rear.font_size=84;rear.pixel_size=.009
			rear.text="Fed" if str(pivot.name).ends_with("L") else "Up"
			rear.modulate=Color("60318a") if rear.text=="Fed" else Color("f28c26")
			rear.position=Vector3(.55 if rear.text=="Fed" else -.55,2.27,.08)
			rear.outline_size=1;pivot.add_child(rear)
		return
	highway.block(body,Vector3(0,1.75,0.6),Vector3(2.3,2.7,3.4),Color("f2eee3"))
	highway.block(body,Vector3(0,1.45,-1.65),Vector3(2.3,2.1,1.7),Color("f2eee3"))
	highway.block(body,Vector3(0,2.15,-2.515),Vector3(1.95,0.9,0.03),Color("234c63"))
	highway.block(body,Vector3(0,0.65,-2.6),Vector3(2.45,0.22,0.22),Color("263342"))
	for x in [-0.85,0.85]:
		highway.block(body,Vector3(x,1,-2.53),Vector3(0.38,0.28,0.04),Color("ffdfa0"))
	for x in [-1.17,1.17]:
		for z in [-1.5,1.6]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.48
			cylinder.bottom_radius = 0.48
			cylinder.height = 0.25
			wheel.mesh = cylinder
			wheel.material_override = highway.material(Color("202631"))
			wheel.rotation.z = PI/2
			wheel.position = Vector3(x,0.5,z)
			body.add_child(wheel)
	for side in [-1,1]:
		var brand := Label3D.new()
		brand.text = "FedUp"
		brand.font_size = 100
		brand.modulate = Color("60318a")
		brand.pixel_size = 0.012
		brand.position = Vector3(side*1.16,2,0.5)
		brand.rotation.y = side * PI/2
		body.add_child(brand)
	highway.block(body,Vector3(0,0.5,2.34),Vector3(2.2,0.2,0.05),Color("ec8334"))
	var rear_brand := Label3D.new()
	rear_brand.text = "FedUp"
	rear_brand.font_size = 50
	rear_brand.pixel_size = 0.009
	rear_brand.modulate = Color("60318a")
	rear_brand.position = Vector3(0,2,2.31)
	body.add_child(rear_brand)

func add_brand(parent: Node3D, pos: Vector3, yaw: float, font_size: int, pixel_size: float) -> void:
	var face := SystemFont.new()
	face.font_names = PackedStringArray(["Arial","Liberation Sans"])
	face.font_weight = 900
	face.font_italic = true
	var fed_width := face.get_string_size("Fed",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*pixel_size
	var up_width := face.get_string_size("Up",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*pixel_size
	var label := Label3D.new()
	label.font = face
	label.text = "Fed"
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color("542589")
	label.position = pos+Basis(Vector3.UP,yaw)*Vector3(-up_width/2,0,0)
	label.rotation.y = yaw
	label.outline_size = 2
	parent.add_child(label)
	var up := Label3D.new()
	up.font = face
	up.text = "Up"
	up.font_size = font_size
	up.pixel_size = pixel_size
	up.modulate = Color("ef7c24")
	up.position = pos+Basis(Vector3.UP,yaw)*Vector3(fed_width/2,0,0)
	up.rotation.y = yaw
	up.outline_size = 2
	parent.add_child(up)

func text_label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	return label

func button(value: String, action: Callable, parent: Node) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size = Vector2(360,36)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	dashboard = Cockpit.new()
	dashboard.vehicle = van
	dashboard.navigation = navigation
	dashboard.traffic = traffic
	dashboard.cargo = cargo
	for field in ["show_gps","show_mirror","show_controls"]:
		dashboard.set(field,bool(local_options.get_value("hud",field,dashboard.get(field))))
	hud.add_child(dashboard)
	dashboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.move_child(dashboard,0)
	menu_art = preload("res://scripts/menu_art.gd").new()
	menu_art.outerbelt = outerbelt
	layer.add_child(menu_art)
	menu_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = 180
	menu.offset_right = 600
	menu.offset_top = -330
	menu.offset_bottom = 330
	layer.add_child(menu)
	apply_menu_theme()
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,28)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	scroll.add_child(margin)
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	margin.add_child(choices)
	menu_title = text_label("LET'S DELIVER.",40)
	menu_title.add_theme_font_override("font",preload("res://assets/fonts/Bangers-Regular.ttf"))
	choices.add_child(menu_title)
	choices.add_child(text_label("INDEPENDENCE / I-480 + I-77\nOHIO MOTORWAY" if outerbelt else "PUBLIC SQUARE + TOWER CITY\nCLEVELAND, OHIO",24))
	start_button = button("Drive Independence, Ohio / I-480" if outerbelt else "Train / Public Square, Cleveland",start_drive,choices)
	var primary:=StyleBoxFlat.new();primary.bg_color=Color("ffcb47");primary.border_color=Color("130d1b");primary.set_border_width_all(3);primary.set_corner_radius_all(3);primary.shadow_color=Color("130d1b");primary.shadow_size=3
	for state in ["normal","hover","pressed","focus"]:start_button.add_theme_stylebox_override(state,primary)
	start_button.add_theme_color_override("font_color",Color("23152f"));start_button.add_theme_color_override("font_hover_color",Color("23152f"));start_button.add_theme_color_override("font_focus_color",Color("23152f"))
	map_button = button("Drive Public Square, Cleveland" if outerbelt else "Drive Independence, Ohio / I-480",func(): switch_location(true),choices)
	button("Dashboard / Audio [Tab]",toggle_options,choices)
	button("Fullscreen / windowed",toggle_fullscreen,choices)
	if not legacy_test:
		var credit := LinkButton.new()
		credit.text = "Map data: © OpenStreetMap contributors / ODbL"
		credit.uri = "https://www.openstreetmap.org/copyright"
		choices.add_child(credit)
	choices.add_child(text_label("Drive the city. Recover every package.\nWatch your truck energy / Save the delivery.",20))
	choices.add_child(text_label("WASD drive / X exit or re-enter truck / C camera\nTouch: landscape recommended / portrait supported",18))
	if FileAccess.file_exists("res://data/build_version.json"):
		var version:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/build_version.json"))
		choices.add_child(text_label("BUILD "+str(version.state_id),14))
	hud.hide()
	start_button.grab_focus()
	if DisplayServer.get_name() != "headless":
		var mirror := preload("res://scripts/rear_mirror.gd").new()
		mirror.van = van
		mirror.dashboard = dashboard
		add_child(mirror)
	set_menu_camera()
	options = preload("res://scripts/dashboard_options.gd").new()
	options.game = self
	layer.add_child(options)
	var shortcuts := HBoxContainer.new()
	hud_shortcuts = shortcuts
	shortcuts.theme = menu.theme
	shortcuts.position = Vector2(550,18)
	hud.add_child(shortcuts)
	for entry in [["M  GPS",func(): dashboard_key(KEY_M)],["N  Destination",func(): navigation.next_target()],["Tab  Dashboard",toggle_options]]:
		if not legacy_test and entry[0]=="N  Destination": entry[0]="N  Road info"
		var shortcut := Button.new()
		shortcut.text = entry[0]
		shortcut.custom_minimum_size = Vector2(130,34)
		shortcut.pressed.connect(entry[1])
		shortcut.focus_mode = Control.FOCUS_NONE
		shortcuts.add_child(shortcut)
	camera_shortcut = Button.new()
	camera_shortcut.position = Vector2(1100,20)
	camera_shortcut.size = Vector2(153,34)
	camera_shortcut.tooltip_text = "Cycle cockpit / chase / raised view [C]. Right-drag to orbit; wheel to zoom."
	camera_shortcut.focus_mode = Control.FOCUS_NONE
	for state in ["normal","pressed","focus","hover"]:
		camera_shortcut.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	camera_shortcut.pressed.connect(toggle_camera)
	hud.add_child(camera_shortcut)
	recovery_back=preload("res://scripts/prompt_frame.gd").new();recovery_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var recovery_style:=StyleBoxFlat.new();recovery_style.bg_color=Color("202332");recovery_style.border_color=Color("ffd044")
	recovery_style.set_border_width_all(3);recovery_style.set_corner_radius_all(14)
	recovery_back.add_theme_stylebox_override("panel",recovery_style);hud.add_child(recovery_back);recovery_back.hide()
	recovery_panel = Control.new()
	recovery_panel.theme = menu.theme
	recovery_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(recovery_panel)
	recovery_status = text_label("",21)
	recovery_status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	recovery_status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	recovery_panel.add_child(recovery_status)
	upright_button = button("RIGHT TRUCK / RECOVER [U]",func(): van.recover_upright(),recovery_panel)
	new_truck_button = button("START WITH A NEW TRUCK",func():
		if cargo and not cargo.complete: return
		if cargo:
			cargo.next_stage()
			return
		van.new_truck(),recovery_panel)
	recovery_panel.hide()
	for action in [upright_button,new_truck_button]:
		action.custom_minimum_size=Vector2.ZERO;action.focus_mode=Control.FOCUS_NONE
		action.add_theme_font_override("font",preload("res://assets/fonts/BarlowCondensed-Bold.ttf"))
	touch_controls=preload("res://scripts/touch_controls.gd").new()
	touch_controls.game=self
	hud.add_child(touch_controls)
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().disable_3d=true

func responsive_layout() -> void:
	var actual:=get_window().size
	if actual.x<1 or actual.y<1:return
	var aspect:=float(actual.x)/actual.y
	# Bound 3D pixel cost on large/retina windows; 2D artwork and HUD stay native.
	get_viewport().scaling_3d_scale=clampf(sqrt(1280.0*800.0/(float(actual.x)*actual.y)),.65,1.0)
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_size=Vector2i(720,roundi(720/aspect)) if aspect<1.6 else Vector2i(roundi(720*aspect),720)
	if not menu:return
	var logical:=Vector2(get_window().content_scale_size)
	var compact:=aspect<1.6
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var hero_width:=minf(656,logical.y*.3*1.5)
	var menu_y:=141+hero_width/1.5+28
	menu.position=Vector2(24,menu_y) if compact else Vector2(logical.x/2+140,30)
	menu.size=Vector2(logical.x-48,logical.y-menu_y-24) if compact else Vector2(460,660)
	resize_menu_buttons(menu,compact)
	if options:
		options.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		options.position=Vector2((logical.x-650)/2,maxf(20,(logical.y-620)/2))
		options.size=Vector2(650,minf(620,logical.y-40))

func resize_menu_buttons(node:Node,compact:bool) -> void:
	if node is Button:
		node.custom_minimum_size.y=80 if compact else 64
		node.add_theme_font_size_override("font_size",27 if compact else 25)
		if OS.has_feature("web") and (node.text.begins_with("Window size") or node.text=="Quit"):node.hide()
	for child in node.get_children():resize_menu_buttons(child,compact)

func toggle_camera() -> void:
	if cargo and cargo.on_foot:
		cargo.actor.cycle_camera()
		return
	van.cycle_camera()

func toggle_options() -> void:
	camera_drag_button=0
	if options.visible:
		options.hide()
		get_tree().paused = options_was_paused
		save_options()
	else:
		options_was_paused = get_tree().paused
		get_tree().paused = true
		options.sync_checks()
		options.show()

func quit_demo(code := 0) -> void:
	if shutting_down:
		return
	shutting_down = true
	get_tree().paused = false
	van.active = false
	if dashboard:
		save_options()
	if audio_manager:
		audio_manager.shutdown()
	if traffic:
		traffic.shutdown()
	# Let the audio mixer retire active WAV voices before renderer/server teardown.
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(code)

func save_options() -> void:
	local_options.set_value("audio","master",master_volume)
	local_options.set_value("audio","nature",nature_volume)
	for field in ["show_gps","show_mirror","show_controls"]:
		local_options.set_value("hud",field,dashboard.get(field))
	local_options.save("user://driver_options.cfg")

func dashboard_key(key: int) -> void:
	match key:
		KEY_Q: van.set_indicator(-1)
		KEY_E: van.set_indicator(1)
		KEY_H:
			van.hazards = not van.hazards
			van.indicator = 0
			van.blink_time = 0
		KEY_L: van.headlights = not van.headlights
		KEY_K:
			van.high_beam = not van.high_beam
			van.headlights = true
		KEY_I: van.toggle_engine()
		KEY_F: van.refuel()
		KEY_P:
			van.parking_brake = not van.parking_brake
			van.cruise = false
		KEY_T: van.toggle_cruise()
		KEY_B:
			if audio_manager:
				audio_manager.horn_time = 0.4
		KEY_N: navigation.next_target()
		KEY_G: dashboard.show_gps = not dashboard.show_gps
		KEY_V: dashboard.show_mirror = not dashboard.show_mirror
		KEY_M:
			dashboard.show_gps = true
			dashboard.expanded_map = not dashboard.expanded_map

func apply_menu_theme() -> void:
	var theme := Theme.new()
	theme.default_font=preload("res://assets/fonts/BarlowCondensed-Medium.ttf")
	theme.default_font_size=21
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("23172f")
	panel.border_color = Color("ffd044")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(5)
	panel.shadow_color = Color(0,0,0,0.7)
	panel.shadow_size = 7
	theme.set_stylebox("panel","PanelContainer",panel)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("48265f") if state == "normal" else Color("6b3886")
		style.border_color = Color("9371a5") if state == "normal" else Color("ffd044")
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		if state == "focus":
			style.bg_color = Color(0,0,0,0)
		theme.set_stylebox(state,"Button",style)
	theme.set_color("font_color","Button",Color("f3ebd8"))
	theme.set_color("font_hover_color","Button",Color("ffd044"))
	menu.theme = theme

func set_menu_camera() -> void:
	van.set_view(false)
	van.camera.position = Vector3(6,3.7,7)
	van.camera.look_at(van.position+Vector3(0,1.6,0))

func set_resolution(size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)

func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func switch_location(start_on_load := false) -> void:
	if switching_location:
		return
	switching_location = true
	start_button.disabled = true
	map_button.disabled = true
	menu_title.text = "LOADING CLEVELAND..." if outerbelt else "LOADING OHIO..."
	get_tree().paused = false
	van.active = false
	van.dispose_roll_body()
	save_options()
	audio_manager.shutdown()
	traffic.shutdown()
	get_tree().set_meta("outerbelt",not outerbelt)
	get_tree().set_meta("start_selected_location",start_on_load)
	await get_tree().process_frame
	get_tree().reload_current_scene()

func start_drive() -> void:
	get_viewport().disable_3d=false
	var entering := not driving
	driving = true
	paused = false
	get_tree().paused = false
	van.active = true
	van.pause_crash(false)
	if outerbelt:highway.barriers.pause_debris(false)
	van.camera_manual = false
	menu.hide()
	menu_art.hide()
	van.set_view(true if entering else van.cockpit)
	if cargo:
		cargo.pause_packages(false)
		if cargo.on_foot: cargo.actor.camera.make_current()
	hud.show()

func return_to_menu() -> void:
	get_viewport().disable_3d=true
	get_tree().paused = false
	paused = false
	driving = false
	van.active = false
	van.pause_crash(true)
	if outerbelt:highway.barriers.pause_debris(true)
	if cargo: cargo.pause_packages(true)
	hud.hide()
	menu.show()
	menu_art.show()
	set_menu_camera()
	menu_title.text = "LET'S DRIVE."
	start_button.text = "Resume drive"
	start_button.grab_focus()

func reset_van() -> void:
	if cargo and (cargo.spilled or cargo.on_foot):
		van.notify_driver("Recover your packages before resetting the route")
		return
	van.reset_vehicle()
	update_hud(0,"N",0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_TAB or (event.keycode == KEY_ESCAPE and options.visible):
		toggle_options()
		return
	if options.visible:
		return
	if event.keycode == KEY_ESCAPE and driving:
		paused = not paused
		get_viewport().disable_3d=paused
		get_tree().paused = paused
		menu.visible = paused
		menu_art.visible = paused
		menu_title.text = "TAKE A BREATHER" if paused else "FedUp / DRIVER"
		start_button.text = "Resume drive"
		if paused:
			start_button.grab_focus()
	if not driving or paused:
		return
	if event.keycode==KEY_F and cargo and cargo.on_foot:
		return
	if event.keycode!=KEY_G and not (cargo and cargo.on_foot and event.keycode in [KEY_Q,KEY_E]):dashboard_key(event.keycode)
	if event.keycode == KEY_C:
		toggle_camera()
	if event.keycode == KEY_G:
		if cargo and cargo.on_foot:cargo.actor.recenter_camera()
		else:van.recenter_camera()
	if event.keycode == KEY_X and cargo:
		cargo.interact()
	if event.keycode == KEY_R:
		reset_van()
	if event.keycode == KEY_U:
		van.recover_upright()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and camera_drag_button==event.button_index:camera_drag_button=0
	if not driving or paused or (options and options.visible):camera_drag_button=0
	if driving and not paused and not options.visible:
		var walking:bool=cargo and cargo.on_foot
		if event is InputEventMouseButton and event.device!=-1 and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed and can_drag_camera(event.position):camera_drag_button=event.button_index
			elif not event.pressed and camera_drag_button==event.button_index:camera_drag_button=0
		if event is InputEventMouseMotion and event.device!=-1 and camera_drag_button!=0:
			if walking:cargo.actor.orbit_camera(-event.relative.x*.008,event.relative.y*.005)
			else:van.orbit_camera(-event.relative.x*.008,event.relative.y*.005)
			get_viewport().set_input_as_handled()
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var amount:float=-.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .1
			if walking:cargo.actor.camera_zoom=clampf(cargo.actor.camera_zoom+amount,.65,1.6)
			elif not van.cockpit:van.camera_zoom=clampf(van.camera_zoom+amount,.65,1.6)
	# Tab is a global dashboard shortcut, even while a GUI slider/button has focus.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or (event.keycode == KEY_ESCAPE and options and options.visible):
			toggle_options()
			get_viewport().set_input_as_handled()

func can_drag_camera(at:Vector2) -> bool:
	if dashboard.compact_layout():return touch_controls.world_point(at/(touch_controls.size.x/720))
	var factor:=minf(hud.size.x/1280,hud.size.y/720)
	var point:Vector2=(at-(hud.size-Vector2(1280,720)*factor)*.5)/factor
	if point.y<145 or point.y>680:return false
	var map_rect:=Rect2(305,125,670,365) if dashboard.expanded_map else Rect2(23,521,220,165)
	if dashboard.show_gps and map_rect.has_point(point):return false
	if point.x>1000 and point.y>530:return false
	var hovered:Control=get_viewport().gui_get_hovered_control()
	return not hovered or hovered.mouse_filter==Control.MOUSE_FILTER_IGNORE or not hovered.get_global_rect().has_point(at)

func update_hud(speed: float, gear: String, distance: float) -> void:
	if dashboard:
		update_recovery_prompt()
		navigation.update_position(van.position,van.speed)
		dashboard.update_state(speed,gear,distance,van.steering,atan2(van.position.z,van.position.x),van.cockpit)
		if hud_shortcuts and camera_shortcut:
			var ui_scale:=minf(hud.size.x/1280,hud.size.y/720)
			hud_shortcuts.visible=not dashboard.compact_layout()
			camera_shortcut.visible=not dashboard.compact_layout()
			hud_shortcuts.scale=Vector2.ONE*ui_scale
			hud_shortcuts.position=Vector2(550,18)*ui_scale
			camera_shortcut.scale=Vector2.ONE*ui_scale
			camera_shortcut.position=Vector2(1100,20)*ui_scale

func update_recovery_prompt() -> void:
	if not recovery_panel:return
	var complete:bool=cargo and cargo.complete
	var recovering:bool=van.overturned and not (cargo and cargo.on_foot)
	var disabled:bool=not cargo and van.wrecked
	recovery_panel.visible=complete or recovering or disabled
	recovery_back.visible=recovery_panel.visible
	dashboard.action_prompt_visible=recovery_panel.visible
	if not recovery_panel.visible:
		upright_button.hide();new_truck_button.hide();return
	var compact:bool=dashboard.compact_layout()
	var factor:float=hud.size.x/720 if compact else minf(hud.size.x/1280,hud.size.y/720)
	var design:Vector2=hud.size/factor
	var rect:=Rect2((design.x-500)/2,605,500,64)
	if compact:rect=preload("res://scripts/hud_layout.gd").prompt_rect(design.y)
	var action:bool=complete or disabled or not compact
	var action_width:float=156 if compact and design.y>=600 else (140 if rect.size.x<400 else 180)
	var action_height:float=88 if compact and design.y>=600 else 44
	recovery_panel.position=rect.position*factor;recovery_panel.scale=Vector2.ONE*factor;recovery_panel.size=rect.size
	recovery_back.position=recovery_panel.position;recovery_back.scale=Vector2.ONE*factor;recovery_back.size=rect.size
	recovery_back.set_kind("complete" if complete else ("wait" if not van.roll_settled and recovering else "recover"))
	recovery_status.position=Vector2(50,10)
	recovery_status.size=Vector2(rect.size.x-62-(action_width+10 if action else 0),rect.size.y-20)
	recovery_status.add_theme_font_size_override("font_size",24 if compact and design.y>=600 else (16 if rect.size.x<400 else 22))
	recovery_status.text="ROUTE COMPLETE" if complete else ("TRUCK SETTLING" if recovering and not van.roll_settled else ("RIGHT TRUCK" if recovering else "TRUCK DISABLED"))
	upright_button.visible=recovering and not compact
	upright_button.disabled=not van.roll_settled
	upright_button.text="RECOVER [U]"
	new_truck_button.visible=complete or disabled
	new_truck_button.text="PLAY AGAIN" if complete else "NEW TRUCK"
	for control in [upright_button,new_truck_button]:
		control.position=Vector2(rect.size.x-action_width-10,(rect.size.y-action_height)/2)
		control.size=Vector2(action_width,action_height);control.add_theme_font_size_override("font_size",22 if compact and design.y>=600 else 18)

func smoke_test() -> void:
	assert(FileAccess.file_exists("res://data/empty_day.json"))
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/empty_day.json"))
	assert(not config.traffic_enabled and not config.hazards_enabled)
	start_drive()
	for frame in 120:
		await get_tree().physics_frame
	assert(van.is_on_floor(),"Van must settle on road")
	assert(absf(van.position.y) < 0.5,"Spawn must remain on road")
	van.speed = 12.0
	var before: Vector3 = van.position
	for frame in 60:
		await get_tree().physics_frame
	assert(van.position.distance_to(before) > 5.0,"Van must move")
	van.set_view(true)
	assert(van.cockpit and not van.body.visible)
	get_tree().paused = true
	before = van.position
	for frame in 10:
		await get_tree().process_frame
	assert(van.position == before,"Pause must stop physics")
	get_tree().paused = false
	reset_van()
	assert(van.speed == 0.0 and van.position == Vector3(260,0.15,0))
	print("SMOKE PASS: empty config, road contact, movement, cockpit, pause, reset")
	await quit_demo()
