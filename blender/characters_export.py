"""
characters_export.py — ตัวละครคลาส (ร้านคลาส/หุ่นบนเวที/รูปโปรไฟล์) จากโมเดลจริง CC0 ของ Quaternius
  U = Ultimate Animated Character Pack (Nov 2019)   R = RPG Characters (Nov 2020)
ขั้นตอน: โหลด .blend -> ตั้งท่า Idle ของ armature -> อบท่าลงเมช -> รวมเป็นชิ้นเดียว -> ปรับสีตามคลาส
        -> สูง HEIGHT studs เท้าที่ y=0 หน้าหัน -Z ของ Roblox -> PropMeshData/Char_<Class>.lua + รูปพรีวิว art/chars
รัน: blender -b --factory-startup --python blender/run_chars.py -- [Class ...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import as_kit
import mesh_export

importlib.reload(as_kit)
importlib.reload(mesh_export)

DL = r"E:\GAME\roblox\Animal Survival\assets\downloads"
SRC = {
    "U": os.path.join(DL, "chars_ultimate", "Ultimate Animated Character Pack - Nov 2019", "Blends", "{}.blend"),
    "R": os.path.join(DL, "chars_rpg", "RPG Characters - Nov 2020", "Blends", "{}.blend"),
}
OUT = os.path.join(as_kit.ROOT, "src", "ReplicatedStorage", "PropMeshData")
PREVIEW = os.path.join(as_kit.ROOT, "art", "chars")
os.makedirs(PREVIEW, exist_ok=True)
C = lambda r, g, b: (r / 255, g / 255, b / 255)
HEIGHT = 5.6

# คลาส: (แหล่ง, ไฟล์, ตัวเลือก)
#   recolor: {คำในชื่อวัสดุ: สี sRGB}   tint: {คำในชื่อวัสดุ: ตัวคูณ}   drop: [ชื่อเมชที่ไม่เอา]   action: ชื่อท่า   frame: 0..1
CHARS = {
    "Survivor": ("U", "Casual_Male", dict(turn=True, recolor={"skin": C(212, 166, 130)})),
    "Forager": ("U", "Cowboy_Female", dict(recolor={"skin": C(214, 160, 120)})),
    "Lumberjack": ("U", "Viking_Male", dict(turn=True, recolor={"skin": C(208, 160, 124)})),
    "Medic": ("R", "Cleric", dict(action="Idle_Weapon")),
    "Hunter": ("R", "Ranger", dict(action="Idle_Weapon", turn=True)),
    "Builder": ("U", "Worker_Male", dict(turn=True, recolor={"skin": C(170, 118, 84)})),
    "Scout": ("R", "Rogue", dict(action="Idle_Weapon")),
    "Firekeeper": ("R", "Monk", dict(turn=True, tint={"monk": (1.35, 0.78, 0.55)})),
    "Elementalist": ("R", "Wizard", dict(action="Idle_Weapon", turn=True)),
    "Beastwarden": ("R", "Warrior", dict(action="Idle_Weapon")),
}


TEX_DIR = os.path.join(DL, "chars_rpg", "RPG Characters - Nov 2020", "Textures")


def load_blend(path):
    # ล้างท่า/ภาพจากไฟล์ก่อน (กันชื่อซ้ำเป็น .001 และเลือกท่าผิดโครง)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
        dst.actions = list(src.actions)
    for o in dst.objects:
        if o:
            bpy.context.scene.collection.objects.link(o)
    # ภาพ texture อ้างไฟล์ภายนอก -> ชี้ไปโฟลเดอร์ Textures แล้วโหลดใหม่
    for img in bpy.data.images:
        if img.source == "FILE" and not img.has_data:
            fn = os.path.basename(bpy.path.abspath(img.filepath) or img.name)
            cand = os.path.join(TEX_DIR, fn)
            if not os.path.exists(cand):
                cand = os.path.join(TEX_DIR, img.name if img.name.lower().endswith(".png") else img.name + ".png")
            if os.path.exists(cand):
                img.filepath = cand
                img.reload()
                print("  texture:", fn, img.has_data, tuple(img.size))
    return [o for o in dst.objects if o], [a for a in dst.actions if a]


def pose(arm, actions, want, frac):
    names = [want] if want else []
    names += ["Idle", "Idle_Neutral", "CharacterArmature|Idle"]
    act = None
    base = lambda a: a.name.split("|")[-1].split(".")[0]
    for n in names:
        act = next((a for a in actions if base(a) == n.split("|")[-1]), None)
        if act:
            break
    act = act or next((a for a in actions if "idle" in a.name.lower()), None)
    if not act:
        print("  (ไม่มีท่า idle)")
        return
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    try:
        if getattr(act, "slots", None) and len(act.slots) > 0 and ad.action_slot is None:
            ad.action_slot = act.slots[0]
    except Exception:
        pass
    a, b = act.frame_range
    bpy.context.scene.frame_set(int(a + (b - a) * frac))
    print("  pose:", act.name)


def bake(objs, drop):
    """อบท่าปัจจุบันลงเมช (รวม modifier) แล้วคืนวัตถุเมชใหม่ในพิกัดโลก"""
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        if o.type != "MESH" or o.name in drop or o.name.split(".")[0] in drop:
            continue
        ev = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
        me.transform(o.matrix_world)
        n = bpy.data.objects.new("B_" + o.name, me)
        bpy.context.scene.collection.objects.link(n)
        out.append(n)
    return out


def facing_fix(ob):
    """ให้หน้าหัน -Y ของ Blender (= -Z ของ Roblox): ดูว่าจมูก/ตา (จุดที่ยื่นสุดช่วงหัว) อยู่ฝั่งไหน"""
    pts = [v.co for v in ob.data.vertices]
    zmax = max(p.z for p in pts)
    zmin = min(p.z for p in pts)
    head = [p for p in pts if p.z > zmin + (zmax - zmin) * 0.72]
    cy = sum(p.y for p in head) / len(head)
    # จุดหน้า = ส่วนหัวที่ยื่นออกมากสุด เทียบกับแกนกลางหัว
    fwd = max(head, key=lambda p: abs(p.y - cy))
    return fwd.y > cy  # True = หันไป +Y -> ต้องหมุน 180


def recolor(ob, cid, opt):
    for m in ob.data.materials:
        if not m:
            continue
        nm = m.name.lower()
        for key, col in opt.get("recolor", {}).items():
            if key in nm:
                m["as_color"] = list(col)
                m["as_notex"] = True
                if m.use_nodes:  # ให้ภาพพรีวิวตรงกับในเกมด้วย
                    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                    if bsdf:
                        bsdf.inputs["Base Color"].default_value = (*as_kit.lin(col), 1)
        for key, t in opt.get("tint", {}).items():
            if key in nm:
                m["as_tint"] = list(t)


def build(cid, preview=True):
    kind, name, opt = CHARS[cid]
    as_kit.reset_scene()
    objs, actions = load_blend(SRC[kind].format(name))
    arm = next((o for o in objs if o.type == "ARMATURE"), None)
    if arm:
        pose(arm, actions, opt.get("action"), opt.get("frame", 0.25))
    baked = bake(objs, set(opt.get("drop", [])))
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    ob = as_kit.join("Char_" + cid, baked)
    me = ob.data
    flip = facing_fix(ob)
    if opt.get("turn"):
        flip = not flip  # ตรวจจากภาพพรีวิวแล้ว ตัวนี้หันกลับด้าน
    if flip:
        me.transform(Matrix.Rotation(math.pi, 4, "Z"))
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    me.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))))
    me.transform(Matrix.Scale(HEIGHT / (mx.z - mn.z), 4))
    me.update()
    recolor(ob, cid, opt)
    for p in me.polygons:
        p.use_smooth = False
    ob.name = "Main"
    parts = {"Main": ob}
    if preview:
        render_preview(cid, ob)
    mesh_export.export("Char_" + cid, parts, out_dir=OUT)
    return parts


def render_preview(cid, ob):
    as_kit.setup_render(360, 480, samples=16)
    as_kit.world_sky((0.25, 0.3, 0.38), 1.0)
    as_kit.ground_plane("F", 30, mat=as_kit.material("PFloor", C(46, 50, 46), roughness=0.9))
    as_kit.light("SUN", (0, 0, 10), 3.5, C(255, 244, 228), rot=(math.radians(50), 0, math.radians(-20)))
    # มองจากด้านหน้า (-Y) เยื้องนิดๆ
    as_kit.camera((2.5, -11, 3.6), (0, 0, 2.7), lens=55)
    as_kit.render(os.path.join(PREVIEW, cid + ".png"))


def build_all(ids=None, preview=True):
    done, failed = [], []
    for cid in ids or CHARS:
        try:
            build(cid, preview)
            done.append(cid)
        except Exception:
            import traceback
            failed.append(cid)
            print("FAILED", cid, traceback.format_exc()[-800:])
    print("done", len(done), "failed", failed)
    return done
