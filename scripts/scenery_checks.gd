extends Node
## Regression for filled-black inverted-hull facades and unchanged solid faces.
func face_key(points:Array) -> String:
	var keys:PackedStringArray=[]
	for point in points:keys.append(str(point.snapped(Vector3.ONE*.001)))
	keys.sort();return "|".join(keys)

func run(game:Node) -> Array[String]:
	var failures:Array[String]=[];var buildings:=0;var triangles:=0
	for node in game.highway.get_children():
		if not node is MeshInstance3D or not node.has_meta("review_facade"):continue
		buildings+=1
		var arrays:Array=node.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var physical:=PackedVector3Array()
		for body in node.get_children():
			if body is StaticBody3D:
				for child in body.get_children():
					if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:physical=child.shape.get_faces()
		if physical.is_empty() or physical.size()>vertices.size():failures.append("Facade collision faces missing");continue
		var original:Dictionary={}
		for i in range(0,physical.size(),3):
			var key:=face_key([physical[i],physical[i+1],physical[i+2]])
			original[key]=int(original.get(key,0))+1
		for i in range(0,vertices.size(),3):
			triangles+=1
			var cross:Vector3=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
			if cross.length_squared()>.000001 and cross.normalized().dot(normals[i])>-.99:
				failures.append("Facade winding exposes its ink pass");break
			if i<physical.size():
				var key:=face_key([vertices[i],vertices[i+1],vertices[i+2]])
				if int(original.get(key,0))<=0:failures.append("Facade footprint differs from original collision");break
				original[key]-=1
	if buildings==0:failures.append("No Open Road facades checked")
	print("SCENERY CHECK buildings=",buildings," triangles=",triangles)
	return failures
