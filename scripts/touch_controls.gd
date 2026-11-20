extends Control
## A Mayhem direction stick and independent simulator steering/pedal fingers.
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
var layout_walking:=false
var drawing_state:Array=[]
const Layout=preload("res://scripts/hud_layout.gd")
const Ink=preload("res://scripts/dashboard_ink.gd")
const FACE=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font

func layout() -> void:
	layout_size=size
	layout_walking=game.cargo and game.cargo.on_foot
	var h:=size.y*720/size.x
	regions=Layout.regions(h,game.arcade)
	if game.arcade and layout_walking:
		regions["hand"]=Rect2(430,h-54,128,42) if Layout.wide(h) else Rect2(340,h-102,118,88)

func release_inputs() -> void:
	for action in ["accelerate","brake_reverse","steer_left","steer_right","handbrake","sprint"]:Input.action_release(action)
	fingers.clear();stick=Vector2.ZERO

func set_stick(point:Vector2) -> void:
	var reach:float=regions.stick.size.x*.4 if game.arcade else 80.0
	stick=(point-regions.stick.get_center())/reach

func world_point(point:Vector2) -> bool:
	var h:=size.y*720/size.x
	if point.y<Layout.header_height(h):return false
	for key in regions:
		if key=="upright" and not game.van.overturned:continue
		if key=="gear" and (game.van.overturned or (game.cargo and game.cargo.on_foot)):continue
		if regions[key].has_point(point):return false
	if game.dashboard.show_gps and game.van.location_world:
		if game.dashboard.compact_map_rect().has_point(point):return false
	if Layout.prompt_rect(h).has_point(point) and game.recovery_back.visible:return false
	return point.y<h-Layout.deck_height(h) and Rect2(0,0,720,h).has_point(point)

func _process(delta:float) -> void:
	var active:bool=game.driving and not game.paused and not game.options.visible and not (game.cargo and game.cargo.complete) and (game.dashboard.compact_layout() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args())
	if enabled and not active:release_inputs()
	enabled=active;visible=active
	if active and not game.arcade and "camera" in fingers.values():
		camera_hold+=delta
		if camera_hold>=.55 and not camera_recentered:
			camera_recentered=true
			if game.cargo and game.cargo.on_foot:game.cargo.actor.recenter_camera()
			else:game.van.recenter_camera()
	else:camera_hold=0;camera_recentered=false
	if active:
		var walking:bool=game.cargo and game.cargo.on_foot
		var resized:bool=layout_size!=size or layout_walking!=walking
		if resized:layout()
		var view:int=game.cargo.actor.camera_view if walking else -1
		var current:Array=[stick,reverse_selected,walking,view,game.van.overturned,game.van.roll_settled,game.van.steering,fingers.values()]
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
					"camera":camera_hold=0;camera_recentered=false
					"map":game.dashboard.expanded_map=not game.dashboard.expanded_map
					"options":game.toggle_options()
					"exit":if game.cargo:game.cargo.interact()
					"upright":game.van.recover_upright()
					"gear":reverse_selected=not reverse_selected
					"stick":set_stick(pos)
				get_viewport().set_input_as_handled();break
			if not game.arcade and not fingers.has(event.index) and world_point(pos):
				fingers[event.index]="orbit";get_viewport().set_input_as_handled()
		else:
			if fingers.get(event.index)=="stick":stick=Vector2.ZERO
			if fingers.get(event.index)=="camera" and not camera_recentered:game.toggle_camera()
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.get(event.index)=="stick":
		set_stick(event.position/scale_factor)
	elif event is InputEventScreenDrag and fingers.get(event.index)=="orbit":
		if game.arcade:return
		if game.cargo and game.cargo.on_foot:game.cargo.actor.orbit_camera(-event.relative.x/scale_factor*.009,event.relative.y/scale_factor*.006)
		else:game.van.orbit_camera(-event.relative.x/scale_factor*.009,event.relative.y/scale_factor*.006)
		get_viewport().set_input_as_handled()
	else:return
	update_actions()

func update_actions() -> void:
	var held:Array=fingers.values()
	var walking:bool=game.cargo and game.cargo.on_foot
	var move:=stick.limit_length()
	var actions:Dictionary={"steer_left":maxf(0,-move.x),"steer_right":maxf(0,move.x),"accelerate":maxf(float("gas" in held),maxf(0,-move.y)),"brake_reverse":maxf(float("brake" in held),maxf(0,move.y)),"handbrake":float("hand" in held and not walking),"sprint":float("hand" in held and walking)}
	if not walking and not game.arcade:
		# Pulling the stick selects reverse, including while another finger
		# holds gas. Direction remains selected when the stick recenters.
		if move.y>.4:reverse_selected=true
		elif move.y<-.4:reverse_selected=false
		var pedal:float=maxf(float("gas" in held),absf(move.y) if absf(move.y)>.24 else 0)
		actions.accelerate=0.0 if reverse_selected else pedal
		actions.brake_reverse=maxf(float("brake" in held),pedal if reverse_selected else 0.0)
	elif game.arcade:
		# Both truck and worker consume a screen-direction vector in Mayhem.
		# Releasing the stick releases every axis; reverse is never latched.
		reverse_selected=false
	for action in actions:
		if actions[action]>.06:Input.action_press(action,actions[action])
		else:Input.action_release(action)

func _draw() -> void:
	if not enabled:return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*size.x/720)
	var walking:bool=game.cargo and game.cargo.on_foot
	var wide:=Layout.wide(size.y*720/size.x)
	var labels:Dictionary={"gas":"MOVE" if walking else ("REV" if reverse_selected else "GAS"),"brake":"BACK" if walking else "BRAKE","hand":"RUN" if walking else "DRIFT","camera":"VIEW","map":"GPS","options":"SETUP","exit":"ENTER" if walking else "WALK","upright":"RECOVER" if game.van.roll_settled else "WAIT"}
	labels["gear"]="R / D" if reverse_selected else "D / R"
	for key in regions:
		var rect:Rect2=regions[key]
		if key=="upright" and not game.van.overturned:continue
		if key=="gear" and (walking or game.van.overturned):continue
		if key=="stick":
			if walking or game.arcade:
				var at:=rect.get_center();var r:=rect.size.x*.4
				draw_circle(at,r+8,Color(.07,.06,.1,.55));draw_arc(at,r,0,TAU,48,Color("b79abf"),3,true)
				draw_arc(at,r-6,0,TAU,48,Color("5f397f"),2,true)
				if game.arcade:
					for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
						var tip:Vector2=at+direction*(r-12);var base:Vector2=at+direction*(r-19);var side:=Vector2(-direction.y,direction.x)*3.5
						draw_polyline(PackedVector2Array([base+side,tip,base-side]),Color("d5bdde"),2,true)
				draw_circle(at+stick.limit_length()*r*.52,r*.25,Color("ad88c6"))
			else:Ink.wheel(self,rect,game.van.steering,stick)
			var wheel_label:="MOVE" if game.arcade else ("WALK" if walking else "STEER")
			draw_string(FACE,rect.get_center()+Vector2(-18,rect.size.y*.47),wheel_label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f3ebd8"))
			continue
		Ink.plate(self,rect,key in fingers.values(),key in ["camera","map","options","exit"])
		var label:String=labels[key];var text_size:=11 if wide else 18
		if key in ["camera","map","options","exit"]:
			Ink.icon(self,key,rect.get_center()+Vector2(-12,0) if wide else rect.get_center()-Vector2(0,12),.64 if wide else 1.1)
			var at:Vector2=rect.get_center()+Vector2(4,4) if wide else rect.get_center()+Vector2(-FACE.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x/2,28)
			draw_string(FACE,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("f3ebd8"))
		elif key in ["gas","brake"]:
			# Physical ribbed pedals, warm accelerator and metal brake surfaces.
			var tone:=Color("d8a267") if key=="gas" else Color("a4a9b1")
			for i in 3:
				var at:=rect.position+Vector2(15,12+i*7)
				draw_line(at,at+Vector2(rect.size.x-30,0),Color("10121e"),5,true);draw_line(at,at+Vector2(rect.size.x-30,0),tone,2,true)
			draw_string(FACE,rect.position+Vector2(15,rect.size.y-10),label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("f3ebd8"))
		elif key=="hand" or key=="upright":
			Ink.icon(self,key,rect.position+Vector2(23,rect.size.y/2),.65,Color("ffd044"))
			draw_string(FACE,rect.position+Vector2(43,rect.size.y/2+6),label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color("f3ebd8"))
		else:
			var tone:=Color("ffd044") if reverse_selected else Color("8de0e9")
			draw_string(FACE,rect.get_center()+Vector2(-FACE.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x/2,6),label,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,tone)
