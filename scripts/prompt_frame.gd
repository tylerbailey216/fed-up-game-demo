extends Panel
## Compact comic action strip; its footprint never depends on hidden children.
var kind:="recover"
func set_kind(value:String) -> void:
	if kind!=value:kind=value;queue_redraw()
func _draw() -> void:
	var h:=size.y
	var accent:=Color("8de0e9") if kind=="complete" else Color("ffd044")
	draw_colored_polygon(PackedVector2Array([Vector2(6,8),Vector2(44,8),Vector2(34,h-8),Vector2(6,h-8)]),Color("6a39a0"))
	var center:=Vector2(22,h*.5)
	if kind=="complete":
		draw_polyline(PackedVector2Array([center+Vector2(-8,0),center+Vector2(-2,7),center+Vector2(10,-8)]),accent,3,true)
	else:
		draw_arc(center,12,-PI*.8,PI*.7,24,accent,2,true)
		if kind=="wait":
			draw_line(center,center+Vector2(0,-7),accent,2,true);draw_line(center,center+Vector2(6,2),accent,2,true)
		else:
			draw_colored_polygon(PackedVector2Array([center+Vector2(-13,-9),center+Vector2(-5,-9),center+Vector2(-12,-2)]),accent)
	draw_line(Vector2(52,7),Vector2(size.x-16,7),Color("6a39a0"),2,true)
	for i in 3:
		var at:=Vector2(size.x-16-i*7,h-7)
		draw_line(at,at+Vector2(3,-5),accent,2,true)
