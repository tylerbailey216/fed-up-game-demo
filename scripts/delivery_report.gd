extends Control
## End-of-run dispatch slip. Only opens after gameplay has finished.
const FACE=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const LOGO=preload("res://assets/fonts/Bangers-Regular.ttf")
const Ink=preload("res://scripts/dashboard_ink.gd")
var game:Node
var replay:Button
var was_open:=false
var design:=Vector2(620,430)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	replay=Button.new();replay.text="ONE MORE DELIVERY";replay.theme=game.menu.theme
	replay.add_theme_font_override("font",LOGO);replay.add_theme_font_size_override("font_size",28)
	replay.pressed.connect(func():game.touch_controls.release_inputs();game.cargo.next_stage())
	add_child(replay);hide()

func _process(_delta:float) -> void:
	var open:bool=game.driving and game.cargo.complete and not game.paused and not game.options.visible
	visible=open
	if not open:was_open=false;return
	var viewport_size:=get_viewport_rect().size
	var factor:=minf(1.4,minf((viewport_size.x-48)/design.x,(viewport_size.y-64)/design.y))
	scale=Vector2.ONE*factor;size=design;position=(viewport_size-design*factor)*.5
	replay.position=Vector2(36,346);replay.size=Vector2(548,62)
	if not was_open:
		game.touch_controls.release_inputs();replay.grab_focus();queue_redraw()
	was_open=true

func words(at:Vector2,value:String,px:int,tone:=Color("f3ebd8"),face:Font=FACE) -> void:
	draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tone)

func _draw() -> void:
	if not game.cargo or not game.cargo.arcade_run:return
	var run:Node=game.cargo.arcade_run
	Ink.plate(self,Rect2(Vector2.ZERO,design),false,true)
	draw_rect(Rect2(14,14,592,83),Color("48265f"))
	Ink.hatch(self,Rect2(14,14,592,9))
	words(Vector2(32,59),"FedUp / DISPATCH REPORT",38,Color("ffd044"),LOGO)
	words(Vector2(34,84),"DELIVERY MAYHEM  /  CLEVELAND BLOCK",18,Color("d9c0e4"))
	words(Vector2(34,137),run.verdict(),26,Color("ffd044"),LOGO)
	var rows:Array=[["MANIFEST","%02d / %02d DELIVERED" % [game.cargo.quota,game.cargo.quota]],["ROUND TIME",run.time_text()+" / NO DEADLINE"],["TRUCK ENERGY USED","%d%%" % roundi(run.energy_used)],["PACKAGE SCRAMBLE","%02d AUTO-COLLECTED" % game.cargo.recovered if game.cargo.spilled else "LOAD STAYED SECURED"]]
	for i in rows.size():
		var y:float=174+i*35
		words(Vector2(36,y),rows[i][0],18,Color("b9a8c6"));words(Vector2(302,y),rows[i][1],21)
		draw_line(Vector2(36,y+10),Vector2(584,y+10),Color("504052"),1,true)
	words(Vector2(36,326),"ALL PACKAGES ACCOUNTED FOR. DISPATCH CAN EXHALE.",18,Color("8de0e9"))
