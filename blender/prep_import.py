"""
prep_import.py — เตรียมโมเดล Meshy (GLB) ให้พร้อมอัปโหลดเข้า Roblox
  - ลบลูกบอล Icosphere ที่ติดมา · ต่อจุดซ้อนตามรอย UV · ลดเนื้อเหลือ <target> สามเหลี่ยม (Roblox รับได้ไม่เกิน 20,000)
  - ย่อภาพเท็กซ์เจอร์เหลือ <tex> px (ไฟล์เล็ก โหลดเร็ว)
  - มีกระดูก (สัตว์ที่ช่วย): น้ำหนักกระดูกยังอยู่ · --hindlegs = เพิ่มกระดูกขาหลังซ้าย/ขวา (โครงจาก Meshy บางตัวมีแค่ขาหน้า)
รัน: blender -b --factory-startup --python blender/prep_import.py -- <in.glb> <out.glb> <target_tris> <tex> [--hindlegs]
"""
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, TARGET, TEX = args[0], args[1], int(args[2]), int(args[3])
HIND = "--hindlegs" in args
FORMAT = "AUTO" if "--png" in args else "JPEG"  # --png = เก็บภาพแบบไม่บีบ (รายละเอียดไม่แตก)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
rig = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)


def tri_count():
    dg = bpy.context.evaluated_depsgraph_get()
    me = mesh.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    mesh.evaluated_get(dg).to_mesh_clear()
    return n


bpy.context.view_layer.objects.active = mesh
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00001 * max(mesh.dimensions), use_sharp_edge_from_normals=False)
bpy.ops.object.mode_set(mode="OBJECT")
tris = tri_count()
if tris > TARGET:
    mod = mesh.modifiers.new("Decimate", "DECIMATE")
    mod.use_collapse_triangulate = True
    mod.ratio = TARGET / tris
    while mesh.modifiers.find("Decimate") > 0:
        bpy.ops.object.modifier_move_up(modifier="Decimate")
    bpy.ops.object.modifier_apply(modifier="Decimate")
for poly in mesh.data.polygons:
    poly.use_smooth = True
print("TRIS", tris, "->", tri_count())
for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, TEX)

if HIND and rig:
    # ขาหลัง: หาเนื้อส่วนขาหลังจากตำแหน่งจุด (ครึ่งหลัง = +Y ใกล้พื้น) แล้วสร้างกระดูก 1 ท่อนต่อข้าง ผูกกับกระดูกราก
    mw = mesh.matrix_world
    pts = [(v.index, mw @ v.co) for v in mesh.data.vertices]
    zmin = min(p.z for _, p in pts)
    ys = sorted(p.y for _, p in pts)
    ymid = ys[len(ys) // 2]
    legH = max(p.z for _, p in pts) * 0.24
    groups = {}
    for side, sgn in (("L", -1), ("R", 1)):
        sel = [(i, p) for i, p in pts if p.y > ymid and p.z < zmin + legH and p.x * sgn > 0.08]
        if not sel:
            continue
        c = sum((p for _, p in sel), Vector()) / len(sel)
        groups[side] = (c, sel)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    root = eb[0]
    inv = rig.matrix_world.inverted()
    for side, (c, _) in groups.items():
        b = eb.new("Hind" + side)
        b.head = inv @ Vector((c.x, c.y, zmin + legH * 1.6))
        b.tail = inv @ Vector((c.x, c.y, zmin))
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    for side, (c, sel) in groups.items():
        vg = mesh.vertex_groups.new(name="Hind" + side)
        top = zmin + legH * 1.6
        for i, p in pts:
            if p.y > ymid - 0.05 and p.x * (-1 if side == "L" else 1) > 0.04 and p.z < top:
                w = min(1.0, max(0.0, (top - p.z) / (legH * 0.9)))
                if w <= 0:
                    continue
                v = mesh.data.vertices[i]
                # ลดน้ำหนักกระดูกเดิมลงตามส่วน ให้รวมกัน = 1
                for g in v.groups:
                    g.weight *= (1 - w)
                vg.add([i], w, "REPLACE")
        print("HIND", side, "center", tuple(round(x, 3) for x in c), "verts", len(sel))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_animations=False, export_skins=rig is not None,
                          export_image_format=FORMAT, export_jpeg_quality=88)
print("OUT", OUT)
