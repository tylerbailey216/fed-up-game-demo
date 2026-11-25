extends Control
var game:Node
var inspected:="truck"
var cards:Array[Button]=[]
var grid:GridContainer
var detail:Label
var progress:Label
var confirm:Button
var container:VBoxContainer
var actions:Array[Button]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_STOP
	var back:=ColorRect.new();back.color=Color("171320");back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	container=VBoxContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.offset_left=28;container.offset_right=-28;container.offset_top=20;container.offset_bottom=-20;container.add_theme_constant_override("separation",12);add_child(container)
	var title:=Label.new();title.text="FedUp / CHOOSE YOUR RIDE";title.add_theme_font_override("font",preload("res://assets/fonts/Bangers-Regular.ttf"));title.add_theme_font_size_override("font_size",44);title.modulate=Color("ffd044");container.add_child(title)
	var mode:=Button.new();mode.text="DELIVERY MAYHEM / SWITCH TO ZEN DRIVE" if game.arcade else "ZEN DRIVE / SWITCH TO DELIVERY MAYHEM";mode.custom_minimum_size.y=42
	mode.pressed.connect(func():game.switch_location(false));container.add_child(mode);actions.append(mode)
	grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);container.add_child(grid)
	var atlas:Texture2D=load("res://assets/art/presentation/fleet-select.png")
	for i in game.fleet.catalog.size():
		var card:=preload("res://scripts/fleet_card.gd").new();card.vehicle=game.fleet.catalog[i]
		var region:=AtlasTexture.new();region.atlas=atlas;region.region=Rect2((i%2)*768,floori(i/2.0)*512,768,512);card.picture=region
		if i==2:region.region=Rect2(0,512,720,512)
		if i==3:region.region=Rect2(730,512,806,512)
		card.flat=true;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.pressed.connect(inspect.bind(str(card.vehicle.id)))
		grid.add_child(card);cards.append(card)
	detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",22);container.add_child(detail)
	progress=Label.new();progress.modulate=Color("88d9da");progress.add_theme_font_size_override("font_size",20);container.add_child(progress)
	confirm=Button.new();confirm.custom_minimum_size.y=52;confirm.pressed.connect(depart);container.add_child(confirm);actions.append(confirm)
	var back_button:=Button.new();back_button.text="MAIN MENU";back_button.custom_minimum_size.y=42;back_button.pressed.connect(hide);container.add_child(back_button);actions.append(back_button)
	resized.connect(fit);inspect(game.fleet.selected);fit.call_deferred()
	confirm.grab_focus()

func fit() -> void:
	if not grid:return
	grid.columns=2 if size.x/size.y<1.6 else 4
	var ratio:=size.y/maxf(1,get_window().size.y)
	var button_height:=maxf(52,44*ratio)
	for action in actions:
		action.custom_minimum_size.y=button_height
		action.add_theme_font_size_override("font_size",maxi(21,roundi(16*ratio)))
		action.add_theme_font_override("font",preload("res://assets/fonts/Bangers-Regular.ttf"))
	detail.add_theme_font_size_override("font_size",maxi(22,roundi(13*ratio)))
	progress.add_theme_font_size_override("font_size",maxi(20,roundi(12*ratio)))
	var fixed:=40.0+12*(container.get_child_count()-1)
	for child in container.get_children():
		if child!=grid:fixed+=child.get_combined_minimum_size().y
	for card in cards:card.custom_minimum_size=Vector2(0,clampf((size.y-fixed)/(2 if grid.columns==2 else 1),120,290))

func inspect(id:String) -> void:
	inspected=id
	for card in cards:
		card.locked=not game.fleet.unlocked(card.vehicle.id);card.picked=card.vehicle.id==id;card.queue_redraw()
	var spec:Dictionary=game.fleet.spec(id)
	var unlocked:bool=game.fleet.unlocked(id)
	detail.text=str(spec.description) if unlocked else "%s / UNLOCK AFTER %d COMPLETED DELIVERIES" % [spec.role,int(spec.deliveries)]
	progress.text="CAREER DELIVERIES: %d / PROGRESS SAVED ON THIS DEVICE" % game.fleet.deliveries
	if game.fleet.save_error!=OK:progress.text="CAREER DELIVERIES: %d / SAVE UNAVAILABLE THIS SESSION" % game.fleet.deliveries
	confirm.text="DRIVE / "+str(spec.name) if unlocked else "LOCKED / %d MORE DELIVERIES" % maxi(0,int(spec.deliveries)-game.fleet.deliveries)
	confirm.disabled=not unlocked
	fit.call_deferred()

func depart() -> void:
	if not game.fleet.choose(inspected):return
	if not game.fleet.persistent:get_tree().set_meta("fleet_fixture",{"deliveries":game.fleet.deliveries,"selected":inspected})
	if game.vehicle_id!=inspected or game.has_started:
		get_tree().set_meta("start_selected_location",true);get_tree().reload_current_scene();return
	hide();game.start_drive()
