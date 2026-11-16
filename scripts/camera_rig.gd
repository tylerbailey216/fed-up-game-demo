extends RefCounted
## Sweep a near-plane-sized sphere so the view stays in front of world geometry.
var sphere:=SphereShape3D.new()

func resolve(space:PhysicsDirectSpaceState3D,focus:Vector3,desired:Vector3,excluded:Array[RID]) -> Vector3:
	var motion:=desired-focus
	if motion.length()<.05:return desired
	sphere.radius=.28
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere
	query.transform=Transform3D(Basis.IDENTITY,focus);query.motion=motion
	query.collision_mask=1;query.exclude=excluded;query.margin=.04
	var result:=space.cast_motion(query)
	return focus+motion*maxf(0,result[0]-.08/motion.length()) if result[0]<1 else desired
