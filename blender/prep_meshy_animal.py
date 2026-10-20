"""
prep_meshy_animal.py — เตรียมสัตว์จาก Meshy (ผูกกระดูก + ท่า) ให้พร้อม Import 3D เข้า Roblox
  - ลบลูกบอล Icosphere ที่ติดมา · ลดเนื้อเหลือ ~18,000 สามเหลี่ยม (ลิมิต Roblox 20,000) โดยน้ำหนักกระดูกยังอยู่
  - ส่งออก GLB พร้อมกระดูก + ท่า (ไม่เปลี่ยนขนาด/แกน: เกมย่อขยายเอง)
  - รูปตรวจ 4 เฟรมของท่า (ดูว่าเป็นท่ายืน/เดิน)
รัน: blender -b --factory-startup --python blender/prep_meshy_animal.py -- <in.glb> <out.glb> <preview.png>
"""
import math
import sys

import bpy
from mathutils import Vector

SRC, OUT, PREV = sys.argv[sys.argv.index("--") + 1:][:3]
TARGET_TRIS = 18000

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
dg = bpy.context.evaluated_depsgraph_get()
me = mesh.evaluated_get(dg).to_mesh()
me.calc_loop_triangles()
tris = len(me.loop_triangles)
mesh.evaluated_get(dg).to_mesh_clear()
# ต่อจุดที่ซ้อนกันตามรอย UV ให้เนื้อเป็นชิ้นเดียวก่อน (ไม่งั้นลดเนื้อแล้วรอยต่อฉีกเป็นแหลมๆ)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00001 * max(mesh.dimensions) / max(rig.scale[0], 1e-6), use_sharp_edge_from_normals=False)
bpy.ops.object.mode_set(mode="OBJECT")
print("WELD verts", len(mesh.data.vertices))
if tris > TARGET_TRIS:
    bpy.context.view_layer.objects.active = mesh
    mod = mesh.modifiers.new("Decimate", "DECIMATE")
    mod.use_collapse_triangulate = True
    mod.ratio = TARGET_TRIS / tris
    # ย้าย Decimate ไปก่อน Armature (ลดเนื้อในท่ายืน ไม่ใช่ท่าที่ขยับแล้ว)
    while mesh.modifiers.find("Decimate") > 0:
        bpy.ops.object.modifier_move_up(modifier="Decimate")
    bpy.ops.object.modifier_apply(modifier="Decimate")
me = mesh.data
for poly in me.polygons:
    poly.use_smooth = True
me.calc_loop_triangles()
print("TRIS", tris, "->", len(me.loop_triangles))
for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, 1024)
act = rig.animation_data.action if rig.animation_data else None
print("ACTION", act and act.name, act and tuple(act.frame_range))

# ---- ขยายให้ได้ขนาดจริง (Meshy ส่งออกเป็นหน่วยเซนติเมตร ตัวเล็ก ~0.01): ด้านยาวสุด = 2 หน่วย
#   ขยายวัตถุ -> apply scale (กระดูก+เนื้อขยายตาม) -> คูณค่าตำแหน่งในท่าด้วยตัวคูณเดียวกัน (ไม่งั้นสะโพกขยับเพี้ยน)
print("SCALES rig", tuple(round(v, 4) for v in rig.scale), "mesh", tuple(round(v, 4) for v in mesh.scale), "mesh parent", mesh.parent and mesh.parent.name)
dg = bpy.context.evaluated_depsgraph_get()
pts = [mesh.matrix_world @ v.co for v in mesh.evaluated_get(dg).to_mesh().vertices]
mesh.evaluated_get(dg).to_mesh_clear()
ext = max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))
k = 2.0 / ext
before = rig.matrix_world.to_scale()[0]
rig.scale = rig.scale * k
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
# ตำแหน่งในท่าเป็นค่าในแกนกระดูก: กระดูกถูกขยาย (before*k) เท่า -> คูณตาม
mult = before * k
def all_fcurves(a):
    if a is None:
        return []
    if hasattr(a, "fcurves") and len(a.fcurves):
        return list(a.fcurves)
    out = []  # Blender 4.4+: action แบบ layer/slot
    for layer in getattr(a, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                out += list(bag.fcurves)
    return out


fcs = all_fcurves(act)
# ลบการย่อขยายในท่า (Roblox ไม่รองรับ scale animation)
removed = 0
for layer in getattr(act, "layers", []) if act else []:
    for strip in layer.strips:
        for bag in getattr(strip, "channelbags", []):
            for fc in [f for f in bag.fcurves if f.data_path.endswith("scale")]:
                bag.fcurves.remove(fc)
                removed += 1
if act and hasattr(act, "fcurves"):
    for fc in [f for f in act.fcurves if f.data_path.endswith("scale")]:
        act.fcurves.remove(fc)
        removed += 1
print("FCURVES", len(fcs), "scale removed", removed)
for fc in all_fcurves(act):
    if fc.data_path.endswith("location"):
        for kp in fc.keyframe_points:
            kp.co[1] *= mult
            kp.handle_left[1] *= mult
            kp.handle_right[1] *= mult
print("NORMALIZE ext", round(ext, 5), "k", round(k, 2), "loc mult", round(mult, 3))

# ---- รูปตรวจ 4 เฟรม (มองจากข้าง)
sc = bpy.context.scene
f0, f1 = (int(act.frame_range[0]), int(act.frame_range[1])) if act else (0, 0)
sc.frame_set(f0)
dg = bpy.context.evaluated_depsgraph_get()
pts = [mesh.matrix_world @ v.co for v in mesh.evaluated_get(dg).to_mesh().vertices]
mesh.evaluated_get(dg).to_mesh_clear()
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2
size = max((mx - mn)[:])
print("WORLD SIZE", tuple(round(v, 3) for v in (mx - mn)))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = size * 1.4
d = size * 4
cam.location = (c.x + d * 0.75, c.y - d * 0.65, c.z + d * 0.25)
cam.rotation_euler = (math.radians(80), 0, math.radians(49))
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sc.collection.objects.link(sun)
sun.rotation_euler = (0.9, 0.2, 0.6)
sun.data.energy = 3.5
wd = bpy.data.worlds.new("w")
sc.world = wd
wd.color = (0.4, 0.42, 0.46)
eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in eng else eng[0]
sc.render.resolution_x, sc.render.resolution_y = 400, 400
frames = [f0 + round((f1 - f0) * k / 4) for k in range(4)]
paths = []
for i, f in enumerate(frames):
    sc.frame_set(f)
    sc.render.filepath = f"{PREV}_{i}.png"
    bpy.ops.render.render(write_still=True)
    paths.append(sc.render.filepath)
bpy.data.objects.remove(cam, do_unlink=True)
bpy.data.objects.remove(sun, do_unlink=True)
sc.frame_set(f0)
print("PREVIEWS", paths)

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True, export_animations=True,
                          export_image_format="JPEG")
print("WROTE", OUT)
