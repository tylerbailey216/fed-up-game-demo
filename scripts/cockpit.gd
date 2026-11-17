extends Control
## Original vector-drawn comic cockpit. Numbers use live vehicle telemetry.
var speed := 0.0
var gear := "N"
var steering := 0.0
var phase := 0.0
var distance := 0.0
var inside := false
var font: Font
var title_font: SystemFont
var mirror_texture: Texture2D
var illustration: Texture2D
var vehicle: Node
var navigation: Node
var show_gps := true
var show_mirror := true
var show_controls := false
var expanded_map := false
var traffic: Node
var cargo: Node
var last_redraw_us := 0
var action_prompt_visible:=false
var touch_preview:=false # Native layout review only; normal play uses the device.
const INK := Color("10121e")
const PANEL := Color("202332")
const CREAM := Color("f3ebd8")
const CYAN := Color("8de0e9")
const GOLD := Color("ffd044")
const PURPLE := Color("6a39a0")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Arial","Liberation Sans"])
	title_font.font_weight = 800
	title_font.font_italic = true
	if ResourceLoader.exists("res://assets/art/cockpit_illustrated_v2.png"):
		illustration = load("res://assets/art/cockpit_illustrated_v2.png")

func update_state(kph: float, current_gear: String, meters: float, steer: float, angle: float, cockpit: bool) -> void:
	speed = kph/1.609344
	gear = current_gear
	distance = meters
	steering = steer
	phase = angle
	inside = cockpit
	# Keep telemetry current; reuse the recorded drawing between HUD updates.
	# Vehicle simulation and character animation retain their own cadence.
	var now := Time.get_ticks_usec()
	if now-last_redraw_us >= 33333:
		last_redraw_us=now
		queue_redraw()

func caption(at: Vector2, value: String, size_px: int, color := CREAM, bold := false) -> void:
	var face: Font = title_font if bold else font
	draw_string(face,at+Vector2(1,2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,INK)
	draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func shape(points: Array, fill: Color, width := 4.0) -> void:
	var pts := PackedVector2Array(points)
	draw_colored_polygon(pts,fill)
	pts.append(pts[0])
	draw_polyline(pts,INK,width,true)

func panel(rect: Rect2, color := PANEL, border := GOLD, width := 3) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(width+3)
	style.set_corner_radius_all(12)
	draw_style_box(style,rect.grow(3))
	style.border_color = border
	style.set_border_width_all(width)
	draw_style_box(style,rect)

func dial(center: Vector2, radius: float, value: float, maximum: float, label: String) -> void:
	draw_circle(center,radius+5,INK)
	draw_circle(center,radius+1,Color("827983"))
	draw_circle(center,radius-1,Color("ccc1b2"))
	for ring in 18:
		var shade := Color("101723").lerp(Color("2b3745"),ring/40.0)
		draw_circle(center+Vector2(0,ring*0.03),radius-3-ring*1.5,shade)
	draw_arc(center,radius-2,0,TAU,80,CREAM,2,true)
	draw_arc(center,radius-7,PI*1.03,PI*1.52,32,Color(0.75,0.85,0.9,0.18),3,true)
	if maximum == 5:
		draw_arc(center,radius-7,deg_to_rad(364),deg_to_rad(420),22,Color("d86250"),3,true)
	var tick_count := 25 if maximum == 5 else 50
	var tick_group := 5
	for i in tick_count+1:
		var angle := deg_to_rad(140.0+i*280.0/tick_count)
		var direction := Vector2(cos(angle),sin(angle))
		var major := i%tick_group == 0
		draw_line(center+direction*(radius-(13 if major else 8)),center+direction*(radius-5),CREAM,2 if major else 1,true)
		if major:
			var number := str(roundi(float(i)/tick_count*maximum))
			var pos := center+direction*(radius-23)
			draw_string(font,pos-Vector2(7,-4),number,HORIZONTAL_ALIGNMENT_LEFT,-1,10,CREAM)
	var angle := deg_to_rad(140+clampf(value/maximum,0,1)*280)
	var direction := Vector2(cos(angle),sin(angle))
	draw_line(center-direction*9,center+direction*(radius-16),INK,6,true)
	draw_line(center-direction*9,center+direction*(radius-16),Color("ff694b"),3,true)
	draw_circle(center,5,INK)
	draw_circle(center,2,CREAM)
	var label_width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
	caption(center+Vector2(-label_width/2,radius*0.78),label,10)

func _draw() -> void:
	if compact_layout():
		draw_compact()
		draw_package_guide()
		return
	var factor:=minf(size.x/1280.0,size.y/720.0)
	draw_set_transform((size-Vector2(1280,720)*factor)/2,0,Vector2.ONE*factor)
	if inside:
		draw_cab()
	draw_brand()
	panel(Rect2(1012,78,242,48))
	caption(Vector2(1025,95),"TRUCK ENERGY",12,GOLD,true)
	draw_energy(Rect2(1025,102,216,14))
	if cargo:
		draw_objective_line(Vector2(375,89),600,14)
	if show_gps:
		draw_route()
	if not inside and not (cargo and cargo.on_foot):
		panel(Rect2(1012,533,242,151))
		caption(Vector2(1032,565),"GROUND SPEED",13,GOLD,true)
		caption(Vector2(1030,622),"%03d" % roundi(speed),55,CREAM,true)
		caption(Vector2(1150,621),"mph",21,CYAN,true)
		caption(Vector2(1034,656),gear+"  /  AUTOMATIC",15)
		if vehicle:
			caption(Vector2(1034,676),"FUEL %.1f GAL / %d MI EST." % [vehicle.fuel_gallons,roundi(vehicle.fuel_gallons*18)],11,GOLD)
			draw_status()
	if show_controls:
		caption(Vector2(278,701),"WASD DRIVE  Q/E BLINKERS  H HAZARD  L LIGHTS  TAB OPTIONS",12,CREAM,true)
	else:
		caption(Vector2(278,701),"WASD WALK / SHIFT RUN / X ENTER / DRAG LOOK / G RECENTER" if cargo and cargo.on_foot else "TAB OPTIONS / M MAP / C VIEW / DRAG LOOK / G RECENTER / ESC PAUSE",12,CREAM,true)
	caption(Vector2(280,108),"%05.2f mi  /  %s" % [distance/1609.344,location_name()],13,CREAM)
	draw_package_guide()

func draw_package_guide() -> void:
	if not cargo or not cargo.on_foot:return
	var item:Dictionary=cargo.safety.nearest()
	if item.is_empty():return
	var camera:Camera3D=cargo.actor.camera
	var target:Vector3=item.body.global_position+Vector3.UP*.9
	var projected:=camera.unproject_position(target)
	var center:=size/2
	var compact:=compact_layout();var factor:=size.x/720 if compact else minf(size.x/1280,size.y/720)
	var design_height:=size.y/factor
	var top:float=(370 if design_height>=850 else (132 if design_height<480 else 286))*factor if compact else 145*factor
	var bottom:float=size.y-(380 if design_height>=850 else 195)*factor if compact else size.y-155*factor
	bottom=maxf(top+45,bottom)
	var bounds:=Rect2(Vector2(22,top),Vector2(size.x-44,bottom-top))
	var behind:=camera.is_position_behind(target)
	if behind:projected=center-(projected-center)
	var at:=projected.clamp(bounds.position,bounds.end)
	var edge:bool=behind or not bounds.has_point(projected)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if edge:
		var direction:Vector2=(projected-center).normalized()
		if direction.is_zero_approx():direction=Vector2.DOWN
		var side:=Vector2(-direction.y,direction.x)
		shape([at+direction*12,at-direction*8+side*7,at-direction*8-side*7],GOLD,2)
	else:
		shape([at+Vector2(0,-9),at+Vector2(7,0),at+Vector2(0,9),at+Vector2(-7,0)],GOLD,2)
	var meters:=roundi(cargo.actor.global_position.distance_to(item.body.global_position))
	var label:="BOX %02d / %d m" % [int(item.id)+1,meters]
	var font_size:=clampi(roundi(18*factor),12,20)
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var label_at:=Vector2(clampf(at.x-width/2,12,size.x-width-12),minf(at.y+28,bottom+28))
	panel(Rect2(label_at+Vector2(-6,-font_size-2),Vector2(width+12,font_size+10)),PANEL,GOLD,1)
	caption(label_at,label,font_size,GOLD)

func status_message() -> String:
	var message:String=cargo.objective() if cargo else ""
	if vehicle.notice_time>0:message=vehicle.notice
	if mission_message_active():
		message=cargo.popup
		if message.begins_with("COLLECTION INCOMPLETE"):message="%d PACKAGES LEFT / CHECK GPS" % cargo.remaining_notice
		elif message.begins_with("ALL "):message="ALL %d SECURED / TRUCK READY" % cargo.quota
		elif message.begins_with("DEMO COMPLETE"):message="ALL %d DELIVERED / ROUTE COMPLETE" % cargo.quota
	if message.begins_with("ON FOOT"):message="ON FOOT / WALK OVER PACKAGES"
	if message.begins_with("TRAINING COMPLETE"):message="DOWNTOWN OPEN / LIVE TRAFFIC"
	return message.replace("\n"," / ").to_upper()

func mission_message_active() -> bool:
	return cargo and cargo.popup_time>0 and (vehicle.notice_time<=0 or cargo.popup_last_at>=vehicle.notice_last_at)

func message_time() -> float:
	return cargo.popup_time if mission_message_active() else vehicle.notice_time

func draw_objective_line(at:Vector2,width:float,text_size:int) -> void:
	var message:=status_message()
	var time:=message_time()
	var face:Font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
	var fitted:=message
	while face.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x>width and fitted.length()>4:fitted=fitted.substr(0,fitted.length()-2)+"…"
	var tone:=GOLD if time>0 else CYAN
	tone.a=clampf(time/.35,0,1) if time>0 else 1.0
	draw_string(face,at+Vector2(1,1),fitted,HORIZONTAL_ALIGNMENT_LEFT,width,text_size,Color(INK,tone.a))
	draw_string(face,at,fitted,HORIZONTAL_ALIGNMENT_LEFT,width,text_size,tone)
	if time>0:
		draw_line(at+Vector2(0,5),at+Vector2(width*clampf(time/2.6,0,1),5),Color(tone,.65*tone.a),1,true)

func compact_layout() -> bool:
	return touch_preview or size.x/maxf(1,size.y)<1.6 or DisplayServer.is_touchscreen_available()

func compact_map_rect() -> Rect2:
	var h:=size.y/(size.x/720)
	if h<480:return Rect2(170,122,534,90) if expanded_map else Rect2(538,80,166,90)
	return Rect2(24,282 if h>=850 else 138,672,minf(440,h-690) if h>=850 else h-340) if expanded_map else Rect2(378,140,326,210 if h>=850 else 150)

func location_name() -> String:
	if vehicle.location_world:
		return "CLEVELAND / PUBLIC SQUARE" if vehicle.location_world.get("is_downtown") else "INDEPENDENCE, OH"
	return "TRAINING LOOP"

func draw_packages(rect:Rect2) -> void:
	if not cargo or not vehicle.location_world:return
	if vehicle.location_world.has_method("map_point"):
		for item in cargo.packages:
			if item.state=="loose" and is_instance_valid(item.body):draw_circle(vehicle.location_world.map_point(item.body.position,rect),3.5,GOLD)
		var stop:Vector2=vehicle.location_world.map_point(cargo.checkpoint_position,rect)
		draw_rect(Rect2(stop-Vector2.ONE*5,Vector2.ONE*10),CYAN)
		draw_rect(Rect2(stop-Vector2.ONE*5,Vector2.ONE*10),INK,false,1)

func draw_compact() -> void:
	var factor:=size.x/720
	var h:=size.y/factor
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var wide:=h<480
	panel(Rect2(16,12 if wide else 16,688,60 if wide else 110))
	caption(Vector2(32,37 if wide else 48),"FedUp",22 if wide else 28,CREAM,true)
	caption(Vector2(162,36 if wide else 45),location_name(),14 if wide else 20,GOLD,true)
	caption(Vector2(32,61 if wide else 77),"TRUCK",11 if wide else 16,GOLD,true)
	draw_energy(Rect2(96,49,240,15) if wide else Rect2(150,61,540,20))
	if cargo:draw_objective_line(Vector2(360,61) if wide else Vector2(32,107),330 if wide else 658,13 if wide else 18)
	if show_gps and vehicle.location_world:
		var rect:=compact_map_rect()
		panel(rect,Color("202f36"))
		vehicle.location_world.draw_map(self,rect,cargo.player_position() if cargo else vehicle.position)
		draw_packages(rect)
		caption(rect.position+Vector2(12,22),"GOLD: BOXES / BLUE: STOP",10 if h<480 else 13,GOLD,true)
		caption(rect.end-Vector2(rect.size.x-12,10),"© OSM contributors" if h<480 else "© OpenStreetMap contributors",9 if h<480 else 10)
	if action_prompt_visible:return
	var y:=h-360
	if wide:
		y=h-80
		panel(Rect2(172,y,242,58))
		caption(Vector2(184,y+25),"ON FOOT" if cargo and cargo.on_foot else "%03d mph / %s" % [roundi(speed),gear],22,GOLD,true)
		caption(Vector2(184,y+46),"WALK OVER BOXES TO COLLECT" if cargo and cargo.on_foot else "FUEL %.1f GAL / %s" % [vehicle.fuel_gallons,"ON" if vehicle.engine_on else "OFF"],12)
		return
	if h<850:
		y=h-190
		panel(Rect2(196,y,346,102))
		caption(Vector2(210,y+30),"ON FOOT" if cargo and cargo.on_foot else "%03d mph / %s" % [roundi(speed),gear],25,GOLD,true)
		caption(Vector2(210,y+60),"WALK OVER BOXES TO COLLECT" if cargo and cargo.on_foot else "FUEL %.1f GAL / %s" % [vehicle.fuel_gallons,"ENGINE ON" if vehicle.engine_on else "ENGINE OFF"],14)
		caption(Vector2(210,y+86),"%d BOXES SECURED" % cargo.recovered if cargo else "FREE DRIVE",14,CYAN)
		return
	panel(Rect2(24,y,672,120))
	if cargo and cargo.on_foot:
		caption(Vector2(44,y+43),"ON FOOT",28,GOLD,true)
		caption(Vector2(44,y+76),"Walk over boxes / Auto return to truck",18)
	else:
		caption(Vector2(44,y+48),"%03d" % roundi(speed),43,CREAM,true)
		caption(Vector2(144,y+46),"mph / "+gear,20,CYAN,true)
		caption(Vector2(44,y+81),"FUEL %.1f GAL    ENGINE %s" % [vehicle.fuel_gallons,"ON" if vehicle.engine_on else "OFF"],16,GOLD)
		caption(Vector2(342,y+40),"HAZARDS" if vehicle.hazards else "TURN SIGNALS",18,CREAM)
		var flash:=fmod(vehicle.blink_time,1.0)<.5
		shape([Vector2(330,y+27),Vector2(342,y+19),Vector2(342,y+35)],Color("73d998") if flash and (vehicle.hazards or vehicle.indicator==-1) else Color("4b5159"),1)
		shape([Vector2(665,y+27),Vector2(653,y+19),Vector2(653,y+35)],Color("73d998") if flash and (vehicle.hazards or vehicle.indicator==1) else Color("4b5159"),1)
		caption(Vector2(342,y+73),"LOAD SECURED" if not cargo or not cargo.spilled else "RECOVER LOST PACKAGES",14,CYAN)

func energy_fraction() -> float:
	return clampf(1.0-cargo.damage/100.0,0,1) if cargo else clampf(1.0-vehicle.flip_count/3.0,0,1)

func draw_energy(rect:Rect2) -> void:
	var energy:=energy_fraction()
	var low:=energy>0 and energy<.35
	var tone:=Color("69df93") if energy>.68 else (GOLD if energy>.35 else Color("ff654d"))
	if low:tone=tone.lerp(Color("ffe3a4"),.35+.35*sin(Time.get_ticks_msec()*.012))
	draw_rect(rect.grow(3),INK)
	draw_rect(rect.grow(1),CREAM,false,1)
	draw_rect(rect,Color("493348"))
	if energy>0:
		var filled:=Rect2(rect.position,Vector2(rect.size.x*energy,rect.size.y))
		draw_rect(filled,tone)
		draw_rect(Rect2(filled.position,Vector2(filled.size.x,filled.size.y*.28)),tone.lightened(.3))
		for i in range(1,12):
			var x:=rect.position.x+rect.size.x*i/12.0
			if x<filled.end.x:draw_line(Vector2(x,rect.position.y+2),Vector2(x,rect.end.y-2),tone.darkened(.25),1)
	else:
		caption(rect.position+Vector2(5,rect.size.y-2),"DISABLED",maxi(9,roundi(rect.size.y*.75)),Color("ff8e6c"),true)

func draw_brand() -> void:
	shape([Vector2(26,17),Vector2(340,17),Vector2(323,59),Vector2(13,59)],INK,5)
	draw_polyline(PackedVector2Array([Vector2(27,20),Vector2(337,20),Vector2(321,56),Vector2(15,56),Vector2(27,20)]),GOLD,2,true)
	shape([Vector2(25,63),Vector2(258,63),Vector2(250,96),Vector2(16,96)],PURPLE,3)
	caption(Vector2(37,46),"FedUp",28,CREAM,true)
	caption(Vector2(130,45),"DRIVING SIMULATOR",17,GOLD,true)
	caption(Vector2(36,85),"DOWNTOWN / CLEVELAND" if vehicle.location_world and vehicle.location_world.get("is_downtown") else ("I-480 / I-77 / OHIO" if vehicle.location_world else "TRAINING / CITY EXIT AHEAD"),13,GOLD,true)
	panel(Rect2(1100,20,153,34),PANEL,GOLD,2)
	caption(Vector2(1112,43),"C  SWITCH VIEW",14,CREAM,true)

func draw_route() -> void:
	var rect := Rect2(23,521,220,165) if not expanded_map else Rect2(305,125,670,365)
	panel(rect,Color("202f36"))
	if vehicle.location_world:
		if navigation and not navigation.enabled:
			caption(rect.position+Vector2(12,22),"GPS OFF / G TO ENABLE",11,GOLD,true)
			return
		vehicle.location_world.draw_map(self,rect,cargo.player_position() if cargo else vehicle.position)
		draw_packages(rect)
		caption(rect.position+Vector2(12,20),location_name(),11,GOLD,true)
		caption(rect.position+Vector2(12,rect.size.y-10),"© OpenStreetMap contributors",10,CREAM)
		return
	if traffic and traffic.in_city(vehicle.position):
		caption(rect.position+Vector2(12,22),"LIVE CITY / FREE ROAM",12,GOLD,true)
		var origin := rect.position+Vector2(18,35)
		var scale_xy := (rect.size-Vector2(36,68))/Vector2(194,240)
		for x in [280,330,430]:
			draw_line(origin+Vector2(x-262,95 if x==280 else 20)*scale_xy,origin+Vector2(x-262,150 if x==280 else 210)*scale_xy,Color("71848a"),5)
		for z in [-145,-75,-20,45]:
			draw_line(origin+Vector2(18,z+170)*scale_xy,origin+Vector2(168,z+170)*scale_xy,Color("71848a"),5)
		for car in traffic.cars:
			draw_circle(origin+Vector2(car.position.x-262,car.position.z+170)*scale_xy,2,CREAM)
		var player := origin+Vector2(vehicle.position.x-262,vehicle.position.z+170)*scale_xy
		draw_circle(player,5,CYAN)
		caption(rect.position+Vector2(12,rect.size.y-10),"CROSS ST: "+traffic.ew_light+" / NS: "+traffic.ns_light,10,GOLD)
		return
	var center := rect.position+rect.size*Vector2(0.5,0.48)
	var radii := rect.size*Vector2(0.32,0.27)
	draw_ellipse(center,radii,Color("83958c"),14)
	draw_ellipse(center,radii,Color("141b25"),8)
	draw_ellipse(center,radii,GOLD,2)
	var exit_point := center+Vector2(cos(-0.29)*radii.x,sin(-0.29)*radii.y)
	draw_circle(exit_point,4,Color("f08c35"))
	if expanded_map:
		caption(exit_point+Vector2(8,12),"CITY EXIT / BARRELS",12,Color("f4af57"))
	for marker in 4:
		var angle := -(marker+1)*PI/2
		var point := center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
		draw_circle(point,4,CREAM)
		if expanded_map and navigation:
			caption(point+Vector2(8,-8),navigation.DESTINATIONS[marker],13)
	var dot := center+Vector2(cos(phase)*radii.x,sin(phase)*radii.y)
	draw_circle(dot,8,INK)
	draw_circle(dot,5,CYAN)
	if navigation and navigation.enabled:
		var dest := center+Vector2(cos(-navigation.target_progress)*radii.x,sin(-navigation.target_progress)*radii.y)
		draw_circle(dest,8,GOLD)
		caption(rect.position+Vector2(12,22),"GPS  /  "+navigation.DESTINATIONS[navigation.target_index].to_upper(),12,GOLD,true)
		var remaining: float = navigation.remaining_m/1609.344
		var eta := "--" if navigation.eta_seconds < 0 else "%d:%02d" % [int(navigation.eta_seconds)/60,int(navigation.eta_seconds)%60]
		caption(rect.position+Vector2(12,rect.size.y-31),"ARRIVED" if navigation.arrived else "%.2f mi  /  ETA %s" % [remaining,eta],12,CREAM,true)
		caption(rect.position+Vector2(12,rect.size.y-12),"N NEXT STOP  /  M MAP",10,CREAM)
	else:
		caption(rect.position+Vector2(12,22),"GPS OFF  /  METRO LOOP",12,GOLD,true)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 81:
		var angle := TAU*i/80.0
		pts.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_polyline(pts,color,width,true)

func draw_cab() -> void:
	if illustration:
		draw_illustrated_cab()
		return
	shape([Vector2(0,0),Vector2(70,0),Vector2(134,505),Vector2(73,550),Vector2(0,510)],Color("74665f"),7)
	shape([Vector2(15,0),Vector2(39,0),Vector2(112,506),Vector2(89,514)],Color("bc9c7d"),3)
	shape([Vector2(0,0),Vector2(1280,0),Vector2(1280,17),Vector2(99,27)],Color("3d3444"),5)
	shape([Vector2(1235,0),Vector2(1280,0),Vector2(1280,537),Vector2(1205,503)],Color("655969"),6)
	draw_line(Vector2(1251,25),Vector2(1224,501),Color("b89d87"),7,true)
	panel(Rect2(13,275,98,175),INK,Color("a7a1a0"),3)
	if mirror_texture:
		draw_texture_rect(mirror_texture,Rect2(20,283,84,157),false)
	caption(Vector2(28,463),"REAR VIEW",10,CREAM,true)
	shape([Vector2(0,550),Vector2(190,520),Vector2(460,495),Vector2(810,495),Vector2(1095,521),Vector2(1280,547),Vector2(1280,720),Vector2(0,720)],Color("353044"),6)
	shape([Vector2(0,548),Vector2(190,516),Vector2(460,490),Vector2(810,490),Vector2(1095,516),Vector2(1280,545),Vector2(1280,562),Vector2(1095,532),Vector2(810,507),Vector2(460,507),Vector2(190,532),Vector2(0,566)],Color("ceaa84"),4)
	shape([Vector2(240,700),Vector2(272,571),Vector2(398,528),Vector2(897,528),Vector2(1014,574),Vector2(1044,720)],Color("171923"),5)
	draw_polyline(PackedVector2Array([Vector2(267,690),Vector2(294,578),Vector2(408,544),Vector2(885,544),Vector2(992,583)]),Color("797080"),5,true)
	dial(Vector2(526,617),70,speed,100,"mph")
	dial(Vector2(803,617),70,clampf(0.8+speed*0.029,0.8,4.6),5,"RPM x1000 / EST.")
	panel(Rect2(619,568,96,79),Color("2c3949"),Color("7c8993"),2)
	caption(Vector2(630,609),"%03d" % roundi(speed),35,CREAM,true)
	caption(Vector2(641,632),"mph",15,CYAN,true)
	caption(Vector2(657,670),gear,24,CREAM,true)
	var wheel := Vector2(405,743)
	draw_arc(wheel,140,0,TAU,100,INK,28,true)
	draw_arc(wheel,140,PI,TAU,60,Color("ad9b87"),14,true)
	draw_arc(wheel,148,PI+0.1,TAU-0.1,60,Color("efd3a8"),3,true)
	for spoke in 3:
		var angle := steering*1.8+spoke*TAU/3.0
		draw_line(wheel,wheel+Vector2(cos(angle),sin(angle))*127,INK,22,true)
		draw_line(wheel,wheel+Vector2(cos(angle),sin(angle))*120,Color("574c58"),10,true)
	panel(Rect2(1067,565,178,109),Color("26232f"),GOLD,2)
	caption(Vector2(1081,596),"Fed",28,CREAM,true)
	caption(Vector2(1135,596),"Up",28,Color("f79338"),true)
	caption(Vector2(1080,621),"FUEL / RANGE",11,Color("a9a3aa"))
	caption(Vector2(1080,641),"DEMO SYSTEM",12,CREAM,true)
	for vent in 5:
		draw_line(Vector2(919,610+vent*8),Vector2(978,622+vent*8),Color("61566b"),3,true)

func draw_illustrated_cab() -> void:
	# Glass and instruments remain live beneath/above the authored illustration.
	if mirror_texture and show_mirror:
		draw_texture_rect(mirror_texture,Rect2(27,259,86,254),false)
	else:
		draw_rect(Rect2(27,259,86,254),INK)
	draw_texture_rect(illustration,Rect2(0,0,1280,720),false)
	dial(Vector2(513,620),62,vehicle.rpm/1000.0 if vehicle else 0.8,5,"EST. RPM x1000")
	dial(Vector2(817,620),62,speed,100,"mph")
	panel(Rect2(617,581,102,66),Color("233446"),Color("7c8993"),2)
	caption(Vector2(631,619),"%03d" % roundi(speed),36,CREAM,true)
	caption(Vector2(645,638),"mph",14,CYAN,true)
	caption(Vector2(656,672),gear,22,CREAM,true)
	if vehicle:
		small_gauge(Vector2(403,583),vehicle.fuel_gallons/vehicle.TANK_GALLONS,"FUEL","E","F")
		small_gauge(Vector2(923,623),clampf((vehicle.temperature_f-100)/140,0,1),"TEMP","C","H")
		caption(Vector2(378,624),"%.1f gal" % vehicle.fuel_gallons,10,GOLD)
		caption(Vector2(891,674),"%d F" % roundi(vehicle.temperature_f),10,CREAM)
		caption(Vector2(1020,710),"EST. RANGE %d MI" % roundi(vehicle.fuel_gallons*18),10,CREAM)
		draw_status()
	# Detailed leather rim, colored bevels, stitching and real steering spokes.
	var wheel := Vector2(362,804)
	draw_arc(wheel,178,0,TAU,120,INK,31,true)
	draw_arc(wheel,178,PI,TAU,70,Color("554450"),23,true)
	draw_arc(wheel,182,PI,TAU,70,Color("bc9981"),13,true)
	draw_arc(wheel,189,PI+0.05,TAU-0.05,70,Color("f3d0a0"),3,true)
	draw_arc(wheel,168,PI+0.05,TAU-0.05,70,Color("231f2e"),3,true)
	for stitch in 48:
		var angle := PI+stitch*PI/48.0+steering*0.04
		var direction := Vector2(cos(angle),sin(angle))
		draw_line(wheel+direction*174,wheel+direction*179,Color("dbb99a"),1,true)
	for spoke in 3:
		var angle := steering*1.8+spoke*TAU/3.0
		var end := wheel+Vector2(cos(angle),sin(angle))*160
		draw_line(wheel,end,INK,25,true)
		draw_line(wheel,end,Color("6a5863"),14,true)
		draw_line(wheel+Vector2(0,3),end+Vector2(0,3),Color("99818b"),2,true)

func small_gauge(center: Vector2, amount: float, label: String, low: String, high: String) -> void:
	draw_circle(center,31,INK)
	draw_circle(center,29,Color("b5aaa1"))
	draw_circle(center,27,Color("17212b"))
	for i in 5:
		var angle := deg_to_rad(150+i*60)
		var direction := Vector2(cos(angle),sin(angle))
		draw_line(center+direction*20,center+direction*25,CREAM,1,true)
	var angle := deg_to_rad(150+clampf(amount,0,1)*240)
	draw_line(center,center+Vector2(cos(angle),sin(angle))*21,Color("ff825b"),2,true)
	caption(center+Vector2(-19,18),low,8)
	caption(center+Vector2(14,18),high,8)
	caption(center+Vector2(-14,-36),label,9,GOLD,true)

func draw_status() -> void:
	var flash: bool = fmod(vehicle.blink_time,1.0) < 0.5
	var green := Color("7ee875")
	var origin := Vector2(587,569) if inside else Vector2(1030,517)
	shape([origin+Vector2(0,-10),origin+Vector2(19,-22),origin+Vector2(19,2)],green if flash and (vehicle.indicator == -1 or vehicle.hazards) else Color("364339"),2)
	shape([origin+Vector2(158,-10),origin+Vector2(139,-22),origin+Vector2(139,2)],green if flash and (vehicle.indicator == 1 or vehicle.hazards) else Color("364339"),2)
	var status: Array[String] = []
	if vehicle.hazards:
		status.append("HAZARDS")
	if vehicle.headlights:
		status.append("HIGH BEAM" if vehicle.high_beam else "LIGHTS ON")
	if vehicle.parking_brake:
		status.append("PARK BRAKE")
	if vehicle.cruise:
		status.append("CRUISE %d MPH" % roundi(vehicle.cruise_speed*2.2369363))
	if not vehicle.engine_on:
		status.append("ENGINE OFF")
	if vehicle.fuel_gallons < 3:
		status.append("LOW FUEL")
	caption(Vector2(1000,688),"  /  ".join(status),10,GOLD)
