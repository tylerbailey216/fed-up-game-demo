extends RefCounted
## Original articulated 3D interpretation of the matching Thanksgiving illustration.
var m:RefCounted
const BROWN=Color("a3441d")
const LIGHT=Color("c65e28")
const SKIN=Color("ffb64c")

func build(maker:RefCounted) -> void:
	m=maker
	# Fan feathers are individually rounded, tipped and inked, never a billboard.
	for i in 9:
		var angle:float=(i-4)*.27
		var center:=Vector3(sin(angle)*1.12,2.85+cos(angle)*.2,1.7)
		var feather:MeshInstance3D=m.ball(center,Vector3(.7,2.35,.23),BROWN if i%2 else LIGHT)
		feather.rotation.z=-angle
		var tip:MeshInstance3D=m.ball(center+Vector3(sin(angle),cos(angle),0)*.84,Vector3(.69,.75,.25),m.CREAM);tip.rotation.z=-angle
		m.rod(center-Vector3(sin(angle),cos(angle),0)*.7,center+Vector3(sin(angle),cos(angle),0)*.55,.022,Color("72321e"))
	m.ball(Vector3(0,1.9,.05),Vector3(2.45,2.05,3.2),BROWN)
	m.ball(Vector3(0,2.2,-1.0),Vector3(1.8,1.75,1.7),LIGHT)
	# Layered breast/wing contours, chest harness and parcel saddle.
	for side in [-1,1]:
		for i in 4:
			var feather:MeshInstance3D=m.ball(Vector3(side*(1.23-i*.03),1.85-i*.13,-.05+i*.22),Vector3(.50,.54,1.18-i*.10),LIGHT if i%2==0 else BROWN)
			feather.rotation.x=-.25
		m.rod(Vector3(side*.7,2.4,-1.24),Vector3(side*.82,1.4,-1.14),.10,m.PURPLE)
		m.rod(Vector3(side*.82,1.4,-1.14),Vector3(0,1.2,-1.35),.10,m.PURPLE)
		m.ball(Vector3(side*.74,2.26,-1.39),Vector3(.2,.2,.12),m.GOLD)
		m.box(Vector3(side*1.25,2.06,.65),Vector3(.7,.95,1.3),m.PURPLE)
		m.box(Vector3(side*1.25,2.55,.65),Vector3(.74,.16,1.34),m.PURPLE)
		m.box(Vector3(side*1.62,2.05,.65),Vector3(.04,.58,1.12),m.CREAM)
		m.box(Vector3(side*1.64,2.1,.32),Vector3(.05,.94,.13),m.ORANGE)
		m.box(Vector3(side*1.66,2.43,.32),Vector3(.06,.18,.19),m.GOLD)
		m.brand(Vector3(side*1.65,2.08,.8),side*PI/2,.60)
		leg(side)
	m.box(Vector3(0,2.85,.15),Vector3(1.2,.18,1.6),m.PURPLE)
	for i in 3:
		m.box(Vector3((i%2-.5)*.65,2.95+floori(i/2.0)*.5,1.12),Vector3(.65,.48,.68),Color("dfae70"))
		m.box(Vector3((i%2-.5)*.65,3.2+floori(i/2.0)*.5,1.12),Vector3(.13,.025,.7),m.PURPLE)
	# Friendly expressive bird face; golden beak, red wattle, white eyes.
	m.ball(Vector3(0,2.93,-1.38),Vector3(.94,1.4,.9),BROWN)
	m.ball(Vector3(0,3.38,-1.55),Vector3(1.0,1.05,1.0),LIGHT)
	m.ball(Vector3(0,3.18,-2.05),Vector3(.85,.43,.8),m.GOLD)
	m.ball(Vector3(0,2.94,-2.03),Vector3(.57,.21,.53),m.GOLD)
	m.ball(Vector3(0,2.75,-1.92),Vector3(.37,.83,.34),Color("f43b43"))
	for side in [-1,1]:
		m.ball(Vector3(side*.39,3.58,-1.86),Vector3(.37,.53,.19),m.CREAM)
		m.ball(Vector3(side*.39,3.57,-1.97),Vector3(.18,.31,.09),m.INK)
		m.ball(Vector3(side*.37,3.67,-2.02),Vector3(.075,.10,.025),Color.WHITE)
		m.rod(Vector3(side*.22,3.91,-1.82),Vector3(side*.48,3.91,-1.73),.035,m.INK)
		m.rod(Vector3(side*.35,3.15,-1.55),Vector3(side*.4,3.27,-1.48),.07,m.PURPLE)
	# Seated established FedUp worker: white yoke, purple uniform, amber face,
	# compact cap/head proportions, pockets, articulated-looking arms and boots.
	m.batch()
	var bird:Node3D=m.root
	var rider:=Node3D.new();rider.name="TurkeyRider";bird.add_child(rider);m.root=rider
	m.ball(Vector3(0,3.18,.08),Vector3(.86,.78,.67),m.PURPLE)
	m.ball(Vector3(0,3.47,.06),Vector3(.92,.4,.7),m.CREAM)
	m.box(Vector3(0,3.23,-.28),Vector3(.035,.55,.04),m.INK)
	for side in [-1,1]:
		m.box(Vector3(side*.24,3.25,-.29),Vector3(.24,.18,.06),m.PURPLE)
		m.box(Vector3(side*.24,3.36,-.33),Vector3(.25,.035,.025),m.ORANGE)
		m.rod(Vector3(side*.81,2.63,-.15),Vector3(side*.94,2.20,-.29),.025,m.ORANGE)
		m.rod(Vector3(side*.4,3.45,-.02),Vector3(side*.58,3.14,-.43),.15,m.PURPLE)
		m.rod(Vector3(side*.58,3.14,-.43),Vector3(side*.38,3.16,-.73),.13,SKIN)
		m.ball(Vector3(side*.38,3.16,-.73),Vector3(.3,.3,.3),SKIN)
		m.rod(Vector3(side*.3,2.99,.02),Vector3(side*.75,2.68,-.04),.23,m.PURPLE)
		m.rod(Vector3(side*.75,2.68,-.04),Vector3(side*.87,2.14,-.24),.20,m.PURPLE)
		m.ball(Vector3(side*.88,2.06,-.36),Vector3(.43,.38,.68),Color("815828"))
		m.box(Vector3(side*.88,1.91,-.36),Vector3(.45,.08,.7),m.INK)
		m.rod(Vector3(side*.38,3.16,-.76),Vector3(side*.4,3.28,-1.48),.035,m.GOLD)
	m.ball(Vector3(0,3.98,-.05),Vector3(.86,.85,.76),SKIN)
	for side in [-1,1]:
		m.ball(Vector3(side*.44,3.96,-.05),Vector3(.15,.28,.17),SKIN)
		m.ball(Vector3(side*.18,4.0,-.407),Vector3(.09,.16,.055),m.INK)
	m.ball(Vector3(0,3.89,-.455),Vector3(.10,.09,.09),SKIN)
	m.rod(Vector3(-.09,3.79,-.4),Vector3(0,3.76,-.43),.018,m.INK)
	m.rod(Vector3(0,3.76,-.43),Vector3(.09,3.79,-.4),.018,m.INK)
	m.ball(Vector3(0,4.29,-.035),Vector3(.98,.65,.89),m.PURPLE)
	m.rod(Vector3(0,4.60,-.05),Vector3(0,4.49,-.39),.018,m.ORANGE)
	m.box(Vector3(0,4.36,-.43),Vector3(.66,.3,.08),m.CREAM)
	m.brand(Vector3(0,4.36,-.478),PI,.38)
	m.ball(Vector3(0,4.12,-.37),Vector3(1.04,.13,.68),m.ORANGE)
	m.ball(Vector3(0,4.14,-.38),Vector3(1.0,.09,.68),m.PURPLE)
	m.batch();m.root=bird

func leg(side:float) -> void:
	var hip:=Node3D.new();hip.name="TurkeyLeg_"+str(side);hip.position=Vector3(side*.68,1.2,.25);hip.set_meta("gait_phase",0.0 if side<0 else PI);m.root.add_child(hip)
	var knee:=Node3D.new();knee.name="Knee";knee.position.y=-.58;hip.add_child(knee)
	for joint in [hip,knee]:
		var bone:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.11;mesh.bottom_radius=.09;mesh.height=.56;mesh.radial_segments=12
		bone.mesh=mesh;bone.position.y=-.28;bone.material_override=m.art.material(m.GOLD,true);joint.add_child(bone)
	for toe in [-1,0,1]:
		var mesh:=CapsuleMesh.new();mesh.radius=.075;mesh.height=.55;mesh.radial_segments=10;mesh.rings=4
		var foot:=MeshInstance3D.new();foot.mesh=mesh;foot.position=Vector3(toe*.13,-.56,-.22);foot.rotation=Vector3(PI/2,0,toe*.3);foot.material_override=m.art.material(m.GOLD,true);knee.add_child(foot)
