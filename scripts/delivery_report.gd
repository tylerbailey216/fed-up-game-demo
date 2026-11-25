extends Control
## End-of-run dispatch slip. Only opens after gameplay has finished.
const FACE=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const LOGO=preload("res://assets/fonts/Bangers-Regular.ttf")
const Ink=preload("res://scripts/dashboard_ink.gd")
var game:Node
var replay:Button
var garage:Button
var was_open:=false
const REVEAL_SECONDS:=.62
var design:=Vector2(620,454)
var compact:=false
var report_age:=0.0
var animation_progress:=0.0
var displayed_manifest:=0
var displayed_seconds:=0
var displayed_energy:=0
var displayed_recovered:=0
var last_viewport:=Vector2.ZERO

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	replay=Button.new();replay.text="ONE MORE DELIVERY";replay.theme=game.menu.theme
	replay.add_theme_font_override("font",LOGO);replay.add_theme_font_size_override("font_size",28)
	replay.pressed.connect(func():game.touch_controls.release_inputs();game.cargo.next_stage())
	add_child(replay);hide()
	garage=Button.new();garage.text="VEHICLE GARAGE";garage.theme=game.menu.theme
	garage.add_theme_font_override("font",LOGO);garage.add_theme_font_size_override("font_size",20)
	garage.pressed.connect(func():game.return_to_menu();game.open_garage());add_child(garage)

func _process(delta:float) -> void:
	if not game.cargo.complete:
		visible=false;was_open=false;report_age=0;animation_progress=0
		return
	var open:bool=game.driving and not game.paused and not game.options.visible
	visible=open
	# Main runs while paused; the report must freeze rather than restarting its
	# reveal when settings or the pause menu is closed.
	if not open:return
	var viewport_size:=get_viewport_rect().size
	compact=viewport_size.y/maxf(1,viewport_size.x)>1.45
	design=Vector2(364,498) if compact else Vector2(620,454)
	var factor:=minf(2.0 if compact else 1.4,minf((viewport_size.x-32)/design.x,(viewport_size.y-32)/design.y))
	var previous_progress:=animation_progress
	if not was_open:
		game.touch_controls.release_inputs();replay.grab_focus()
		report_age=0;animation_progress=0
	report_age=minf(REVEAL_SECONDS,report_age+delta)
	animation_progress=clampf(report_age/REVEAL_SECONDS,0,1)
	var settle:=1.0-pow(1.0-animation_progress,3)
	scale=Vector2.ONE*factor;size=design
	position=(viewport_size-design*factor)*.5+Vector2(0,(1-settle)*14*factor)
	modulate=Color(1,1,1,.82+.18*settle)
	replay.position=Vector2(24,426) if compact else Vector2(36,368)
	replay.size=Vector2(152,54) if compact else Vector2(350,62)
	replay.text="DRIVE AGAIN" if compact else "ONE MORE DELIVERY"
	garage.position=Vector2(188,426) if compact else Vector2(398,368)
	garage.size=Vector2(152,54) if compact else Vector2(186,62)
	# The completion button is live from the first frame. Results never impose
	# an extra confirmation, wait or reward gate on a finished delivery.
	var button_px:=21 if compact else 28
	if replay.get_theme_font_size("font_size")!=button_px:replay.add_theme_font_size_override("font_size",button_px)
	update_displayed_stats()
	if not was_open or previous_progress!=animation_progress or last_viewport!=viewport_size:queue_redraw()
	last_viewport=viewport_size
	was_open=true

func row_progress(index:int) -> float:
	var value:=clampf((report_age-index*.035)/.48,0,1)
	return 1.0-pow(1.0-value,3)

func update_displayed_stats() -> void:
	var run:Node=game.cargo.arcade_run
	if not run:return
	displayed_manifest=roundi(game.cargo.quota*row_progress(0))
	displayed_seconds=roundi(floori(run.elapsed)*row_progress(1))
	displayed_energy=roundi(run.energy_used*row_progress(2))
	displayed_recovered=roundi(game.cargo.recovered*row_progress(3))

func words(at:Vector2,value:String,px:int,tone:=Color("f3ebd8"),face:Font=FACE) -> void:
	draw_string(face,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tone)

func wrapped(at:Vector2,value:String,px:int,width:float,tone:Color,face:Font=FACE) -> void:
	var line:="";var y:=at.y
	for word in value.split(" "):
		var candidate:=word if line.is_empty() else line+" "+word
		if not line.is_empty() and face.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>width:
			words(Vector2(at.x,y),line,px,tone,face);line=word;y+=px+3
		else:line=candidate
	if not line.is_empty():words(Vector2(at.x,y),line,px,tone,face)

func completion_seal(at:Vector2) -> void:
	var stamp:=clampf((report_age-.2)/.34,0,1)
	var tone:=Color("8de0e9");tone.a=.35+.65*stamp
	var width:=266.0 if compact else 548.0
	draw_line(at,at+Vector2(width,0),Color("66516c"),1,true)
	var tick:=PackedVector2Array([at+Vector2(2,16),at+Vector2(7,21),at+Vector2(17,9)])
	draw_polyline(tick,Color("10121e"),6,true);draw_polyline(tick,tone,3,true)
	var unlocked:bool=not game.cargo.unlocked_names.is_empty()
	words(at+Vector2(26,22),"NEW RIDE UNLOCKED!" if unlocked else "MANIFEST COMPLETE",20,tone,LOGO)
	if not compact:words(at+Vector2(237,22),str(game.cargo.unlocked_names[0]) if unlocked else "DISPATCH CAN EXHALE.",17,Color("b9a8c6"))

func _draw() -> void:
	if not game.cargo or not game.cargo.arcade_run:return
	var run:Node=game.cargo.arcade_run
	Ink.plate(self,Rect2(Vector2.ZERO,design),false,true)
	var left:=24.0 if compact else 36.0
	draw_rect(Rect2(14,14,design.x-28,83),Color("48265f"))
	Ink.hatch(self,Rect2(14,14,design.x-28,9))
	words(Vector2(left,57),"FedUp / DISPATCH REPORT",28 if compact else 38,Color("ffd044"),LOGO)
	words(Vector2(left,83),"DELIVERY MAYHEM / ROUND COMPLETE",15 if compact else 18,Color("d9c0e4"))
	wrapped(Vector2(left,129 if compact else 137),run.verdict(),22 if compact else 26,design.x-left*2,Color("ffd044"),LOGO)
	var time_value:="%d:%02d" % [displayed_seconds/60,displayed_seconds%60]
	var rows:Array=[["MANIFEST","%02d / %02d DELIVERED" % [displayed_manifest,game.cargo.quota]],["ROUND TIME",time_value+" / NO DEADLINE"],["TRUCK ENERGY USED","%d%%" % displayed_energy],["PACKAGE SCRAMBLE","%02d AUTO-COLLECTED" % displayed_recovered if game.cargo.spilled else "LOAD STAYED SECURED"]]
	for i in rows.size():
		var y:float=(179+i*54) if compact else (180+i*40)
		var tone:=Color("f3ebd8");tone.a=.5+.5*row_progress(i)
		words(Vector2(left,y),rows[i][0],15 if compact else 18,Color("b9a8c6"))
		words(Vector2(left if compact else 302,y+24 if compact else y),rows[i][1],22 if compact else 21,tone)
		draw_line(Vector2(left,y+33 if compact else y+11),Vector2(design.x-left,y+33 if compact else y+11),Color("504052"),1,true)
	completion_seal(Vector2(left,391 if compact else 327))
