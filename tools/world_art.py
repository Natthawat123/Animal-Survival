"""วิหารโบราณศักดิ์สิทธิ์ 4 ธาตุ (Ancient Sanctum) — ฉากในแมพ สร้างเป็น Part ล้วนจากข้อมูล (แบบ tools/lobby_art.py)

  python tools/world_art.py                          -> assets/rbxm/WorldArt/Sanctum_<Element>.rbxmx (build_rbxlx ใส่ไว้ใน ServerStorage.WorldArt)
  <bpy-python> tools/world_art.py --preview out.png <Element|All> [front|top|door] [samples]   -> ภาพตัวอย่างจาก Blender

พิกัดของพรีแฟบ: จุดกลางลาน = 0,0,0 (ผิวพื้น y = 0) · ทางเข้าอยู่ด้าน -Z (Lua หันด้านนี้เข้าหาแคมป์) · วิหาร/ห้องผนึกอยู่ด้าน +Z
ชิ้นที่มีชื่อเฉพาะ (SanctumService ใช้ต่อ):
  Origin (ล่องหน, PrimaryPart) · Obelisk1..3 (Model: Glyph/Crystal/Activator/Top) · HintSlot1..3 · AltarCrystal
  VaultDoor (Model) · VaultChest (Model: ChestBody) · ChestLid (Model) · VaultLight · Beacon · Brazier · CaveGlow · Mist
"""
import math
import os
import random
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "rbxm", "WorldArt")
ELEMENTS = ("Earth", "Water", "Air", "Fire")

MAT = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784, "Basalt": 788,
    "Slate": 800, "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880, "Rock": 896,
    "Metal": 1088, "Grass": 1280, "Sand": 1296, "Fabric": 1312, "Ground": 1376, "Ice": 1536, "Glass": 1568,
}

# ---------------------------------------------------------------- จานสีแต่ละธาตุ
PALETTES = {
    "Earth": dict(
        stone=[(118, 124, 108), (106, 114, 98), (128, 132, 114), (96, 104, 90)], light=(156, 160, 140), dark=(76, 84, 72),
        mat="Slate", trim_mat="Cobblestone", floor_mat="Slate",
        glow=(120, 245, 90), soft=(200, 255, 160), accent=(250, 214, 90),
        moss=[(84, 132, 56), (70, 118, 48), (98, 146, 62)], leaf=[(66, 140, 54), (52, 120, 46), (88, 158, 64), (44, 104, 42)],
        ground=(78, 116, 52), vine=(50, 98, 40), plant=(56, 116, 60),
    ),
    "Water": dict(
        stone=[(198, 212, 208), (186, 202, 200), (210, 220, 216), (176, 194, 194)], light=(232, 240, 236), dark=(136, 162, 166),
        mat="Marble", trim_mat="Marble", floor_mat="Slate",
        glow=(70, 210, 255), soft=(170, 240, 255), accent=(255, 150, 130),
        moss=[(70, 150, 140), (60, 132, 128), (90, 168, 150)], leaf=[(40, 150, 130), (50, 170, 150), (30, 128, 118), (70, 186, 160)],
        ground=(222, 206, 160), vine=(40, 120, 110), plant=(40, 140, 120),
    ),
    "Air": dict(
        stone=[(132, 142, 172), (120, 132, 164), (142, 150, 180), (112, 124, 156)], light=(196, 204, 226), dark=(78, 88, 120),
        mat="Slate", trim_mat="Slate", floor_mat="Slate",
        glow=(110, 190, 255), soft=(215, 238, 255), accent=(255, 226, 140),
        moss=[(200, 214, 236), (220, 230, 246), (186, 200, 228)], leaf=[(120, 170, 150), (100, 156, 140), (140, 186, 166), (90, 140, 128)],
        ground=(232, 238, 248), vine=(90, 130, 120), plant=(110, 160, 150),
    ),
    "Fire": dict(
        stone=[(62, 52, 52), (54, 46, 46), (72, 60, 58), (48, 40, 42)], light=(104, 84, 76), dark=(32, 26, 28),
        mat="Basalt", trim_mat="Slate", floor_mat="Slate",
        glow=(255, 110, 30), soft=(255, 200, 100), accent=(255, 60, 20),
        moss=[(90, 40, 30), (110, 50, 34), (70, 34, 28)], leaf=[(120, 60, 40), (90, 44, 34), (140, 70, 40), (70, 36, 30)],
        ground=(58, 48, 44), vine=(60, 34, 30), plant=(80, 40, 30),
    ),
}

P = PALETTES["Earth"]
EL = "Earth"
rng = random.Random(1)
parts = []
group = [None]


# ---------------------------------------------------------------- คณิต CFrame (4x4, พิกัด Roblox: Y ขึ้น, -Z หน้า)
def T(x, y, z):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def RX(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[1, 1], m[1, 2], m[2, 1], m[2, 2] = c, -s, s, c
    return m


def RY(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    return m


def RZ(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 1], m[1, 0], m[1, 1] = c, -s, s, c
    return m


def look_at(pos, target):
    p, t = np.array(pos, float), np.array(target, float)
    f = t - p
    f /= np.linalg.norm(f)
    r = np.cross(f, (0, 1, 0))
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    m = np.eye(4)
    m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = r, u, -f, p
    return m


def pos_of(cf):
    return cf[:3, 3]


def jit(c, k=8):
    return tuple(int(max(0, min(255, v + rng.randint(-k, k)))) for v in c)


class Group:
    def __init__(self, name):
        self.name = name

    def __enter__(self):
        self.prev = group[0]
        group[0] = self.name

    def __exit__(self, *a):
        group[0] = self.prev


def add(shape, size, cf, color, mat="SmoothPlastic", tr=0.0, name=None, collide=True, shadow=True):
    if shape == "Ball":
        d = min(size)
        size = (d, d, d)
    parts.append(dict(shape=shape, size=tuple(float(v) for v in size), cf=cf, color=tuple(int(c) for c in color), mat=mat, tr=tr,
                      name=name, collide=collide, shadow=shadow, group=group[0]))


def block(size, cf, color, mat=None, **kw):
    add("Block", size, cf, color, mat or P["mat"], **kw)


def ball(d, cf, color, mat="SmoothPlastic", **kw):
    add("Ball", (d, d, d), cf, color, mat, **kw)


def cylinder_y(h, d, cf, color, mat=None, **kw):
    add("Cylinder", (h, d, d), cf @ RZ(math.pi / 2), color, mat or P["mat"], **kw)


def cylinder_z(h, d, cf, color, mat=None, **kw):
    add("Cylinder", (h, d, d), cf @ RY(math.pi / 2), color, mat or P["mat"], **kw)


def wedge(size, cf, color, mat=None, **kw):
    add("Wedge", size, cf, color, mat or P["mat"], **kw)


def neon(size, cf, color=None, **kw):
    kw.setdefault("collide", False)
    kw.setdefault("shadow", False)
    add("Block", size, cf, color or P["glow"], "Neon", **kw)


def seg(a, b, w, color, mat="SmoothPlastic", **kw):
    a, b = np.array(a, float), np.array(b, float)
    L = np.linalg.norm(b - a)
    if L < 1e-3:
        return
    cf = look_at((a + b) / 2, b) if abs((b - a)[1]) < L * 0.999 else T(*((a + b) / 2)) @ RX(math.pi / 2)
    block((w, w, L), cf, color, mat, **kw)


def stone_c():
    return jit(rng.choice(P["stone"]), 6)


# ---------------------------------------------------------------- ชิ้นส่วนย่อย
def rune_glyph(cf, size=1.0, kind=None, color=None, name=None):
    """รูนเรืองแสงบนผิวหิน (cf = จุดกลาง หน้า +Z)"""
    kind = kind or rng.choice(("X", "Y", "D", "F", "I"))
    w, d = 0.22 * size, 0.08
    bars = {
        "X": [(0, 0, 1.3, 0.7), (0, 0, 1.3, -0.7)],
        "Y": [(0, -0.15, 1.1, 0), (-0.25, 0.4, 0.7, 0.75), (0.25, 0.4, 0.7, -0.75)],
        "D": [(-0.21, 0.21, 0.6, -0.785), (0.21, 0.21, 0.6, 0.785), (-0.21, -0.21, 0.6, 0.785), (0.21, -0.21, 0.6, -0.785)],
        "F": [(0, 0, 1.3, 0), (0.22, 0.32, 0.55, -1.0), (0.22, 0.0, 0.55, -1.0)],
        "I": [(0, 0, 1.3, 0), (0, 0.45, 0.6, 1.5708)],
        "O": [(0, 0.45, 0.62, 1.5708), (0, -0.45, 0.62, 1.5708), (-0.42, 0, 0.62, 0), (0.42, 0, 0.62, 0), (0, 0, 0.5, 0.785)],
    }[kind]
    for bx, by, L, rot in bars:
        neon((w, L * size, d), cf @ T(bx * size, by * size, 0) @ RZ(rot), color, name=name)


def element_sigil(cf, s=1.0, name=None):
    """สัญลักษณ์ประจำธาตุขนาดใหญ่ (หน้า +Z)"""
    g = P["glow"]
    if EL == "Earth":  # ภูเขา 3 ยอด + ราก
        for x, h in ((-0.9, 1.4), (0, 2.1), (0.9, 1.4)):
            neon((0.26 * s, h * s, 0.1), cf @ T((x - 0.3) * s, (h / 2 - 0.9) * s, 0) @ RZ(-0.5), g, name=name)
            neon((0.26 * s, h * s, 0.1), cf @ T((x + 0.3) * s, (h / 2 - 0.9) * s, 0) @ RZ(0.5), g, name=name)
        neon((3.0 * s, 0.24 * s, 0.1), cf @ T(0, -1.05 * s, 0), g, name=name)
    elif EL == "Water":  # คลื่น 3 ชั้น
        for row in range(3):
            for k in range(4):
                a = (k - 1.5) * 0.75
                neon((0.75 * s, 0.22 * s, 0.1), cf @ T(a * s, (row - 1) * 0.75 * s + math.sin(k * 1.6) * 0.18 * s, 0) @ RZ(0.45 if k % 2 else -0.45), g, name=name)
    elif EL == "Air":  # ก้นหอยลม
        n = 14
        for k in range(n):
            t = k / n * math.tau * 1.4
            r = 0.25 + k / n * 1.25
            neon((0.42 * s, 0.22 * s, 0.1), cf @ T(math.cos(t) * r * s, math.sin(t) * r * s, 0) @ RZ(t + math.pi / 2), g, name=name)
    else:  # เปลวไฟ
        for k, (x, h) in enumerate(((-0.75, 1.6), (0, 2.6), (0.75, 1.6))):
            neon((0.3 * s, h * s, 0.1), cf @ T(x * s, (h / 2 - 1.1) * s, 0) @ RZ(-x * 0.35), g, name=name)
        neon((2.4 * s, 0.24 * s, 0.1), cf @ T(0, -1.15 * s, 0), g, name=name)
    # วงแหวนรอบ
    n = 12
    for k in range(n):
        a = k / n * math.tau
        neon((0.62 * s * 1.8 * math.pi / n * 1.9, 0.18 * s, 0.1), cf @ T(math.cos(a) * 1.95 * s, math.sin(a) * 1.95 * s, -0.02) @ RZ(a + math.pi / 2), g, name=name)


def crystal_cluster(cf, s=1.0, n=None, colors=None, name=None):
    colors = colors or (P["glow"], P["soft"])
    for k in range(n or rng.randint(3, 5)):
        h = rng.uniform(1.4, 3.2) * s * (1.5 if k == 0 else 1)
        w = rng.uniform(0.45, 0.75) * s
        tilt = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5)) if k else (0, 0)
        c = cf @ T(rng.uniform(-0.6, 0.6) * s, 0, rng.uniform(-0.6, 0.6) * s) @ RX(tilt[0]) @ RZ(tilt[1]) @ T(0, h / 2, 0) @ RY(rng.uniform(0, 1.5))
        add("Block", (w, h, w), c, rng.choice(colors), "Neon", collide=False, shadow=False, name=name)
        add("Block", (w * 0.7, w * 0.7, w * 0.7), c @ T(0, h / 2, 0) @ RX(math.pi / 4) @ RZ(math.pi / 4), P["soft"], "Neon", collide=False, shadow=False, name=name)


def leaf_cluster(p, n=3, r=1.0):
    for _ in range(n):
        d = rng.uniform(0.6, 1.0) * r * 1.5
        o = np.array(p) + (rng.uniform(-r, r) * 0.7, rng.uniform(-r, r) * 0.4, rng.uniform(-r, r) * 0.7)
        ball(d, T(*o), jit(rng.choice(P["leaf"]), 8), "Grass", collide=False, shadow=False)


def hanging_vine(top, length, wiggle=0.35):
    p = np.array(top, float)
    n = max(2, int(length / 2.4))
    for _ in range(n):
        q = p + (rng.uniform(-wiggle, wiggle), -length / n, rng.uniform(-wiggle, wiggle))
        seg(p, q, 0.24, P["vine"], "Grass", collide=False, shadow=False)
        ball(rng.uniform(0.7, 1.0), T(*(q + (rng.uniform(-0.4, 0.4), 0, rng.uniform(-0.4, 0.4)))), jit(rng.choice(P["leaf"]), 8), "Grass", collide=False, shadow=False)
        p = q


def glow_plant(p, s=1.0):
    x, y, z = p
    for _ in range(2):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(1.4, 2.4) * s
        wedge((0.12, h, 1.1 * s), T(x, y + h / 2, z) @ RY(a) @ RX(rng.uniform(-0.35, 0.05)), jit(rng.choice(P["leaf"]), 10), "Grass", collide=False, shadow=False)
    for _ in range(rng.randint(2, 3)):
        a, r = rng.uniform(0, math.tau), rng.uniform(0.1, 0.7) * s
        h = rng.uniform(1.2, 2.8) * s
        base = np.array((x + math.cos(a) * r, y, z + math.sin(a) * r))
        tip = base + (math.cos(a) * 0.4 * s, h, math.sin(a) * 0.4 * s)
        seg(base, tip, 0.12, P["plant"], "Grass", collide=False, shadow=False)
        ball(rng.uniform(0.4, 0.62) * s, T(*tip), rng.choice((P["glow"], P["soft"])), "Neon", collide=False, shadow=False)


def mushroom(p, s=1.0):
    x, y, z = p
    for _ in range(rng.randint(2, 3)):
        ox, oz = rng.uniform(-0.8, 0.8) * s, rng.uniform(-0.8, 0.8) * s
        h = rng.uniform(0.8, 1.8) * s
        cylinder_y(h, 0.35 * s, T(x + ox, y + h / 2, z + oz), (220, 214, 196), "SmoothPlastic", collide=False, shadow=False)
        cylinder_y(0.35 * s, rng.uniform(1.0, 1.6) * s, T(x + ox, y + h, z + oz), P["glow"], "Neon", collide=False, shadow=False)


def fern(p, s=1.0, n=6):
    x, y, z = p
    for k in range(n):
        a = k / n * math.tau + rng.uniform(-0.2, 0.2)
        L = rng.uniform(2.6, 3.8) * s
        wedge((0.12, L, 1.3 * s), T(x, y + 0.2, z) @ RY(a) @ RX(-rng.uniform(0.5, 0.9)) @ T(0, L / 2, 0), jit(rng.choice(P["leaf"]), 12), "Grass", collide=False, shadow=False)


def rock(p, d, mat="Rock"):
    x, y, z = p
    block((d, d * rng.uniform(0.55, 0.85), d * rng.uniform(0.7, 1.0)), T(x, y + d * 0.25, z) @ RY(rng.uniform(0, 3)) @ RX(rng.uniform(-0.3, 0.3)) @ RZ(rng.uniform(-0.3, 0.3)), stone_c(), mat)


def coral(p, s=1.0):
    x, y, z = p
    cols = ((255, 120, 110), (255, 170, 120), (250, 110, 170), (120, 220, 255))
    for _ in range(rng.randint(3, 5)):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(1.2, 2.6) * s
        base = np.array((x + rng.uniform(-0.6, 0.6) * s, y, z + rng.uniform(-0.6, 0.6) * s))
        tip = base + (math.cos(a) * 0.7 * s, h, math.sin(a) * 0.7 * s)
        c = rng.choice(cols)
        seg(base, tip, 0.34 * s, c, "SmoothPlastic", collide=False, shadow=False)
        ball(0.55 * s, T(*tip), c, "Neon" if rng.random() < 0.4 else "SmoothPlastic", collide=False, shadow=False)


def flora(p, s=1.0):
    """พืชประจำธาตุ"""
    r = rng.random()
    if EL == "Earth":
        if r < 0.35:
            fern((p[0], p[1] + 0.1, p[2]), s)
        elif r < 0.65:
            mushroom(p, s)
        else:
            glow_plant(p, s)
    elif EL == "Water":
        if r < 0.5:
            coral(p, s)
        else:
            glow_plant(p, s)
    elif EL == "Air":
        if r < 0.5:
            crystal_cluster(T(*p), 0.6 * s, 3)
        else:
            glow_plant(p, s)
    else:
        if r < 0.55:
            obsidian_spike(p, s)
        else:
            crystal_cluster(T(*p), 0.55 * s, 3)


def obsidian_spike(p, s=1.0):
    x, y, z = p
    for _ in range(rng.randint(2, 3)):
        h = rng.uniform(2.5, 5.0) * s
        c = T(x + rng.uniform(-1, 1) * s, y, z + rng.uniform(-1, 1) * s) @ RX(rng.uniform(-0.3, 0.3)) @ RZ(rng.uniform(-0.3, 0.3))
        block((0.9 * s, h, 0.9 * s), c @ T(0, h / 2, 0) @ RY(rng.uniform(0, 1)), (34, 26, 40), "Glass", collide=False)
        neon((0.25 * s, h * 0.7, 0.25 * s), c @ T(0, h * 0.4, 0), P["glow"])


# ---------------------------------------------------------------- โครงสร้างหลัก
def floor_disk(r, y=0.0):
    """ลานหินกลม: ฐานหนา + แผ่นหินแตกเป็นวงแหวน + เส้นเรืองแสง"""
    cylinder_y(3.0, r * 2 + 2, T(0, y - 1.3, 0), P["dark"], P["trim_mat"])
    rings = [(r - 2.5, r, 20), (r - 7.0, r - 3.0, 14), (4.5, r - 7.6, 10)]
    for k, (r0, r1, n) in enumerate(rings):
        for i in range(n):
            a0 = i / n * math.tau
            rm = (r0 + r1) / 2
            w = math.tau * rm / n * 0.94
            h = 0.3 + rng.uniform(0, 0.08)
            block((w, h, (r1 - r0) * 0.94), T(0, y + 0.15, 0) @ RY(-a0 - math.pi / n) @ T(0, 0, rm) @ RX(rng.uniform(-0.02, 0.02)), stone_c(), P["floor_mat"], shadow=False)
    for rr in (r - 2.75, 4.2):
        cylinder_y(0.12, rr * 2, T(0, y + 0.12, 0), P["glow"], "Neon", collide=False, shadow=False)
    for i in range(8):
        a = i / 8 * math.tau + math.pi / 8
        neon((0.3, 0.06, r - 8), T(0, y + 0.33, 0) @ RY(a) @ T(0, 0, (r + 2) / 2 + 1.5))
    for i in range(8):
        a = i / 8 * math.tau
        rune_glyph(T(0, y + 0.36, 0) @ RY(a) @ T(0, 0, r - 5.0) @ RX(-math.pi / 2), 0.95)


def altar():
    """แท่นบูชากลางลาน: ช่องรูนบอกความคืบหน้า 3 ช่อง + คริสตัลลอย"""
    cylinder_y(1.0, 7.0, T(0, 0.8, 0), P["dark"])
    cylinder_y(1.0, 5.6, T(0, 1.8, 0), P["light"])
    block((3.0, 3.2, 3.0), T(0, 3.9, 0) @ RY(math.pi / 4), stone_c())
    block((4.2, 0.8, 4.2), T(0, 5.9, 0) @ RY(math.pi / 4), P["light"])
    for i in range(3):
        a = i / 3 * math.tau + math.pi / 2  # หน้าละช่อง
        neon((1.0, 1.4, 0.12), T(0, 3.9, 0) @ RY(a) @ T(0, 0, 2.15), P["dark"], name=f"HintSlot{i + 1}")
    neon((1.4, 2.6, 1.4), T(0, 8.4, 0) @ RY(0.4) @ RX(0.15), P["glow"], name="AltarCrystal")
    neon((0.9, 0.9, 0.9), T(0, 9.9, 0) @ RX(math.pi / 4) @ RZ(math.pi / 4), P["soft"])
    neon((0.9, 0.9, 0.9), T(0, 6.9, 0) @ RX(math.pi / 4) @ RZ(math.pi / 4), P["soft"])
    for i in range(4):
        a = i / 4 * math.tau
        crystal_cluster(T(0, 0, 0) @ RY(a) @ T(0, 0.4, 3.6), 0.45, 2)


def obelisk(idx, x, z, kind):
    """เสาหินรูน (ต้องปลุกตามลำดับ): ฐาน 2 ชั้น + เสาสอบ + หน้ารูนใหญ่ + คริสตัลลอยยอด"""
    face = math.atan2(-x, -z)  # หันหน้า (+Z ของเสา) เข้าหาแท่นกลาง
    cf = T(x, 0, z) @ RY(face)
    with Group(f"Obelisk{idx}"):
        block((5.2, 1.0, 5.2), cf @ T(0, 0.5, 0), P["dark"], name="Activator")
        block((4.2, 1.0, 4.2), cf @ T(0, 1.5, 0), P["light"])
        for k in range(4):  # ขั้นบันไดเล็ก + ขอบเรืองแสง
            neon((4.3, 0.12, 0.12), cf @ RY(k * math.pi / 2) @ T(0, 2.04, 2.1), P["glow"], name="Glyph")
        H = 15.0
        n = 5
        for k in range(n):  # เสาสอบขึ้น (ซ้อนบล็อกย่อ)
            w = 3.0 - k * 0.32
            block((w, H / n + 0.02, w), cf @ T(0, 2 + H / n * (k + 0.5), 0), stone_c())
        block((2.0, 1.6, 2.0), cf @ T(0, 2 + H + 0.8, 0) @ RY(math.pi / 4), P["light"])
        # หน้ารูน: กรอบหิน + รูนใหญ่ + รูนเล็กไล่ลงมา
        block((2.3, 3.6, 0.3), cf @ T(0, 11.5, 1.32), P["light"], shadow=False)
        rune_glyph(cf @ T(0, 11.5, 1.5), 2.1, kind, name="Glyph")
        for gy in (5.0, 8.0):
            rune_glyph(cf @ T(0, gy, 1.46 - (gy - 4.6) * 0.03), 0.8, rng.choice("XYDFI"), name="Glyph")
        for sx in (-1, 1):
            neon((0.14, H * 0.8, 0.14), cf @ T(sx * 1.38, 2 + H * 0.45, 1.38), P["glow"], name="Glyph")
        neon((1.3, 2.4, 1.3), cf @ T(0, 2 + H + 3.6, 0) @ RY(0.5), P["glow"], name="Crystal")
        neon((0.8, 0.8, 0.8), cf @ T(0, 2 + H + 5.3, 0) @ RX(math.pi / 4) @ RZ(math.pi / 4), P["soft"], name="Crystal")
        block((1, 1, 1), cf @ T(0, 2 + H + 7.5, 0), (0, 0, 0), tr=1, name="Top", collide=False, shadow=False)
    # พืช/มอส (นอกกลุ่ม)
    if EL in ("Earth", "Water"):
        block((3.1, 0.5, 1.4), cf @ T(0, 2 + H * 0.3, -1.0), jit(rng.choice(P["moss"]), 6), "Grass", collide=False, shadow=False)
    flora(pos_of(cf @ T(3.4, 0, -1.8)), 0.8)


def pillar(x, z, h, cap=True, lean=0.0):
    cf = T(x, 0, z) @ RY(rng.uniform(0, 3)) @ RZ(lean)
    block((3.6, 1.0, 3.6), cf @ T(0, 0.5, 0), P["dark"])
    cylinder_y(h, 2.6, cf @ T(0, 1 + h / 2, 0), stone_c())
    for k in range(3):  # ร่องเสา
        neon((0.12, h * 0.55, 0.08), cf @ RY(k * math.tau / 3) @ T(0, 1 + h * 0.45, 1.3), P["glow"]) if rng.random() < 0.5 else None
    if cap:
        block((3.4, 0.9, 3.4), cf @ T(0, 1 + h + 0.45, 0), P["light"])
    else:  # หักกลาง
        block((2.4, 1.0, 2.4), cf @ T(0.2, 1 + h + 0.2, 0) @ RZ(0.4) @ RX(0.3), stone_c())
    return cf


def colonnade():
    """แนวเสาหักรอบลาน + คานพาด"""
    R = 31.0
    angs = [a for a in range(-160, 181, 26) if not (60 < a < 120) and not (-118 < a < -62)]
    tops = []
    for i, ad in enumerate(angs):
        a = math.radians(ad)
        x, z = math.cos(a) * R, math.sin(a) * R
        broken = rng.random() < 0.35
        h = rng.uniform(5, 8) if broken else rng.uniform(11, 13)
        pillar(x, z, h, cap=not broken)
        tops.append((x, z, h, broken))
        if EL in ("Earth", "Water") and not broken and rng.random() < 0.5:
            hanging_vine((x + 1.2, 1 + h, z), rng.uniform(4, 8))
    for (x0, z0, h0, b0), (x1, z1, h1, b1) in zip(tops, tops[1:]):
        if not b0 and not b1 and math.hypot(x1 - x0, z1 - z0) < 16 and rng.random() < 0.7:
            y = 1 + min(h0, h1) + 1.4
            cf = look_at(((x0 + x1) / 2, y, (z0 + z1) / 2), (x1, y, z1))
            L = math.hypot(x1 - x0, z1 - z0) + 3
            block((2.6, 1.6, L), cf, stone_c())
            block((0.1, 0.3, L * 0.8), cf @ T(1.32, 0, 0), P["glow"], "Neon", collide=False, shadow=False)
            block((0.1, 0.3, L * 0.8), cf @ T(-1.32, 0, 0), P["glow"], "Neon", collide=False, shadow=False)
            if EL == "Earth":
                block((2.9, 0.5, L * 0.7), cf @ T(0, 0.95, 0), jit(rng.choice(P["moss"]), 6), "Grass", collide=False, shadow=False)
    # เสาล้ม
    for (x, z, a) in ((-24, -30, 0.5), (27, 22, 2.4)):
        for k in range(3):
            cylinder_y(2.7, 2.5, T(x, 1.2, z) @ RY(a) @ T(0, 0, k * 2.9) @ RX(math.pi / 2 + rng.uniform(-0.12, 0.12)) @ RY(rng.uniform(-0.1, 0.1)), stone_c())
        flora((x + 2, 0, z + 1), 0.9)


def temple():
    """วิหารผนึก: ฐานยก 3 ชั้น + บันได + อาคารหน้าบัน + ประตูหินผนึก (ยุบลงได้) + ห้องหีบ"""
    Z = 40.0  # จุดกลางอาคาร
    W, D = 26.0, 20.0
    # ฐานยก
    for k, (w, d, h) in enumerate(((34, 26, 1.6), (30, 23, 1.6), (27, 21, 1.6))):
        block((w, h, d), T(0, h / 2 + k * 1.6, Z), P["dark"] if k == 0 else stone_c(), P["trim_mat"])
        neon((w + 0.1, 0.14, 0.14), T(0, (k + 1) * 1.6 - 0.25, Z - d / 2), P["glow"])
    base = 4.8
    # บันได
    for k in range(6):
        sh = base * (k + 1) / 6
        block((12, sh, 1.4), T(0, sh / 2, Z - 10.5 - (6 - k) * 1.4 + 0.7), jit(P["light"] if k % 2 else rng.choice(P["stone"]), 4), P["trim_mat"])
    for sx in (-1, 1):  # ราวบันได + เตาไฟ
        block((1.6, 3.0, 9.0), T(sx * 6.8, 1.5, Z - 15.5) @ RX(-0.0), P["dark"])
        block((2.2, 1.6, 2.2), T(sx * 6.8, 3.8, Z - 19.3), P["light"])
        block((1.2, 1.0, 1.2), T(sx * 6.8, 5.0, Z - 19.3), P["glow"], "Neon", name="Brazier", collide=False, shadow=False)
    # ตัวอาคาร: ผนังซ้าย/ขวา/หลัง (เว้นช่องประตูหน้า)
    H = 17.0
    door_w, door_h = 9.0, 12.0
    fz = Z - D / 2 + 1.0  # ผนังหน้า
    wall = P["stone"]
    for sx in (-1, 1):
        x = sx * (door_w / 2 + (W / 2 - door_w / 2) / 2)
        ww = W / 2 - door_w / 2
        block((ww, H, 2.4), T(x, base + H / 2, fz), jit(rng.choice(wall), 4))
        block((2.4, H, D - 2), T(sx * (W / 2 - 1.2), base + H / 2, Z + 0.5), jit(rng.choice(wall), 4))
        # เสาประดับหน้า (คู่)
        for k, ox in enumerate((door_w / 2 + 1.6, W / 2 - 0.4)):
            cylinder_y(H - 1, 2.6, T(sx * ox, base + (H - 1) / 2, fz - 1.8), P["light"])
            block((3.4, 1.0, 3.4), T(sx * ox, base + 0.5, fz - 1.8), P["dark"])
            block((3.4, 1.0, 3.4), T(sx * ox, base + H - 0.5, fz - 1.8), P["dark"])
            neon((0.12, H - 4, 0.12), T(sx * ox, base + H / 2, fz - 3.12), P["glow"])
        # รูนแถวตั้งบนผนังหน้า
        for gy in (4.0, 9.0, 14.0):
            rune_glyph(T(sx * (door_w / 2 + 3.8), base + gy, fz - 1.25), 1.1)
    block((W, H, 2.4), T(0, base + H / 2, Z + D / 2 - 0.2), jit(rng.choice(wall), 4))
    block((door_w + 0.2, H - door_h, 2.4), T(0, base + door_h + (H - door_h) / 2, fz), jit(rng.choice(wall), 4))
    # กรอบประตู + ทับหลัง + สัญลักษณ์ธาตุ
    for sx in (-1, 1):
        block((1.2, door_h + 1, 3.0), T(sx * (door_w / 2 + 0.4), base + door_h / 2, fz - 0.2), P["light"])
        neon((0.16, door_h, 0.16), T(sx * (door_w / 2 - 0.2), base + door_h / 2, fz - 1.75), P["glow"])
    block((door_w + 3.4, 1.6, 3.2), T(0, base + door_h + 0.8, fz - 0.3), P["light"])
    neon((door_w + 2.6, 0.16, 0.16), T(0, base + door_h + 0.1, fz - 1.95), P["glow"])
    element_sigil(T(0, base + door_h + 3.0, fz - 1.3), 1.0)
    # บัวหลังคา + หน้าบันจั่ว
    block((W + 2, 1.4, D + 1), T(0, base + H + 0.7, Z + 0.5), P["light"])
    neon((W + 2.1, 0.14, 0.14), T(0, base + H + 0.2, Z - D / 2), P["glow"])
    roof_h = 7.0
    for sx in (-1, 1):
        wedge((D + 0.6, roof_h, W / 2 + 0.6), T(sx * (W / 4 + 0.3), base + H + 1.4 + roof_h / 2, Z + 0.5) @ RY(-sx * math.pi / 2), jit(P["dark"], 6), P["trim_mat"])
    # ตาจั่ว
    neon((1.6, 1.6, 0.2), T(0, base + H + 4.0, Z - D / 2 - 0.25) @ RZ(math.pi / 4), P["glow"])
    block((1, 1, 1), T(0, base + H + roof_h + 4, Z), (0, 0, 0), tr=1, name="Beacon", collide=False, shadow=False)
    # ขอบหลังคาเรืองแสง + ผลึกยอดมุม + วงรัศมีลอยเหนือวิหาร
    slope = math.atan2(roof_h, W / 2)
    L = math.hypot(roof_h, W / 2)
    for sx in (-1, 1):
        neon((L, 0.2, 0.2), T(sx * W / 4, base + H + 1.5 + roof_h / 2, Z - D / 2 + 0.1) @ RZ(-sx * slope), P["glow"])
        crystal_cluster(T(sx * (W / 2 + 0.4), base + H + 1.4, Z - D / 2 + 0.6), 0.8, 2)
    crystal_cluster(T(0, base + H + 1.4 + roof_h, Z - D / 2 + 1.2), 0.9, 3)
    hy = base + H + roof_h + 9
    for k in range(16):
        a = k / 16 * math.tau
        neon((2.5, 0.35, 0.35), T(0, hy, Z) @ RX(math.pi / 2 - 0.25) @ RZ(a) @ T(0, 6.2, 0), P["glow"], name="Halo")
    neon((2.2, 3.6, 2.2), T(0, hy, Z) @ RY(0.6) @ RX(0.3), P["soft"], name="Halo")
    # ส่วนพัง: มุมหลังคาแตก + เศษหิน
    block((5, 3, 4), T(W / 2 - 1, base + H + 1.2, Z + D / 2 - 2) @ RZ(0.5) @ RX(0.3), stone_c())
    for _ in range(3):
        rock((rng.uniform(W / 2 + 1, W / 2 + 6), 0, Z + rng.uniform(-8, 8)), rng.uniform(1.6, 3.2), P["mat"])
    # ห้องภายใน (มืด) + แท่นหีบ
    block((door_w + 0.4, 0.4, D - 4), T(0, base + 0.2, Z + 0.5), P["dark"], shadow=False)
    block((door_w + 0.4, 0.6, D - 4), T(0, base + door_h + 0.3, Z + 0.5), P["dark"])
    block((door_w + 0.4, door_h, 0.6), T(0, base + door_h / 2, Z + D / 2 - 1.6), P["dark"])
    block((5.4, 1.4, 4.0), T(0, base + 0.9, Z + 4.0), P["light"])
    neon((5.5, 0.12, 4.1), T(0, base + 1.45, Z + 4.0), P["glow"])
    block((1, 1, 1), T(0, base + 6, Z + 2), (0, 0, 0), tr=1, name="VaultLight", collide=False, shadow=False)
    for sx in (-1, 1):
        crystal_cluster(T(sx * 3.4, base + 0.4, Z + 6.0), 0.7, 3)
    # ประตูผนึก (ยุบลงพื้นเมื่อไขปริศนาได้)
    with Group("VaultDoor"):
        block((door_w, door_h, 1.4), T(0, base + door_h / 2, fz - 0.4), P["dark"], name="DoorSlab")
        block((door_w - 1.2, door_h - 1.2, 0.2), T(0, base + door_h / 2, fz - 1.15), jit(P["light"], 4), shadow=False)
        element_sigil(T(0, base + door_h / 2 + 0.6, fz - 1.3), 1.15, name="DoorSeal")
        for k in range(2):
            neon((0.16, door_h - 1.8, 0.1), T((k * 2 - 1) * (door_w / 2 - 1.0), base + door_h / 2, fz - 1.28), P["glow"], name="DoorSeal")
    # หีบศักดิ์สิทธิ์
    cz = Z + 4.0
    cy = base + 1.6
    with Group("VaultChest"):
        block((3.6, 2.0, 2.4), T(0, cy + 1.0, cz), (110, 72, 40), "WoodPlanks", name="ChestBody")
        for sx in (-1, 1):
            block((0.3, 2.1, 2.5), T(sx * 1.55, cy + 1.0, cz), (210, 170, 70), "Metal")
        block((3.7, 0.3, 2.5), T(0, cy + 0.2, cz), (210, 170, 70), "Metal")
        neon((0.7, 0.8, 0.12), T(0, cy + 1.5, cz - 1.26), P["glow"])
    with Group("ChestLid"):
        block((3.7, 0.9, 2.5), T(0, cy + 2.45, cz), (130, 86, 48), "WoodPlanks", name="LidBody")
        block((3.8, 0.25, 2.6), T(0, cy + 2.95, cz), (210, 170, 70), "Metal")
        neon((1.0, 0.2, 0.2), T(0, cy + 2.55, cz - 1.3), P["soft"])


def cave_arch(x, z, face):
    """ปากถ้ำคริสตัล / ซุ้มหินธรรมชาติ"""
    cf = T(x, 0, z) @ RY(face)
    R = 9.0
    for k in range(13):
        th = k / 12 * math.pi
        p = cf @ T(math.cos(th) * R, 1 + math.sin(th) * R * 1.25, 0)
        s = rng.uniform(4.2, 5.8)
        block((s, s * rng.uniform(0.8, 1.1), s * rng.uniform(1.2, 1.6)), p @ RZ(th + rng.uniform(-0.3, 0.3)) @ RX(rng.uniform(-0.2, 0.2)), stone_c(), "Rock")
    for k in range(7):  # หลังถ้ำ (ทึบมืด)
        th = k / 6 * math.pi
        block((5, 5, 6), cf @ T(math.cos(th) * (R - 2.0), math.sin(th) * (R - 2.5) * 1.1, 4.5), jit(P["dark"], 4), "Rock")
    block((R * 1.6, R * 1.2, 1.0), cf @ T(0, R * 0.55, 6.5), (14, 14, 18), "SmoothPlastic", shadow=False)
    block((1, 1, 1), cf @ T(0, 4, 2), (0, 0, 0), tr=1, name="CaveGlow", collide=False, shadow=False)
    for ox in (-5.5, -2.5, 2.8, 5.6):
        crystal_cluster(cf @ T(ox, 0.2, rng.uniform(-1, 2)), rng.uniform(0.9, 1.4), 3)
    crystal_cluster(cf @ T(0, R * 1.2, -0.5) @ RX(math.pi), 0.8, 3)  # ผลึกห้อยเพดาน
    for _ in range(3):
        rock(pos_of(cf @ T(rng.uniform(-R - 3, R + 3), 0, rng.uniform(-4, -1))), rng.uniform(1.8, 3.4))
    if EL in ("Earth", "Water"):
        for k in range(3):
            hanging_vine(pos_of(cf @ T(-4 + k * 4, 1 + R * 1.15, -2.2)), rng.uniform(4, 8))
    if EL == "Water":  # น้ำตกเล็กไหลจากปากถ้ำ
        block((4.0, R * 1.1, 0.6), cf @ T(0, R * 0.55 + 1, -3.0), (110, 200, 235), "Glass", tr=0.3, collide=False, shadow=False)
        neon((2.6, R * 1.1, 0.3), cf @ T(0, R * 0.55 + 1, -3.3), (220, 245, 255), tr=0.55)
        cylinder_y(0.4, 9, cf @ T(0, 0.3, -5.5), (90, 180, 220), "Glass", tr=0.25, collide=False, shadow=False)


def side_ruin(x, z, face):
    """กำแพงพังมีรูน + แผ่นศิลาจารึก"""
    cf = T(x, 0, z) @ RY(face)
    for k in range(5):
        h = rng.uniform(4, 9) if k not in (2,) else 2.5
        c = cf @ T((k - 2) * 4.2, h / 2, 0)
        block((4.3, h, 2.6), c, stone_c())
        if rng.random() < 0.6:
            rune_glyph(c @ T(0, rng.uniform(-0.8, 1.2), 1.34), 1.0)
        if EL == "Earth":
            block((4.4, 0.45, 2.8), c @ T(0, h / 2 + 0.2, 0), jit(rng.choice(P["moss"]), 6), "Grass", collide=False, shadow=False)
    stele = cf @ T(0, 0, -6)
    block((4.6, 0.8, 2.6), stele @ T(0, 0.4, 0), P["dark"])
    block((3.6, 7, 1.0), stele @ T(0, 4.3, 0), P["light"])
    for gy in (3.0, 5.6):
        for gx in (-0.9, 0.9):
            rune_glyph(stele @ T(gx, gy, -0.55) @ RY(math.pi), 0.7)
    for _ in range(2):
        flora(pos_of(cf @ T(rng.uniform(-9, 9), 0, rng.uniform(-4, -2))), rng.uniform(0.8, 1.2))


def entrance():
    """ประตูทางเข้า (ด้านหน้า -Z) + ทางเดินหินพร้อมเส้นเรืองแสง"""
    z = -44.0
    for sx in (-1, 1):
        x = sx * 7.5
        block((4.6, 1.6, 4.6), T(x, 0.8, z), P["dark"])
        h = 15 if sx < 0 else 9.5  # ขวาหัก
        block((3.4, h, 3.4), T(x, 1.6 + h / 2, z), stone_c())
        for gy in (4.5, 8.0, 11.5):
            if gy < h:
                rune_glyph(T(x, gy, z - 1.75) @ RY(math.pi), 1.0)
        block((4.2, 1.0, 4.2), T(x, 1.6 + h + 0.5, z), P["light"]) if sx < 0 else None
        block((1.4, 1.2, 1.4), T(x, 1.6 + h + (1.6 if sx < 0 else 0.6), z), P["glow"], "Neon", name="Brazier", collide=False, shadow=False)
    # ทับหลังที่หล่นเอียง
    block((19, 2.2, 3.2), T(-2.0, 13.5, z) @ RZ(-0.33), stone_c())
    neon((15, 0.14, 0.14), T(-2.0, 13.5, z - 1.65) @ RZ(-0.33), P["glow"])
    # ทางเดิน
    block((9, 0.5, 26), T(0, -0.1, -30.5), P["dark"], P["trim_mat"], shadow=False)
    for k in range(9):
        zz = -42.5 + k * 2.9
        for ox in (-2.2, 2.2):
            block((rng.uniform(3.6, 4.1), 0.34, rng.uniform(2.3, 2.7)), T(ox + rng.uniform(-0.2, 0.2), 0.2, zz) @ RY(rng.uniform(-0.15, 0.15)), stone_c(), P["floor_mat"], shadow=False)
    for sx in (-1, 1):
        neon((0.18, 0.08, 26), T(sx * 4.4, 0.18, -30.5))
    for k in range(4):
        zz = -40 + k * 6
        for sx in (-1, 1):
            block((1.2, 2.4, 1.2), T(sx * 5.6, 1.2, zz), P["light"])
            neon((0.8, 0.6, 0.8), T(sx * 5.6, 2.7, zz), P["soft"])


def element_extras():
    if EL == "Earth":
        # รากยักษ์โอบเสา/กำแพง + ต้นไม้โบราณข้างวิหาร
        for (x, z) in ((-20, 46), (21, 50)):
            h = 30
            seg((x, 0, z), (x + 1, h, z + 1), 3.6, (92, 72, 52), "Wood")
            for k in range(5):
                a = k / 5 * math.tau
                seg((x + math.cos(a) * 6, 0, z + math.sin(a) * 6), (x, 6, z), 1.4, (86, 66, 48), "Wood")
            for _ in range(5):
                o = (x + rng.uniform(-7, 7), h + rng.uniform(-3, 3), z + rng.uniform(-7, 7))
                ball(rng.uniform(10, 15), T(*o), jit(rng.choice(P["leaf"]), 8), "Grass", collide=False)
            hanging_vine((x - 4, h - 3, z - 4), 12)
            hanging_vine((x + 4, h - 3, z - 3), 10)
        for _ in range(6):
            a, r = rng.uniform(0, math.tau), rng.uniform(36, 46)
            flora((math.cos(a) * r, 0, math.sin(a) * r), rng.uniform(0.9, 1.3))
    elif EL == "Water":
        # สระน้ำสองข้างทางขึ้นวิหาร + เปลือกหอยยักษ์
        for sx in (-1, 1):
            block((10, 0.8, 12), T(sx * 13.5, 0.15, 22), P["light"], P["trim_mat"])
            block((8.6, 0.3, 10.6), T(sx * 13.5, 0.62, 22), (80, 180, 220), "Glass", tr=0.25, collide=False, shadow=False)
            neon((8.0, 0.08, 10.0), T(sx * 13.5, 0.45, 22), P["glow"], tr=0.4)
            coral((sx * 13.5 + 2, 0.6, 20), 1.0)
            coral((sx * 13.5 - 2.5, 0.6, 24), 0.8)
        for (x, z) in ((-36, -8), (37, -14)):
            for k in range(7):
                a = (k - 3) * 0.32
                wedge((1.2, 5.2 - abs(k - 3) * 0.6, 2.4), T(x, 0, z) @ RY(1.2) @ RZ(a) @ T(0, 2.6, 0), (250, 222, 210), "Marble")
            ball(1.4, T(x, 1.2, z), P["soft"], "Neon", collide=False, shadow=False)
        for _ in range(6):
            a, r = rng.uniform(0, math.tau), rng.uniform(35, 46)
            flora((math.cos(a) * r, 0, math.sin(a) * r), rng.uniform(0.9, 1.3))
    elif EL == "Air":
        # หินลอยฟ้า + ธงมนต์ลม
        for k in range(5):
            a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
            r = rng.uniform(34, 46)
            y = rng.uniform(24, 36)
            x, z = math.cos(a) * r, math.sin(a) * r
            s = rng.uniform(3, 6)
            block((s, s * 0.7, s), T(x, y, z) @ RY(rng.uniform(0, 3)) @ RX(0.2), stone_c(), "Rock")
            wedge((s * 0.9, s * 1.2, s * 0.9), T(x, y - s * 0.95, z) @ RX(math.pi) @ RY(rng.uniform(0, 3)), stone_c(), "Rock")
            crystal_cluster(T(x, y + s * 0.35, z), 0.6, 2)
        for side in (-1, 1):
            p0 = np.array((side * 7.5, 15.5 if side < 0 else 10, -44))
            p1 = np.array((side * 14.5, 13.5, 26))
            n = 10
            prev = p0
            for k in range(n):
                t = (k + 0.5) / n
                q = p0 + (p1 - p0) * t - np.array((0, math.sin(t * math.pi) * 3.5, 0))
                seg(prev, q, 0.12, (230, 220, 200), "Fabric", collide=False, shadow=False)
                prev = q
                col = ((230, 90, 80), (250, 220, 120), (110, 190, 140), (100, 160, 240), (245, 245, 250))[k % 5]
                block((1.5, 1.9, 0.08), T(*q) @ RY(math.atan2(p1[0] - p0[0], p1[2] - p0[2]) + math.pi / 2) @ T(0, -0.95, 0), col, "Fabric", collide=False, shadow=False)
        for _ in range(6):
            a, r = rng.uniform(0, math.tau), rng.uniform(35, 46)
            flora((math.cos(a) * r, 0, math.sin(a) * r), rng.uniform(0.9, 1.3))
    else:
        # ร่องลาวาตัดลาน + หินบะซอลต์หกเหลี่ยม + หัวกะโหลกมังกร
        for a in (0.35, 2.8, 4.4):
            for k in range(6):
                r0 = 20 + k * 3.4
                neon((0.7, 0.12, 3.6), T(0, 0.05, 0) @ RY(a + rng.uniform(-0.06, 0.06)) @ T(rng.uniform(-0.6, 0.6), 0, r0), P["accent"])
        for (x, z) in ((-37, 4), (38, 6), (-30, 30), (31, 33)):
            for k in range(4):
                h = rng.uniform(4, 12)
                cylinder_y(h, 2.6, T(x + rng.uniform(-2.5, 2.5), h / 2, z + rng.uniform(-2.5, 2.5)), jit(P["dark"], 6), "Basalt")
        sx, sz = 34, -26
        ball(7, T(sx, 3, sz), (226, 216, 196), "SmoothPlastic")
        block((5, 3, 7), T(sx, 1.6, sz - 4), (220, 210, 190), "SmoothPlastic")
        for k in (-1, 1):
            ball(1.6, T(sx + k * 1.7, 3.6, sz - 3.0), P["glow"], "Neon", collide=False, shadow=False)
            seg((sx + k * 2.6, 5, sz + 1), (sx + k * 6, 9.5, sz + 4.5), 1.0, (230, 222, 200), "SmoothPlastic")
        for _ in range(6):
            a, r = rng.uniform(0, math.tau), rng.uniform(35, 46)
            flora((math.cos(a) * r, 0, math.sin(a) * r), rng.uniform(0.9, 1.3))


def mist_points():
    for (x, z) in ((0, 0), (-20, 10), (20, 10), (0, 26)):
        block((1, 1, 1), T(x, 0.5, z), (0, 0, 0), tr=1, name="Mist", collide=False, shadow=False)


OBELISKS = [(-23.0, -3.0, "X"), (-11.0, -26.0, "D"), (23.0, -3.0, "Y")]


def build(el):
    global P, EL, rng, parts
    EL, P = el, PALETTES[el]
    rng = random.Random({"Earth": 11, "Water": 22, "Air": 33, "Fire": 44}[el])
    parts = []
    block((1, 1, 1), T(0, 0, 0), (0, 0, 0), tr=1, name="Origin", collide=False, shadow=False)
    floor_disk(19.0)
    altar()
    for i, (x, z, kind) in enumerate(OBELISKS, 1):
        obelisk(i, x, z, kind)
    temple()
    colonnade()
    entrance()
    cave_arch(-39.0, 20.0, math.radians(-62))
    side_ruin(40.0, 16.0, math.radians(60))
    element_extras()
    mist_points()
    return parts


# ---------------------------------------------------------------- เขียน .rbxmx
def f3(v):
    return f"{v:.3f}".rstrip("0").rstrip(".") if abs(v) > 1e-6 else "0"


def part_xml(p, ref):
    cls = "WedgePart" if p["shape"] == "Wedge" else "Part"
    m = p["cf"]
    r, g, b = p["color"]
    col = (0xFF << 24) | (r << 16) | (g << 8) | b
    cfx = (f'<CoordinateFrame name="CFrame"><X>{f3(m[0,3])}</X><Y>{f3(m[1,3])}</Y><Z>{f3(m[2,3])}</Z>'
           f'<R00>{f3(m[0,0])}</R00><R01>{f3(m[0,1])}</R01><R02>{f3(m[0,2])}</R02>'
           f'<R10>{f3(m[1,0])}</R10><R11>{f3(m[1,1])}</R11><R12>{f3(m[1,2])}</R12>'
           f'<R20>{f3(m[2,0])}</R20><R21>{f3(m[2,1])}</R21><R22>{f3(m[2,2])}</R22></CoordinateFrame>')
    sx, sy, sz = p["size"]
    shape = "" if cls == "WedgePart" else f'<token name="shape">{ {"Ball": 0, "Block": 1, "Cylinder": 2}[p["shape"]] }</token>'
    return (
        f'<Item class="{cls}" referent="{ref}"><Properties><string name="Name">{p["name"] or p["shape"]}</string>'
        f'<bool name="Anchored">true</bool>{cfx}<Vector3 name="size"><X>{f3(sx)}</X><Y>{f3(sy)}</Y><Z>{f3(sz)}</Z></Vector3>'
        f'<Color3uint8 name="Color3uint8">{col}</Color3uint8><token name="Material">{MAT[p["mat"]]}</token>'
        f'<float name="Transparency">{p["tr"]}</float><bool name="CanCollide">{str(p["collide"]).lower()}</bool>'
        f'<bool name="CanQuery">{str(p["collide"] or p["name"] == "Activator").lower()}</bool><bool name="CanTouch">false</bool>'
        f'<bool name="CastShadow">{str(p["shadow"]).lower()}</bool>{shape}'
        '<token name="TopSurface">0</token><token name="BottomSurface">0</token></Properties></Item>'
    )


def write_rbxmx(path, name):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">']
    out.append(f'<Item class="Model" referent="RBX0"><Properties><string name="Name">{name}</string><Ref name="PrimaryPart">RBX1</Ref></Properties>')
    groups = {}
    n = 0
    for p in parts:
        n += 1
        ref = f"RBX{n}"
        if p["group"]:
            groups.setdefault(p["group"], []).append(part_xml(p, ref))
        else:
            out.append(part_xml(p, ref))
    for gname, items in groups.items():
        n += 1
        out.append(f'<Item class="Model" referent="RBX{n}"><Properties><string name="Name">{gname}</string></Properties>')
        out.extend(items)
        out.append("</Item>")
    out.append("</Item></roblox>")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))


# ---------------------------------------------------------------- ภาพตัวอย่าง (Blender)
def preview(path, els, view, spp):
    import bpy  # noqa: I001
    import bmesh
    import mathutils

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    coll = scene.collection
    mats = {}

    def material(color, matname, tr):
        key = (color, matname, round(tr, 2))
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new(str(key))
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        lin = tuple((c / 255) ** 2.2 for c in color)
        b.inputs["Base Color"].default_value = (*lin, 1)
        b.inputs["Roughness"].default_value = {"Glass": 0.05, "Neon": 0.2, "Metal": 0.35, "Marble": 0.4, "Ice": 0.1}.get(matname, 0.85)
        if matname == "Metal":
            b.inputs["Metallic"].default_value = 0.9
        if matname == "Neon":
            b.inputs["Emission Color"].default_value = (*lin, 1)
            b.inputs["Emission Strength"].default_value = 3.0
        if tr > 0:
            b.inputs["Alpha"].default_value = 1 - tr
            m.blend_method = "BLEND"
        mats[key] = m
        return m

    meshes = {}

    def mesh(shape):
        if shape in meshes:
            return meshes[shape]
        me = bpy.data.meshes.new(shape)
        bm = bmesh.new()
        if shape == "Block":
            bmesh.ops.create_cube(bm, size=1.0)
        elif shape == "Ball":
            bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
        elif shape == "Cylinder":
            bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1.0,
                                  matrix=mathutils.Matrix.Rotation(math.pi / 2, 4, "Y"))
        else:
            vs = [bm.verts.new(v) for v in [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]]
            bm.faces.new([vs[0], vs[1], vs[2], vs[3]])
            bm.faces.new([vs[3], vs[2], vs[5], vs[4]])
            bm.faces.new([vs[0], vs[4], vs[5], vs[1]])
            bm.faces.new([vs[0], vs[3], vs[4]])
            bm.faces.new([vs[1], vs[5], vs[2]])
        bm.to_mesh(me)
        bm.free()
        meshes[shape] = me
        return me

    Cm = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], float)
    placeholder = bpy.data.materials.new("placeholder")

    def place(shape, size, cf, color, matname, tr):
        me = mesh(shape)
        if len(me.materials) == 0:
            me.materials.append(placeholder)
        o = bpy.data.objects.new(shape, me)
        M = Cm @ cf @ np.diag((size[0], size[1], size[2], 1))
        o.matrix_world = mathutils.Matrix(M.tolist())
        coll.objects.link(o)
        o.material_slots[0].link = "OBJECT"
        o.material_slots[0].material = material(color, matname, tr)

    SPACING = 125.0
    for i, el in enumerate(els):
        ox = ((i % 2) - 0.5) * SPACING if len(els) > 1 else 0.0
        oz = ((i // 2) - 0.5) * SPACING if len(els) > 1 else 0.0
        build(el)
        off = T(ox, 0, oz)
        place("Cylinder", (1, 130, 130), off @ T(0, -0.6, 0) @ RZ(math.pi / 2), PALETTES[el]["ground"], "Grass", 0)
        for p in parts:
            if p["tr"] >= 1:
                continue
            place(p["shape"], p["size"], off @ p["cf"], p["color"], p["mat"], p["tr"])

    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    sky = world.node_tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    night = "night" in view
    view = view.replace("night", "").strip("_") or "front"
    sky.sun_elevation = math.radians(4 if night else 24)
    sky.sun_rotation = math.radians(200)
    world.node_tree.links.new(sky.outputs["Color"], world.node_tree.nodes["Background"].inputs["Color"])
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.03 if night else 0.16
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 0.35 if night else 2.2
    if night:
        sun.color = (0.55, 0.65, 1.0)
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(58), 0, math.radians(200))
    coll.objects.link(so)

    grid = len(els) > 1
    views = {
        "front": ((0, 150, -250), (0, 0, 30), 50) if grid else ((0, 26, -88), (0, 9, 12), 55),
        "top": ((0, 300, -120), (0, 0, 10), 55) if grid else ((0, 110, -70), (0, 0, 8), 55),
        "door": ((-14, 9, 6), (0, 11, 32), 60),
        "side": ((-70, 30, -40), (0, 8, 10), 55),
    }
    cpos, ctgt, fov = views[view]
    camd = bpy.data.cameras.new("cam")
    camd.angle = math.radians(fov)
    camd.clip_end = 4000
    cam = bpy.data.objects.new("cam", camd)
    coll.objects.link(cam)
    bp = mathutils.Vector((cpos[0], -cpos[2], cpos[1]))
    bt = mathutils.Vector((ctgt[0], -ctgt[2], ctgt[1]))
    cam.location = bp
    cam.rotation_euler = (bt - bp).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = spp
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x, scene.render.resolution_y = (1600, 900) if grid else (1280, 720)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.1
    scene.use_nodes = True
    cn = scene.node_tree
    cn.nodes.clear()
    rl = cn.nodes.new("CompositorNodeRLayers")
    gl = cn.nodes.new("CompositorNodeGlare")
    gl.glare_type = "FOG_GLOW"
    gl.quality = "MEDIUM"
    gl.threshold = 1.2
    gl.size = 7
    co = cn.nodes.new("CompositorNodeComposite")
    cn.links.new(rl.outputs["Image"], gl.inputs["Image"])
    cn.links.new(gl.outputs["Image"], co.inputs["Image"])
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", path)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        k = sys.argv.index("--preview")
        out, which = sys.argv[k + 1], sys.argv[k + 2]
        view = sys.argv[k + 3] if len(sys.argv) > k + 3 else "front"
        spp = int(sys.argv[k + 4]) if len(sys.argv) > k + 4 else 24
        els = list(ELEMENTS) if which == "All" else [which]
        preview(out, els, view, spp)
    else:
        for el in ELEMENTS:
            build(el)
            path = os.path.join(OUT_DIR, f"Sanctum_{el}.rbxmx")
            write_rbxmx(path, f"Sanctum_{el}")
            counts = {}
            for p in parts:
                if p["group"]:
                    counts[p["group"]] = counts.get(p["group"], 0) + 1
            print(f"Sanctum_{el}: {len(parts)} parts -> {os.path.relpath(path, ROOT)}  groups={counts}")
