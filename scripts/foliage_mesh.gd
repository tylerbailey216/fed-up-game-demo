extends RefCounted
## Deterministic irregular crowns, sharing the original sphere triangle budget.
## Visual geometry only: trunk collision, vegetation probes and LOD stay separate.
static func crown(radius:=.5,height:=1.0,radial:=8,rings:=4) -> ArrayMesh:
	var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=height
	sphere.radial_segments=radial;sphere.rings=rings
	var arrays:=sphere.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var face:Array[Vector3]=[]
		for j in 3:
			var at:Vector3=vertices[indices[i+j]]
			var angle:=atan2(at.z,at.x);var level:=at.y/maxf(.01,height*.5)
			var contour:=1.0+.07*sin(angle*3.0+level*1.3)+.04*cos(angle*5.0-level*2.1)
			face.append(Vector3(at.x*contour,at.y*(1.0+.04*cos(angle*3.0)),at.z*contour))
		var normal:Vector3=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
		if normal.dot((face[0]+face[1]+face[2])/3)<0:normal=-normal
		for at in face:tool.set_normal(normal);tool.add_vertex(at)
	return tool.commit()
