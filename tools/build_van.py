"""Rebuild the original meter-scale van with Blender (no external assets).

Run: blender --background --python tools/build_van.py
Coordinates below use Godot conventions: X right, Y up, -Z forward.
"""
from pathlib import Path
import bpy
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "assets" / "source"
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.82
    return mat


white = material("Paint_WarmWhite", (0.89, 0.88, 0.82))
ink = material("Outline_Charcoal", (0.035, 0.049, 0.073))
glass = material("Glass_GraphicBlue", (0.06, 0.22, 0.31))
glint = material("Glass_Highlight", (0.75, 0.9, 1.0))
purple = material("Brand_Purple", (0.22, 0.065, 0.36))
orange = material("Brand_Orange", (0.94, 0.31, 0.06))
metal = material("Metal_Silver", (0.45, 0.52, 0.57))
red = material("TailLamp_Red", (0.68, 0.035, 0.025))
lamp = material("Headlamp_Cream", (1.0, 0.87, 0.53))


def point(v):
    return v[0], -v[2], v[1]


def box(name, pos, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(pos))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Small manufactured edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


box("Cargo_Roof", (0,3.08,.63),(2.30,.12,3.42),white,.04)
box("Cargo_Floor", (0,.69,.63),(2.30,.12,3.42),ink)
box("Cargo_Bulkhead", (0,1.88,-1.02),(2.30,2.5,.12),white)
for side in [-1,1]:box("Cargo_Side",(side*1.10,1.88,.63),(.10,2.5,3.42),white,.025)
box("Cab_Lower", (0, 1.13, -1.70), (2.26, 1.0, 1.38), white, 0.16)
box("Cab_Roof", (0, 2.96, -1.45), (2.31, 0.16, 1.48), white, 0.07)
for name, pos, size, mat, bevel in [
    ("Windscreen_Seal", (0, 2.23, -2.34), (2.10, 1.20, .08), ink, .06),
    ("Windscreen", (0, 2.23, -2.39), (1.94, 1.06, .035), glass, .04),
    ("Windscreen_Center", (0, 2.23, -2.42), (.035, 1.12, .03), white, 0),
]:
    obj = box(name, pos, size, mat, bevel)
    obj.rotation_euler[0] = .22
for x in [-1.065, 1.065]:
    obj = box("A_Pillar", (x, 2.23, -2.32), (0.16, 1.38, 0.18), white)
    obj.rotation_euler[0] = .22
for x in [-.55, .55]:
    obj = box("Windscreen_Glint", (x, 2.36, -2.43), (.12, .68, .018), glint, .008)
    obj.rotation_euler[0] = .22
for side in [-1, 1]:
    x = side * 1.14
    box("Side_Window_Seal", (x, 2.27, -1.57), (0.05, 1.08, 1.12), ink, 0.03)
    box("Side_Window", (x + side * .03, 2.27, -1.57), (.025, .94, .98), glass)
    obj = box("Side_Window_Glint", (x + side * .05, 2.32, -1.67), (.018, .65, .12), glint, .008)
    obj.rotation_euler[0] = -.32
    box("Side_Door_Seam", (x, 1.28, -1.18), (.035, 1.0, .025), ink)
    box("Door_Handle", (x + side * .035, 1.61, -1.12), (.07, .07, .22), ink)
    box("Mirror_Arm", (side * 1.33, 2.02, -2.05), (.42, .055, .055), ink)
    box("Mirror_Housing", (side * 1.49, 2.16, -2.05), (.18, .54, .27), ink, .045)
    box("Mirror_StaticGlass", (side * 1.49, 2.16, -1.90), (.12, .45, .025), metal)
    box("Side_RubRail", (side * 1.17, .88, .40), (.065, .11, 3.7), ink)
    box("Orange_SideStripe", (side * 1.157, 1.12, .60), (.025, .12, 3.25), orange)
    box("Step", (side * 1.20, .42, -1.95), (.32, .11, .65), metal)
    for z in [-1.52, 1.52]:
        pivot = bpy.data.objects.new("WheelPivot_" + ("Front" if z < 0 else "Rear")
                                     + ("_L" if side < 0 else "_R"), None)
        bpy.context.collection.objects.link(pivot)
        pivot.location = point((side * 1.14, .48, z))
        bpy.context.view_layer.update()
        # Cylinders are authored along the lateral axle.
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=.46, depth=.24,
            location=point((side * 1.14, .48, z)), rotation=(0, math.pi / 2, 0))
        wheel = bpy.context.object
        wheel.name = "Wheel_Tire"
        wheel.data.materials.append(ink)
        wheel.parent = pivot
        wheel.matrix_parent_inverse = pivot.matrix_world.inverted()
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.255, depth=.255,
            location=point((side * 1.15, .48, z)), rotation=(0, math.pi / 2, 0))
        bpy.context.object.name = "Wheel_Hub"
        bpy.context.object.data.materials.append(metal)
        bpy.context.object.parent = pivot
        bpy.context.object.matrix_parent_inverse = pivot.matrix_world.inverted()
        for lug in range(5):
            angle = lug * math.tau / 5
            lug_obj = box("Hub_Lug", (side * 1.29, .48 + math.sin(angle) * .14,
                            z + math.cos(angle) * .14), (.025, .04, .04), ink, .006)
            lug_obj.parent = pivot
            lug_obj.matrix_parent_inverse = pivot.matrix_world.inverted()
        # A dark wheel-arch lip gives the body a proper coachwork silhouette.
        for arc_index in range(13):
            angle = arc_index * math.pi / 12
            arch = box("Wheel_ArchLip", (side * 1.20, .48 + math.sin(angle) * .52,
                        z + math.cos(angle) * .52), (.065, .08, .15), ink, .012)
            arch.rotation_euler[0] = angle

box("Front_Bumper", (0, .67, -2.53), (2.42, .24, .23), ink, .04)
box("Front_Grille", (0, 1.12, -2.405), (1.20, .39, .05), ink)
for y in [.99, 1.10, 1.21]:
    box("Grille_Slat", (0, y, -2.44), (1.08, .028, .025), metal)
for x in [-.87, .87]:
    box("Headlight_Bezel", (x, 1.17, -2.405), (.38, .39, .07), ink, .025)
    box("Headlight", (x, 1.19, -2.45), (.29, .26, .025), lamp)
    box("Front_Indicator", (x, 1.49, -2.41), (.30, .10, .03), orange)
for x in [-.48, .48]:
    wiper = box("Wiper", (x, 1.87, -2.50), (.62, .025, .025), ink)
    wiper.rotation_euler[1] = -.12
for side in [-1,1]:
    pivot=bpy.data.objects.new('RearDoorPivot_'+('L' if side<0 else 'R'),None)
    bpy.context.collection.objects.link(pivot);pivot.location=point((side*1.09,0,2.40))
    parts=[box('Rear_Door',(side*.55,1.91,2.37),(1.06,2.15,.075),white,.025),
           box('Door_LockBar',(side*.14,1.59,2.43),(.025,.84,.035),metal),
           box('Rear_Handle',(side*.14,1.64,2.46),(.12,.055,.04),ink),
           box('Rear_OrangeBand',(side*.55,1.15,2.42),(1.03,.12,.028),orange)]
    bpy.context.view_layer.update()
    for obj in parts:
        obj.parent=pivot;obj.matrix_parent_inverse=pivot.matrix_world.inverted()
for x in [-.89, .89]:
    for y in [1.05, 2.61]:
        box("Door_Hinge", (x, y, 2.425), (.18, .10, .05), metal)
    box("TailLamp_Seal", (x, .81, 2.41), (.22, .34, .07), ink)
    box("TailLamp", (x, .85, 2.455), (.15, .20, .025), red)
    box("ReverseLamp", (x, .70, 2.455), (.15, .07, .025), lamp)
box("Rear_StepBumper", (0, .43, 2.49), (2.42, .16, .35), ink, .025)
box("Rear_Plate", (0, .72, 2.43), (.48, .17, .035), purple)
for x in [-.86, 0, .86]:
    box("Roof_Marker", (x, 3.11, -1.98), (.12, .08, .14), orange, .02)

bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "fedup_van.blend"))
# Keep the saved source fully editable; batch only the exported static exterior.
for mat in list(bpy.data.materials):
    group = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
             and obj.parent is None and len(obj.data.materials) == 1 and obj.data.materials[0] == mat]
    if not group:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    if len(group) > 1:
        bpy.ops.object.join()
    bpy.context.object.name = "Van_" + mat.name
for pivot in [obj for obj in bpy.context.scene.objects if obj.type == "EMPTY"
              and (obj.name.startswith("WheelPivot_") or obj.name.startswith("RearDoorPivot_"))]:
    group = list(pivot.children)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    bpy.ops.object.join()
    bpy.context.object.name = "Rolling_" + pivot.name
bpy.ops.export_scene.gltf(filepath=str(OUT / "fedup_van.glb"), export_format="GLB",
    export_yup=True, export_cameras=False, export_lights=False)
print("FEDUP_ASSET_BUILT", OUT / "fedup_van.glb")
