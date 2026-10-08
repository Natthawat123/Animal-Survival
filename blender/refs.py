"""
refs.py — นำเข้าโมเดลสัตว์ต้นแบบ CC0 (Quaternius / OpenGameArt) เข้า Blender แบบปลอดภัย (append ไม่รันสคริปต์)

SOURCES: id -> (ไฟล์ .blend, ชื่อ armature, [ชื่อ mesh]) ทุกไฟล์อยู่ใน assets/downloads (CC0)
"""
import os

import bpy
from mathutils import Vector

ROOT = r"E:\GAME\roblox\Animal Survival"
DL = os.path.join(ROOT, "assets", "downloads")

SOURCES = {
    "Wolf": (r"qvol2\Animal Pack Vol.2 by @Quaternius\Blends\Wolf.blend", ["WolfArmature", "Wolf"]),
    "Dog": (r"qvol2\Animal Pack Vol.2 by @Quaternius\Blends\Dog.blend", ["DogArmature", "Dog"]),
    "Cat": (r"qvol2\Animal Pack Vol.2 by @Quaternius\Blends\Cat.blend", ["CatArmature", "Cat"]),
    "Eagle": (r"qvol2\Animal Pack Vol.2 by @Quaternius\Blends\Eagle.blend", ["EagleArmature", "Eagle"]),
    "Fox": (r"qvol1\Animals Pack by Quaternius\Blends\Red Fox.blend", ["Armature", "Cylinder"]),
    "Bird": (r"qvol1\Animals Pack by Quaternius\Blends\Bird.blend", ["Armature", "Cylinder"]),
    "Horse": (r"farm\Farm Animals by @Quaternius\Blends\Horse.blend", ["Armature", "Horse"]),
    "Cow": (r"farm\Farm Animals by @Quaternius\Blends\Cow.blend", ["Armature", "Cow"]),
    "Pig": (r"farm\Farm Animals by @Quaternius\Blends\Pig.blend", ["Armature", "Pig"]),
    "Sheep": (r"farm\Farm Animals by @Quaternius\Blends\Sheep.blend", ["Armature", "Sheep"]),
    "Llama": (r"farm\Farm Animals by @Quaternius\Blends\Llama.blend", ["Armature", "Llama"]),
    "Deer": (r"deer1.blend", ["Armature", "Body", "Head", "Horns", "Eyes"]),
    "Tiger": (r"tiger\tiger.blend", ["Armature", "Tiger"]),
    "Croc": (r"croc\croc2.blend", ["Crocodile"]),
    "Rhino": (r"rhino\white_rhino.blend", ["White_rhino"]),
    "Bear": (r"bear\Bear.blend", ["Plane"]),
    "Rabbit": (r"rabbit.blend", ["Armature", "Rabbit"]),
    "Limule": (r"limule.blend", ["Armature", "Limule-Predator"]),
}


def append(ref_id, coll_name=None):
    """append ต้นแบบ -> คืน (root, [objects]) root = armature ถ้ามี ไม่งั้น mesh"""
    rel, names = SOURCES[ref_id]
    path = os.path.join(DL, rel)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
        dst.actions = list(src.actions)
    coll = bpy.data.collections.get(coll_name or ref_id) or bpy.data.collections.new(coll_name or ref_id)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    obs = [o for o in dst.objects if o]
    for o in obs:
        coll.objects.link(o)
    arm = next((o for o in obs if o.type == "ARMATURE"), None)
    root = arm or next(o for o in obs if o.type == "MESH")
    # mesh ที่ไม่มี parent -> ผูกกับ armature (ถ้ามี)
    return root, obs


def bounds(obs):
    bpy.context.view_layer.update()
    pts = []
    for o in obs:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def normalize(root, obs, length=None, height=None, location=(0, 0, 0)):
    """ย่อ/ขยายให้ได้ความยาว(แกนยาวสุดแนวนอน) หรือความสูงที่ต้องการ แล้ววางเท้าบนพื้นที่ location"""
    # ราก = object ที่ไม่มี parent
    tops = [o for o in obs if o.parent is None]
    mn, mx = bounds(obs)
    size = mx - mn
    if length:
        s = length / max(size.x, size.y)
    elif height:
        s = height / size.z
    else:
        s = 1
    for o in tops:
        o.scale = o.scale * s
    bpy.context.view_layer.update()
    mn, mx = bounds(obs)
    off = Vector(location) - Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for o in tops:
        o.location = o.location + off
    bpy.context.view_layer.update()
    return bounds(obs)
