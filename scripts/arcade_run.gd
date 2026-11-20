extends Node3D
## Ordered route progress and an untimed delivery run; no forced opening crash.
var cargo:Node
var route_index:=0
var elapsed:=0.0
var energy_used:=0.0
var marker:Node3D
var route_label:Label3D

func _ready() -> void:
	marker=Node3D.new();add_child(marker)
	for side in [-1,1]:
		cargo.game.highway.block(marker,Vector3(side*5.7,.025,0),Vector3(.5,.025,5),Color("9a65d1"))
	route_label=Label3D.new();route_label.font=preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
	route_label.font_size=52;route_label.pixel_size=.018;route_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	route_label.outline_size=10;route_label.modulate=Color("c995ff");route_label.position.y=4.3;marker.add_child(route_label)
	refresh_marker()

func reset() -> void:
	route_index=0;elapsed=0;energy_used=0;refresh_marker()
	var van:Node=cargo.game.van
	van.camera_high=true;van.camera_orbit=0;van.camera_pitch=0;van.camera_zoom=1;van.set_view(false)
	if is_instance_valid(cargo.game.fixed_camera):cargo.game.fixed_camera.recenter()

func target() -> Vector3:
	var points:Array=cargo.game.highway.route_points
	return points[route_index] if route_index<points.size() else cargo.checkpoint_position

func route_finished() -> bool:
	return route_index>=cargo.game.highway.route_points.size()

func refresh_marker() -> void:
	marker.visible=not route_finished()
	if not marker.visible:return
	marker.position=target();route_label.text="ROUTE %d / %d\nDRIVE THROUGH" % [route_index+1,cargo.game.highway.route_points.size()]
	var previous:Vector3=cargo.game.highway.spawn_position if route_index==0 else cargo.game.highway.route_points[route_index-1]
	var direction:Vector3=target()-previous;marker.rotation.y=atan2(-direction.x,-direction.z)

func update(delta:float) -> void:
	if cargo.complete:return
	elapsed+=delta
	var van:Node=cargo.game.van
	if route_finished() or cargo.on_foot or van.wrecked or van.overturned or van.stunts.active:return
	var gap:Vector3=van.position-target()
	if Vector2(gap.x,gap.z).length()<14 and absf(gap.y)<2 and van.is_on_floor():
		var cleared:Vector3=target()
		route_index+=1;refresh_marker()
		if is_instance_valid(cargo.game.get("gameplay_feedback")):cargo.game.gameplay_feedback.checkpoint(cleared,route_index,cargo.game.highway.route_points.size())
		cargo.show_popup("ROUTE CLEAR / STOP AT THE GOLD COLLECTION BAY" if route_finished() else "ROUTE %d / %d CLEARED" % [route_index,cargo.game.highway.route_points.size()])

func guidance() -> String:
	if route_finished():return "STOP AT GOLD BAY / FULL STOP TO DELIVER"
	return "ROUTE %d/%d / PURPLE MARKER / %d m" % [route_index+1,cargo.game.highway.route_points.size(),roundi(cargo.game.van.position.distance_to(target()))]

func time_text() -> String:
	var seconds:=floori(elapsed)
	return "%d:%02d" % [seconds/60,seconds%60]

func verdict() -> String:
	if cargo.spilled:return "SPECIAL DELIVERY. EXTRA MILEAGE."
	if energy_used>0:return "A FEW DENTS. EVERY BOX DELIVERED."
	return "SIGNED. SEALED. SUSPICIOUSLY INTACT."
