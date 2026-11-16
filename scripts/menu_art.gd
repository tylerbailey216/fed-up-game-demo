extends Control
var heading: SystemFont
var small: Font
var outerbelt := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading = SystemFont.new()
	heading.font_names = PackedStringArray(["Arial","Liberation Sans"])
	heading.font_weight = 900
	heading.font_italic = true
	small = ThemeDB.fallback_font

func title(pos: Vector2, value: String, size_px: int, color: Color) -> void:
	draw_string_outline(heading,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,9,Color("10121e"))
	draw_string(heading,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.04,.075,.6))
	if size.x/maxf(1,size.y)<1.6:
		var factor:=size.x/720
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
		title(Vector2(30,70),"FedUp / DRIVER",43,Color("ffd044"))
		return
	var factor:=minf(size.x/1280,size.y/720)
	draw_set_transform((size-Vector2(1280,720)*factor)/2,0,Vector2.ONE*factor)
	draw_rect(Rect2(0,0,1280,720),Color(0.035,0.045,0.075,0.44))
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(675,0),Vector2(480,720),Vector2(0,720)]),Color(0.035,0.04,0.075,0.80))
	draw_line(Vector2(675,0),Vector2(480,720),Color("ffd044"),4,true)
	title(Vector2(58,152),"Fed",92,Color("f3ebd8"))
	title(Vector2(214,152),"Up",92,Color("f78c2f"))
	title(Vector2(65,192),"DRIVING SIMULATOR",26,Color("ffd044"))
	draw_line(Vector2(65,218),Vector2(424,218),Color("6a39a0"),8,true)
	title(Vector2(61,315),"YOUR ROUTE.",48,Color("f3ebd8"))
	title(Vector2(61,370),"YOUR PACE.",48,Color("f3ebd8"))
	draw_string(small,Vector2(65,425),"Real roads. A new place to explore." if outerbelt else "A sunlit skyline. Three open lanes.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d4cbbd"))
	draw_string(small,Vector2(65,455),"I-480 / I-77. Geographic prototype." if outerbelt else "Push past the barrels. Join the city traffic.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d4cbbd"))
	title(Vector2(65,615),"02  /  INDEPENDENCE, OHIO" if outerbelt else "01  /  DOWNTOWN CLEVELAND",18,Color("ffd044"))
	draw_string(small,Vector2(65,646),"OFFLINE PC DEMO  •  KEYBOARD DRIVING",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d4cbbd"))
