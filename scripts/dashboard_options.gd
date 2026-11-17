extends PanelContainer
var game: Node
var checks: Dictionary = {}
var tabs: TabContainer
var master_slider: HSlider
var mute_toggle: CheckButton
var last_volume := 0.7

func _ready() -> void:
	theme = game.menu.theme
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -325
	offset_right = 325
	offset_top = -310
	offset_bottom = 310
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	column.add_child(game.text_label("DASHBOARD / AUDIO",28))
	column.add_child(game.text_label("Paused - settings save locally when you close",14))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var gps := add_tab("HUD / GPS")
	for item in [["GPS navigation","show_gps"],["Live rear-view mirror","show_mirror"],["Show extended controls","show_controls"]]:
		var check := CheckButton.new()
		check.text = item[0]
		var field: String = item[1]
		check.button_pressed = game.dashboard.get(field)
		check.toggled.connect(func(value: bool): game.dashboard.set(field,value))
		checks[field] = check
		gps.add_child(check)
	gps.add_child(game.text_label("Local loop destinations",18))
	for target in 4:
		game.button(game.navigation.DESTINATIONS[target],game.navigation.select_target.bind(target),gps)
	gps.add_child(game.text_label("M map · N next destination · G recenter · V mirror\nDrag the world to orbit/tilt; wheel zooms.\nF refuels the demo van anywhere while stopped.",14))
	var vehicle := add_tab("Vehicle")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	vehicle.add_child(grid)
	for item in [["Ignition [I]",KEY_I],["Headlights [L]",KEY_L],["High beam [K]",KEY_K],["Hazards [H]",KEY_H],["Left signal [Q]",KEY_Q],["Right signal [E]",KEY_E],["Parking brake [P]",KEY_P],["Cruise [T]",KEY_T],["Demo refuel [F]",KEY_F],["Horn [B]",KEY_B]]:
		var control: Button = game.button(item[0],game.dashboard_key.bind(item[1]),grid)
		control.custom_minimum_size = Vector2(270,80)
	vehicle.add_child(game.text_label("B holds horn · Space handbrake/drift · R resets\nC switches to the turning chase camera.\nCruise requires 12 mph; brakes cancel cruise.\nRefuel only while stopped; use I to restart if empty.",15))
	var audio := add_tab("Audio")
	for channel in ["Master volume","Nature / ambience"]:
		audio.add_child(game.text_label(channel,18))
		var slider := HSlider.new()
		slider.name = "Master" if channel == "Master volume" else "Nature"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.value = game.master_volume if channel == "Master volume" else game.nature_volume
		slider.custom_minimum_size = Vector2(500,40)
		slider.value_changed.connect(set_volume.bind(channel == "Master volume"))
		if channel == "Master volume":
			master_slider = slider
		audio.add_child(slider)
	var mute := CheckButton.new()
	mute_toggle = mute
	mute.text = "Mute all sound"
	mute.button_pressed = game.master_volume == 0
	mute.toggled.connect(func(value: bool):
		if value and game.master_volume > 0:
			last_volume = game.master_volume
		master_slider.value = 0.0 if value else last_volume
	)
	audio.add_child(mute)
	audio.add_child(game.text_label("Engine / throttle / rolling tires / wind / birds\nSignals / horn / starter / brake air / impact\nOriginal synthesized sounds - no external downloads.",15))
	game.button("Return to main menu",func(): hide();game.return_to_menu(),column)
	game.button("Close / Resume [Tab or Esc]",game.toggle_options,column)
	hide()

func add_tab(title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title.replace("/","-")
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	var scroll:=ScrollContainer.new()
	scroll.name=margin.name
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	scroll.add_child(margin)
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",8)
	margin.add_child(list)
	return list

func sync_checks() -> void:
	for field in checks:
		checks[field].set_pressed_no_signal(game.dashboard.get(field))

func set_volume(value: float, master: bool) -> void:
	if master:
		game.master_volume = value
		if mute_toggle:
			mute_toggle.set_pressed_no_signal(value == 0)
	else:
		game.nature_volume = value
	if game.audio_manager:
		game.audio_manager.master_volume = game.master_volume
		game.audio_manager.nature_volume = game.nature_volume
