extends RigidBody3D
## Contact telemetry only. Godot resolves motion/rotation and contact impulses.
var supported:=false
var contact_serial:=0
var contact_speed:=0.0
var contact_normal:=Vector3.UP
var previous_linear:=Vector3.ZERO
var previous_angular:=Vector3.ZERO
var previous_contact:=false
var air_gap:=0.0
func _integrate_forces(state:PhysicsDirectBodyState3D) -> void:
	supported=false
	var peak:=0.0;var normal:=Vector3.UP
	for i in state.get_contact_count():
		var n:=state.get_contact_local_normal(i).normalized()
		if n.y>.45:supported=true
		var arm:=state.get_contact_local_position(i)-(state.transform.origin+state.center_of_mass)
		var relative:=previous_linear+previous_angular.cross(arm)-state.get_contact_collider_velocity_at_position(i)
		var closing:=maxf(0,-relative.dot(n))
		if closing>peak:peak=closing;normal=n
	if state.get_contact_count()>0 and not previous_contact and air_gap>.08:
		contact_serial+=1;contact_speed=peak;contact_normal=normal
	air_gap=0.0 if state.get_contact_count()>0 else air_gap+state.step
	previous_contact=state.get_contact_count()>0
	previous_linear=state.linear_velocity;previous_angular=state.angular_velocity
