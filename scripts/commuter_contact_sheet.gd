extends Control
## Opt-in native review of the imported drawings, not a gameplay overlay.
var definition:Dictionary
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("d7d1bf"))
	var font:=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
	for row in 4:
		var direction:String=["front","back","left","right"][row]
		var clip:Dictionary=definition.clips["walk_"+direction]
		var texture:Texture2D=load(clip.texture)
		var scale:float=195.0/float(clip.height)
		var baseline:float=253+row*250
		draw_string(font,Vector2(10,baseline-214),direction.to_upper()+" / 12 DRAWN POSES",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("272332"))
		for i in 12:
			var frame:Dictionary=clip.frames[i];var r:Array=frame.region;var p:Array=frame.pivot
			var x:float=64+i*128
			draw_line(Vector2(x-60,baseline),Vector2(x+60,baseline),Color("acaa98"))
			var at:=Vector2(x+(float(r[0])-float(p[0]))*scale,baseline+(float(r[1])-float(p[1]))*scale)
			draw_texture_rect_region(texture,Rect2(at,Vector2(r[2],r[3])*scale),Rect2(r[0],r[1],r[2],r[3]))
