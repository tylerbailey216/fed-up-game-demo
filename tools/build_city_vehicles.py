"""Build the supplied FedUp vehicle lineup as original editable 3D models.

Blender 5.2: blender --background --python tools/build_city_vehicles.py
Coordinates are Godot X/right Y/up -Z/front. Materials and wheel pivots are
retained for the runtime vertex-color merge and articulated wheel shader.
"""
from pathlib import Path
import json,math
import bpy,bmesh
from mathutils import Vector,Matrix

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/traffic';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/source/traffic';SOURCE.mkdir(parents=True,exist_ok=True)
FONT=bpy.data.fonts.load(str(ROOT/'assets/fonts/BarlowCondensed-Bold.ttf'))
PALETTE={'ink':'202330','white':'f3ecd9','purple':'783da1','orange':'f68a25','glass':'477caa','shine':'a2d9ed','metal':'a9acb7','red':'d95048','yellow':'ffc638','olive':'929b4b','blue':'a2b8e2','black':'30323a','brake':'a52f3e','lamp':'ffe8a4'}
MATS={}
def mat(key):
    if key in MATS:return MATS[key]
    h=PALETTE.get(key,key);rgb=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
    m=bpy.data.materials.new('Brake_Live' if key=='brake' else 'FedUp_'+key);m.diffuse_color=(*rgb,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.87;MATS[key]=m;return m
def point(p):return Vector((p[0],-p[2],p[1]))
def box(name,p,size,color,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat(color))
    if bevel:
        b=o.modifiers.new('Rounded illustrated edges','BEVEL');b.width=bevel;b.segments=3;bpy.ops.object.modifier_apply(modifier=b.name)
        n=o.modifiers.new('Weighted cartoon planes','WEIGHTED_NORMAL');n.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=n.name)
    return o
def quad(name,points,color):
    center=sum((Vector(p) for p in points),Vector())/len(points)
    wanted=Vector((1 if center.x>0 else -1,0,0)) if name.startswith('Side') else Vector((0,0,-1))
    normal=(Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]))
    order=tuple(range(len(points))) if normal.dot(wanted)>0 else tuple(range(len(points)-1,-1,-1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([point(p) for p in points],[],[order]);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(mat(color));return o
def profile(name,width,points,color):
    n=len(points);verts=[point((side*width/2,y,z)) for side in [-1,1] for y,z in points]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(mat(color))
    bpy.context.view_layer.objects.active=o;o.select_set(True);b=o.modifiers.new('Soft cartoon shell','BEVEL');b.width=.075;b.segments=3;bpy.ops.object.modifier_apply(modifier=b.name);o.select_set(False);return o
def cylinder(name,p,radius,depth,color,axis='x',vertices=16):
    rot=(0,math.pi/2,0) if axis=='x' else ((math.pi/2,0,0) if axis=='z' else (0,0,0))
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=point(p),rotation=rot);o=bpy.context.object;o.name=name;o.data.materials.append(mat(color));return o
def text(value,p,width,color,normal=(0,0,-1)):
    bpy.ops.object.text_add(location=point(p));o=bpy.context.object;o.name='Lettering_'+value;o.data.body=value;o.data.font=FONT;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=.3;o.data.extrude=0;o.data.resolution_u=3
    bpy.context.view_layer.update();s=width/max(.001,o.dimensions.x);o.scale=(s,s,s)
    up=Vector((0,1,0));norm=Vector(normal);right=up.cross(norm)
    o.rotation_euler=Matrix((point(right),point(up),point(norm))).transposed().to_euler();o.data.materials.append(mat(color));bpy.ops.object.convert(target='MESH');return bpy.context.object
def branding(p,width,normal):
    right=Vector((0,1,0)).cross(Vector(normal));p=Vector(p)
    text('Fed',p-right*width*.20,width*.58,'purple',normal);text('Up',p+right*width*.28,width*.45,'orange',normal)
def wheels(width,axles,radius):
    positions=[]
    for axle,z in enumerate(axles):
        sides=[0] if width<1 else [-1,1]
        for side in sides:
            p=(side*width*.49,radius,z);pivot=bpy.data.objects.new('WheelPivot_'+('Front' if axle==0 else 'Rear')+'_'+str(axle)+'_'+str(side),None);bpy.context.collection.objects.link(pivot);pivot.location=point(p);bpy.context.view_layer.update()
            items=[cylinder('Rubber_tire',p,radius,.24,'ink'),cylinder('Wheel_sidewall',(p[0]+side*.125,p[1],p[2]),radius*.83,.02,'black'),cylinder('Silver_hub',(p[0]+side*.14,p[1],p[2]),radius*.53,.03,'metal'),cylinder('Hub_center',(p[0]+side*.16,p[1],p[2]),radius*.19,.035,'ink')]
            for o in items:o.parent=pivot;o.matrix_parent_inverse=pivot.matrix_world.inverted()
            positions.append(list(p))
    return positions
def cabin(width,front,back,top,color):
    # A shaped sloping windshield and rounded roof, not a stacked-box cab.
    nose=front-.03;wind_bottom=front+.46;wind_top=front+.88
    profile('Shaped_passenger_cabin',width,[(.83,nose),(1.03,wind_bottom),(top-.10,wind_top),(top,wind_top+.2),(top,back-.3),(top-.18,back),(.84,back+.26)],color)
    quad('Dark_windscreen_seal',[(-width*.45,1.06,wind_bottom-.04),(width*.45,1.06,wind_bottom-.04),(width*.43,top-.11,wind_top-.04),(-width*.43,top-.11,wind_top-.04)],'ink')
    quad('Blue_windscreen',[(-width*.41,1.10,wind_bottom-.06),(width*.41,1.10,wind_bottom-.06),(width*.39,top-.16,wind_top-.06),(-width*.39,top-.16,wind_top-.06)],'glass')
    quad('Windshield_glint',[(-width*.30,1.12,wind_bottom-.065),(-width*.19,1.12,wind_bottom-.065),(width*.01,top-.18,wind_top-.065),(-width*.10,top-.18,wind_top-.065)],'shine')
    for side in [-1,1]:
        x=side*(width/2+.01)
        quad('Side_window_seal',[(x,1.07,wind_bottom+.09),(x,top-.14,wind_top+.10),(x,top-.14,back-.25),(x,1.07,back+.03)],'ink')
        quad('Side_glass',[(x+side*.013,1.13,wind_bottom+.19),(x+side*.013,top-.20,wind_top+.17),(x+side*.013,top-.20,back-.32),(x+side*.013,1.13,back-.06)],'glass')
        box('Door_handle',(x+side*.03,.99,back-.14),(.045,.07,.23),'ink',.025)
        box('Door_seam',(x+side*.02,.78,back+.11),(.025,.45,.018),'ink',.006)
        box('Mirror',(x+side*.13,1.19,wind_bottom+.25),(.25,.16,.22),color,.07)
def front_details(w,z,y=.77,round_lamps=False):
    box('Front_bumper',(0,.48,z-.045),(w*1.02,.22,.22),'ink',.09)
    box('Grille',(0,y,z-.07),(w*.40,.31,.05),'ink',.055)
    for row in [-1,1]:box('Grille_bar',(0,y+row*.075,z-.11),(w*.32,.035,.025),'metal',.01)
    for side in [-1,1]:
        if round_lamps:
            cylinder('Headlight_seal',(side*w*.36,y,z-.085),.21,.05,'ink','z');cylinder('Headlight',(side*w*.36,y,z-.12),.16,.025,'lamp','z')
        else:
            box('Headlight_seal',(side*w*.35,y,z-.08),(.45,.30,.07),'ink',.08);box('Headlight',(side*w*.35,y,z-.13),(.35,.22,.035),'lamp',.06)
def rear_details(w,z):
    box('Rear_bumper',(0,.47,z+.05),(w,.18,.18),'ink',.07)
    for side in [-1,1]:box('Live_brake_lens',(side*w*.39,.8,z+.075),(.25,.25,.045),'brake',.055)
    box('License_plate',(0,.65,z+.08),(.45,.17,.03),'white',.025)

SPECS={
 'compact':(1.72,3.45,1.85,.37,[-1.02,1.02],850),
 'sedan':(1.96,4.55,1.72,.38,[-1.42,1.38],1250),
 'taxi':(1.90,4.08,1.90,.38,[-1.25,1.25],1200),
 'pickup':(2.04,4.90,2.02,.43,[-1.50,1.48],1800),
 'suv':(2.05,4.64,2.12,.44,[-1.43,1.43],1900),
 'delivery-van':(2.05,4.72,2.68,.42,[-1.42,1.45],2300),
 'box-truck':(2.34,6.15,3.10,.48,[-1.95,1.90],3800),
 'school-bus':(2.25,7.40,2.86,.47,[-2.45,2.45],5800),
 'city-bus':(2.30,7.60,2.86,.47,[-2.5,2.5],6400),
 'police':(1.96,4.55,1.92,.38,[-1.42,1.38],1450),
 'ambulance':(2.25,5.55,2.95,.44,[-1.75,1.70],3400),
 'tow-truck':(2.20,5.65,2.75,.45,[-1.80,1.65],3300),
 'dump-truck':(2.40,6.30,3.04,.49,[-2.03,1.05,2.15],5200),
 'scooter':(.74,1.92,1.54,.28,[-.66,.63],160),
}
metadata={}
for kind,(w,l,h,r,axles,mass) in SPECS.items():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    paint={'compact':'white','sedan':'blue','taxi':'yellow','pickup':'red','suv':'olive','police':'white','school-bus':'yellow','city-bus':'white','dump-truck':'yellow'}.get(kind,'white')
    if kind=='scooter':
        box('Footboard',(0,.35,0),(.65,.16,1.0),'purple',.12);box('Rear_cowling',(0,.65,.51),(.69,.63,.70),'purple',.19);box('Seat',(0,1.02,.38),(.64,.16,.64),'ink',.07)
        box('Leg_shield',(0,.89,-.46),(.58,1.02,.20),'white',.12);box('Handlebar',(0,1.28,-.55),(.83,.10,.10),'ink',.04);cylinder('Headlight',(0,1.20,-.69),.18,.12,'lamp','z')
        box('Rear_delivery_box',(0,1.20,.65),(.64,.65,.57),'white',.09)
        for side in [-1,1]:branding((side*.331,1.2,.65),.49,(side,0,0));box('Mirror_stem',(side*.34,1.43,-.55),(.04,.31,.04),'metal',.01)
    elif kind in ['compact','sedan','taxi','police','suv']:
        box('Rounded_body',(0,.74,0),(w,.83,l),paint,.20)
        cabin(w*.86,-l*.40,l*.23,h-.05,'purple' if kind=='compact' else ('black' if kind=='police' else paint))
        front_details(w,-l/2,round_lamps=kind in ['compact','taxi']);rear_details(w,l/2)
        if kind=='taxi':
            box('Roof_sign',(0,h+.07,0),(.72,.29,.24),'yellow',.05);text('TAXI',(0,h+.08,-.126),.55,'ink')
            for side in [-1,1]:
                for i in range(8):box('Taxi_checker',(side*(w/2+.012),.93,-.5+i*.145),(.02,.095,.13),'ink' if i%2==0 else 'white',.002)
        if kind=='police':
            box('Lightbar',(0,h-.08,0),(1.04,.16,.35),'ink',.04)
            for side,c in [(-1,'blue'),(1,'red')]:box('Emergency_lens',(side*.27,h+.02,0),(.48,.16,.31),c,.06)
            for side in [-1,1]:
                box('Police_door',(side*(w/2+.014),.91,0),(.024,.40,1.18),'white',.015);text('POLICE',(side*(w/2+.03),.92,0),.77,'ink',(side,0,0))
        if kind=='suv':
            for side in [-1,1]:box('Roof_rack',(side*.64,h+.015,.14),(.10,.13,1.85),'ink',.035)
            for z in [-.55,.6]:box('Rack_crossbar',(0,h+.10,z),(1.40,.08,.09),'metal',.025)
    elif kind=='pickup':
        box('Chassis',(0,.76,0),(w,.69,l),paint,.15);cabin(w*.87,-2.16,.27,1.98,paint)
        box('Bed_floor',(0,.96,1.30),(w*.88,.13,1.93),'ink',.04)
        for side in [-1,1]:box('Bed_side',(side*(w/2-.07),1.27,1.33),(.15,.65,1.97),paint,.07)
        box('Tailgate',(0,1.27,2.37),(w,.65,.14),paint,.07);front_details(w,-l/2);rear_details(w,l/2)
    elif kind in ['school-bus','city-bus']:
        box('Bus_body',(0,1.56,0),(w,2.50,l),paint,.18)
        for side in [-1,1]:
            for i in range(7):box('Window_seal',(side*(w/2+.01),2.04,-2.7+i*.88),(.035,.91,.79),'ink',.065);box('Bus_glass',(side*(w/2+.03),2.05,-2.7+i*.88),(.025,.78,.66),'glass',.045)
            for y in [1.10,.88]:box('Bus_band',(side*(w/2+.015),y,0),(.035,.08,l-.18),'ink' if kind=='school-bus' else 'purple',.02)
            if kind=='city-bus':
                box('Purple_lower_body',(side*(w/2+.025),.70,0),(.04,.55,l-.20),'purple',.06);branding((side*(w/2+.05),1.21,.55),1.7,(side,0,0))
        box('Front_bus_glass',(0,2.04,-l/2-.02),(w*.88,.93,.05),'ink',.08);box('Front_bus_glass_inner',(0,2.04,-l/2-.055),(w*.80,.80,.025),'glass',.05)
        box('Destination_panel',(0,2.66,-l/2-.025),(w*.86,.28,.06),'yellow' if kind=='school-bus' else 'ink',.05)
        text('SCHOOL BUS' if kind=='school-bus' else 'CITY BUS',(0,2.66,-l/2-.068),w*.76,'ink' if kind=='school-bus' else 'yellow')
        front_details(w,-l/2,1.01,True);rear_details(w,l/2)
    else:
        cab_length=1.88 if kind in ['box-truck','dump-truck','tow-truck'] else 1.64
        front=-l/2;cab_back=front+cab_length
        box('Truck_chassis',(0,.71,0),(w,.53,l),'ink',.10)
        box('Cab_lower',(0,1.05,front+cab_length/2),(w*.92,.91,cab_length),paint,.16)
        cabin(w*.87,front+.03,cab_back-.20,2.35 if h>2.9 else 2.20,paint)
        rear_length=l-cab_length
        if kind in ['delivery-van','box-truck','ambulance']:
            box('Cargo_shell',(0,(h+.78)/2,cab_back+rear_length/2),(w,h-.78,rear_length),paint,.12)
            for side in [-1,1]:
                box('Brand_lower_band',(side*(w/2+.02),.97,cab_back+rear_length/2),(.04,.34,rear_length-.10),'red' if kind=='ambulance' else 'purple',.05)
                if kind=='ambulance':
                    box('Medical_cross_vertical',(side*(w/2+.05),1.95,cab_back+rear_length/2),(.04,.88,.24),'red',.025);box('Medical_cross_horizontal',(side*(w/2+.05),1.95,cab_back+rear_length/2),(.04,.25,.88),'red',.025)
                else:branding((side*(w/2+.05),1.92,cab_back+rear_length/2),min(1.65,rear_length*.67),(side,0,0))
            for side in [-1,1]:box('Rear_door_seam',(side*w*.23,1.90,l/2+.02),(.025,h-.92,.025),'ink',.004)
        elif kind=='dump-truck':
            box('Tipper_floor',(0,1.15,.89),(w,.24,rear_length),'yellow',.08)
            for side in [-1,1]:
                box('Tipper_wall',(side*(w/2-.08),1.93,.89),(.17,1.44,rear_length),'yellow',.08)
                for i in range(6):box('Tipper_rib',(side*(w/2+.025),1.94,cab_back+.26+i*.49),(.08,1.29,.09),'orange',.02)
            box('Tipper_tailgate',(0,1.93,l/2-.09),(w,1.44,.18),'yellow',.06)
        elif kind=='tow-truck':
            box('Recovery_bed',(0,1.01,.87),(w,.27,rear_length),'purple',.08);boom=box('Crane_boom',(0,1.99,1.00),(.24,.24,2.90),'purple',.08);boom.rotation_euler[0]=-.31
            cylinder('Crane_top',(0,2.48,2.31),.22,.36,'purple');box('Hook_cable',(0,2.10,2.31),(.035,.65,.035),'ink',.01)
        front_details(w*.92,front);rear_details(w,l/2)
        if kind=='ambulance':
            box('Roof_lightbar',(0,2.50,front+.86),(1.13,.22,.33),'red',.07)
    positions=wheels(w,axles,r)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',export_apply=True,export_materials='EXPORT',export_yup=True,export_cameras=False,export_lights=False)
    metadata[kind]={'model':'res://assets/models/traffic/'+kind+'.glb','width':w,'length':l,'height':h,'radius':r,'mass':mass,'wheels':positions,'reference':'FedUp Vehicle Look Sheet.png'}
(ROOT/'data/traffic_vehicles.json').write_text(json.dumps({'vehicles':metadata},indent=2)+'\n')
print('BUILT TRAFFIC LINEUP:',len(metadata),'editable models')
