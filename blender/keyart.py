"""
keyart.py — ภาพปก/ภาพโปรโมตของ ANIMAL SURVIVAL (เรนเดอร์ Eevee + หมอก volumetric)

ฉาก:
  bonfire_scene()  "Bonfire Night"  — ผู้รอดชีวิตยืนข้างกองไฟ / ฝูงหมาป่าตาเรืองแสง / กวางกลวงในหมอก / แสงจันทร์
ผลลัพธ์: art/keyart_bonfire.png (1920x1080), art/icon_512.png, art/thumb_*.png

ใช้ผ่าน MCP:   exec(open(r"...\\blender\\keyart.py", encoding="utf-8").read()); bonfire_scene()
ใช้ headless:  blender -b blender/keyart_bonfire.blend --python blender/render_cli.py -- art/keyart_bonfire.png 1920 1080 96
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import animals
import as_kit

importlib.reload(as_kit)
importlib.reload(animals)
from as_kit import V, blob, cone, cube, join, material, sphere

rad = math.radians
C = lambda r, g, b: (r / 255, g / 255, b / 255)


def group(name, parts, loc=(0, 0, 0), face=None, scale=1.0):
    """รวมชิ้นสัตว์ใต้ Empty แล้ววาง/หมุนให้หันไปทาง face (x,y)"""
    emp = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(emp)
    for ob in parts.values():
        ob.parent = emp
    emp.location = loc
    emp.scale = (scale, scale, scale)
    if face is not None:
        d = Vector((face[0] - loc[0], face[1] - loc[1]))
        emp.rotation_euler = (0, 0, math.atan2(d.x, -d.y))
    return emp


# ---------------------------------------------------------------- ต้นสน
def make_pine(name="PineProto", mat_leaf=None, mat_bark=None):
    parts = [as_kit.cone(name + "_trunk", 0.55, 9, (0, 0, 0), mat=mat_bark, verts=8, tip_r=0.3)]
    z, r, h = 3.0, 4.2, 6.0
    for i in range(5):
        parts.append(as_kit.cone(name + f"_t{i}", r, h, (0, 0, z), rot=(0, 0, i * 0.7), mat=mat_leaf, verts=9))
        z += h * 0.5
        r *= 0.78
        h *= 0.86
    ob = join(name, parts)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def scatter_pines(proto, count, rmin, rmax, seed=1, avoid=None):
    rng = random.Random(seed)
    made = 0
    tries = 0
    while made < count and tries < count * 20:
        tries += 1
        a = rng.uniform(0, math.tau)
        r = rng.uniform(rmin, rmax)
        x, y = math.cos(a) * r, math.sin(a) * r
        if avoid and any((Vector((x, y)) - Vector(c)).length < rr for c, rr in avoid):
            continue
        ob = bpy.data.objects.new(f"Pine{made}", proto.data)
        ob.location = (x, y, -0.3)
        s = rng.uniform(0.8, 1.9)
        ob.scale = (s, s, s * rng.uniform(0.9, 1.3))
        ob.rotation_euler = (rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), rng.uniform(0, math.tau))
        bpy.context.scene.collection.objects.link(ob)
        made += 1
    proto.hide_render = True
    proto.hide_viewport = True


# ---------------------------------------------------------------- กองไฟ
def flame_material(name, color, strength):
    """เปลวไฟนุ่ม: สว่างที่โคน จางโปร่งใสที่ปลาย"""
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*as_kit.lin(color), 1)
    emit.inputs["Strength"].default_value = strength
    transp = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    as_kit.set_input(noise, "Scale", 3.0)
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["Z"], add.inputs[0])
    mulN = nt.nodes.new("ShaderNodeMath")
    mulN.operation = "MULTIPLY"
    mulN.inputs[1].default_value = 0.35
    nt.links.new(noise.outputs["Fac"], mulN.inputs[0])
    nt.links.new(mulN.outputs[0], add.inputs[1])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.25
    ramp.inputs["From Max"].default_value = 1.15
    nt.links.new(add.outputs[0], ramp.inputs["Value"])
    nt.links.new(ramp.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(emit.outputs[0], mix.inputs[1])
    nt.links.new(transp.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat["as_color"] = list(color)
    mat["as_emissive"] = True
    return mat


def campfire(loc=(0, 0, 0)):
    loc = Vector(loc)
    stone = material("FireStone", C(110, 104, 98), roughness=0.9, noise=0.5)
    wood = material("FireLog", C(70, 46, 30), roughness=0.8, noise=0.4)
    char = material("Charcoal", C(20, 16, 14), roughness=0.9, emission=C(255, 80, 20), strength=1.5)
    rng = random.Random(4)
    for i in range(12):
        a = i / 12 * math.tau
        s = as_kit.sphere(f"FireRock{i}", 0.7, tuple(loc + Vector((math.cos(a) * 3.2, math.sin(a) * 3.2, 0.25))), mat=stone, segments=8,
                          scale=(1.2, 0.9, 0.7))
        s.rotation_euler = (rng.uniform(0, 1), rng.uniform(0, 1), a)
    for i in range(6):
        a = i / 6 * math.tau
        log = as_kit.cone(f"Log{i}", 0.35, 4.0, tuple(loc + Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, 0.2))),
                          rot=(0, rad(62), a + math.pi), mat=wood, verts=8, tip_r=0.3)
        log.data.materials.append(char)
    as_kit.sphere("Embers", 1.4, tuple(loc + Vector((0, 0, 0.2))), mat=char, scale=(1.2, 1.2, 0.35))
    # เปลวไฟ: กรวยเรืองแสงซ้อนกัน
    flame_o = flame_material("FlameOuter", C(255, 96, 18), 30)
    flame_i = flame_material("FlameInner", C(255, 210, 110), 60)
    # ลิ้นไฟ: ก้อน metaball ยาวโค้งขึ้น (โคนอ้วน ปลายแหลม)
    for i in range(9):
        a = i / 9 * math.tau + rng.uniform(-0.3, 0.3)
        r0 = 0.0 if i == 0 else rng.uniform(0.35, 0.95)
        h = 5.2 if i == 0 else rng.uniform(1.8, 3.8)
        bend = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0))
        base = loc + Vector((math.cos(a) * r0, math.sin(a) * r0, 0.4))
        els = []
        n = 6
        for k in range(n):
            t = k / (n - 1)
            p = base + Vector((0, 0, t * h)) + bend * (t * t) * h * 0.4
            rr = (0.62 if i == 0 else 0.42) * (1 - t * 0.82)
            els.append(("ellipsoid", tuple(p), (rr, rr, rr * 1.7)))
        f = blob(f"Flame{i}", els, mat=flame_i if (i == 0 or i % 3 == 0) else flame_o, resolution=0.06)
        f.visible_shadow = False
    # สะเก็ดไฟลอย
    ember = material("EmberSpark", C(255, 160, 60), emission=C(255, 140, 40), strength=60)
    for i in range(45):
        h = rng.uniform(2, 11)
        p = loc + Vector((rng.gauss(0, 0.5 + h * 0.12), rng.gauss(0, 0.5 + h * 0.12), h))
        s = as_kit.sphere(f"Spark{i}", rng.uniform(0.025, 0.06), tuple(p), mat=ember, segments=6)
        s.visible_shadow = False
    # แสงไฟ
    l1 = as_kit.light("POINT", tuple(loc + Vector((0, 0, 3.0))), 4200, C(255, 130, 50), size=1.2, name="FireLight")
    l2 = as_kit.light("POINT", tuple(loc + Vector((0.6, -0.4, 1.4))), 900, C(255, 90, 30), size=0.6, name="FireLight2")
    for l in (l1, l2):
        l.data.volume_factor = 0.18  # ไม่ให้หมอกทั้งฉากกลายเป็นสีส้ม
    # ควันไฟ (volumetric)
    smoke = as_kit.cube("Smoke", (5, 5, 26), tuple(loc + Vector((0, 0, 15))))
    m = bpy.data.materials.new("SmokeMat")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    as_kit.set_input(vol, "Color", (0.25, 0.22, 0.2, 1))
    noise = nt.nodes.new("ShaderNodeTexNoise")
    as_kit.set_input(noise, "Scale", 0.6)
    as_kit.set_input(noise, "Detail", 6)
    grad = nt.nodes.new("ShaderNodeMath")
    grad.operation = "MULTIPLY"
    grad.inputs[1].default_value = 0.35
    nt.links.new(noise.outputs["Fac"], grad.inputs[0])
    nt.links.new(grad.outputs[0], vol.inputs["Density"])
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    smoke.data.materials.append(m)
    smoke.display_type = "BOUNDS"


# ---------------------------------------------------------------- ผู้รอดชีวิต (ผ้าคลุม + คบเพลิง)
def survivor(loc, face):
    cloak = material("Cloak", C(46, 40, 44), roughness=0.95, noise=0.4)
    trim = material("CloakTrim", C(120, 70, 40), roughness=0.8)
    skin = material("SurvivorSkin", C(150, 110, 90), roughness=0.6)
    els = [
        ("ellipsoid", (0, 0, 1.9), (0.62, 0.48, 1.45)),  # ลำตัวใต้ผ้า
        ("ellipsoid", (0, 0.08, 0.75), (0.95, 0.8, 0.75)),  # ชายผ้าคลุมบาน
        ("ellipsoid", (0, 0.05, 3.25), (0.95, 0.5, 0.42)),  # ไหล่
        ("ellipsoid", (0, 0.1, 2.6), (0.85, 0.62, 0.9)),  # ผ้าคลุมหลัง
        ("ellipsoid", (0, 0.05, 4.0), (0.46, 0.48, 0.52)),  # ฮู้ด
        ("ellipsoid", (0, 0.32, 4.25), (0.22, 0.3, 0.3)),  # ปลายฮู้ด
        ("-ellipsoid", (0, -0.36, 3.95), (0.27, 0.22, 0.32)),  # ช่องหน้า
    ]
    body = blob("SurvivorBody", els, mat=cloak, resolution=0.07)
    arm = blob("SurvivorArm", [("capsule", (0.85, -0.25, 2.95), 1.3, 0.2, (0, rad(55), rad(70))), ("ball", (1.05, -0.8, 2.6), 0.2)], mat=cloak, resolution=0.05)
    hand = as_kit.sphere("Hand", 0.16, (1.12, -0.95, 2.55), mat=skin, segments=8)
    torch = as_kit.cone("Torch", 0.08, 2.4, (1.12, -0.95, 1.6), rot=(rad(-14), rad(10), 0), mat=material("TorchWood", C(80, 55, 35)), verts=6)
    flame = blob("TorchFlame", [("ellipsoid", (1.32, -1.5, 4.25), (0.2, 0.2, 0.3)), ("ellipsoid", (1.35, -1.55, 4.6), (0.12, 0.12, 0.25))],
                 mat=bpy.data.materials.get("FlameInner"), resolution=0.04)
    flame.visible_shadow = False
    belt = as_kit.cube("Belt", (1.2, 0.95, 0.14), (0, 0, 2.2), mat=trim)
    scarf = blob("Scarf", [("ellipsoid", (0, -0.1, 3.5), (0.5, 0.45, 0.2))], mat=trim, resolution=0.05)
    emp = bpy.data.objects.new("Survivor", None)
    bpy.context.scene.collection.objects.link(emp)
    for o in (body, arm, hand, torch, flame, belt, scarf):
        o.parent = emp
    emp.location = loc
    d = Vector((face[0] - loc[0], face[1] - loc[1]))
    emp.rotation_euler = (0, 0, math.atan2(d.x, -d.y))
    bpy.context.view_layer.update()
    tl = as_kit.light("POINT", tuple(flame.matrix_world.translation + Vector((0, 0, 0.3))), 260, C(255, 150, 70), size=0.3, name="TorchLight")
    tl.data.volume_factor = 0.2
    return emp


# ---------------------------------------------------------------- ฉากหลัก
def bonfire_scene(render_path=None, res=(1920, 1080), samples=64):
    sc = as_kit.reset_scene()
    as_kit.setup_render(res[0], res[1], samples=samples)
    as_kit.night_sky(fog_density=0.006, fog_color=(0.45, 0.58, 0.95), fog_anisotropy=0.55)
    # พื้น
    grass = material("NightGrass", C(46, 62, 38), roughness=0.95, noise=0.6)
    dirt = material("CampDirt", C(70, 56, 42), roughness=0.95, noise=0.5)
    as_kit.ground_plane("Ground", 400, mat=grass, subdiv=7, displace=1.6, noise_scale=0.02, seed=3)
    patch = as_kit.ground_plane("CampDirt", 20, loc=(0, 0, 0.06), mat=dirt, subdiv=4, displace=0.08)
    # ป่าสน
    leaf = material("PineLeaf", C(26, 44, 32), roughness=0.9, noise=0.4)
    bark = material("PineBark", C(54, 40, 30), roughness=0.9, noise=0.4)
    proto = make_pine(mat_leaf=leaf, mat_bark=bark)
    scatter_pines(proto, 170, 26, 150, seed=7, avoid=[((6, -24), 12), ((-6, 20), 9)])
    # หินใหญ่
    rock = material("BigRock", C(84, 82, 86), roughness=0.9, noise=0.6)
    rng = random.Random(9)
    for i in range(14):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(14, 60)
        if math.sin(a) < -0.35:
            continue  # ไม่วางหินบังกล้อง
        s = as_kit.sphere(f"Boulder{i}", rng.uniform(1.2, 3.5), (math.cos(a) * r, math.sin(a) * r, 0.4), mat=rock, segments=7,
                          scale=(rng.uniform(1, 1.6), rng.uniform(0.8, 1.3), rng.uniform(0.5, 0.9)))
        s.rotation_euler = (rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 3))
    campfire((0, 0, 0))
    # ตัวละคร
    stag_pos = (-12.5, 31, 0)
    survivor((8.8, -5.2, 0), face=stag_pos)
    stag = animals.build("HollowStag")
    group("HollowStagRig", stag, loc=stag_pos, face=(0, 0))
    for i, (x, y) in enumerate(((-17, 3), (-21, 10), (-13, 12))):
        wolf = animals.build("MossWolf", coll=as_kit.collection(f"Wolf{i}"))
        group(f"WolfRig{i}", wolf, loc=(x, y, 0), face=(0, 0), scale=0.95 + i * 0.05)
    # ดวงจันทร์ + แสงจันทร์ด้านหลัง (ขอบแสง)
    moon_mat = material("Moon", C(230, 236, 255), emission=C(220, 230, 255), strength=12)
    as_kit.sphere("Moon", 14, (-90, 420, 130), mat=moon_mat, segments=24)
    as_kit.light("SUN", (0, 0, 50), 4.5, C(140, 170, 255), rot=(rad(-58), 0, rad(165)), angle=0.03, name="MoonLight")
    # แสงจันทร์ส่องจากด้านหลังกวาง (ขอบเงาเรืองๆ)
    as_kit.light("SPOT", (-14, 48, 18), 6000, C(150, 180, 255), rot=(rad(-70), 0, rad(170)), size=2, name="StagRim")
    # กล้อง
    cam = as_kit.camera((15, -27, 5.2), (-4.0, 11.0, 5.6), lens=32, dof_target=(0, 0, 2), fstop=6.0)
    as_kit.bloom_compositor(strength=0.5, threshold=1.0, size=7)
    sc.view_settings.exposure = 0.75
    path = os.path.join(as_kit.ART, "keyart_bonfire.blend")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(as_kit.ROOT, "blender", "keyart_bonfire.blend"))
    if render_path:
        as_kit.render(render_path)
    return cam
