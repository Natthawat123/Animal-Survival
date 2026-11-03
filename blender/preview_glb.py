"""
preview_glb.py — ภาพตรวจโมเดล GLB 2 มุม (ข้าง +X / หน้าเฉียง) พร้อมป้ายแกน ไว้ดูว่าหัวหันทางไหน
รัน: blender -b --factory-startup --python blender/preview_glb.py -- <in.glb> <out.png>
"""
import math
import sys

import bpy
from mathutils import Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
center = (lo + hi) / 2
size = max(hi - lo)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 640, 480
world = bpy.data.worlds.new("W")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.35, 0.38, 0.42, 1)
bg.inputs[1].default_value = 1.2
sc.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(40), 0, math.radians(30))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
# ป้ายบอกทิศ: ลูกบอลแดงที่ +Y, น้ำเงินที่ -Y (ดูว่าหัวอยู่ทางไหน)
for col, y in (((1, 0, 0, 1), 1), ((0, 0.3, 1, 1), -1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=size * 0.04, location=(center.x, center.y + y * size * 0.62, lo.z))
    m = bpy.data.materials.new("M")
    m.diffuse_color = col
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs[0].default_value = col
    bpy.context.object.data.materials.append(m)
import os

base, ext = os.path.splitext(OUT)
for tag, d in (("side", Vector((1, 0, 0.25))), ("front", Vector((0.6, -0.8, 0.35)))):
    cam.location = center + d.normalized() * size * 2.2
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = base + "_" + tag + ext
    bpy.ops.render.render(write_still=True)
print("DONE", OUT)
