extends Control
## Independent finger tracking permits simultaneous steering, gas and braking.
var game:Node
var fingers:Dictionary={}
var stick:=Vector2.ZERO
var enabled:=false
var regions:Dictionary={}
var font:Font
var camera_hold:=0.0
var camera_recentered:=false
var reverse_selected:=false
var layout_size:=Vector2.ZERO
var drawing_state:Array=[]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font

func layout() -> void:
	layout_size=size
	var h:=size.y*720/size.x
	regions={"gas":Rect2(552,h-218,140,94),"brake":Rect2(552,h-110,140,84),"stick":Rect2(24,h-226,208,208),"hand":Rect2(278,h-116,180,78),"camera":Rect2(24,112,156,52),"map":Rect2(198,112,156,52),"options":Rect2(24,178,156,52),"exit":Rect2(198,178,156,52),"upright":Rect2(278,h-214,180,70)}
	if h>=850:
		regions.camera.size.y=88;regions.map.size.y=88
		regions.options=Rect2(24,214,156,88);regions.exit=Rect2(198,214,156,88)
	if h<850:
		regions.stick=Rect2(24,h-174,150,150)
		regions.gas=Rect2(566,h-174,130,70)
		regions.brake=Rect2(566,h-94,130,70)
		regions.hand=Rect2(278,h-76,180,52)
		regions.upright=Rect2(278,h-250,180,52)
	if h<480:
		for i in 4:regions[["camera","map","options","exit"][i]]=Rect2(24+i*124,80,112,38)
		regions.stick=Rect2(20,h-152,128,128)
		regions.gas=Rect2(582,h-152,118,56);regions.brake=Rect2(582,h-84,118,56)
		regions.hand=Rect2(430,h-70,126,42);regions.upright=Rect2(430,h-122,126,42)
	else:
		for key in ["camera","map","options","exit"]:regions[key].position.y+=28
	regions["gear"]=regions.upright

func release_inputs() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake","sprint"]:Input.action_release(action)
	fingers.clear();stick=Vector2.ZERO

func _process(delta:float) -> void:
	var active:bool=game.driving and not game.paused and not game.options.visible and not (game.cargo and game.cargo.complete) and (game.dashboard.compact_layout() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args())
	if enabled and not active:release_inputs()
	enabled=active;visible=active
	if active and "camera" in fingers.values() and game.cargo and game.cargo.on_foot:
		camera_hold+=delta
		if camera_hold>=.55 and not camera_recentered:
			camera_recentered=true;game.cargo.actor.recenter_camera()
	else:camera_hold=0;camera_recentered=false
	if active:
		var resized:bool=layout_size!=size
		if resized:layout()
		var walking:bool=game.cargo and game.cargo.on_foot
		var view:int=game.cargo.actor.camera_view if walking else -1
		var current:Array=[stick,reverse_selected,walking,view,game.van.overturned]
		if resized or current!=drawing_state:
			drawing_state=current;queue_redraw()

func _input(event:InputEvent) -> void:
	if not enabled:return
	var scale_factor:=size.x/720
	if event is InputEventScreenTouch:
		if event.pressed:
			var pos:Vector2=event.position/scale_factor
			for key in regions:
				if key=="upright" and not game.van.overturned:continue
				if key=="gear" and (game.van.overturned or (game.cargo and game.cargo.on_foot)):continue
				if not regions[key].has_point(pos):continue
				fingers[event.index]=key
				match key:
					"camera":game.toggle_camera()
					"map":game.dashboard.expanded_map=not game.dashboard.expanded_map
					"options":game.toggle_options()
					"exit":if game.cargo:game.cargo.interact()
					"upright":game.van.recover_upright()
					"gear":reverse_selected=not reverse_selected
					"stick":stick=(pos-regions.stick.get_center())/80
				get_viewport().set_input_as_handled();break
			var h:=size.y/scale_factor
			var world_top:=360 if h>=850 else (130 if h<480 else 280)
			if not fingers.has(event.index) and game.cargo and game.cargo.on_foot and pos.y>world_top and pos.y<h-180:
				fingers[event.index]="orbit";get_viewport().set_input_as_handled()
		else:
			if fingers.get(event.index)=="stick":stick=Vector2.ZERO
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.get(event.index)=="stick":
		stick=(event.position/scale_factor-regions.stick.get_center())/80
	elif event is InputEventScreenDrag and fingers.get(event.index)=="orbit":
		game.cargo.actor.orbit_camera(-event.relative.x/scale_factor*.009,event.relative.y/scale_factor*.006)
		get_viewport().set_input_as_handled()
	else:return
	update_actions()

func update_actions() -> void:
	var held:Array=fingers.values()
	var walking:bool=game.cargo and game.cargo.on_foot
	var move:=stick.limit_length()
	var actions:Dictionary={"steer_left":maxf(0,-move.x),"steer_right":maxf(0,move.x),"accelerate":maxf(float("gas" in held),maxf(0,-move.y)),"brake_reverse":maxf(float("brake" in held),maxf(0,move.y)),"handbrake":float("hand" in held and not walking),"sprint":float("hand" in held and walking)}
	if not walking:
		# Pulling the stick selects reverse, including while another finger
		# holds gas. Direction remains selected when the stick recenters.
		if move.y>.4:reverse_selected=true
		elif move.y<-.4:reverse_selected=false
		var pedal:float=maxf(float("gas" in held),absf(move.y) if absf(move.y)>.24 else 0)
		actions.accelerate=0.0 if reverse_selected else pedal
		actions.brake_reverse=maxf(float("brake" in held),pedal if reverse_selected else 0.0)
	for action in actions:
		if actions[action]>.06:Input.action_press(action,actions[action])
		else:Input.action_release(action)

func _draw() -> void:
	if not enabled:return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*size.x/720)
	var walking:bool=game.cargo and game.cargo.on_foot
	var labels:Dictionary={"gas":"MOVE" if walking else "GAS","brake":"BACK" if walking else "BRAKE / REV","hand":"RUN" if walking else "HANDBRAKE","camera":"CAMERA","map":"GPS MAP","options":"OPTIONS","exit":"ENTER" if walking else "EXIT / WALK","upright":"RIGHT TRUCK"}
	labels["gear"]="GEAR: R" if reverse_selected else "GEAR: D"
	if reverse_selected and not walking:labels.gas="REVERSE"
	if walking:labels.camera=["TRAVEL VIEW","WIDE VIEW","SURVEY VIEW"][game.cargo.actor.camera_view]
	for key in regions:
		var rect:Rect2=regions[key]
		if key=="upright" and not game.van.overturned:continue
		if key=="gear" and (walking or game.van.overturned):continue
		var style:=StyleBoxFlat.new();style.bg_color=Color(.07,.08,.13,.83);style.border_color=Color("ffca55");style.set_border_width_all(2);style.set_corner_radius_all(18)
		draw_style_box(style,rect)
		if key=="stick":
			draw_arc(rect.get_center(),rect.size.x*.33,0,TAU,48,Color("9175a7"),3,true)
			draw_circle(rect.get_center()+stick.limit_length()*rect.size.x*.30,rect.size.x*.14,Color("b393cf"))
		else:
			var text_size:=25 if size.y*720/size.x>=850 else 18
			var label:String=labels[key]
			while font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x>rect.size.x-14 and text_size>12:text_size-=1
			var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
			draw_string(font,rect.get_center()+Vector2(-width/2,-1 if walking and key=="camera" else 7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("fff0d2"))
			if walking and key=="camera":
				var hint:="HOLD: LOOK AHEAD";var hint_size:=12 if rect.size.y<60 else 15
				draw_string(font,rect.get_center()+Vector2(-font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size).x/2,14 if rect.size.y<60 else 17),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size,Color("ffca55"))
