"""
props_export.py — ไอเทม/อาวุธ/ต้นไม้/หิน/ของในแคมป์ จากโมเดลจริง CC0 -> ข้อมูลเมชในเกม (src/ReplicatedStorage/PropMeshData)

แหล่ง (CC0 ทั้งหมด):
  K  = Kenney Nature Kit      (assets/downloads/kenney_nature)
  S  = Kenney Survival Kit    (assets/downloads/kenney_survival)
  R  = Quaternius RPG Items   (assets/downloads/rpg)

ทุกชิ้นส่งออกเป็นพิกัด Roblox: พื้นอยู่ y = 0 กลางชิ้นที่ x = z = 0 (เครื่องมือ: ด้ามตั้งตามแกน Y หัวอยู่ด้านบน)
ชิ้น "Glow_RRGGBB" = Neon เรืองแสงในเกม
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import as_kit
import mesh_export

importlib.reload(as_kit)
importlib.reload(mesh_export)

DL = r"E:\GAME\roblox\Animal Survival\assets\downloads"
SRC = {
    "K": os.path.join(DL, "kenney_nature", "Models", "GLTF format", "{}.glb"),
    "S": os.path.join(DL, "kenney_survival", "Models", "GLB format", "{}.glb"),
    "R": os.path.join(DL, "rpg", "Ultimate RPG Items Pack - Aug 2019", "Blends", "{}.blend"),
}
OUT = os.path.join(as_kit.ROOT, "src", "ReplicatedStorage", "PropMeshData")
PREVIEW = os.path.join(as_kit.ROOT, "art", "props")
os.makedirs(PREVIEW, exist_ok=True)
C = lambda r, g, b: (r / 255, g / 255, b / 255)

# id: (แหล่ง, ไฟล์, ขนาด, ตัวเลือก)
#   size: ("h", สูง) | ("max", ด้านยาวสุด)
#   tint: คูณสีทุกวัสดุ (sRGB) / recolor: {คำในชื่อวัสดุ: สี} / glow: {คำในชื่อวัสดุ: สี}
#   tool: True = จัดด้ามตามแกน Y หัวอยู่บน
PROPS = {
    # ---------- ต้นไม้/พืช
    "Oak": ("K", "tree_oak", ("h", 18), dict(recolor={"leaf": C(92, 150, 66)})),
    "GiantPine": ("K", "tree_pineTallA_detailed", ("h", 34), dict(recolor={"leaf": C(38, 84, 52)})),
    "AncientOak": ("K", "tree_detailed_dark", ("h", 30), dict(recolor={"leaf": C(46, 98, 50)})),
    "Palm": ("K", "tree_palmDetailedTall", ("h", 24), dict(recolor={"leaf": C(76, 160, 70)})),
    "FrostPine": ("K", "tree_pineRoundC", ("h", 26), dict(recolor={"leaf": C(150, 196, 200), "leafs": C(150, 196, 200)})),
    "CharredTree": ("K", "tree_thin_dark", ("h", 20), dict(recolor_all=C(34, 30, 30), embers=C(255, 110, 30))),
    "Bush": ("K", "plant_bushLarge", ("h", 4.5), dict(recolor={"leaf": C(70, 130, 58)})),
    "BerryBush": ("K", "plant_bushDetailed", ("h", 4.5), dict(recolor={"leaf": C(60, 118, 52)}, berries=C(214, 40, 90))),
    "Flowers": ("K", "flower_yellowA", ("h", 2.4)),
    "GlowShroom": ("K", "mushroom_redGroup", ("h", 6), dict(glow_all_but_stem=C(90, 240, 200))),
    # ---------- หิน/แร่/คริสตัล
    "Boulder": ("K", "rock_largeA", ("h", 6)),
    "MossRock": ("K", "rock_largeB", ("h", 7), dict(moss=C(70, 130, 50))),
    "SeaRock": ("K", "rock_tallC", ("h", 10), dict(tint=C(220, 236, 226))),
    "SkyStone": ("K", "stone_tallB", ("h", 9), dict(tint=C(170, 182, 230))),
    "IronRock": ("K", "stone_largeC", ("h", 6), dict(ore=C(214, 140, 96))),
    "CoalRock": ("K", "rock_largeD", ("h", 6), dict(recolor_all=C(46, 42, 44), ore_glow=C(255, 96, 24))),
    "TerraCrystal": ("R", "Crystal2", ("h", 9), dict(glow_all=C(130, 240, 100))),
    "TideCrystal": ("R", "Crystal3", ("h", 9), dict(glow_all=C(90, 210, 255))),
    "GaleCrystal": ("R", "Crystal1", ("h", 9), dict(glow_all=C(220, 236, 255))),
    "EmberCrystal": ("R", "Crystal5", ("h", 9), dict(glow_all=C(255, 120, 40))),
    # ---------- แคมป์/สิ่งของ
    "Campfire": ("K", "campfire_stones", ("max", 9)),
    "Tent": ("K", "tent_detailedOpen", ("h", 9)),
    "Workbench": ("S", "workbench", ("max", 9)),
    "Chest": ("S", "chest", ("max", 4.2)),
    "LogWall": ("S", "fence-fortified", ("max", 12)),
    "Bed": ("S", "bedroll", ("max", 8)),
    "Barrel": ("S", "barrel", ("h", 4)),
    "LogPile": ("K", "log_stackLarge", ("max", 8)),
    # ---------- เครื่องมือ/อาวุธ
    "OldAxe": ("S", "tool-axe", ("max", 4.2), dict(tool=True)),
    "IronAxe": ("S", "tool-axe-upgraded", ("max", 4.6), dict(tool=True)),
    "StoneAxe": ("R", "Axe_small", ("max", 4.4), dict(tool=True)),
    "Pickaxe": ("S", "tool-pickaxe-upgraded", ("max", 4.6), dict(tool=True)),
    "Bow": ("R", "Bow_Wooden", ("max", 5.0), dict(tool=True)),
    "GaleBow": ("R", "Bow_Golden", ("max", 6.0), dict(tool=True, tint=C(200, 225, 255), glow_trim=C(180, 225, 255))),
    "TerraHammer": ("R", "Hammer_Double", ("max", 5.6), dict(tool=True, tint=C(150, 170, 140), glow_trim=C(130, 240, 100))),
    "EmberBlade": ("R", "Sword_big", ("max", 6.2), dict(tool=True, tint=C(90, 70, 70), glow_trim=C(255, 120, 30))),
    "FourfoldBlade": ("R", "Sword_big_Golden", ("max", 6.8), dict(tool=True, glow_trim=C(255, 240, 200))),
}


# ---------------------------------------------------------------- นำเข้า
def import_source(kind, name):
    path = SRC[kind].format(name)
    before = set(bpy.data.objects)
    if path.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o:
                bpy.context.scene.collection.objects.link(o)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    for o in meshes:
        o.parent = None
    return as_kit.join("SRC_" + name, meshes)


def srgb_of(mat):
    c, _, _ = mesh_export.mat_info(mat)
    return c


def flat_mat(name, color, emissive=False):
    m = bpy.data.materials.new(name)
    m["as_color"] = list(color)
    m["as_emissive"] = emissive
    m.use_nodes = True
    bsdf = as_kit.principled(m)
    bsdf.inputs["Base Color"].default_value = (*as_kit.lin(color), 1)
    if emissive:
        as_kit.set_input(bsdf, ["Emission Color", "Emission"], (*as_kit.lin(color), 1))
        as_kit.set_input(bsdf, "Emission Strength", 6)
    return m


def normalize(ob, size, tool=False):
    me = ob.data
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    d = mx - mn
    if tool:
        # ด้านยาวสุด -> แกน Z (Roblox Y)
        axis = max(range(3), key=lambda i: d[i])
        if axis == 0:
            me.transform(Matrix.Rotation(math.pi / 2, 4, "Y"))
        elif axis == 1:
            me.transform(Matrix.Rotation(-math.pi / 2, 4, "X"))
        pts = [v.co for v in me.vertices]
        zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
        span = zmax - zmin

        def width(lo, hi):
            sel = [p for p in pts if lo <= p.z <= hi]
            if not sel:
                return 0
            return (max(p.x for p in sel) - min(p.x for p in sel)) + (max(p.y for p in sel) - min(p.y for p in sel))
        # หัว (กว้างกว่า) ต้องอยู่ด้านบน
        if width(zmin, zmin + span * 0.3) > width(zmax - span * 0.3, zmax):
            me.transform(Matrix.Rotation(math.pi, 4, "X"))
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    d = mx - mn
    mode, val = size
    s = val / (d.z if mode == "h" else max(d))
    me.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))))
    me.transform(Matrix.Scale(s, 4))
    me.update()


def apply_colors(ob, pid, opt):
    """ปรับสีวัสดุตามตัวเลือก + แยกส่วนเรืองแสงเป็นชิ้น Glow"""
    me = ob.data
    glow_faces = {}  # color -> [poly index]
    new_mats = []
    saved_idx = [p.material_index for p in me.polygons]
    for i, m in enumerate(me.materials):
        _, _, img = mesh_export.mat_info(m)
        if img is not None and not any(k in opt for k in ("recolor_all", "recolor")):
            m["as_textured"] = True
            new_mats.append(m)  # มี texture -> คงไว้ (ส่งออกจะสุ่มสีจาก texture ทีละหน้า)
            continue
        base = srgb_of(m)
        nm = (m.name if m else "").lower()
        col = base
        # ใบไม้สีฟ้าอมเขียวของ Kenney -> เขียวป่า (ให้เข้ากับโทนเกม)
        if col[1] > 0.6 and col[2] > 0.55 and col[0] < 0.55 and not opt.get("keep_teal"):
            col = opt.get("leaf", C(78, 140, 60))
        if "tint" in opt:
            col = tuple(min(1, c * t * 1.15) for c, t in zip(col, opt["tint"]))
        if "recolor_all" in opt:
            col = opt["recolor_all"]
        for key, rc in opt.get("recolor", {}).items():
            if key in nm:
                col = rc
        new_mats.append(flat_mat(f"{pid}_m{i}", col))
    me.materials.clear()
    for m in new_mats:
        me.materials.append(m)
    for p, i in zip(me.polygons, saved_idx):
        p.material_index = i  # materials.clear() รีเซ็ตเลขวัสดุเป็น 0 -> คืนค่าเดิม
    lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    for p in me.polygons:
        g = None
        nm_ = new_mats[p.material_index] if new_mats else None
        c = tuple(nm_["as_color"]) if nm_ is not None and nm_.get("as_color") is not None else (0.8, 0.8, 0.8)
        if "glow_all" in opt:
            g = opt["glow_all"]
        elif "glow_all_but_stem" in opt and lum(c) < 0.75:
            g = opt["glow_all_but_stem"]
        elif "glow_trim" in opt and (lum(c) > 0.55 or (c[0] > 0.6 and c[1] > 0.45 and c[2] < 0.35)):
            g = opt["glow_trim"]  # ขอบโลหะ/ทอง -> เรืองแสง
        elif "ore_glow" in opt and p.index % 7 == 0:
            g = opt["ore_glow"]
        if g:
            glow_faces.setdefault(g, []).append(p.index)
    parts = {}
    if glow_faces:
        import bmesh
        allglow = set(i for v in glow_faces.values() for i in v)
        for col, faces in glow_faces.items():
            parts[mesh_export_glow_name(col)] = sub_object(ob, set(faces), mesh_export_glow_name(col), flat_mat(f"{pid}_glow", col, True))
        main = sub_object(ob, set(range(len(me.polygons))) - allglow, "Main")
    else:
        main = ob
        main.name = "Main"
    if main is not None and len(main.data.polygons) > 0:
        parts["Main"] = main
    if ob is not main and ob.name in bpy.data.objects:
        bpy.data.objects.remove(ob, do_unlink=True)
    return parts


def mesh_export_glow_name(rgb):
    return "Glow_%02x%02x%02x" % tuple(int(max(0, min(1, c)) * 255) for c in rgb)


def sub_object(ob, keep, name, mat=None):
    import bmesh
    if not keep:
        return None
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if mat:
        me.materials.append(mat)
    else:
        for m in ob.data.materials:
            me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def extras(pid, parts, opt):
    main = parts.get("Main")
    if not main:
        return
    pts = [v.co for v in main.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    d = mx - mn
    import random
    rng = random.Random(len(pid))
    if "berries" in opt:
        col = opt["berries"]
        m = flat_mat(pid + "_berry", col)
        bs = []
        for i in range(14):
            a = rng.uniform(0, math.tau)
            bs.append(as_kit.sphere("b", d.x * 0.06, (math.cos(a) * d.x * 0.42, math.sin(a) * d.y * 0.42, rng.uniform(0.3, 0.85) * d.z), mat=m, segments=6))
        parts["Berries"] = as_kit.join("Berries", bs)
    if "embers" in opt:
        col = opt["embers"]
        m = flat_mat(pid + "_ember", col, True)
        es = [as_kit.sphere("e", d.z * 0.02, (rng.uniform(-0.1, 0.1) * d.x, rng.uniform(-0.1, 0.1) * d.y, rng.uniform(0.15, 0.9) * d.z), mat=m, segments=5) for _ in range(9)]
        parts[mesh_export_glow_name(col)] = as_kit.join(mesh_export_glow_name(col), es)
    if "moss" in opt:
        m = flat_mat(pid + "_moss", opt["moss"])
        ms = [as_kit.sphere("m", d.x * 0.22, (rng.uniform(-0.2, 0.2) * d.x, rng.uniform(-0.2, 0.2) * d.y, d.z * 0.88), mat=m, segments=7, scale=(1.2, 1, 0.35)) for _ in range(4)]
        parts["Moss"] = as_kit.join("Moss", ms)
    if "ore" in opt:
        m = flat_mat(pid + "_ore", opt["ore"])
        os_ = [as_kit.cube("o", (d.x * 0.14,) * 3, (rng.uniform(-0.35, 0.35) * d.x, rng.uniform(-0.35, 0.35) * d.y, rng.uniform(0.4, 0.95) * d.z),
                           rot=(rng.uniform(0, 3), rng.uniform(0, 3), 0), mat=m) for _ in range(7)]
        parts["Ore"] = as_kit.join("Ore", os_)


def build(pid, preview=True):
    kind, name, size, *rest = PROPS[pid]
    opt = rest[0] if rest else {}
    as_kit.reset_scene()
    ob = import_source(kind, name)
    normalize(ob, size, opt.get("tool"))
    parts = apply_colors(ob, pid, opt)
    extras(pid, parts, opt)
    for o in parts.values():
        for p in o.data.polygons:
            p.use_smooth = False
    if preview:
        render_preview(pid, parts)
    mesh_export.export(pid, parts, out_dir=OUT)
    return parts


def render_preview(pid, parts):
    pts = []
    for p in parts.values():
        pts += [p.matrix_world @ v.co for v in p.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    r = max((mx - mn).length, 1)
    as_kit.setup_render(400, 400, samples=16)
    as_kit.world_sky((0.25, 0.3, 0.38), 1.0)
    floor = as_kit.ground_plane("F", r * 6, mat=as_kit.material("PFloor", C(46, 50, 46), roughness=0.9))
    sun = as_kit.light("SUN", (0, 0, 10), 3.5, C(255, 244, 228), rot=(math.radians(50), 0, math.radians(30)))
    cam = as_kit.camera(tuple(c + Vector((r * 0.9, -r * 1.2, r * 0.55))), tuple(c), lens=50)
    as_kit.render(os.path.join(PREVIEW, pid + ".png"))


def build_all(ids=None, preview=True):
    done, failed = [], []
    for pid in ids or PROPS:
        try:
            build(pid, preview)
            done.append(pid)
        except Exception:
            import traceback
            failed.append(pid)
            print("FAILED", pid, traceback.format_exc()[-600:])
    print("done", len(done), "failed", failed)
    return done
