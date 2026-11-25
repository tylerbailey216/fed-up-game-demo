extends Button
var vehicle:Dictionary
var picture:Texture2D
var locked:=true
var picked:=false
var ui_ratio:=1.0
func _draw() -> void:
	var ink:=Color("15131f");var gold:=Color("ffd044");var cream:=Color("f3ebd8")
	var rect:=Rect2(Vector2(4,4),size-Vector2(8,8))
	draw_style_box(panel(Color("352343") if picked else Color("20232f"),gold if picked else Color("766583")),rect)
	var font:=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
	var ratio:=ui_ratio
	var title:=str(vehicle.name)
	draw_string(font,Vector2(16,32),title,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted_font(font,title,maxi(25,roundi(14*ratio)),size.x-32),gold if picked else cream)
	if picture:
		var area:=Rect2(12,43,size.x-24,maxf(20,size.y-104))
		var fitted:=picture.get_size();fitted*=minf(area.size.x/fitted.x,area.size.y/fitted.y)
		draw_texture_rect(picture,Rect2(area.get_center()-fitted*.5,fitted),false,Color.BLACK if locked else Color.WHITE)
	if locked:
		var center:=Vector2(size.x-32,size.y-35)
		draw_arc(center-Vector2(0,8),9,PI,TAU,20,gold,3,true)
		draw_rect(Rect2(center-Vector2(12,8),Vector2(24,20)),gold)
		draw_circle(center+Vector2(0,0),2.5,ink)
	var caption:="LOCKED / %d DELIVERIES" % int(vehicle.deliveries) if locked else ("SELECTED" if picked else "AVAILABLE")
	draw_string(font,Vector2(16,size.y-23),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted_font(font,caption,maxi(20,roundi(12*ratio)),size.x-(72 if locked else 32)),cream)

func fitted_font(font:Font,value:String,target:int,width:float) -> int:
	return mini(target,maxi(10,floori(target*maxf(1,width)/maxf(1,font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,target).x))))

func panel(fill:Color,line:Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=line;style.set_border_width_all(3);style.set_corner_radius_all(10);return style
