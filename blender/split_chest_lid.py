"""
split_chest_lid.py — แยกฝาหีบ (Meshy · เมชก้อนเดียว) เป็น 2 ชิ้น "Body" + "Lid" ให้เปิดฝาได้จริงในเกม
  - ตัดแนวนอนที่ความสูง <frac> ของกล่อง (ใต้แถบทองคาดกลาง)
  - เมช Meshy ไม่ปิดสนิท อุดรอยตัดตรงๆ ไม่ได้ -> ใส่ "ถาด" แยกชิ้นในเมชเดียวกัน:
      ตัวหีบ = ขอบปากหีบ + ผนังใน + ก้นโพรง (มองลงไปเห็นโพรงมืด) · ฝา = ขอบ + ผนังใน + เพดาน (ใต้ฝาเว้า)
  - สีของถาดดึงจากเท็กซ์เจอร์เดิม (ใช้ภาพเดิม ไม่ต้องอัปภาพใหม่): ขอบ = สีตรงรอยตัด · ข้างใน = สีมืด
  - แกน: Blender (x, y, z) -> Roblox (-x, z, y) (ตัวนำเข้า Roblox หมุนโมเดล 180°)
      หน้าหีบ (อัญมณีใหญ่) = -Y ของ Blender = -Z ใน Roblox · บานพับอยู่หลัง = +Y ของ Blender = +Z ใน Roblox
  - เขียน <out>.json: จุดศูนย์กลาง/ขนาดของแต่ละชิ้น + บานพับ (พิกัด Roblox) ให้ tools/chest_lid_rbxmx.py ใช้
  - --open <png> = เรนเดอร์ภาพตรวจตอนฝาเปิด (ไม่ส่งออก)
รัน: blender -b --factory-startup --python blender/split_chest_lid.py -- <in.glb> <out.glb> <frac> [--open <preview.png>]
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, FRAC = args[0], args[1], float(args[2])
PREVIEW = args[args.index("--open") + 1] if "--open" in args else None
OPEN_DEG = 105

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
src = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

ws = [v.co.copy() for v in src.data.vertices]
lo = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
hi = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
size = hi - lo
H = lo.z + size.z * FRAC
print("BOX", tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi), "cut", round(H, 3))

# ภาพสี (Base Color) ของวัสดุ
mat = src.active_material
img = None
if mat and mat.use_nodes:
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf and bsdf.inputs[0].is_linked:
        node = bsdf.inputs[0].links[0].from_node
        while node and node.type != "TEX_IMAGE" and node.inputs and node.inputs[0].is_linked:
            node = node.inputs[0].links[0].from_node
        if node and node.type == "TEX_IMAGE":
            img = node.image
PX = img.pixels[:] if img else None
IW, IH = (img.size[0], img.size[1]) if img else (1, 1)


def lum_at(u, v):
    x = min(IW - 1, max(0, int((u % 1) * IW)))
    y = min(IH - 1, max(0, int((v % 1) * IH)))
    i = (y * IW + x) * 4
    return 0.3 * PX[i] + 0.59 * PX[i + 1] + 0.11 * PX[i + 2]


DARK_UV = (0.5, 0.5)
if img:
    cand = []
    step = max(1, (IW * IH) // 40000)
    for i in range(0, IW * IH, step):
        r, g, b, a = PX[i * 4:i * 4 + 4]
        lum = 0.3 * r + 0.59 * g + 0.11 * b
        if a > 0.5 and lum > 0.02:
            cand.append((lum, i))
    cand.sort()
    _, i = cand[len(cand) // 25]
    DARK_UV = (((i % IW) + 0.5) / IW, ((i // IW) + 0.5) / IH)


def pct(vals, q):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, max(0, int(len(vals) * q)))]


def make_piece(name, keep_above):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = name
    ob.data.name = name
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.active
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=(0, 0, H), plane_no=(0, 0, 1),
                                 clear_outer=not keep_above, clear_inner=keep_above)
    cutverts = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMVert)]
    cutv = [v.co for v in cutverts]
    # สีขอบปาก = สีผิวตรงรอยตัด (ค่ากลาง) -> ทอง/หินตามกล่อง
    rim_uv = DARK_UV
    if uv and img:
        samples = []
        for v in cutverts:
            for l in v.link_loops:
                u = l[uv].uv
                samples.append((lum_at(u.x, u.y), (u.x, u.y)))
        if samples:
            samples.sort()
            rim_uv = samples[int(len(samples) * 0.6)][1]
    # กรอบปาก (ตัดของตกแต่งที่ยื่นออก: ใช้ช่วง 4-96%) · หดเข้า 1% กันขอบโผล่เกินผนัง
    x0, x1 = pct([v.x for v in cutv], 0.04), pct([v.x for v in cutv], 0.96)
    y0, y1 = pct([v.y for v in cutv], 0.04), pct([v.y for v in cutv], 0.96)
    sh = min(x1 - x0, y1 - y0)
    x0, x1, y0, y1 = x0 + sh * 0.01, x1 - sh * 0.01, y0 + sh * 0.01, y1 - sh * 0.01
    rim = sh * 0.085
    up = 1 if keep_above else -1  # ทิศเข้าไปในเนื้อชิ้น (ฝา = ขึ้น / ตัวหีบ = ลง)
    depth = (hi.z - H) * 0.5 if keep_above else (H - lo.z) * 0.75
    zr = H + 0.002 * -up  # ขอบอยู่เลยรอยตัดนิดเดียว (ไม่ทับผิวเดิมพอดี -> ไม่กะพริบ)
    zb = H + up * depth

    def quad(a, b, c, d, face_dir, uvc):
        f = bm.faces.new([bm.verts.new(p) for p in (a, b, c, d)])
        f.normal_update()
        if f.normal.dot(face_dir) < 0:
            f.normal_flip()
        if uv:
            for l in f.loops:
                l[uv].uv = uvc

    O = [Vector((x0, y0, zr)), Vector((x1, y0, zr)), Vector((x1, y1, zr)), Vector((x0, y1, zr))]
    I = [Vector((x0 + rim, y0 + rim, zr)), Vector((x1 - rim, y0 + rim, zr)), Vector((x1 - rim, y1 - rim, zr)), Vector((x0 + rim, y1 - rim, zr))]
    B = [Vector((p.x, p.y, zb)) for p in I]
    face_out = Vector((0, 0, -up))  # ขอบ/ก้น หันออกจากเนื้อชิ้น (ตัวหีบ = ขึ้นฟ้า / ฝา = ลงพื้น)
    for k in range(4):
        n = (k + 1) % 4
        quad(O[k], O[n], I[n], I[k], face_out, rim_uv)  # ขอบปาก
        mid = (I[k] + I[n]) / 2
        quad(I[k], I[n], B[n], B[k], Vector(((x0 + x1) / 2 - mid.x, (y0 + y1) / 2 - mid.y, 0)), DARK_UV)  # ผนังใน หันเข้ากลาง
    quad(B[0], B[1], B[2], B[3], face_out, DARK_UV)  # ก้นโพรง / เพดานใต้ฝา
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    ob.data.validate()
    return ob, (x0, x1, y0, y1)


body, brect = make_piece("Body", False)
lid, _ = make_piece("Lid", True)
bpy.data.objects.remove(src, do_unlink=True)


def bbox(ob):
    vs = [v.co for v in ob.data.vertices]
    a = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    b = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return a, b


def rb(v):  # Blender -> Roblox
    return [-v.x, v.z, v.y]


# บานพับ: ขอบบนด้านหลังของปากหีบ (หลัง = +Y ของ Blender)
hinge = Vector(((brect[0] + brect[1]) / 2, brect[3], H))
info = {"Hinge": rb(hinge), "OpenDeg": OPEN_DEG}
for ob in (body, lid):
    a, b = bbox(ob)
    c = (a + b) / 2
    s = b - a
    info[ob.name] = {"Center": rb(c), "Size": [s.x, s.z, s.y], "Tris": sum(len(p.vertices) - 2 for p in ob.data.polygons)}
print("INFO", json.dumps(info))

if PREVIEW:
    lid.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-OPEN_DEG), 4, "X") @ Matrix.Translation(-hinge)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 520, 420
    for m in bpy.data.materials:
        m.use_backface_culling = True  # Roblox วาดหน้าเดียว -> ตรวจแบบหน้าเดียว
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.35, 0.38, 0.42, 1)
    bg.inputs[1].default_value = 1.4
    sc.world = world
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    c = (lo + hi) / 2
    big = max(size)
    base, ext = os.path.splitext(PREVIEW)
    for tag, d in (("front", Vector((0.35, -1, 0.75))), ("side", Vector((1, -0.25, 0.45)))):
        cam.location = c + d.normalized() * big * 2.6
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = base + "_" + tag + ext
        bpy.ops.render.render(write_still=True)
else:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False)
    with open(os.path.splitext(OUT)[0] + ".json", "w") as f:
        json.dump(info, f, indent=1)
print("DONE")
