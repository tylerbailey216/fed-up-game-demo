extends Control
var outerbelt:=false
const HERO=preload("res://assets/art/presentation/cleveland-key-art.png")
const HEADING=preload("res://assets/fonts/Bangers-Regular.ttf")
const BODY=preload("res://assets/fonts/BarlowCondensed-Medium.ttf")
const CREAM=Color("fff1da")
const GOLD=Color("ffd04d")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func title(at:Vector2,value:String,px:int,color:Color) -> void:
	draw_string_outline(HEADING,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,9,Color("100b18"))
	draw_string(HEADING,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func artwork(rect:Rect2) -> void:
	draw_rect(rect.grow(6),Color("110d18"))
	draw_rect(rect.grow(8),GOLD,false,2)
	draw_texture_rect(HERO,rect,false)
	draw_line(rect.position-Vector2(10,9),rect.position+Vector2(58,-9),Color("ff941e"),6,true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("21142e"))
	for i in range(-10,40):draw_line(Vector2(i*85,0),Vector2(i*85-size.y*.6,size.y),Color(.7,.4,.8,.035),2)
	var compact:=size.x/maxf(1,size.y)<1.6
	if compact:
		var factor:=size.x/720;var h:=size.y/factor
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
		title(Vector2(34,82),"Fed",66,CREAM);title(Vector2(127,82),"Up",66,Color("ff941e"));title(Vector2(231,82),"DRIVER",66,GOLD)
		draw_string(BODY,Vector2(36,113),"CLEVELAND / EVERY PACKAGE COUNTS",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("cfb0dc"))
		var width:=minf(656,h*.3*1.5)
		artwork(Rect2((720-width)/2,141,width,width/1.5))
		return
	var factor:=minf(size.x/1280,size.y/720)
	draw_set_transform((size-Vector2(1280,720)*factor)/2,0,Vector2.ONE*factor)
	draw_string(BODY,Vector2(36,42),"CLEVELAND DELIVERY ADVENTURE",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("cfb0dc"))
	title(Vector2(34,133),"Fed",96,CREAM);title(Vector2(173,133),"Up",96,Color("ff941e"));title(Vector2(325,133),"DRIVER",96,GOLD)
	draw_string(BODY,Vector2(38,185),"YOUR TRUCK. YOUR CITY. EVERY PACKAGE COUNTS.",HORIZONTAL_ALIGNMENT_LEFT,-1,25,CREAM)
	artwork(Rect2(38,236,672,448))
