extends Node3D
## One world bearing for truck and worker. Following never changes the angle.
const BEARING:=0.0 # Streets and directional controls share the screen axes.
const ELEVATION:=PI/3
const Layout=preload("res://scripts/hud_layout.gd")
var game:Node
var preset:=0
var focus_position:=Vector3.ZERO
var initialized:=false
var followed:Node3D
var truck_outline:MeshInstance3D

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	# A low illustrated footprint keeps the parked truck legible during cutaway.
	truck_outline=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(2.65,.18,6.2);truck_outline.mesh=shape
	truck_outline.material_override=game.highway.art.material(Color("9470af"),true)
	game.van.add_child(truck_outline);truck_outline.position.y=.22;truck_outline.hide()

func cycle_view() -> void:
	preset=(preset+1)%2;update_camera(0)
	game.van.notify_driver("FIXED OVERVIEW / VIEW FOR CLOSER" if preset==1 else "FIXED PLAY VIEW / VIEW FOR WIDER")

func recenter() -> void:
	preset=0;update_camera(0)
	game.van.notify_driver("FIXED PLAY VIEW / SAME ANGLE FOR DRIVING AND WALKING")

func _process(delta:float) -> void:
	if game.driving:update_camera(delta)

func update_camera(delta:=0.0) -> void:
	if not game.cargo:return
	var walking:bool=game.cargo.on_foot
	var subject:Node3D=game.cargo.actor if walking else game.van
	var camera:Camera3D=game.cargo.actor.camera if walking else game.van.camera
	game.van.cockpit=false;game.van.camera_high=true
	game.van.camera_orbit=0;game.van.camera_pitch=0;game.van.camera_zoom=1
	game.cargo.actor.camera_angle=BEARING;game.cargo.actor.camera_pitch=0;game.cargo.actor.camera_zoom=1
	var focus:Vector3=subject.global_position+Vector3.UP*(1.0 if walking else 1.6)
	# Smooth translation only. Transfers, teleports and preset changes snap once.
	if not initialized or followed!=subject or delta<=0 or focus.distance_squared_to(focus_position)>400:
		focus_position=focus;initialized=true;followed=subject
	else:focus_position=focus_position.lerp(focus,1-exp(-12*delta))
	var viewport_size:=get_viewport().get_visible_rect().size
	var aspect:=viewport_size.x/maxf(1,viewport_size.y)
	camera.fov=64;camera.keep_aspect=Camera3D.KEEP_HEIGHT
	var distance:float=(24.0 if walking else 32.0)*(1.28 if preset==1 else 1.0)
	# Preserve useful horizontal room on narrow phones without stretching art.
	if aspect<.8:distance*=1.18
	var offset:=Basis(Vector3.UP,BEARING)*Vector3(0,sin(ELEVATION),cos(ELEVATION))*distance
	camera.global_position=focus_position+offset;camera.look_at(focus_position)
	# Keep the subject in the clear gameplay region, above the illustrated deck.
	# A camera-local vertical shift changes framing without tilting or orbiting.
	var center_y:=viewport_size.y*.49
	if game.dashboard and game.dashboard.compact_layout():
		var factor:float=viewport_size.x/720
		center_y=Layout.scene_rect(viewport_size.y/factor).get_center().y*factor
	var visible_height:float=2*distance*tan(deg_to_rad(camera.fov)*.5)
	camera.global_position+=camera.global_basis.y*((center_y/viewport_size.y-.5)*visible_height)
	if not camera.is_current():camera.make_current()
	game.highway.update_cutaways(camera,focus,walking,delta)
	# The parked truck stays solid. Hide its drawing only when it covers the worker.
	var truck_covers_worker:=false
	if walking:
		var from:=camera.global_position
		# Oriented truck bounds: transform the sight line into its local space.
		from=game.van.to_local(from)
		var to:Vector3=game.van.to_local(subject.global_position+Vector3.UP)
		if game.highway.segment_covers(from,to,Vector3(-1.5,-.1,-3.3),Vector3(1.5,4.1,3.3)):
			truck_covers_worker=true
	game.van.body.visible=not truck_covers_worker
	truck_outline.visible=truck_covers_worker
