"""
game_animals.py — แปลงโมเดลสัตว์จริง (CC0 Quaternius/OpenGameArt) เป็นสัตว์ธาตุของเกม

ขั้นตอนต่อ 1 ตัว:
  1) append ต้นแบบ (refs.py)  2) หมุนให้หัวไปทาง -Y, ย่อ/ขยายเป็น stud, เท้าแตะพื้น
  3) แบ่งชิ้นตาม "กระดูกที่คุมจุดนั้นมากที่สุด" -> Body / Head / Jaw / LegFL.. / Tail1 / WingL/WingR
  4) ย้อมสีตามธาตุ (ถ้ามี texture จะย้อม texture) 5) ติดของตกแต่ง (เขา/คริสตัล/ไฟ/ตาเรืองแสง)
  6) ส่งออก blender/exports/animals/<Id>.fbx + ภาพ art/animals/<Id>.png

ชิ้นชื่อ "Glow_RRGGBB" = Roblox ทำเป็น Neon สีนั้น (AnimalModels.rigCustom)
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import as_kit
import refs

importlib.reload(as_kit)
importlib.reload(refs)

ROOT = as_kit.ROOT
OUT = os.path.join(ROOT, "blender", "exports", "animals")
PREVIEW = os.path.join(ROOT, "art", "animals")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)
C = lambda r, g, b: (r / 255, g / 255, b / 255)
rad = math.radians


# ---------------------------------------------------------------- 1-2 โหลด + จัดทิศ/ขนาด
def merged_rest_mesh(ref_id):
    """โหลดต้นแบบ -> mesh เดียว (ท่ายืนพัก) พิกัดโลก + vertex groups + armature (ถ้ามี)"""
    root, obs = refs.append(ref_id, coll_name="REF_" + ref_id)
    arm = next((o for o in obs if o.type == "ARMATURE"), None)
    meshes = [o for o in obs if o.type == "MESH"]
    if arm:
        arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    parts = []
    for m in meshes:
        for md in m.modifiers:
            if md.type == "ARMATURE":
                md.show_viewport = False
        dg.update()
        me = bpy.data.meshes.new_from_object(m.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        me.transform(m.matrix_world)
        ob = bpy.data.objects.new(m.name + "_rest", me)
        # คง vertex group ชื่อเดิม
        for vg in m.vertex_groups:
            ob.vertex_groups.new(name=vg.name)
        bpy.context.scene.collection.objects.link(ob)
        parts.append(ob)
    merged = as_kit.join("REST_" + ref_id, parts) if len(parts) > 1 else parts[0]
    return merged, arm, [o for o in obs]


def bone_points(arm):
    out = {}
    if not arm:
        return out
    mw = arm.matrix_world
    for b in arm.data.bones:
        out[b.name] = (mw @ b.head_local, mw @ b.tail_local)
    return out


def orient(ob, bones, forward=None, length=6.0):
    """หมุนให้หัวไปทาง -Y ย่อ/ขยายให้ยาว length แล้ววางกลาง/บนพื้น -> คืน matrix ที่ใช้ (เอาไปแปลงตำแหน่งกระดูก)"""
    me = ob.data
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = mx - mn
    if forward is None:
        # เดาหัว: ปลายแกนยาวด้านที่มีจุดสูงกว่า (หัว/คอสูงกว่าหาง)
        axis = 0 if size.x > size.y else 1
        lo = [p for p in pts if p[axis] < mn[axis] + size[axis] * 0.2]
        hi = [p for p in pts if p[axis] > mx[axis] - size[axis] * 0.2]
        zlo = max(p.z for p in lo) if lo else 0
        zhi = max(p.z for p in hi) if hi else 0
        forward = ("-X" if zlo > zhi else "+X") if axis == 0 else ("-Y" if zlo > zhi else "+Y")
    rot = {"-Y": 0, "+Y": math.pi, "+X": -math.pi / 2, "-X": math.pi / 2}[forward]
    R = Matrix.Rotation(rot, 4, "Z")
    me.transform(R)
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    L = mx.y - mn.y
    s = length / L
    S = Matrix.Scale(s, 4)
    T = Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    M = S @ T
    me.transform(M)
    me.update()
    full = M @ R
    nb = {k: (full @ h, full @ t) for k, (h, t) in bones.items()}
    return full, nb, forward


# ---------------------------------------------------------------- 3 แบ่งชิ้น
def classify_point(p, box, kind):
    """จัดจุด/กระดูกเข้าหมวด ตามตำแหน่ง (หัวอยู่ -Y)"""
    mn, mx = box
    L, W, H = mx.y - mn.y, mx.x - mn.x, mx.z - mn.z
    fy = (p.y - mn.y) / L  # 0 = หน้าสุด 1 = หลังสุด
    hz = (p.z - mn.z) / H
    side = "L" if p.x < 0 else "R"
    if kind == "Bird":
        if abs(p.x) > W * 0.16:
            return "WingL" if p.x < 0 else "WingR"
        if fy < 0.28:
            return "Head"
        return "Body"
    if kind == "Crab":
        if fy < 0.2 and hz > 0.25:
            return "Head"
        if hz < 0.3 and abs(p.x) > W * 0.2:
            return ("LegF" if fy < 0.5 else "LegB") + side
        return "Body"
    head_cut = kind == "Long" and 0.17 or 0.24
    if fy < head_cut and hz > 0.32:
        return "Head"
    if kind == "Long" and fy > 0.62:
        return "Tail1"
    if hz < 0.42:
        return ("LegF" if fy < 0.5 else "LegB") + side
    if fy > 0.88:
        return "Tail1"
    return "Body"


def split_parts(ob, bones, kind="Quad", jaw_bones=()):
    """แยก mesh เป็นชิ้นตามกระดูกที่มีน้ำหนักมากสุด (ถ้าไม่มีกระดูก ใช้ตำแหน่ง)"""
    me = ob.data
    pts = [v.co for v in me.vertices]
    box = (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
           Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))
    # หมวดของกระดูก: ใช้ "จุดกลาง" ของกระดูก
    gname = {vg.index: vg.name for vg in ob.vertex_groups}
    bone_cat = {}
    for name, (h, t) in bones.items():
        if any(j.lower() in name.lower() for j in jaw_bones):
            bone_cat[name] = "Jaw"
        else:
            bone_cat[name] = classify_point((h + t) / 2, box, kind)
    vcat = []
    for v in me.vertices:
        best, w = None, 0
        for g in v.groups:
            nm = gname.get(g.group)
            if nm in bone_cat and g.weight > w:
                best, w = nm, g.weight
        vcat.append(bone_cat[best] if best else classify_point(v.co, box, kind))
    # หน้า -> หมวดที่มากสุดของจุด (ขา/หัวได้เปรียบเล็กน้อย กันขาขาด)
    bm = bmesh.new()
    bm.from_mesh(me)
    buckets = {}
    for f in bm.faces:
        votes = {}
        for v in f.verts:
            c = vcat[v.index]
            votes[c] = votes.get(c, 0) + (1.2 if c != "Body" else 1.0)
        cat = max(votes, key=votes.get)
        buckets.setdefault(cat, []).append(f.index)
    bm.free()
    out = {}
    names = {"LegFL": "LegFL", "LegFR": "LegFR", "LegBL": "LegBL", "LegBR": "LegBR"}
    for cat, faces in buckets.items():
        nm = names.get(cat, cat)
        bm = bmesh.new()
        bm.from_mesh(me)
        keep = set(faces)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        nme = bpy.data.meshes.new(nm)
        bm.to_mesh(nme)
        bm.free()
        for m in me.materials:
            nme.materials.append(m)
        part = bpy.data.objects.new(nm, nme)
        bpy.context.scene.collection.objects.link(part)
        out[nm] = part
    return out


# ---------------------------------------------------------------- 4 ย้อมสี
def luminance(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def base_color_of(mat):
    if not mat or not mat.use_nodes:
        return tuple(mat.diffuse_color[:3]) if mat else (0.8, 0.8, 0.8), None
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    img = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0 and n.image.has_data), None)
    if bsdf:
        return tuple(bsdf.inputs["Base Color"].default_value[:3]), img
    return (0.8, 0.8, 0.8), img


def recolor_image(img, target, name, contrast=1.0, keep=0.0):
    """ย้อม texture: ความสว่างเดิม x สีเป้าหมาย (เก็บรายละเอียดลาย)"""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    lum = 0.2126 * px[..., 0] + 0.7152 * px[..., 1] + 0.0722 * px[..., 2]
    lum = np.clip((lum / max(lum.mean(), 1e-3)) ** contrast, 0, 2.2)
    t = np.array(target, dtype=np.float32)
    out = np.empty_like(px)
    for c in range(3):
        out[..., c] = np.clip(lum * t[c] * (1 - keep) + px[..., c] * keep, 0, 1)
    out[..., 3] = 1
    new = bpy.data.images.new(name, w, h)
    new.pixels = out.ravel().tolist()
    new.filepath_raw = os.path.join(OUT, name + ".png")
    new.file_format = "PNG"
    new.save()
    return new


def image_material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = as_kit.principled(mat)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    as_kit.set_input(bsdf, "Roughness", 0.8)
    return mat


def recolor(parts, roles, name):
    """
    roles = {"dark": rgb, "main": rgb, "light": rgb, "eye": rgb}  (สี 0-1 sRGB)
    วัสดุสีเดียว (Quaternius) -> ไล่ตามความสว่างเดิม: มืดสุด=dark, สว่างสุด=light, ที่เหลือ=main
    วัสดุมี texture -> ย้อม texture ด้วยสี main
    """
    mats = []
    for p in parts.values():
        for m in p.data.materials:
            if m and m not in mats:
                mats.append(m)
    info = [(m, *base_color_of(m)) for m in mats]
    flat = [(m, c) for m, c, img in info if img is None]
    flat.sort(key=lambda mc: luminance(mc[1]))
    mapping = {}
    for i, (m, c) in enumerate(flat):
        lname = m.name.lower()
        if "eye" in lname:
            role = "eye"
        elif "antler" in lname or "horn" in lname:
            role = "horn"
        elif len(flat) == 1:
            role = "main"
        elif i == 0 and luminance(c) < 0.08:
            role = "dark"
        elif i == len(flat) - 1 and luminance(c) > 0.35:
            role = "light"
        else:
            role = "main"
        col = roles.get(role) or (roles.get("light") if role == "horn" else None) or roles["main"]
        nm = as_kit.material(f"{name}_{role}_{i}", col, roughness=0.75, noise=0.25,
                             emission=col if role == "eye" else None, strength=8 if role == "eye" else 0)
        mapping[m.name] = nm
    for m, c, img in info:
        if img is not None:
            new_img = recolor_image(img, as_kit.lin(roles["main"]), f"{name}_tex", contrast=roles.get("contrast", 1.0), keep=roles.get("keep", 0.0))
            mapping[m.name] = image_material(f"{name}_texmat", new_img)
    main_mat = as_kit.material(f"{name}_main_default", roles["main"], roughness=0.75, noise=0.25)
    for p in parts.values():
        if len(p.data.materials) == 0 or all(m is None for m in p.data.materials):
            p.data.materials.clear()
            p.data.materials.append(main_mat)
            continue
        for i, m in enumerate(p.data.materials):
            if m is None:
                p.data.materials[i] = main_mat
            elif m.name in mapping:
                p.data.materials[i] = mapping[m.name]
    # วัสดุเดียวทั้งตัว -> ไล่สีท้องอ่อน (ใช้หน้าที่หันลง)
    if len(flat) <= 1 and "light" in roles:
        light = as_kit.material(f"{name}_belly", roles["light"], roughness=0.75, noise=0.25)
        for nm, p in parts.items():
            if nm in ("Body", "Head", "Tail1") and len(p.data.materials) == 1:
                p.data.materials.append(light)
                for poly in p.data.polygons:
                    if poly.normal.z < -0.45:
                        poly.material_index = 1
    return mapping


# ---------------------------------------------------------------- 5 ของตกแต่ง
def bbox(ob):
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def glow_name(rgb):
    return "Glow_%02x%02x%02x" % tuple(int(max(0, min(1, c)) * 255) for c in rgb)


def add_glow_eyes(parts, color, size=0.075, spread=0.3, back=0.42, up=0.22):
    """ตาเรืองแสง: วางบนผิวด้านข้างหัว ตำแหน่ง ~40% จากปลายจมูก"""
    head = parts.get("Head")
    if not head:
        return
    mn, mx = bbox(head)
    c = (mn + mx) / 2
    d = mx - mn
    mat = as_kit.material("EyeGlow_" + glow_name(color), color, emission=color, strength=5)
    y = mn.y + d.y * back
    # หาผิวหัวแถว y นี้ เพื่อให้ตาแนบผิว
    vs = [head.matrix_world @ v.co for v in head.data.vertices if abs((head.matrix_world @ v.co).y - y) < d.y * 0.12]
    zs = [v.z for v in vs] or [c.z]
    z = min(zs) + (max(zs) - min(zs)) * (0.55 + up * 0.5)
    eyes = []
    for s in (-1, 1):
        xs = [v.x for v in vs if abs(v.z - z) < d.z * 0.2 and v.x * s > 0] or [c.x + s * d.x * spread]
        x = (max(xs) if s > 0 else min(xs)) * 0.92
        eyes.append(as_kit.sphere("eye", size * max(d.y, 0.6), (x, y, z), mat=mat, segments=8, scale=(0.6, 1.0, 0.7)))
    parts[glow_name(color)] = as_kit.join(glow_name(color), eyes)


def spikes_on(part, mat, n=7, height=0.8, base=0.2, along=(0.15, 0.85), tilt=-35, name="Deco_Spikes", jitter=0.15):
    mn, mx = bbox(part)
    d = mx - mn
    obs = []
    for i in range(n):
        t = along[0] + (along[1] - along[0]) * i / max(n - 1, 1)
        y = mn.y + d.y * t
        # หาจุดสูงสุดของผิวแถวๆ y นี้
        zs = [ (part.matrix_world @ v.co).z for v in part.data.vertices if abs((part.matrix_world @ v.co).y - y) < d.y * 0.08 and abs((part.matrix_world @ v.co).x - (mn.x + mx.x) / 2) < d.x * 0.25]
        z = max(zs) if zs else mx.z
        h = height * (1 - abs(t - 0.4) * 0.6)
        obs.append(as_kit.cone("sp", base, h, ((mn.x + mx.x) / 2 + math.sin(i * 2.3) * d.x * jitter, y, z - base * 0.4), rot=(rad(tilt), 0, 0), mat=mat, verts=5))
    return as_kit.join(name, obs)


def crystals_on(part, color, n=7, size=1.0, name=None):
    mn, mx = bbox(part)
    d = mx - mn
    mat = as_kit.material("Crystal_" + glow_name(color), color, emission=color, strength=6, roughness=0.15)
    obs = []
    for i in range(n):
        t = 0.2 + 0.6 * i / max(n - 1, 1)
        y = mn.y + d.y * t
        zs = [(part.matrix_world @ v.co).z for v in part.data.vertices if abs((part.matrix_world @ v.co).y - y) < d.y * 0.08]
        z = max(zs) if zs else mx.z
        h = size * (0.8 + (i % 3) * 0.45)
        obs.append(as_kit.crystal("cr", h * 0.22, h, ((mn.x + mx.x) / 2 + math.sin(i * 1.9) * d.x * 0.2, y, z - h * 0.15),
                                  rot=(math.sin(i) * 0.45, math.cos(i * 1.3) * 0.35, i), mat=mat))
    return as_kit.join(name or glow_name(color), obs)


def horns_curled(head, mat, size=1.0):
    mn, mx = bbox(head)
    c = (mn + mx) / 2
    d = mx - mn
    obs = []
    for s in (-1, 1):
        p = Vector((c.x + s * d.x * 0.38, c.y + d.y * 0.05, mx.z - d.z * 0.12))
        ang = 0.0
        r = 0.22 * size
        for k in range(9):
            ang += 0.62
            q = p + Vector((s * (0.12 * k) * size, math.sin(ang) * 0.42 * size, -math.cos(ang) * 0.42 * size + 0.42 * size))
            obs.append(as_kit.sphere("hn", r * (1 - k * 0.07), tuple(q), mat=mat, segments=8))
    return as_kit.join("Deco_Horns", obs)


def antlers(head, mat, size=1.0, name="Deco_Antlers"):
    mn, mx = bbox(head)
    c = (mn + mx) / 2
    d = mx - mn
    obs = []
    for s in (-1, 1):
        def branch(start, direction, length, r, depth):
            end = start + direction.normalized() * length
            dv = end - start
            obs.append(as_kit.cone("ant", r, length, tuple(start), rot=tuple(dv.to_track_quat("Z", "Y").to_euler()), mat=mat, verts=5, tip_r=r * 0.55))
            if depth > 0:
                for k, (ax, ay) in enumerate(((0.6, 0.2), (-0.35, -0.3), (0.2, 0.55))):
                    if k < 2 or depth > 1:
                        branch(start + dv * (0.45 + k * 0.2), direction.normalized() + Vector((s * ax, ay * 0.6, 0.55)), length * 0.6, r * 0.62, depth - 1)
        branch(Vector((c.x + s * d.x * 0.22, c.y + d.y * 0.15, mx.z - d.z * 0.1)), Vector((s * 0.8, 0.3, 1.0)), 1.5 * size, 0.1 * size, 3)
    return as_kit.join(name, obs)


def flames_on(part, color, n=6, size=0.6, name=None, region=(0.0, 1.0), top=True):
    mn, mx = bbox(part)
    d = mx - mn
    mat = as_kit.material("Flame_" + glow_name(color), color, emission=color, strength=14)
    obs = []
    for i in range(n):
        t = region[0] + (region[1] - region[0]) * (i + 0.5) / n
        y = mn.y + d.y * t
        x = (mn.x + mx.x) / 2 + math.sin(i * 2.7) * d.x * 0.3
        z = mx.z - d.z * 0.15 if top else mn.z + d.z * (0.3 + 0.4 * (i % 2))
        obs.append(as_kit.cone("fl", size * 0.35, size * (1.1 + (i % 3) * 0.35), (x, y, z), rot=(rad(-25), 0, math.sin(i) * 0.3), mat=mat, verts=6))
    return as_kit.join(name or glow_name(color), obs)


def shell_mountain(body, rock_mat, moss_mat, crystal_color, size=1.0):
    mn, mx = bbox(body)
    c = (mn + mx) / 2
    d = mx - mn
    shell = as_kit.blob("Deco_Shell", [
        ("ellipsoid", (c.x, c.y, mx.z - d.z * 0.05), (d.x * 0.62, d.y * 0.5, d.z * 0.45)),
        ("ellipsoid", (c.x, c.y - d.y * 0.1, mx.z + d.z * 0.25), (d.x * 0.35, d.y * 0.3, d.z * 0.35)),
        ("ellipsoid", (c.x + d.x * 0.2, c.y + d.y * 0.15, mx.z + d.z * 0.12), (d.x * 0.3, d.y * 0.25, d.z * 0.3)),
    ], mat=rock_mat, resolution=max(d.x, d.y) * 0.025)
    moss = []
    for i in range(7):
        a = i / 7 * math.tau
        moss.append(as_kit.sphere("ms", d.x * 0.12, (c.x + math.cos(a) * d.x * 0.3, c.y + math.sin(a) * d.y * 0.25, mx.z + d.z * 0.32), mat=moss_mat, segments=8, scale=(1, 1, 0.5)))
    trees = []
    leaf = as_kit.material("TinyPine", C(40, 90, 50), roughness=0.9)
    for i in range(6):
        a = i / 6 * math.tau + 0.4
        trees.append(as_kit.cone("tr", d.x * 0.07, d.z * 0.5, (c.x + math.cos(a) * d.x * 0.22, c.y + math.sin(a) * d.y * 0.2, mx.z + d.z * 0.35), mat=leaf, verts=6))
    deco = as_kit.join("Deco_ShellMoss", moss + trees)
    cr = crystals_on(shell, crystal_color, n=5, size=d.z * 0.35)
    return shell, deco, cr


# ---------------------------------------------------------------- 6 ส่งออก
def palette_parts(parts, animal_id):
    """ชิ้นที่ใช้วัสดุสีเดียว -> palette texture เดียว / ชิ้นที่มี texture แล้วคงไว้ / ชิ้น Glow คงสีไว้"""
    flat = []
    for nm, p in parts.items():
        if nm.startswith("Glow_"):
            continue
        has_tex = any(m and m.use_nodes and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes) for m in p.data.materials)
        if not has_tex:
            flat.append(p)
    if flat:
        img, pal = as_kit.bake_palette(flat, animal_id + "_palette")
        for p in flat:
            p.data.materials.clear()
            p.data.materials.append(pal)


def export(animal_id, parts, preview=True):
    for nm, p in parts.items():
        p.name = nm
        p.data.name = nm
        for poly in p.data.polygons:
            poly.use_smooth = False
    if preview:
        render_preview(animal_id, parts)
    import mesh_export
    importlib.reload(mesh_export)
    mesh_export.export(animal_id, parts)  # ข้อมูลเมชให้เกมประกอบเอง (ไม่ต้องอัปโหลด)
    palette_parts(parts, animal_id)
    path = as_kit.export_fbx(list(parts.values()), os.path.join(OUT, animal_id + ".fbx"))
    tris = sum(as_kit.tri_count(p) for p in parts.values())
    print(f"[game_animals] {animal_id}: parts={sorted(parts)} tris={tris} -> {path}")
    return path


def render_preview(animal_id, parts):
    """ภาพพรีวิว 3/4 สวยๆ (ก่อนแปลงเป็น palette)"""
    sc = bpy.context.scene
    hidden = []
    for o in sc.objects:
        if o.name not in parts and o.type in ("MESH", "ARMATURE") and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    pts = []
    for p in parts.values():
        pts += [p.matrix_world @ v.co for v in p.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    r = (mx - mn).length
    as_kit.setup_render(900, 700, samples=32)
    as_kit.world_sky((0.05, 0.06, 0.09), 1.0)
    floor = as_kit.ground_plane("PreviewFloor", r * 6, mat=as_kit.material("PreviewFloor", C(40, 42, 46), roughness=0.9))
    key = as_kit.light("AREA", tuple(c + Vector((r * 0.8, -r * 1.2, r * 1.4))), 600 * r * r / 30, C(255, 240, 220), size=r, rot=(rad(50), 0, rad(35)))
    key.rotation_euler = (c - key.location).to_track_quat("-Z", "Y").to_euler()
    rim = as_kit.light("AREA", tuple(c + Vector((-r * 0.9, r * 1.2, r * 0.9))), 450 * r * r / 30, C(150, 180, 255), size=r)
    rim.rotation_euler = (c - rim.location).to_track_quat("-Z", "Y").to_euler()
    cam = as_kit.camera(tuple(c + Vector((r * 0.95, -r * 1.25, r * 0.45))), tuple(c + Vector((0, 0, -r * 0.05))), lens=50)
    as_kit.bloom_compositor(strength=0.4, threshold=1.2, size=5)
    as_kit.render(os.path.join(PREVIEW, animal_id + ".png"))
    for o in (floor, key, rim, cam):
        bpy.data.objects.remove(o, do_unlink=True)
    for o in hidden:
        o.hide_render = False


# ---------------------------------------------------------------- สูตรสัตว์ทุกตัว
R = {}  # id -> function(parts) ตกแต่งเพิ่ม

RECIPES = {
    # id: ref, ความยาว(stud), ชนิดการแบ่งชิ้น, สี, ตา, หน้า(ถ้าเดาไม่ถูก)
    "Rabbit": dict(ref="Rabbit", length=2.4, kind="Quad", roles=dict(main=C(176, 150, 122), light=C(244, 236, 224), eye=C(20, 16, 14)), eye=None),
    "Deer": dict(ref="Deer", length=4.8, kind="Quad", roles=dict(main=C(150, 98, 58), light=C(226, 206, 170), horn=C(214, 196, 160), eye=C(20, 16, 14)), eye=None, forward="-Y"),
    "MossWolf": dict(ref="Wolf", length=6.0, kind="Quad", roles=dict(dark=C(26, 30, 26), main=C(66, 78, 62), light=C(132, 140, 112)), eye=C(150, 255, 90)),
    "Thornboar": dict(ref="Pig", length=5.2, kind="Quad", roles=dict(dark=C(40, 28, 22), main=C(92, 62, 48), light=C(124, 92, 70)), eye=C(255, 140, 60)),
    "StoneBear": dict(ref="Bear", length=8.0, kind="Quad", roles=dict(main=C(104, 100, 98), keep=0.15, contrast=1.3), eye=C(150, 255, 110)),
    "ReefCrab": dict(ref="Limule", length=5.0, kind="Crab", roles=dict(main=C(214, 82, 64), keep=0.2), eye=C(80, 230, 255)),
    "RiptideCroc": dict(ref="Croc", length=9.0, kind="Long", roles=dict(main=C(40, 92, 92), light=C(170, 196, 164), dark=C(20, 48, 56)), eye=C(255, 220, 60)),
    "GaleHawk": dict(ref="Eagle", length=3.6, kind="Bird", roles=dict(dark=C(70, 100, 160), main=C(226, 232, 244), light=C(250, 250, 255)), eye=C(130, 225, 255)),
    "SkyLynx": dict(ref="Cat", length=5.6, kind="Quad", roles=dict(dark=C(90, 100, 150), main=C(206, 214, 232), light=C(250, 250, 255)), eye=C(150, 235, 255)),
    "StormRam": dict(ref="Sheep", length=5.2, kind="Quad", roles=dict(dark=C(54, 60, 84), main=C(236, 240, 250), light=C(255, 255, 255)), eye=C(140, 220, 255)),
    "EmberFox": dict(ref="Fox", length=4.4, kind="Quad", roles=dict(dark=C(50, 24, 20), main=C(236, 92, 30), light=C(255, 226, 180)), eye=C(255, 236, 90)),
    "MagmaRhino": dict(ref="Rhino", length=9.5, kind="Quad", roles=dict(main=C(46, 38, 40), light=C(80, 56, 50), dark=C(24, 20, 20)), eye=C(255, 210, 80)),
    "LavaSalamander": dict(ref="Croc", length=5.0, kind="Long", roles=dict(main=C(36, 28, 30), light=C(255, 140, 40), dark=C(16, 12, 14)), eye=C(255, 240, 120)),
    "HollowStag": dict(ref="Deer", length=6.5, kind="Quad", roles=dict(main=C(26, 24, 30), light=C(40, 36, 44), horn=C(226, 218, 200), eye=C(10, 10, 12)), eye=C(255, 248, 235), forward="-Y"),
    "Terragon": dict(ref="Rhino", length=24.0, kind="Quad", roles=dict(main=C(108, 98, 78), light=C(150, 140, 110), dark=C(60, 56, 48)), eye=C(170, 255, 120)),
    "Leviathan": dict(ref="Croc", length=30.0, kind="Long", roles=dict(main=C(22, 52, 96), light=C(120, 190, 210), dark=C(10, 24, 50)), eye=C(120, 255, 255)),
    "TempestRoc": dict(ref="Eagle", length=16.0, kind="Bird", roles=dict(dark=C(30, 34, 54), main=C(70, 84, 120), light=C(214, 222, 240)), eye=C(200, 245, 255)),
    "Solfang": dict(ref="Tiger", length=17.0, kind="Quad", roles=dict(main=C(140, 52, 26), keep=0.0, contrast=1.1), eye=C(255, 255, 210), jaw=("Jaw",)),
    "TerraPup": dict(ref="Fox", length=2.4, kind="Quad", roles=dict(dark=C(60, 110, 50), main=C(140, 210, 100), light=C(230, 250, 210)), eye=C(255, 255, 255)),
    "TidePup": dict(ref="Fox", length=2.4, kind="Quad", roles=dict(dark=C(40, 90, 160), main=C(90, 180, 255), light=C(220, 244, 255)), eye=C(255, 255, 255)),
    "GalePup": dict(ref="Fox", length=2.4, kind="Quad", roles=dict(dark=C(140, 160, 210), main=C(236, 242, 255), light=C(255, 255, 255)), eye=C(90, 140, 255)),
    "EmberPup": dict(ref="Fox", length=2.4, kind="Quad", roles=dict(dark=C(150, 50, 20), main=C(255, 120, 50), light=C(255, 230, 190)), eye=C(255, 255, 255)),
}


def deco(animal_id, parts):
    m = as_kit.material
    if animal_id == "MossWolf":
        parts["Deco_Moss"] = spikes_on(parts["Body"], m("MossFur", C(58, 98, 44), roughness=0.95), n=11, height=0.55, base=0.16, name="Deco_Moss", tilt=-55)
    elif animal_id == "Thornboar":
        parts["Deco_Thorns"] = spikes_on(parts["Body"], m("Thorn", C(66, 110, 44)), n=8, height=1.1, base=0.2)
        head = parts["Head"]
        mn, mx = bbox(head)
        tusk = m("Tusk", C(238, 228, 204), roughness=0.4)
        parts["Deco_Tusks"] = as_kit.join("Deco_Tusks", [as_kit.cone("t", 0.12, 0.8, (s * (mx.x - mn.x) * 0.3 + (mn.x + mx.x) / 2, mn.y + 0.25, mn.z + (mx.z - mn.z) * 0.3), rot=(rad(-60), rad(s * 15), 0), mat=tusk, verts=6) for s in (-1, 1)])
    elif animal_id == "StoneBear":
        parts[glow_name(C(120, 240, 100))] = crystals_on(parts["Body"], C(120, 240, 100), n=8, size=1.4)
    elif animal_id == "StormRam":
        parts["Deco_Horns"] = horns_curled(parts["Head"], m("RamHorn", C(214, 190, 130), roughness=0.5), size=0.9)
        parts[glow_name(C(160, 220, 255))] = flames_on(parts["Body"], C(160, 220, 255), n=5, size=0.5)
    elif animal_id == "SkyLynx":
        parts[glow_name(C(200, 235, 255))] = spikes_on(parts["Body"], m("WindRibbon", C(200, 235, 255), emission=C(200, 235, 255), strength=6), n=5, height=0.6, base=0.12, tilt=-70, name=glow_name(C(200, 235, 255)))
    elif animal_id == "EmberFox":
        if "Tail1" in parts:
            parts[glow_name(C(255, 150, 40))] = flames_on(parts["Tail1"], C(255, 150, 40), n=5, size=0.55, region=(0.4, 1.0))
    elif animal_id == "MagmaRhino":
        parts[glow_name(C(255, 104, 20))] = flames_on(parts["Body"], C(255, 104, 20), n=8, size=0.7, top=False)
        parts["Deco_Spikes"] = spikes_on(parts["Body"], m("Obsidian", C(28, 24, 30), roughness=0.2), n=6, height=1.2, base=0.3)
    elif animal_id == "LavaSalamander":
        parts[glow_name(C(255, 120, 30))] = flames_on(parts["Body"], C(255, 120, 30), n=6, size=0.35)
    elif animal_id == "RiptideCroc":
        parts["Deco_Plates"] = spikes_on(parts["Body"], m("CrocPlate", C(22, 52, 60)), n=9, height=0.5, base=0.25, tilt=0)
        parts[glow_name(C(80, 220, 255))] = spikes_on(parts["Body"], m("CrocGlow", C(80, 220, 255), emission=C(80, 220, 255), strength=8), n=6, height=0.25, base=0.1, tilt=0, name=glow_name(C(80, 220, 255)), jitter=0.4)
    elif animal_id == "ReefCrab":
        parts[glow_name(C(255, 120, 170))] = crystals_on(parts["Body"], C(255, 120, 170), n=6, size=0.6)
    elif animal_id == "HollowStag":
        skull = m("StagSkull", C(226, 218, 200), roughness=0.5)
        # เขาเดิมของกวาง + เขาใหญ่พิเศษ
        parts["Deco_Antlers"] = antlers(parts["Head"], skull, size=1.6)
        # หน้ากากกระโหลก: ทาสีหน้าของหัวให้เป็นกระดูก (ไม่ใส่ลูกบอลแยก)
        head = parts["Head"]
        mn, mx = bbox(head)
        me = head.data
        if skull.name not in [m.name for m in me.materials]:
            me.materials.append(skull)
        si = [m.name for m in me.materials].index(skull.name)
        for poly in me.polygons:
            c = head.matrix_world @ poly.center
            if c.y < mn.y + (mx.y - mn.y) * 0.45:
                poly.material_index = si
    elif animal_id == "Terragon":
        shell, moss, cr = shell_mountain(parts["Body"], m("ShellRock", C(90, 96, 84), roughness=0.9, noise=0.5), m("ShellMoss", C(76, 140, 52)), C(130, 240, 110))
        parts["Deco_Shell"] = shell
        parts["Deco_ShellMoss"] = moss
        parts[glow_name(C(130, 240, 110))] = cr
    elif animal_id == "Leviathan":
        parts[glow_name(C(70, 230, 255))] = spikes_on(parts["Body"], m("LevFin", C(70, 230, 255), emission=C(70, 230, 255), strength=6), n=10, height=3.2, base=0.9, tilt=-20, name=glow_name(C(70, 230, 255)))
    elif animal_id == "TempestRoc":
        parts["Deco_Crest"] = spikes_on(parts["Head"], m("RocCrest", C(30, 34, 54)), n=4, height=2.5, base=0.4, tilt=-50, name="Deco_Crest")
        if "WingL" in parts:
            parts[glow_name(C(160, 210, 255))] = flames_on(parts["Body"], C(160, 210, 255), n=6, size=1.6)
    elif animal_id == "Solfang":
        head = parts["Head"]
        mn, mx = bbox(head)
        c = (mn + mx) / 2
        d = mx - mn
        fire = C(255, 120, 20)
        mat = as_kit.material("ManeFire", fire, emission=fire, strength=12)
        mane = []
        for i in range(14):
            a = i / 14 * math.tau
            mane.append(as_kit.cone("mn", d.x * 0.14, d.z * 0.55, (c.x + math.cos(a) * d.x * 0.5, c.y + d.y * 0.25, c.z + math.sin(a) * d.z * 0.5),
                                    rot=(rad(-90) + math.sin(a) * 0.6, 0, -math.cos(a) * 0.9), mat=mat, verts=5))
        parts[glow_name(fire)] = as_kit.join(glow_name(fire), mane)
    elif animal_id.endswith("Pup"):
        col = RECIPES[animal_id]["roles"]["main"]
        parts[glow_name(col)] = flames_on(parts.get("Tail1") or parts["Body"], col, n=3, size=0.25, region=(0.5, 1.0))


def build(animal_id, preview=True):
    rec = RECIPES[animal_id]
    as_kit.reset_scene()
    merged, arm, ref_obs = merged_rest_mesh(rec["ref"])
    bones = bone_points(arm)
    _, bones, fwd = orient(merged, bones, rec.get("forward"), rec["length"])
    for o in ref_obs:
        bpy.data.objects.remove(o, do_unlink=True)
    parts = split_parts(merged, bones, rec["kind"], rec.get("jaw", ()))
    bpy.data.objects.remove(merged, do_unlink=True)
    # ชิ้นเล็กมาก (เศษ) -> รวมเข้า Body
    for nm in list(parts):
        if nm != "Body" and len(parts[nm].data.polygons) < 4 and "Body" in parts:
            parts["Body"] = as_kit.join("Body", [parts["Body"], parts.pop(nm)])
    recolor(parts, rec["roles"], animal_id)
    if rec.get("eye"):
        add_glow_eyes(parts, rec["eye"])
    deco(animal_id, parts)
    print(animal_id, "forward", fwd, {k: len(v.data.polygons) for k, v in parts.items()})
    return export(animal_id, parts, preview=preview)


def build_all(ids=None, preview=True):
    done = []
    for aid in ids or RECIPES:
        try:
            build(aid, preview)
            done.append(aid)
        except Exception as e:
            import traceback
            print("FAILED", aid, traceback.format_exc())
    return done
