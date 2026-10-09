"""
prep_boss.py — เตรียมโมเดลบอส/สิ่งของจากโฟลเดอร์ "3D Model" ให้พร้อมอัปขึ้น Roblox
  - ลบชิ้นเกิน (Icosphere) · ลดโพลีให้ไม่เกินเพดาน Roblox (20k สามเหลี่ยม/ชิ้น)
  - ย่อ texture เหลือ 1024 · ตั้งชื่อกระดูกตามส่วนของร่างกาย (ใช้ทำท่าในเกม)
  - ส่งออก assets/models/<Id>.glb + ภาพตัวอย่าง assets/models/<Id>.png

  blender -b --factory-startup --python blender/prep_boss.py -- [Id ...]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = r"E:\GAME\roblox\Animal Survival"
SRC = os.path.join(ROOT, "3D Model")
OUT = os.path.join(ROOT, "assets", "models")
MAX_TRIS = 16000
TEX = 1024

# กระดูก: ชื่อเดิม (Bone_xxx) -> ชื่อตามส่วนร่างกาย (หัน -Y = ด้านหน้า, -X = ขวาของตัว)
BIPED_GOLEM = {
    "Bone_000": "Hips", "Bone_014": "Spine1", "Bone_013": "Spine2", "Bone_012": "Spine3", "Bone_011": "Chest",
    "Bone_032": "Neck", "Bone_031": "Head", "Bone_030": "HeadTop", "Bone_029": "HeadEnd",
    "Bone_037": "ClavicleR", "Bone_036": "UpperArmR", "Bone_035": "ForeArmR", "Bone_034": "HandR", "Bone_033": "HandEndR",
    "Bone_042": "ClavicleL", "Bone_041": "UpperArmL", "Bone_040": "ForeArmL", "Bone_039": "HandL", "Bone_038": "HandEndL",
    "Bone_006": "ThighR", "Bone_005": "ShinR", "Bone_004": "FootR",
    "Bone_010": "ThighL", "Bone_009": "ShinL", "Bone_008": "FootL",
}
BIPED_YETI = {
    "Bone_000": "Hips", "Bone_002": "Spine1", "Bone_001": "Spine2", "Bone_005": "Spine3", "Bone_004": "Chest",
    "Bone_003": "Neck", "Bone_015": "Head", "Bone_014": "HeadEnd",
    "Bone_020": "ClavicleR", "Bone_019": "UpperArmR", "Bone_018": "ForeArmR", "Bone_017": "HandR", "Bone_016": "HandEndR",
    "Bone_025": "ClavicleL", "Bone_024": "UpperArmL", "Bone_023": "ForeArmL", "Bone_022": "HandL", "Bone_021": "HandEndL",
    "Bone_013": "ThighR", "Bone_012": "ShinR", "Bone_011": "FootR",
    "Bone_009": "ThighL", "Bone_008": "ShinL", "Bone_007": "FootL",
}
DRAGON = {
    "Bone_000": "Hips", "Bone_005": "Spine1", "Bone_004": "Spine2", "Bone_003": "Spine3", "Bone_002": "Chest",
    "Bone_032": "Neck1", "Bone_031": "Neck2", "Bone_030": "Neck3", "Bone_029": "Neck4", "Bone_028": "Neck5",
    "Bone_027": "Head", "Bone_026": "Jaw", "Bone_025": "HeadEnd",
    "Bone_042": "ArmR1", "Bone_041": "ArmR2", "Bone_040": "ArmR3", "Bone_039": "ArmR4",
    "Bone_037": "ArmL1", "Bone_036": "ArmL2", "Bone_035": "ArmL3", "Bone_034": "ArmL4",
    "Bone_046": "WingR1", "Bone_045": "WingR2", "Bone_044": "WingR3", "Bone_043": "WingR4",
    "Bone_050": "WingL1", "Bone_049": "WingL2", "Bone_048": "WingL3", "Bone_047": "WingL4",
    "Bone_015": "ThighR", "Bone_014": "ShinR", "Bone_013": "AnkleR", "Bone_012": "FootR",
    "Bone_010": "ThighL", "Bone_009": "ShinL", "Bone_008": "AnkleL", "Bone_007": "FootL",
    "Bone_024": "Tail1", "Bone_023": "Tail2", "Bone_022": "Tail3", "Bone_021": "Tail4", "Bone_020": "Tail5",
    "Bone_019": "Tail6", "Bone_018": "Tail7", "Bone_017": "Tail8",
}
MOSA = {
    "Bone_000": "Root", "Bone_001": "Neck", "Bone_003": "Head", "Bone_002": "Skull", "Bone_007": "Jaw", "Bone_009": "Snout",
    "Bone_005": "Body1", "Bone_004": "Body2", "Bone_011": "Body3", "Bone_010": "Body4", "Bone_023": "Body5", "Bone_022": "Body6",
    "Bone_038": "Tail1", "Bone_037": "Tail2", "Bone_036": "Tail3", "Bone_041": "FinLow", "Bone_044": "FinTop", "Bone_047": "FinMid",
    "Bone_027": "Tail0", "Bone_025": "Dorsal",
    "Bone_016": "FlipperFR1", "Bone_015": "FlipperFR2", "Bone_014": "FlipperFR3",
    "Bone_021": "FlipperFL1", "Bone_020": "FlipperFL2", "Bone_019": "FlipperFL3",
    "Bone_031": "FlipperBR1", "Bone_030": "FlipperBR2", "Bone_029": "FlipperBR3",
    "Bone_035": "FlipperBL1", "Bone_034": "FlipperBL2", "Bone_033": "FlipperBL3",
}

JOBS = {
    "Terragon": ("โกเลม/โกเลม.glb", BIPED_GOLEM),
    "Leviathan": ("โมซาซอรัส/ปลาวาฬ.glb", MOSA),
    "TempestRoc": ("เยติ/เยติ.glb", BIPED_YETI),
    "Solfang": ("มังกรไฟ/มังกร.glb", DRAGON),
    "ClassHut": ("กระท่อม class หน้า lobby/กระท่อม.blend", None),
}


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)


def tris_of(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def decimate(o):
    t = tris_of(o)
    if t <= MAX_TRIS:
        return t
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = MAX_TRIS / t * 0.97
    mod.use_collapse_triangulate = True
    while o.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return tris_of(o)


def shrink_images():
    for img in bpy.data.images:
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
            img.pack()


def render(rid, objs):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 480, 360
    pts = []
    for o in objs:
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c, r = (mn + mx) / 2, (mx - mn).length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    a, e = math.radians(-60), math.radians(15)
    cam.location = c + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * r * 1.25
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, rid + ".png")
    bpy.ops.render.render(write_still=True)


def run(rid):
    rel, names = JOBS[rid]
    load(os.path.join(SRC, rel))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    before = sum(tris_of(o) for o in meshes)
    after = sum(decimate(o) for o in meshes)
    shrink_images()
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    renamed = 0
    if arm and names:
        for b in arm.data.bones:
            if b.name in names:
                b.name = names[b.name]
                renamed += 1
        arm.name = rid + "Rig"
    for o in meshes:
        o.name = rid
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, rid + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=False, export_skins=True,
                              export_image_format="AUTO", export_apply=False)
    render(rid, meshes)
    print("[prep] %s tris %d -> %d, bones renamed %d, %.1f MB" % (rid, before, after, renamed, os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    ids = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for rid in ids or list(JOBS):
        run(rid)
