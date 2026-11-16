extends RefCounted

static func build(parent:Node3D,size:float,art:RefCounted) -> void:
	var box:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(size,size*.85,size*.8);box.mesh=mesh;box.material_override=art.material(Color("c6985e"),true);parent.add_child(box)
	for axis in [0,1]:
		var tape:=MeshInstance3D.new();var strip:=BoxMesh.new();strip.size=Vector3(size*.17,.012,size*.82) if axis==0 else Vector3(size*1.01,.014,size*.14);tape.mesh=strip;tape.position.y=size*.43;tape.material_override=art.material(Color("6d3a8b"));parent.add_child(tape)
	var label:=MeshInstance3D.new();var card:=BoxMesh.new();card.size=Vector3(size*.4,size*.25,.015);label.mesh=card;label.position=Vector3(0,0,-size*.405);label.material_override=art.material(Color("f5edda"));parent.add_child(label)
