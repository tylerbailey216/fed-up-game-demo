extends RefCounted
## Purpose-built portrait/landscape adaptation of the illustrated desktop cabin.
const Layout=preload("res://scripts/hud_layout.gd")
const Ink=preload("res://scripts/dashboard_ink.gd")
const FACE=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const LOGO=preload("res://assets/fonts/Bangers-Regular.ttf")
const INK:=Color("10121e")
const CREAM:=Color("f3ebd8")
const GOLD:=Color("ffd044")
const CYAN:=Color("8de0e9")
func text(c:Control,at:Vector2,value:String,px:int,tone:=CREAM) -> void:
	c.draw_string(FACE,at+Vector2(1,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,INK)
	c.draw_string(FACE,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tone)
func gauge(c:Control,at:Vector2,r:float,value:float,maximum:float,label:String,digital:=false) -> void:
	var cache_key:="dial-%f" % r
	if not Ink.textures.has(cache_key):
		var body:="<circle r='%f' fill='#10121e'/><circle r='%f' fill='#b4a294'/><circle r='%f' fill='#17232f'/><circle r='%f' fill='none' stroke='#f3ebd8' stroke-width='1.5'/>" % [r+5,r+2,r,r-3]
		for i in 21:
			var d:=Vector2.from_angle(deg_to_rad(140+i*13.5));var a:=d*(r-(9 if i%5==0 else 6));var b:=d*(r-3)
			body+="<path d='M%f %f L%f %f' stroke='#f3ebd8' stroke-width='%f'/>" % [a.x,a.y,b.x,b.y,1.5 if i%5==0 else 1.0]
		var a:=Vector2.from_angle(deg_to_rad(340))*(r-7);var b:=Vector2.from_angle(deg_to_rad(410))*(r-7)
		body+="<path d='M%f %f A%f %f 0 0 1 %f %f' fill='none' stroke='#eb694c' stroke-width='3'/>" % [a.x,a.y,r-7,r-7,b.x,b.y]
		Ink.texture(cache_key,body,"%f %f %f %f" % [-r-6,-r-6,(r+6)*2,(r+6)*2],Vector2i(ceil((r+6)*4),ceil((r+6)*4)))
	c.draw_texture_rect(Ink.textures[cache_key],Rect2(at-Vector2.ONE*(r+6),Vector2.ONE*(r+6)*2),false)
	for i in range(0,21,5):
		if r>=32:
			var number:=str(roundi(maximum*i/20.0));var px:=10 if r<45 else 12
			var pos:=at+Vector2.from_angle(deg_to_rad(140+i*13.5))*(r-18)
			if digital and i in [0,20]:pos=at+Vector2(r*(-.74 if i==0 else .72),r*.34)
			text(c,pos-Vector2(FACE.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x*.5,-3),number,px)
	var d:=Vector2.from_angle(deg_to_rad(140+clampf(value/maximum,0,1)*270))
	c.draw_line(at-d*6,at+d*(r-11),INK,5,true);c.draw_line(at-d*6,at+d*(r-11),Color("ff7950"),2.5,true)
	c.draw_circle(at,4,INK);c.draw_circle(at,2,Color("c1c8c8"))
	if digital:
		var number:="%03d" % roundi(value);var px:=24 if r>=45 else 18
		text(c,at+Vector2(-FACE.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x/2,r*.56),number,px)
	text(c,at+Vector2(-FACE.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x/2,r*.84),label,10,GOLD)
func draw(c:Control) -> void:
	var factor:float=c.size.x/720;var h:float=c.size.y/factor;var wide:=Layout.wide(h)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var header:=Rect2(14,10,692,76) if not wide else Rect2(12,8,394,50)
	Ink.plate(c,header,false,true)
	c.draw_string(LOGO,Vector2(28,43 if not wide else 37),"FedUp",HORIZONTAL_ALIGNMENT_LEFT,-1,34 if not wide else 28,CREAM)
	text(c,Vector2(140,34) if not wide else Vector2(120,26),"CLEVELAND / PUBLIC SQUARE" if c.vehicle.location_world and c.vehicle.location_world.get("is_downtown") else "I-480 / I-77 / OHIO",17 if not wide else 11,GOLD)
	if wide:
		c.draw_energy(Rect2(120,33,270,9));c.draw_objective_line(Vector2(18,73),530,13)
	else:
		text(c,Vector2(140,52),"TRUCK ENERGY",12,GOLD);c.draw_energy(Rect2(230,42,460,11))
		c.draw_objective_line(Vector2(28,76),660,17)
	if not wide:text(c,Vector2(24,211),"HOLD VIEW: RECENTER   /   SWIPE ROAD: LOOK",12,CREAM)
	if c.show_gps and c.vehicle.location_world:
		var r:Rect2=c.compact_map_rect();Ink.plate(c,r)
		c.draw_rect(r.grow(-6),Color("1b3038"))
		c.vehicle.location_world.draw_map(c,r.grow(-8),c.cargo.player_position() if c.cargo else c.vehicle.position)
		c.draw_packages(r.grow(-8))
		text(c,r.position+Vector2(10,17),"GPS / GOLD: BOXES",11,GOLD)
		text(c,r.end-Vector2(r.size.x-8,7),"© OpenStreetMap",9,CREAM)
	var deck:float=Layout.deck_height(h);var y:=h-deck
	# Reuse the actual cab's authored hatching, seams and vent trim at native aspect.
	c.shape([Vector2(0,y+20),Vector2(190,y),Vector2(530,y),Vector2(720,y+20),Vector2(720,h),Vector2(0,h)],Color("3a2c45"),4)
	if c.illustration:
		var source:=Rect2(0,650,c.illustration.get_width(),c.illustration.get_height()-650)
		var height:float=720*source.size.y/source.size.x
		c.draw_texture_rect_region(c.illustration,Rect2(0,y,720,height),source)
	c.draw_polyline(PackedVector2Array([Vector2(0,y+16),Vector2(190,y-2),Vector2(530,y-2),Vector2(720,y+16)]),INK,10,true)
	c.draw_polyline(PackedVector2Array([Vector2(0,y+12),Vector2(190,y-6),Vector2(530,y-6),Vector2(720,y+12)]),Color("e6b582"),4,true)
	Ink.hatch(c,Rect2(0,h-18,720,14))
	var housing:=Rect2(168,h-111,250,96) if wide else Rect2(206,y+12,374,132)
	Ink.plate(c,housing,false,true)
	for at in [housing.position+Vector2(10,11),housing.end-Vector2(10,11)]:
		c.draw_circle(at,4,INK);c.draw_circle(at,2,Color("ac9694"));c.draw_line(at-Vector2(2,1),at+Vector2(2,1),INK,1,true)
	var walking:bool=c.cargo and c.cargo.on_foot
	if walking:
		Ink.icon(c,"exit",housing.position+Vector2(36,45),1.3,CYAN)
		text(c,housing.position+Vector2(65,37),"TRUCK READY" if c.cargo.can_enter_truck() else "ON FOOT",24,GOLD)
		text(c,housing.position+Vector2(65,58),"%02d / %02d SECURED" % [c.cargo.recovered,c.cargo.quota],17)
		text(c,housing.position+Vector2(15,housing.size.y-14),(("TAP ENTER TO DRIVE" if c.touch_input() else "PRESS X TO DRIVE") if c.cargo.can_enter_truck() else ("BESIDE TRUCK / TAP ENTER" if c.touch_input() else "BESIDE TRUCK / PRESS X")) if not c.vehicle.wrecked else "WALK OVER BOXES / AUTO RETURN",12,CYAN)
	elif not c.action_prompt_visible:
		var speed_at:=Vector2(232,h-63) if wide else Vector2(294,y+77)
		var rpm_at:=Vector2(317,h-65) if wide else Vector2(414,y+75)
		gauge(c,speed_at,37 if wide else 54,c.speed,100,"MPH",true)
		gauge(c,rpm_at,27 if wide else 42,c.vehicle.rpm/1000.0,5,"RPM x1000")
		var fuel_at:=Vector2(380,h-67) if wide else Vector2(510,y+61)
		gauge(c,fuel_at,21 if wide else 27,c.vehicle.fuel_gallons/c.vehicle.TANK_GALLONS,1,"E     F")
		Ink.icon(c,"fuel",fuel_at+Vector2(-23,34),.32,GOLD)
		text(c,fuel_at+Vector2(-13,38),"%.1f GAL" % c.vehicle.fuel_gallons,11,CYAN)
		if not wide:
			text(c,Vector2(468,y+122),"%d F  /  %s" % [roundi(c.vehicle.temperature_f),c.gear],14,CREAM)
		var flash:bool=fmod(c.vehicle.blink_time,1.0)<.5
		var signals:=Vector2(184,h-101) if wide else Vector2(226,y+25)
		for side in [-1,1]:
			var active:bool=flash and (c.vehicle.hazards or c.vehicle.indicator==side)
			Ink.icon(c,"left" if side<0 else "right",signals+Vector2(0 if side<0 else (214 if wide else 332),0),.7,Color("78ec92") if active else Color("3f5353"))
		var lights:=Vector2(345,h-102) if wide else Vector2(469,y+24)
		for i in 3:
			var lit:bool=[c.vehicle.headlights,not c.vehicle.engine_on,c.vehicle.temperature_f>220][i]
			Ink.icon(c,["lights","engine","temp"][i],lights+Vector2(i*23,0),.48,(CYAN if i==0 else Color("ff855e")) if lit else Color("55515a"))
