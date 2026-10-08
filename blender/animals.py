"""
animals.py — สูตรปั้นสัตว์ ANIMAL SURVIVAL ใน Blender (ออร์แกนิกด้วย metaball)
ชิ้นส่วนตั้งชื่อตรงกับกระดูกในเกม -> นำเข้า Roblox แล้วขยับได้ทันที (AnimalModels.rigCustom)

ใช้:  exec(open(r"...\\blender\\animals.py", encoding="utf-8").read())
      build("MossWolf")       -> dict ชิ้นส่วน
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"E:\GAME\roblox\Animal Survival\blender")
import importlib
import as_kit

importlib.reload(as_kit)
from as_kit import V, blob, cone, crystal, join, material, fur_material, sphere, decimate_to, tri_count

rad = math.radians


def two_tone(ob, top_mat, belly_mat=None, threshold=-0.25):
    """ใส่วัสดุขน (ไล่สีบน-ท้องในเชดเดอร์อยู่แล้ว) — belly_mat ใช้เฉพาะเวลาบังคับสีทั้งชิ้น"""
    me = ob.data
    me.materials.clear()
    me.materials.append(top_mat)
    return ob


def paint_where(ob, mat, test):
    me = ob.data
    if mat.name not in [m.name for m in me.materials]:
        me.materials.append(mat)
    idx = [m.name for m in me.materials].index(mat.name)
    bpy.context.view_layer.update()
    mw = ob.matrix_world
    for p in me.polygons:
        if test(mw @ p.center, p.normal):
            p.material_index = idx
    return ob


# ---------------------------------------------------------------- สี่ขา
def quadruped(name, P, coll=None):
    """
    P: L (ยาวลำตัว), H (สูงลำตัว), W (กว้าง), leg (ความยาวขาใต้ลำตัว), T (ความหนาขา),
       head (w,h,l), snout (w,h,l), neck (ยาวคอ), neck_up (องศาเงยคอ),
       fur, belly, dark, eye (สีตาเรืองแสง), eye_glow, ears ("pointy"/"round"/"big"/"long"/"tufted"/"none"),
       tail ("bushy"/"long"/"short"/"thin"/"puff"/"flame"), mane (bool), res (ความละเอียด)
    """
    L, H, W, leg, T = P["L"], P["H"], P["W"], P["leg"], P["T"]
    res = P.get("res", 0.09)
    fur = fur_material(name + "_Fur", P["fur"], P["belly"])
    belly = material(name + "_Belly", P["belly"], roughness=0.85, noise=0.25, sheen=0.3)
    dark = material(name + "_Dark", P["dark"], roughness=0.7, noise=0.2)
    eye = material(name + "_Eye", P["eye"], emission=P["eye"], strength=P.get("eye_glow", 12.0), roughness=0.2)
    bone = material("Bone_White", (0.86, 0.82, 0.72), roughness=0.4)
    zc = leg + H / 2  # ความสูงศูนย์กลางลำตัว
    parts = {}

    # ---------- ลำตัว + คอ
    hw, hh = W / 2, H / 2
    neck_len = P.get("neck", 1.0)
    neck_up = rad(P.get("neck_up", 35))
    ny0 = -L * 0.40
    nz0 = zc + hh * 0.35
    neck_dir = Vector((0, -math.cos(neck_up), math.sin(neck_up)))
    neck_end = Vector((0, ny0, nz0)) + neck_dir * neck_len
    els = [
        ("ellipsoid", (0, -L * 0.24, zc + hh * 0.06), (hw * 1.05, L * 0.30, hh * 1.06)),  # อก
        ("ellipsoid", (0, 0.0, zc - hh * 0.02), (hw * 0.86, L * 0.34, hh * 0.84)),  # เอว
        ("ellipsoid", (0, L * 0.28, zc + hh * 0.02), (hw * 0.96, L * 0.26, hh * 0.95)),  # สะโพก
        ("ellipsoid", (0, -L * 0.36, zc - hh * 0.25), (hw * 0.7, L * 0.16, hh * 0.6)),  # อกล่าง
    ]
    # คอเป็นช่วงๆ
    for i in range(4):
        t = i / 3
        p = Vector((0, ny0, nz0)).lerp(neck_end, t)
        r = (hw * 0.62) * (1 - t * 0.3)
        els.append(("ellipsoid", tuple(p), (r, r * 1.1, r * 1.2)))
    if P.get("mane"):
        for i in range(5):
            t = i / 4
            p = Vector((0, ny0, nz0)).lerp(neck_end, t)
            els.append(("ellipsoid", (0, p.y + 0.2, p.z + hh * 0.25), (hw * 0.95, hw * 0.7, hh * 0.55)))
    body = blob("Body", els, resolution=res, coll=coll)
    two_tone(body, fur, belly, -0.3)
    parts["Body"] = body

    # ---------- หัว
    hwh, hhh, hlh = P["head"]
    sw, sh, sl = P["snout"]
    head_c = neck_end + Vector((0, -hlh * 0.25, hhh * 0.12))
    snout_c = head_c + Vector((0, -hlh * 0.5 - sl * 0.32, -hhh * 0.12))
    head_els = [
        ("ellipsoid", tuple(head_c), (hwh / 2, hlh / 2, hhh / 2)),
        ("ellipsoid", tuple(snout_c), (sw / 2, sl / 2, sh / 2)),
        ("ellipsoid", tuple(head_c + Vector((0, -hlh * 0.15, -hhh * 0.18))), (hwh * 0.5, hlh * 0.35, hhh * 0.32)),  # แก้ม
        ("ellipsoid", tuple(head_c + Vector((0, -hlh * 0.32, hhh * 0.22))), (hwh * 0.34, hlh * 0.2, hhh * 0.14)),  # คิ้ว
    ]
    head = blob("Head", head_els, resolution=res * 0.7, coll=coll)
    two_tone(head, fur, belly, -0.45)
    nose = sphere("Nose", sw * 0.2, tuple(snout_c + Vector((0, -sl * 0.48, sh * 0.2))), mat=dark, scale=(1.2, 0.9, 0.8))
    ears = []
    ear = P.get("ears", "pointy")
    for side in (-1, 1):
        base = head_c + Vector((side * hwh * 0.28, hlh * 0.08, hhh * 0.36))
        if ear in ("pointy", "big", "tufted"):
            s = 1.5 if ear == "big" else 1.0
            ears.append(cone("Ear", hwh * 0.17 * s, hhh * 0.75 * s, tuple(base), rot=(rad(-12), rad(side * 16), 0), mat=fur, verts=4))
            if ear == "tufted":
                ears.append(cone("Tuft", 0.06, hhh * 0.35, tuple(base + Vector((side * 0.05, 0, hhh * 0.72))), mat=dark, verts=4))
        elif ear == "round":
            ears.append(sphere("Ear", hwh * 0.14, tuple(base + Vector((side * 0.05, 0, 0.05))), mat=fur, scale=(0.6, 1, 1)))
        elif ear == "long":
            ears.append(sphere("Ear", hhh * 0.5, tuple(base + Vector((0, 0.1, hhh * 0.55))), mat=fur, scale=(0.35, 0.28, 1.1)))
    head = join("Head", [head, nose] + ears, coll)
    parts["Head"] = head
    # ตาเรืองแสง (แยกชิ้น -> Roblox ใช้ Neon)
    eyes = []
    for side in (-1, 1):
        ec = head_c + Vector((side * hwh * 0.3, -hlh * 0.36, hhh * 0.12))
        eyes.append(sphere("Eye", max(hwh * 0.09, 0.08), tuple(ec), mat=eye, scale=(1.0, 0.6, 0.7), segments=10))
    parts["EyeGlow"] = join("EyeGlow", eyes, coll)

    # ---------- ขากรรไกร + ฟัน
    jaw_c = snout_c + Vector((0, sl * 0.04, -sh * 0.45))
    jaw = blob("Jaw", [("ellipsoid", tuple(jaw_c), (sw * 0.4, sl * 0.42, sh * 0.2))], resolution=res * 0.6, coll=coll)
    two_tone(jaw, belly)
    teeth = []
    for side in (-1, 1):
        teeth.append(cone("Fang", sw * 0.06, sh * 0.35, tuple(snout_c + Vector((side * sw * 0.24, -sl * 0.3, -sh * 0.12))), rot=(math.pi, 0, 0), mat=bone, verts=5))
    parts["Jaw"] = join("Jaw", [jaw] + teeth, coll)

    # ---------- ขา
    hip_z = zc - hh * 0.1
    for nm, sx, sy in (("LegFL", -1, -1), ("LegFR", 1, -1), ("LegBL", -1, 1), ("LegBR", 1, 1)):
        hip = Vector((sx * hw * 0.55, sy * L * 0.30, hip_z))
        total = hip_z
        front = sy < 0
        if front:
            knee = hip + Vector((0, -T * 0.15, -total * 0.5))
            ankle = hip + Vector((0, T * 0.05, -total * 0.88))
        else:
            knee = hip + Vector((0, -T * 0.9, -total * 0.42))  # ขาหลังหักข้อ
            ankle = hip + Vector((0, T * 0.55, -total * 0.8))
        foot = Vector((hip.x, ankle.y - T * 0.25, T * 0.32))
        def seg(a, b, r):
            d = b - a
            mid = (a + b) / 2
            rot = d.to_track_quat("X", "Z").to_euler()
            return ("capsule", tuple(mid), d.length, r, tuple(rot))
        els = [
            ("ellipsoid", tuple(hip + Vector((0, sy * T * 0.1, -total * 0.12))), (T * 0.95, T * (1.25 if not front else 1.0), total * 0.3)),
            seg(hip, knee, T * 0.55),
            seg(knee, ankle, T * 0.42),
            seg(ankle, foot, T * 0.38),
            ("ellipsoid", tuple(foot + Vector((0, -T * 0.25, -T * 0.05))), (T * 0.6, T * 0.8, T * 0.35)),
        ]
        legob = blob(nm, els, resolution=res * 0.7, coll=coll)
        two_tone(legob, fur, belly, -0.6)
        paint_where(legob, dark, lambda p, n: p.z < T * 0.55)
        parts[nm] = legob

    # ---------- หาง
    tail = P.get("tail", "bushy")
    base = Vector((0, L * 0.47, zc + hh * 0.3))
    if tail != "none":
        n, length, r0 = {"bushy": (7, L * 0.62, hw * 0.45), "long": (8, L * 0.85, hw * 0.2), "short": (3, L * 0.18, hw * 0.25),
                         "thin": (6, L * 0.4, hw * 0.12), "puff": (1, 0.1, hw * 0.45), "flame": (7, L * 0.6, hw * 0.42)}[tail]
        els = []
        for i in range(n):
            t = i / max(n - 1, 1)
            droop = math.sin(t * 1.4) * length * (0.35 if tail != "long" else 0.15)
            p = base + Vector((0, t * length, -droop + (0.15 * length if tail == "bushy" else 0) * t))
            r = r0 * (1 - t * 0.35) if tail in ("bushy", "flame") else r0 * (1 - t * 0.6)
            if tail in ("bushy", "flame"):
                r *= 0.8 + math.sin(t * math.pi) * 0.5
            els.append(("ball", tuple(p), r))
        tob = blob("Tail1", els, resolution=res * 0.8, coll=coll)
        tip_mat = belly if tail == "bushy" else (material(name + "_Flame", (1.0, 0.45, 0.08), emission=(1.0, 0.45, 0.08), strength=18) if tail == "flame" else dark)
        two_tone(tob, fur)
        far = base.y + length * 0.72
        paint_where(tob, tip_mat, lambda p, nrm: p.y > far)
        parts["Tail1"] = tob
    return parts


# ---------------------------------------------------------------- สูตรแต่ละตัว
C = lambda r, g, b: (r / 255, g / 255, b / 255)


def build_MossWolf(coll=None):
    P = dict(L=5.6, H=2.6, W=2.4, leg=2.6, T=0.62, head=(1.75, 1.6, 1.7), snout=(0.9, 0.7, 1.15), neck=1.2, neck_up=22, eye_glow=6,
             fur=C(48, 56, 46), belly=C(104, 110, 88), dark=C(24, 26, 24), eye=C(150, 255, 90), ears="pointy", tail="bushy", mane=True)
    parts = quadruped("MossWolf", P, coll)
    zc = P["leg"] + P["H"] / 2
    top = zc + P["H"] / 2
    # ตะไคร่บนหลัง + ขนแผงคอตั้งชัน
    moss = material("Moss", C(84, 150, 56), roughness=0.95, noise=0.5)
    blobs = []
    for i in range(6):
        y = -1.8 + i * 0.75
        blobs.append(("ellipsoid", (math.sin(i * 2.1) * 0.3, y, top - 0.15 - abs(y + 0.3) * 0.08), (0.6, 0.45, 0.28)))
    m = blob("MossPatch", blobs, mat=moss, resolution=0.08, coll=coll)
    spikes = []
    fur = bpy.data.materials["MossWolf_Fur"]
    for i in range(9):
        y = -2.6 + i * 0.42
        h = 0.9 - abs(i - 3) * 0.08
        spikes.append(cone("Hackle", 0.22, h, (math.sin(i * 1.7) * 0.18, y, top + 0.05 - (0.25 if i > 5 else 0)), rot=(rad(-35), 0, 0), mat=fur, verts=4))
    parts["Body"] = join("Body", [parts["Body"], m] + spikes, coll)
    return parts


def build_HollowStag(coll=None):
    P = dict(L=6.0, H=3.0, W=2.4, leg=6.2, T=0.42, head=(1.4, 2.0, 1.7), snout=(0.85, 0.85, 1.6), neck=3.0, neck_up=62,
             fur=C(16, 14, 18), belly=C(28, 24, 30), dark=C(8, 8, 10), eye=C(255, 246, 230), eye_glow=30, ears="none", tail="short")
    parts = quadruped("HollowStag", P, coll)
    skull = material("Skull", C(226, 218, 200), roughness=0.5, noise=0.25)
    head = parts["Head"]
    # หน้ากระโหลก: ทาสีด้านหน้าหัวเป็นกระดูก
    hc = sum((head.matrix_world @ v.co for v in head.data.vertices), Vector()) / len(head.data.vertices)
    paint_where(head, skull, lambda p, n: p.y < hc.y + 0.1)
    # เขากวางยักษ์ (กิ่งก้านเหมือนต้นไม้ตาย)
    antlers = []
    top = Vector(hc) + Vector((0, 0.3, 0.9))
    for side in (-1, 1):
        def branch(start, direction, length, r, depth):
            end = start + direction.normalized() * length
            d = end - start
            rot = d.to_track_quat("Z", "Y").to_euler()
            antlers.append(cone("Antler", r, length, tuple(start), rot=tuple(rot), mat=skull, verts=6, tip_r=r * 0.55))
            if depth > 0:
                for k, (ax, ay) in enumerate(((0.55, 0.15), (-0.35, -0.25), (0.15, 0.5))):
                    if k < 2 or depth > 1:
                        nd = direction.normalized() + Vector((side * ax, ay * 0.6, 0.6))
                        branch(start + d * (0.45 + k * 0.22), nd, length * 0.62, r * 0.6, depth - 1)
        branch(top + Vector((side * 0.35, 0, 0)), Vector((side * 0.8, 0.25, 1.0)), 2.6, 0.16, 3)
    parts["Head"] = join("Head", [head] + antlers, coll)
    # ซี่โครงโผล่
    ribs = []
    for i in range(5):
        for side in (-1, 1):
            ribs.append(cone("Rib", 0.07, 2.1, (side * 1.2, -0.9 + i * 0.45, 7.2), rot=(0, side * rad(160), 0), mat=skull, verts=5, tip_r=0.04))
    parts["Body"] = join("Body", [parts["Body"]] + ribs, coll)
    return parts


def build_EmberFox(coll=None):
    P = dict(L=4.2, H=1.9, W=1.8, leg=2.0, T=0.42, head=(1.5, 1.3, 1.5), snout=(0.75, 0.55, 1.25), neck=0.8, neck_up=35,
             fur=C(232, 92, 28), belly=C(255, 226, 184), dark=C(56, 28, 22), eye=C(255, 236, 90), ears="big", tail="flame")
    return quadruped("EmberFox", P, coll)


def build_StoneBear(coll=None):
    P = dict(L=7.8, H=4.6, W=4.8, leg=3.0, T=1.35, head=(2.8, 2.5, 2.6), snout=(1.4, 1.15, 1.3), neck=0.9, neck_up=20,
             fur=C(96, 92, 90), belly=C(70, 66, 64), dark=C(44, 42, 42), eye=C(150, 255, 110), ears="round", tail="short", res=0.14)
    parts = quadruped("StoneBear", P, coll)
    gem = material("TerraCrystal", C(120, 240, 100), emission=C(120, 240, 100), strength=8, roughness=0.15)
    crystals = []
    for i in range(9):
        h = 1.4 + (i % 3) * 0.7
        crystals.append(crystal("Crystal", 0.35 + (i % 2) * 0.12, h, (math.sin(i * 1.9) * 1.1, -2.4 + i * 0.6, 3.0 + 4.6 - 0.2), rot=(math.sin(i) * 0.5, math.cos(i * 1.3) * 0.4, i), mat=gem))
    parts["Crystals"] = join("Crystals", crystals, coll)
    return parts


BUILDERS = {
    "MossWolf": build_MossWolf,
    "HollowStag": build_HollowStag,
    "EmberFox": build_EmberFox,
    "StoneBear": build_StoneBear,
}


def build(animal_id, offset=(0, 0, 0), coll=None):
    coll = coll or as_kit.collection(animal_id)
    parts = BUILDERS[animal_id](coll)
    for nm, ob in parts.items():
        ob.location = Vector(ob.location) + Vector(offset)
    return parts


def export_animal(animal_id, parts, target_tris=2400):
    """ทำสำเนา -> ลดโพลี -> palette -> FBX  (blender/exports/animals/<id>.fbx)"""
    out_dir = os.path.join(as_kit.EXPORTS, "animals")
    os.makedirs(out_dir, exist_ok=True)
    copies = []
    for nm, ob in parts.items():
        ob.name = nm + "_SRC"  # ให้สำเนาได้ชื่อตรงเป๊ะ (Body, Head, ...)
    for nm, ob in parts.items():
        c = ob.copy()
        c.parent = None
        c.matrix_world = ob.matrix_world.copy()
        c.data = ob.data.copy()
        c.name = nm
        c.data.name = nm
        bpy.context.scene.collection.objects.link(c)
        decimate_to(c, target_tris if nm in ("Body", "Head") else target_tris // 2)
        copies.append(c)
    img, pal = as_kit.bake_palette(copies, animal_id + "_palette")
    for c in copies:
        emissive = any(m.get("as_emissive") for m in c.data.materials if m)
        if not emissive:
            c.data.materials.clear()
            c.data.materials.append(pal)
    # ย้ายให้เท้าอยู่ที่พื้น ตรงกลางที่ 0
    path = as_kit.export_fbx(copies, os.path.join(out_dir, animal_id + ".fbx"))
    tris = sum(tri_count(c) for c in copies)
    for c in copies:
        bpy.data.objects.remove(c, do_unlink=True)
    for nm, ob in parts.items():
        ob.name = nm
    print(f"[export] {animal_id}: {len(copies)} parts, {tris} tris -> {path}")
    return path
