"""ฉากล็อบบี้ "ป่าโบราณศักดิ์สิทธิ์" — ประตูมิติหินโบราณ 4 ประตู + ซากปรักหักพัง + ป่าดิบ + น้ำตก + พืชเรืองแสง

สร้างเป็นชิ้นส่วน Part ล้วน (ไม่ต้องอัปโหลดอะไร) ในพิกัดของล็อบบี้ (จุดศูนย์กลางล็อบบี้ = 0,0,0 · ผิวหญ้า y = 1)
  python tools/lobby_art.py                    -> assets/rbxm/LobbyArt/LobbyRuins.rbxmx (build_rbxlx ใส่ไว้ใน ServerStorage.LobbyArt)
  <bpy-python> tools/lobby_art.py --preview out.png portal|grove|overview [samples]   -> ภาพตัวอย่างจาก Blender

ชิ้นที่มีชื่อเฉพาะ (LobbyService ใช้ต่อ: ไฟ/อนุภาค/ป้าย/โซน):
  PortalCenter<i> PortalRing<i> PortalVeil<i> PortalBrazier<i>L/R · CampSign · GroveSign · CrystalLamp · WaterfallFoam
"""
import math
import os
import random
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "rbxm", "LobbyArt", "LobbyRuins.rbxmx")

# ---------------------------------------------------------------- จุดสำคัญของผัง (ตรงกับ LobbyService)
GROVE = (52.0, 8.0)  # ลานประตูมิติ (ฝั่งตะวันออก)
GROVE_R = 50.0
PORTAL_ANGLES = (-60, -20, 20, 60)
FX, FZ0, FZ1 = 120, -112, 104  # ขอบเขตค่าย

MAT = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784, "Slate": 800,
    "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880, "Rock": 896, "Grass": 1280,
    "Sand": 1296, "Fabric": 1312, "Ground": 1376, "Glass": 1568,
}

C_STONE = [(116, 124, 118), (104, 114, 108), (126, 132, 124), (96, 106, 100)]
C_STONE_L = (146, 152, 142)
C_STONE_D = (78, 88, 84)
C_MOSS = [(84, 132, 60), (70, 118, 52), (98, 146, 66)]
C_LEAF = [(66, 140, 58), (52, 120, 50), (88, 158, 68), (44, 104, 46)]
C_VINE = (50, 98, 44)
C_CYAN = (70, 230, 255)
C_CYAN_SOFT = (150, 242, 255)
C_BARK = [(96, 74, 54), (84, 64, 46), (106, 82, 58)]
C_WATER = (150, 214, 240)

rng = random.Random(4242)
parts = []


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
    """เหมือน CFrame.lookAt: -Z ชี้ไปหา target (แกน Y ขึ้น)"""
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


def jit(c, k=10):
    return tuple(int(max(0, min(255, v + rng.randint(-k, k)))) for v in c)


def add(shape, size, cf, color, mat="SmoothPlastic", tr=0.0, name=None, collide=True, shadow=True):
    if shape == "Ball":
        d = min(size)
        size = (d, d, d)
    parts.append(dict(shape=shape, size=tuple(float(v) for v in size), cf=cf, color=tuple(color), mat=mat, tr=tr, name=name,
                      collide=collide, shadow=shadow))


def block(size, cf, color, mat="Slate", **kw):
    add("Block", size, cf, color, mat, **kw)


def ball(d, cf, color, mat="SmoothPlastic", **kw):
    add("Ball", (d, d, d), cf, color, mat, **kw)


def cylinder_y(h, d, cf, color, mat="Slate", **kw):
    """ทรงกระบอกตั้ง (แกนตั้ง) — Roblox แกนกระบอก = X จึงหมุน Z 90°"""
    add("Cylinder", (h, d, d), cf @ RZ(math.pi / 2), color, mat, **kw)


def cylinder_z(h, d, cf, color, mat="Slate", **kw):
    """ทรงกระบอกนอน แกนหันไปทาง Z (แผ่นกลมตั้งหันหน้าออก)"""
    add("Cylinder", (h, d, d), cf @ RY(math.pi / 2), color, mat, **kw)


def wedge(size, cf, color, mat="Grass", **kw):
    add("Wedge", size, cf, color, mat, **kw)


def seg(a, b, w, color, mat="SmoothPlastic", **kw):
    """แท่งเชื่อมจุด a -> b (หนา w)"""
    a, b = np.array(a, float), np.array(b, float)
    L = np.linalg.norm(b - a)
    if L < 1e-3:
        return
    cf = look_at((a + b) / 2, b) if abs((b - a)[1]) < L * 0.999 else T(*((a + b) / 2)) @ RX(math.pi / 2)
    block((w, w, L), cf, color, mat, **kw)


# ---------------------------------------------------------------- ชิ้นส่วนย่อย
def leaf_cluster(p, n=3, r=0.9, colors=C_LEAF):
    if r >= 1.0 and rng.random() < 0.6:  # ใบแบนๆ แซม ไม่ให้เป็นลูกบอลล้วน
        a = rng.uniform(0, math.tau)
        wedge((0.12, 1.6 * r, 1.2 * r), T(*p) @ RY(a) @ RX(rng.uniform(-1.2, -0.4)), jit(rng.choice(colors), 10), "Grass", collide=False, shadow=False)
    for _ in range(n):
        d = rng.uniform(0.5, 1.0) * r * 1.4
        o = np.array(p) + (rng.uniform(-r, r) * 0.6, rng.uniform(-r, r) * 0.4, rng.uniform(-r, r) * 0.6)
        ball(d, T(*o), jit(rng.choice(colors), 8), "Grass", collide=False, shadow=False)


def hanging_vine(top, length, wiggle=0.35):
    """เถาวัลย์ห้อยลง: ก้านบาง + ใบเป็นกระจุก"""
    p = np.array(top, float)
    n = max(2, int(length / 1.8))
    for k in range(n):
        q = p + (rng.uniform(-wiggle, wiggle), -length / n, rng.uniform(-wiggle, wiggle))
        seg(p, q, 0.22, C_VINE, "Grass", collide=False, shadow=False)
        for sd in (-0.42, 0.42):
            side = np.array((sd + rng.uniform(-0.15, 0.15), rng.uniform(-0.3, 0.3), rng.uniform(-0.35, 0.35)))
            ball(rng.uniform(0.6, 0.95), T(*(q + side)), jit(rng.choice(C_LEAF), 8), "Grass", collide=False, shadow=False)
        p = q
    leaf_cluster(p, 2, 0.6)


def glow_plant(p, scale=1.0):
    """พืชเรืองแสงฟ้า: ใบเฟิร์น + ก้านดอกปลายเรืองแสง"""
    x, y, z = p
    for _ in range(rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(1.4, 2.4) * scale
        wedge((0.12, h, 1.1 * scale), T(x, y + h / 2, z) @ RY(a) @ RX(rng.uniform(-0.35, 0.05)), jit(rng.choice(C_LEAF), 10), "Grass", collide=False, shadow=False)
    for _ in range(rng.randint(2, 4)):
        a, r = rng.uniform(0, math.tau), rng.uniform(0.1, 0.7) * scale
        h = rng.uniform(1.2, 2.8) * scale
        base = np.array((x + math.cos(a) * r, y, z + math.sin(a) * r))
        tip = base + (math.cos(a) * 0.4 * scale, h, math.sin(a) * 0.4 * scale)
        seg(base, tip, 0.12, (60, 120, 70), "Grass", collide=False, shadow=False)
        ball(rng.uniform(0.38, 0.6) * scale, T(*tip), rng.choice((C_CYAN, C_CYAN_SOFT)), "Neon", collide=False, shadow=False)


def bush(x, z, s=1.0):
    for _ in range(rng.randint(3, 4)):
        d = rng.uniform(3.2, 5.5) * s
        ball(d, T(x + rng.uniform(-2, 2) * s, 1 + d * 0.32, z + rng.uniform(-2, 2) * s), jit(rng.choice(C_LEAF), 10), "Grass", collide=False)


def mossy_rock(p, d):
    x, y, z = p
    ball(d, T(x, y + d * 0.18, z), jit(rng.choice(C_STONE), 8), "Slate")
    ball(d * 0.72, T(x + rng.uniform(-0.2, 0.2) * d, y + d * 0.42, z + rng.uniform(-0.2, 0.2) * d), jit(rng.choice(C_MOSS), 8), "Grass", shadow=False)


def rune_glyph(cf, size=1.0, kind=None):
    """ตัวอักษรรูนเรืองแสงบนผิวหิน (cf = จุดกลาง หันหน้า +Z ของ cf)"""
    kind = kind or rng.choice(("X", "Y", "D", "F", "I"))
    w, d = 0.2 * size, 0.06
    bars = []
    if kind == "X":
        bars = [(0, 0, 1.3, 0.7), (0, 0, 1.3, -0.7)]
    elif kind == "Y":
        bars = [(0, -0.15, 1.1, 0), (-0.25, 0.4, 0.7, 0.75), (0.25, 0.4, 0.7, -0.75)]
    elif kind == "D":
        r = 0.42
        bars = [(-r, 0, 0.62, 0.785), (r, 0, 0.62, -0.785), (-r, 0, 0.62, -0.785), (r, 0, 0.62, 0.785)]
        bars = [(-0.21, 0.21, 0.6, -0.785), (0.21, 0.21, 0.6, 0.785), (-0.21, -0.21, 0.6, 0.785), (0.21, -0.21, 0.6, -0.785)]
    elif kind == "F":
        bars = [(0, 0, 1.3, 0), (0.22, 0.32, 0.55, -1.0), (0.22, 0.0, 0.55, -1.0)]
    else:
        bars = [(0, 0, 1.3, 0), (0, 0.45, 0.6, 1.5708)]
    for bx, by, L, rot in bars:
        block((w, L * size, d), cf @ T(bx * size, by * size, 0) @ RZ(rot), C_CYAN, "Neon", collide=False, shadow=False)


def flagstones(cx, cz, radius=None, rect=None, size=(2.6, 3.6), y=1.0):
    """พื้นหินแผ่นไม่เรียบ (วงกลม หรือ สี่เหลี่ยมตามทาง)"""
    step = sum(size) / 2 + 0.35
    if radius:
        cylinder_y(0.16, radius * 2 + 3, T(cx, y + 0.05, cz), (84, 92, 88), "Cobblestone", shadow=False)
        xs = np.arange(-radius, radius + 0.01, step)
        for gx in xs:
            for gz in xs:
                if gx * gx + gz * gz > radius * radius:
                    continue
                stone(cx + gx, cz + gz, size, y)
    else:
        (x0, z0), (x1, z1), w = rect
        L = math.hypot(x1 - x0, z1 - z0)
        ux, uz = (x1 - x0) / L, (z1 - z0) / L
        block((w + 1.2, 0.16, L + 2), look_at(((x0 + x1) / 2, y + 0.05, (z0 + z1) / 2), (x1, y + 0.05, z1)), (84, 92, 88), "Cobblestone", shadow=False)
        for t in np.arange(0, L + 0.01, step):
            for o in np.arange(-w / 2 + step / 2, w / 2, step):
                stone(x0 + ux * t - uz * o, z0 + uz * t + ux * o, size, y)


def stone(x, z, size, y):
    s = rng.uniform(*size)
    sx, sz = s * rng.uniform(0.85, 1.0), s * rng.uniform(0.75, 0.95)
    jx, jz = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
    col = jit(rng.choice(C_STONE), 8)
    if rng.random() < 0.12:
        col = jit(rng.choice(C_MOSS), 6)
    block((sx, 0.32, sz), T(x + jx, y + 0.16 + rng.uniform(0, 0.05), z + jz) @ RY(rng.uniform(-0.25, 0.25)), col, "Slate", shadow=False)


# ---------------------------------------------------------------- ประตูมิติหินโบราณ
def crystal_cluster(cf, s=1.0, n=None):
    """กระจุกผลึกเรืองแสงงอกจากพื้น"""
    for _ in range(n or rng.randint(3, 5)):
        h = rng.uniform(1.0, 2.6) * s
        w = rng.uniform(0.35, 0.6) * s
        tilt = (rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45))
        c = cf @ T(rng.uniform(-0.5, 0.5) * s, 0, rng.uniform(-0.5, 0.5) * s) @ RX(tilt[0]) @ RZ(tilt[1]) @ T(0, h / 2, 0) @ RY(rng.uniform(0, 1.5))
        block((w, h, w), c, rng.choice((C_CYAN, C_CYAN_SOFT, (110, 210, 255))), "Neon", collide=False, shadow=False)
        block((w * 0.7, w * 0.7, w * 0.7), c @ T(0, h / 2, 0) @ RX(math.pi / 4) @ RZ(math.pi / 4), C_CYAN_SOFT, "Neon", collide=False, shadow=False)
    ball(1.2 * s, cf @ T(0, 0.15, 0), jit(rng.choice(C_STONE), 6), "Slate", collide=False)


def bell_flower(p, s=1.0):
    """ดอกไม้เรืองแสงก้านโค้ง (ระฆังห้อย) + ใบ"""
    x, y, z = p
    for _ in range(rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        h = rng.uniform(1.6, 3.0) * s
        base = np.array((x + rng.uniform(-0.4, 0.4), y, z + rng.uniform(-0.4, 0.4)))
        mid = base + (math.cos(a) * 0.3 * s, h * 0.7, math.sin(a) * 0.3 * s)
        tip = mid + (math.cos(a) * 0.7 * s, h * 0.3, math.sin(a) * 0.7 * s)
        seg(base, mid, 0.12 * s, (56, 116, 66), "Grass", collide=False, shadow=False)
        seg(mid, tip, 0.1 * s, (56, 116, 66), "Grass", collide=False, shadow=False)
        ball(0.62 * s, T(*(tip - (0, 0.35 * s, 0))), C_CYAN, "Neon", collide=False, shadow=False)
        ball(0.3 * s, T(*(tip - (0, 0.72 * s, 0))), (210, 250, 255), "Neon", collide=False, shadow=False)
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        wedge((0.1, 1.3 * s, 0.9 * s), T(x, y + 0.6 * s, z) @ RY(a) @ RX(-0.5) @ T(0, 0, -0.3 * s), jit(rng.choice(C_LEAF), 10), "Grass", collide=False, shadow=False)


def fern(p, s=1.0, n=8):
    x, y, z = p
    for k in range(n):
        a = k / n * math.tau + rng.uniform(-0.2, 0.2)
        L = rng.uniform(2.6, 3.8) * s
        wedge((0.12, L, 1.3 * s), T(x, y + 0.2, z) @ RY(a) @ RX(-rng.uniform(0.5, 0.9)) @ T(0, L / 2, 0), jit(rng.choice(C_LEAF), 12), "Grass", collide=False, shadow=False)


def star_flower(p, s=1.0):
    """ดอกไม้ดาวเรืองแสง (กลีบ 4 แฉก + เกสร) บนก้านสั้น"""
    x, y, z = p
    h = rng.uniform(0.6, 1.6) * s
    seg((x, y, z), (x, y + h, z), 0.1 * s, (56, 116, 66), "Grass", collide=False, shadow=False)
    c = T(x, y + h, z) @ RY(rng.uniform(0, 3)) @ RX(rng.uniform(-0.5, -0.2))
    for k in range(2):
        block((1.1 * s, 0.08, 0.32 * s), c @ RY(k * math.pi / 2 + math.pi / 4), C_CYAN, "Neon", collide=False, shadow=False)
    ball(0.34 * s, c @ T(0, 0.1, 0), (230, 252, 255), "Neon", collide=False, shadow=False)


def flower_patch(x, z, s=1.0):
    for _ in range(rng.randint(2, 4)):
        star_flower((x + rng.uniform(-1.4, 1.4) * s, 1.0, z + rng.uniform(-1.4, 1.4) * s), rng.uniform(0.8, 1.2) * s)
    for _ in range(2):
        a = rng.uniform(0, math.tau)
        wedge((0.1, 1.4 * s, 1.0 * s), T(x, 1.6, z) @ RY(a) @ RX(-0.6) @ T(0, 0, -0.3), jit(rng.choice(C_LEAF), 10), "Grass", collide=False, shadow=False)


def portal(cf, i):
    """ลานกลมเรืองแสงด้านหน้า + ประตูวงแหวนบนฐานยกสูงด้านหลัง (บันได 3 ขั้น) + เสารูนชิดซุ้ม + ตะเกียงหน้าเสา"""
    # ---- ลานกลมด้านหน้า (ขอบเรืองแสงรอบวง)
    cylinder_y(0.5, 23.2, cf @ T(0, 0.25, 0), C_STONE_D, "Cobblestone")
    for k in range(26):
        a = k / 26 * math.tau
        block((2.6, 0.6, 1.1), cf @ RY(a) @ T(0, 0.55, 11.1), jit(rng.choice(C_STONE), 6), "Slate")
    cylinder_y(0.1, 21.4, cf @ T(0, 0.62, 0), C_CYAN, "Neon", name=f"PortalRing{i}", collide=False, shadow=False)
    cylinder_y(0.12, 20.2, cf @ T(0, 0.7, 0), C_STONE_L, "Slate")
    for k, (d, col) in enumerate(((14.6, C_CYAN), (13.8, (176, 180, 168)), (6.6, C_CYAN_SOFT), (5.9, (176, 180, 168)))):
        neon = col in (C_CYAN, C_CYAN_SOFT)
        cylinder_y(0.08, d, cf @ T(0, 0.8 + k * 0.05, 0), col, "Neon" if neon else "Slate", collide=False, shadow=False)
    for k in range(12):
        a = k / 12 * math.tau
        rune_glyph(cf @ RY(a) @ T(0, 0.86, 8.6) @ RX(-math.pi / 2), 0.8)
    for k in range(8):
        block((0.22, 0.05, 2.6), cf @ T(0, 1.06, 0) @ RY(k / 8 * math.pi), C_CYAN, "Neon", collide=False, shadow=False)
    block((4, 0.05, 4), cf @ T(0, 1.1, 0), (0, 0, 0), tr=1, name=f"PortalCenter{i}", collide=False, shadow=False)
    # ---- ฐานยกด้านหลัง + บันได
    dz = -14.5
    dais_h = 2.6
    block((26, dais_h, 9), cf @ T(0, dais_h / 2, dz), C_STONE_D, "Slate")
    block((26.6, 0.5, 9.6), cf @ T(0, dais_h + 0.25, dz), C_STONE_L, "Slate")
    for k in range(6):
        block((0.2, dais_h - 0.4, 0.1), cf @ T(-11 + k * 4.4, dais_h / 2, dz + 4.52), C_CYAN, "Neon", collide=False, shadow=False)
    for k in range(3):
        sh = dais_h * (k + 1) / 3.2
        block((11 - k * 0.8, sh, 1.6), cf @ T(0, sh / 2, dz + 4.5 + 1.6 * (2 - k) + 0.8), jit(C_STONE_L if k % 2 else rng.choice(C_STONE), 4), "Slate")
        block((10 - k * 0.8, 0.06, 0.2), cf @ T(0, sh + 0.03, dz + 4.5 + 1.6 * (2 - k) + 1.5), C_CYAN, "Neon", collide=False, shadow=False)
    base_y = dais_h + 0.5
    # ---- ซุ้มวงแหวน
    R, cz = 8.0, dz
    cy = base_y + R + 0.4
    N = 32
    for k in range(N):
        th = k / N * math.tau + math.pi / N
        deg = math.degrees(th) % 360
        if 245 < deg < 295:
            continue
        rot = RZ(th - math.pi / 2)
        segw = math.tau * (R + 1.3) / N * 1.04
        c = cf @ T(math.cos(th) * R, cy + math.sin(th) * R, cz) @ rot
        block((segw, 2.6, 2.6), c, jit(rng.choice(C_STONE), 6), "Slate")
        block((segw * 0.78, 1.7, 0.12), c @ T(0, 0.1, 1.33), jit(C_STONE_L, 6), "Slate", shadow=False)
        co = cf @ T(math.cos(th) * (R + 1.85), cy + math.sin(th) * (R + 1.85), cz - 0.5) @ rot
        block((math.tau * (R + 2.4) / N * 1.05, 1.1, 1.6), co, jit(C_STONE_D, 5), "Slate")
        ci = cf @ T(math.cos(th) * (R - 1.7), cy + math.sin(th) * (R - 1.7), cz + 0.3) @ rot
        block((math.tau * (R - 1.2) / N * 1.05, 0.9, 2.2), ci, jit((150, 154, 144), 5), "Slate")
        block((0.5, 0.16, 0.06), ci @ T(0, 0, 1.12), C_CYAN, "Neon", collide=False, shadow=False)
        rim = cf @ T(math.cos(th) * (R - 2.25), cy + math.sin(th) * (R - 2.25), cz + 0.3) @ rot
        block((math.tau * (R - 2.25) / N * 1.05, 0.2, 1.8), rim, C_CYAN, "Neon", collide=False, shadow=False)
        if k % 3 == 0:
            rune_glyph(c @ T(0, 0.1, 1.42), 0.55)
    for sx in (-1, 1):
        bx = sx * 4.6
        block((4.0, 2.6, 3.8), cf @ T(bx, base_y + 1.3, cz), jit(rng.choice(C_STONE), 4), "Slate")
        block((2.8, 1.8, 0.1), cf @ T(bx, base_y + 1.3, cz + 1.92), C_STONE_L, "Slate", shadow=False)
        rune_glyph(cf @ T(bx, base_y + 1.3, cz + 2.0), 0.9)
        block((4.4, 0.6, 4.2), cf @ T(bx, base_y + 2.9, cz), C_STONE_L, "Slate")
    # หินยอดทรงหกเหลี่ยมแหลม + ตาเรืองแสง
    kc = cf @ T(0, cy + R + 0.9, cz + 0.3)
    block((3.6, 3.4, 3.2), kc @ T(0, 0.5, 0), C_STONE_L, "Slate")
    block((2.55, 2.55, 3.2), kc @ T(0, -1.2, 0) @ RZ(math.pi / 4), C_STONE_L, "Slate")
    block((2.55, 2.55, 3.2), kc @ T(0, 2.2, 0) @ RZ(math.pi / 4), C_STONE_L, "Slate")
    for k in range(6):
        ang = k / 6 * math.tau + math.pi / 2
        block((0.2, 1.05, 0.08), kc @ T(math.cos(ang) * 0.95, 0.5 + math.sin(ang) * 0.95, 1.63) @ RZ(ang), C_CYAN, "Neon", collide=False, shadow=False)
    ball(0.7, kc @ T(0, 0.5, 1.55), C_CYAN_SOFT, "Neon", collide=False, shadow=False)
    block((0.16, 1.1, 0.09), kc @ T(0, 2.2, 1.62), C_CYAN, "Neon", collide=False, shadow=False)
    block((0.16, 1.1, 0.09), kc @ T(0, -1.2, 1.62), C_CYAN, "Neon", collide=False, shadow=False)
    # ---- ม่านประตู
    vc = cf @ T(0, cy, cz)
    cylinder_z(0.2, 13.0, vc, (30, 190, 255), "Neon", tr=0.2, name=f"PortalVeil{i}", collide=False, shadow=False)
    for k, (d, col, t) in enumerate(((11.2, (60, 210, 255), 0.55), (9.0, (100, 225, 255), 0.4), (6.6, (120, 232, 255), 0.5), (3.6, (170, 242, 255), 0.55))):
        cylinder_z(0.15, d, vc @ T(0, 0, 0.12 + k * 0.08), col, "Neon", tr=t, collide=False, shadow=False)
    for _ in range(10):
        a, r = rng.uniform(0, math.tau), rng.uniform(1.5, 5.8)
        ball(rng.uniform(0.2, 0.45), vc @ T(math.cos(a) * r, math.sin(a) * r, 0.6), (235, 252, 255), "Neon", collide=False, shadow=False)
    # ---- เสารูนชิดซุ้ม (ยืนบนฐานยก) + ตะเกียงเตี้ยหน้าเสา
    for side, tag in ((-1, "L"), (1, "R")):
        pc = cf @ T(side * 11.6, base_y, cz + 0.6)
        block((3.8, 1.0, 3.8), pc @ T(0, 0.5, 0), C_STONE_D, "Slate")
        block((3.2, 0.8, 3.2), pc @ T(0, 1.4, 0), jit(rng.choice(C_STONE), 4), "Slate")
        block((2.5, 12.4, 2.5), pc @ T(0, 8.0, 0), jit(rng.choice(C_STONE), 4), "Slate")
        for cx_, cz_ in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            block((0.42, 12.4, 0.42), pc @ T(cx_ * 1.22, 8.0, cz_ * 1.22), jit(C_STONE_D, 4), "Slate")
        block((1.9, 11.0, 0.1), pc @ T(0, 8.0, 1.27), C_STONE_L, "Slate", shadow=False)
        for gy, kind in ((3.6, "Y"), (6.2, "X"), (8.8, "D"), (11.4, rng.choice(("F", "Y")))):
            rune_glyph(pc @ T(0, gy, 1.34), 0.95, kind)
        block((3.3, 0.6, 3.3), pc @ T(0, 14.5, 0), C_STONE_L, "Slate")
        block((3.8, 0.7, 3.8), pc @ T(0, 15.15, 0), jit(rng.choice(C_STONE), 4), "Slate")
        block((3.5, 0.4, 3.5), pc @ T(0, 15.6, 0), jit(rng.choice(C_MOSS), 6), "Grass", shadow=False)
        crystal_cluster(pc @ T(0, 15.6, 0), 0.75, 3)
        for _ in range(4):
            fy = rng.uniform(2.5, 13)
            fs = rng.choice(((1.27, 0), (-1.27, 0), (0, -1.27)))
            block((0.08 if fs[0] else rng.uniform(0.8, 1.8), rng.uniform(0.8, 2.2), rng.uniform(0.8, 1.8) if fs[0] else 0.08), pc @ T(fs[0], fy, fs[1]), jit(rng.choice(C_MOSS), 6), "Grass", collide=False, shadow=False)
        hanging_vine(pos_of(pc @ T(side * 1.4, 15.0, 1.2)), rng.uniform(8, 12))
        leaf_cluster(pos_of(pc @ T(side * 0.8, 16.0, 0.6)), 4, 1.2)
        # ตะเกียงหน้าเสา (บนพื้น ข้างบันได)
        lc = cf @ T(side * 9.2, 0, dz + 6.4)
        block((1.8, 1.6, 1.8), lc @ T(0, 0.8, 0), C_STONE_D, "Slate")
        block((1.2, 0.3, 1.2), lc @ T(0, 1.75, 0), C_STONE_L, "Slate")
        block((0.9, 1.1, 0.9), lc @ T(0, 2.45, 0), C_CYAN, "Neon", name=f"PortalBrazier{i}{tag}", collide=False, shadow=False)
        for cx_, cz_ in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            block((0.18, 1.4, 0.18), lc @ T(cx_ * 0.55, 2.5, cz_ * 0.55), (70, 74, 72), "Slate", collide=False)
        block((1.4, 0.3, 1.4), lc @ T(0, 3.3, 0), (80, 84, 82), "Slate")
        block((0.7, 0.4, 0.7), lc @ T(0, 3.6, 0) @ RY(math.pi / 4), (80, 84, 82), "Slate")
    # ---- เถาวัลย์หนาคลุมซุ้ม + ดอกดาวเรืองแสง
    for k in range(30):
        th = math.radians(4 + k / 29 * 172 + rng.uniform(-3, 3))
        r = R + rng.uniform(1.3, 2.7)
        p = pos_of(cf @ T(math.cos(th) * r, cy + math.sin(th) * r, cz + rng.uniform(-1.4, 1.8)))
        leaf_cluster(p, 3, 1.2)
        if rng.random() < 0.5:
            c = T(*(p + (0, 0.3, 1.1))) @ RX(-1.2) @ RY(rng.uniform(0, 3))
            for kk in range(2):
                block((1.0, 0.08, 0.3), c @ RY(kk * math.pi / 2 + math.pi / 4), C_CYAN, "Neon", collide=False, shadow=False)
            ball(0.3, c, (230, 252, 255), "Neon", collide=False, shadow=False)
    for th_deg in (6, 16, 164, 174):
        th = math.radians(th_deg)
        p = pos_of(cf @ T(math.cos(th) * (R + 1.8), cy + math.sin(th) * (R + 1.8), cz + 1.4))
        hanging_vine(p, rng.uniform(7, 11))
    # ---- พืชพรรณหนาแน่นรอบซุ้ม/ลาน
    for side in (-1, 1):
        fern(pos_of(cf @ T(side * 13.4, 0.8, dz + 7.5)), 1.2)
        fern(pos_of(cf @ T(side * 17.5, 0.8, -4)), 1.3)
        mossy_rock(pos_of(cf @ T(side * 14.5, 0, -8.5)), rng.uniform(2.6, 3.6))
        crystal_cluster(cf @ T(side * 13.2, 0, -1.5), 1.1)
    for _ in range(9):
        a = rng.uniform(-math.pi * 0.95, math.pi * 0.95) + math.pi / 2
        r = rng.uniform(12.6, 15.5)
        x, z = math.cos(a) * r, math.sin(a) * r
        if z > 7 and abs(x) < 6:
            continue
        if z < -9:
            continue
        rr = rng.random()
        pp = pos_of(cf @ T(x, 0, z))
        if rr < 0.4:
            flower_patch(pp[0], pp[2], rng.uniform(0.9, 1.2))
        elif rr < 0.7:
            bell_flower(pp, rng.uniform(0.9, 1.2))
        else:
            fern(pp + (0, 0.8, 0), rng.uniform(0.9, 1.2))


# ---------------------------------------------------------------- ต้นไม้ป่าดิบ
def jungle_tree(x, z, s=1.0):
    h = rng.uniform(26, 38) * s
    d = rng.uniform(2.6, 3.6) * s
    lean = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06))
    base = np.array((x, 1.0, z))
    topp = base + (lean[0] * h, h, lean[1] * h)
    seg(base, topp, d, jit(rng.choice(C_BARK), 6), "Wood")
    for k in range(4):  # รากค้ำ
        a = k / 4 * math.tau + rng.uniform(-0.3, 0.3)
        wedge((0.9 * s, 4.5 * s, 3.2 * s), T(x + math.cos(a) * d * 0.9, 1 + 2.25 * s, z + math.sin(a) * d * 0.9) @ RY(-a + math.pi / 2), jit(rng.choice(C_BARK), 6), "Wood")
    for _ in range(rng.randint(4, 6)):
        o = topp + (rng.uniform(-7, 7) * s, rng.uniform(-3, 3) * s, rng.uniform(-7, 7) * s)
        ball(rng.uniform(11, 17) * s, T(*o), jit(rng.choice(C_LEAF), 8), "Grass", shadow=True, collide=False)
    for _ in range(rng.randint(0, 1)):
        o = topp + (rng.uniform(-6, 6) * s, -4 * s, rng.uniform(-6, 6) * s)
        hanging_vine(o, rng.uniform(6, 12) * s, 0.4)


def palm_fern(x, z, s=1.0):
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.2, 0.2)
        wedge((0.15, 3.6 * s, 2.0 * s), T(x, 1 + 1.4 * s, z) @ RY(a) @ RX(-0.55) @ T(0, 0, -0.6 * s), jit(rng.choice(C_LEAF), 10), "Grass", collide=False, shadow=False)


# ---------------------------------------------------------------- ซากหิน
def ruin_wall(a, b, h=6.0):
    a, b = np.array(a, float), np.array(b, float)
    L = np.linalg.norm(b - a)
    n = max(1, int(L / 4.2))
    d = (b - a) / n
    for k in range(n):
        p = a + d * (k + 0.5)
        hh = h * rng.uniform(0.45, 1.0)
        if rng.random() < 0.2:
            continue  # ช่องพัง
        cf = look_at((p[0], 1 + hh / 2, p[1]), (p[0] + d[0], 1 + hh / 2, p[1] + d[1]))
        block((2.6, hh, np.linalg.norm(d) * 1.02), cf, jit(rng.choice(C_STONE), 6), "Slate")
        block((2.9, 0.5, np.linalg.norm(d) * 0.9), cf @ T(0, hh / 2 + 0.2, rng.uniform(-0.3, 0.3)), jit(rng.choice(C_MOSS), 6), "Grass", shadow=False)
        if rng.random() < 0.2:
            rune_glyph(cf @ T(1.32, rng.uniform(-0.5, 0.8), 0) @ RY(math.pi / 2), 0.9)
        if rng.random() < 0.1:
            hanging_vine((p[0] + rng.uniform(-0.8, 0.8), 1 + hh + 0.3, p[1]), rng.uniform(2, hh * 0.8))


def broken_pillar(x, z, h=None):
    h = h or rng.uniform(5, 11)
    block((3.4, 1.0, 3.4), T(x, 1.5, z), C_STONE_D, "Slate")
    cylinder_y(h, 2.6, T(x, 2 + h / 2, z) @ RY(rng.uniform(0, 3)), jit(rng.choice(C_STONE), 6), "Slate")
    ball(2.6, T(x, 2 + h, z), jit(rng.choice(C_MOSS), 6), "Grass", shadow=False)
    if rng.random() < 0.6:
        rune_glyph(T(x, 2 + h * 0.55, z) @ RY(rng.uniform(0, math.tau)) @ T(0, 0, 1.32), 0.9)


def fallen_column(x, z, a):
    for k in range(3):
        cylinder_y(2.6, 2.5, T(x, 1 + 1.2, z) @ RY(a) @ T(0, 0, k * 2.9) @ RX(math.pi / 2 + rng.uniform(-0.1, 0.1)), jit(rng.choice(C_STONE), 6), "Slate")
    leaf_cluster((x, 2.6, z), 3, 1.2)


def crystal_lamp(x, z, h=6.5):
    block((1.6, 1.0, 1.6), T(x, 1.5, z), C_STONE_D, "Slate")
    block((1.0, h, 1.0), T(x, 2 + h / 2, z), jit(rng.choice(C_STONE), 6), "Slate")
    block((1.6, 0.5, 1.6), T(x, 2 + h + 0.25, z), C_STONE_L, "Slate")
    block((0.9, 1.9, 0.9), T(x, 2 + h + 1.4, z) @ RY(0.6) @ RX(0.2), C_CYAN, "Neon", name="CrystalLamp", collide=False, shadow=False)
    block((0.5, 1.2, 0.5), T(x + 0.5, 2 + h + 1.0, z - 0.3) @ RZ(0.5), C_CYAN_SOFT, "Neon", collide=False, shadow=False)
    leaf_cluster((x, 2 + h + 0.4, z), 2, 0.7)


def entrance_gate(z):
    for sx in (-1, 1):
        x = sx * 13
        block((5.0, 2.0, 5.0), T(x, 2.0, z), C_STONE_D, "Slate")
        block((3.6, 17, 3.6), T(x, 11.5, z), jit(rng.choice(C_STONE), 4), "Slate")
        block((4.6, 1.2, 4.6), T(x, 20.6, z), C_STONE_L, "Slate")
        for gy in (6.0, 9.5, 13.0):
            rune_glyph(T(x, gy, z + 1.84), 1.2)
            rune_glyph(T(x, gy, z - 1.84) @ RY(math.pi), 1.2)
        hanging_vine((x + sx * 1.6, 20.0, z + 1.6), rng.uniform(6, 10))
        leaf_cluster((x, 21.6, z), 4, 1.4)
    block((32, 2.4, 4.2), T(0, 22.4, z), C_STONE_L, "Slate")
    block((33, 0.7, 4.6), T(0, 23.9, z), jit(rng.choice(C_MOSS), 4), "Grass", shadow=False)
    block((20, 3.6, 0.5), T(0, 18.4, z + 0.4), (70, 78, 74), "Slate", name="CampSign")
    for k in range(10):
        hanging_vine((rng.uniform(-14, 14), 21.1, z + rng.choice((-2.2, 2.2))), rng.uniform(2, 5.5))
    for k in range(8):
        leaf_cluster((rng.uniform(-15, 15), 24.4, z + rng.uniform(-1.5, 1.5)), 3, 1.3)


def cliff_with_falls(x0, x1, z, height, falls):
    x = x0
    while x < x1:
        w = rng.uniform(14, 24)
        h = height * rng.uniform(0.75, 1.15)
        dz = rng.uniform(-6, 6)
        block((w, h, rng.uniform(16, 26)), T(x + w / 2, 1 + h / 2 - 2, z + dz) @ RY(rng.uniform(-0.15, 0.15)), jit(rng.choice(((84, 94, 88), (74, 84, 80), (92, 100, 92))), 8), "Rock")
        for _ in range(3):
            block((w * rng.uniform(0.3, 0.6), rng.uniform(4, 10), 1.0), T(x + rng.uniform(0.2, 0.8) * w, 1 + rng.uniform(0.3, 0.8) * h, z + dz + 8.5), jit(rng.choice(C_MOSS), 8), "Grass", collide=False, shadow=False)
        block((w * 0.95, 2.2, 14), T(x + w / 2, 1 + h - 1.5, z + dz + 2), jit(rng.choice(C_MOSS), 8), "Grass", shadow=False)
        for _ in range(2):
            ball(rng.uniform(9, 14), T(x + rng.uniform(0, w), 1 + h + rng.uniform(1, 4), z + dz + rng.uniform(-4, 6)), jit(rng.choice(C_LEAF), 8), "Grass", collide=False)
        x += w * 0.85
    for fx in falls:
        h = height * 0.95
        fz = z + 12.5
        block((7.5, h, 1.2), T(fx, 1 + h / 2, fz), C_WATER, "Glass", tr=0.25, collide=False, shadow=False)
        block((5.0, h, 1.0), T(fx, 1 + h / 2, fz + 0.4), (225, 245, 255), "Neon", tr=0.55, collide=False, shadow=False)
        cylinder_y(0.6, 22, T(fx, 1.1, fz + 6), (90, 170, 210), "Glass", tr=0.3, collide=False, shadow=False)
        block((6, 1, 3), T(fx, 1.6, fz + 1.5), (240, 250, 255), "Neon", tr=0.4, name="WaterfallFoam", collide=False, shadow=False)
        for _ in range(6):
            a = rng.uniform(0, math.tau)
            mossy_rock((fx + math.cos(a) * 11.5, 1.0, fz + 6 + math.sin(a) * 11.5), rng.uniform(2, 3.5))


# ---------------------------------------------------------------- ผังทั้งหมด
def build():
    """ฉากหิน/ประตู/น้ำตก/แสงเรืองแสง · พื้นหญ้า+ทางหิน (Terrain) และต้นไม้/พุ่มไม้ (โมเดลเมช) ใส่ใน LobbyService"""
    block((1, 1, 1), T(0, 0, 0), (0, 0, 0), tr=1, name="Origin", collide=False, shadow=False)
    gx, gz = GROVE
    for i, a in enumerate(PORTAL_ANGLES, 1):
        px, pz = gx + math.cos(math.radians(a)) * GROVE_R, gz + math.sin(math.radians(a)) * GROVE_R
        cf = look_at((px, 1.0, pz), (px + (px - gx), 1.0, pz + (pz - gz)))
        portal(cf, i)
    # ดอกไม้/พืชเรืองแสงแซมระหว่างทางไปแต่ละประตู
    for ad in (-80, -40, 0, 40, 80):
        for r in (24, 34, 42):
            b = math.radians(ad + rng.uniform(-6, 6))
            x, z = gx + math.cos(b) * r, gz + math.sin(b) * r
            flower_patch(x, z, rng.uniform(1.0, 1.3)) if rng.random() < 0.6 else glow_plant((x, 1.0, z), rng.uniform(1.0, 1.4))
    # ป้ายหินกลางลาน + โคมคริสตัลรอบลาน
    block((5.6, 3.2, 1.0), T(gx - 6, 3.2, gz) @ RY(math.pi / 2), (86, 94, 90), "Slate", name="GroveSign")
    block((6.4, 1.2, 1.8), T(gx - 6, 1.6, gz) @ RY(math.pi / 2), C_STONE_D, "Slate")
    for k in (1, 2, 4, 5):
        a = k / 6 * math.tau
        crystal_lamp(gx + math.cos(a) * 20.5, gz + math.sin(a) * 20.5, 5.5)
    entrance_gate(FZ1)
    for x, z in ((12, -26), (-12, -26)):  # เสาไฟแค่หน้าร้านคลาส (หน้าแท่น = 4 ต้นรอบลานประตูด้านบน)
        crystal_lamp(x, z)
    ruin_wall((-FX, FZ0), (FX, FZ0))
    ruin_wall((FX, FZ0), (FX, FZ1))
    ruin_wall((-FX, FZ1), (-FX, FZ0))
    ruin_wall((FX, FZ1), (16, FZ1))
    ruin_wall((-16, FZ1), (-FX, FZ1))
    for x, z in ((-104, -96), (104, -92), (-60, -98), (40, -100), (-108, 20), (110, 80), (-20, -96), (96, 92)):
        broken_pillar(x, z)
    fallen_column(-70, -60, 0.6)
    fallen_column(20, 96, 1.8)
    fallen_column(-104, 64, 2.6)
    cliff_with_falls(-170, 170, FZ0 - 52, 54, (-46, 58))
    cliff_with_falls(140, 230, -10, 46, ())
    # จุดเรืองแสงประปรายทั่วค่าย (ดอกดาว/ก้านเรืองแสง)
    placed = 0
    while placed < 50:
        x, z = rng.uniform(-FX + 6, FX - 6), rng.uniform(FZ0 + 6, FZ1 - 6)
        if abs(x) < 12 or abs(z - 44) < 9 or math.hypot(x - gx, z - gz) < GROVE_R + 18 or (abs(x) < 32 and -86 < z < -18) or math.hypot(x, z - 88) < 18:
            continue
        placed += 1
        flower_patch(x, z, rng.uniform(0.9, 1.3)) if rng.random() < 0.6 else glow_plant((x, 1.0, z), rng.uniform(0.9, 1.3))
    return parts


# ---------------------------------------------------------------- เขียน .rbxmx
def write_rbxmx(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">']
    out.append('<Item class="Model" referent="RBX0"><Properties><string name="Name">LobbyRuins</string><Ref name="PrimaryPart">RBX1</Ref></Properties>')
    for n, p in enumerate(parts, 1):
        cls = "WedgePart" if p["shape"] == "Wedge" else "Part"
        m = p["cf"]
        r, g, b = p["color"]
        col = (0xFF << 24) | (r << 16) | (g << 8) | b
        f = lambda v: f"{v:.3f}".rstrip("0").rstrip(".") if abs(v) > 1e-6 else "0"  # noqa: E731
        cfx = (f'<CoordinateFrame name="CFrame"><X>{f(m[0,3])}</X><Y>{f(m[1,3])}</Y><Z>{f(m[2,3])}</Z>'
               f'<R00>{f(m[0,0])}</R00><R01>{f(m[0,1])}</R01><R02>{f(m[0,2])}</R02>'
               f'<R10>{f(m[1,0])}</R10><R11>{f(m[1,1])}</R11><R12>{f(m[1,2])}</R12>'
               f'<R20>{f(m[2,0])}</R20><R21>{f(m[2,1])}</R21><R22>{f(m[2,2])}</R22></CoordinateFrame>')
        sx, sy, sz = p["size"]
        shape = "" if cls == "WedgePart" else f'<token name="shape">{ {"Ball": 0, "Block": 1, "Cylinder": 2}[p["shape"]] }</token>'
        out.append(
            f'<Item class="{cls}" referent="RBX{n}"><Properties><string name="Name">{p["name"] or p["shape"]}</string>'
            f'<bool name="Anchored">true</bool>{cfx}<Vector3 name="size"><X>{f(sx)}</X><Y>{f(sy)}</Y><Z>{f(sz)}</Z></Vector3>'
            f'<Color3uint8 name="Color3uint8">{col}</Color3uint8><token name="Material">{MAT[p["mat"]]}</token>'
            f'<float name="Transparency">{p["tr"]}</float><bool name="CanCollide">{str(p["collide"]).lower()}</bool>'
            f'<bool name="CanQuery">{str(p["collide"]).lower()}</bool><bool name="CanTouch">false</bool>'
            f'<bool name="CastShadow">{str(p["shadow"]).lower()}</bool>{shape}'
            '<token name="TopSurface">0</token><token name="BottomSurface">0</token></Properties></Item>'
        )
    out.append("</Item></roblox>")
    open(path, "w", encoding="utf-8").write("\n".join(out))


# ---------------------------------------------------------------- ภาพตัวอย่าง (Blender)
def preview(path, view, spp):
    import bpy  # noqa: I001 (bpy ต้องมาก่อน bmesh)
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
        b.inputs["Roughness"].default_value = 0.85 if matname not in ("Glass", "Neon") else 0.2
        if matname == "Neon":
            b.inputs["Emission Color"].default_value = (*lin, 1)
            b.inputs["Emission Strength"].default_value = 2.2
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
        elif shape == "Cylinder":  # แกน X (แบบ Roblox)
            bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1.0,
                                  matrix=mathutils.Matrix.Rotation(math.pi / 2, 4, "Y"))
        else:  # Wedge: สูงเต็มด้านหลัง (+Z) ลาดลงไปด้านหน้า (-Z)
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

    # Roblox (x, y, z) -> Blender (x, -z, y)
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

    # พื้นล็อบบี้ (เหมือน LobbyService)
    place("Cylinder", (1, 556, 556), T(0, 0.5, 0) @ RZ(math.pi / 2), (72, 138, 60), "Grass", 0)
    
    for p in parts:
        if p["tr"] >= 1:
            continue
        place(p["shape"], p["size"], p["cf"], p["color"], p["mat"], p["tr"])

    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    sky = world.node_tree.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(38)
    sky.sun_rotation = math.radians(150)
    world.node_tree.links.new(sky.outputs["Color"], world.node_tree.nodes["Background"].inputs["Color"])
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.0
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(52), 0, math.radians(150))
    coll.objects.link(so)

    gx, gz = GROVE
    a = math.radians(PORTAL_ANGLES[1])
    ppx, ppz = gx + math.cos(a) * GROVE_R, gz + math.sin(a) * GROVE_R
    views = {
        "portal": ((gx + math.cos(a) * (GROVE_R - 34), 7.5, gz + math.sin(a) * (GROVE_R - 34)), (gx + math.cos(a) * (GROVE_R + 14), 9.5, gz + math.sin(a) * (GROVE_R + 14)), 55),
        "grove": ((gx - 40, 34, gz + 22), (gx + 10, 4, gz), 55),
        "overview": ((-120, 110, 160), (20, 0, -10), 55),
    }
    cpos, ctgt, fov = views[view]
    camd = bpy.data.cameras.new("cam")
    camd.angle = math.radians(fov)
    camd.clip_end = 3000
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
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.2
    scene.use_nodes = True
    cn = scene.node_tree
    cn.nodes.clear()
    rl = cn.nodes.new("CompositorNodeRLayers")
    gl = cn.nodes.new("CompositorNodeGlare")
    gl.glare_type = "FOG_GLOW"
    gl.quality = "MEDIUM"
    gl.threshold = 1.5
    gl.size = 7
    co = cn.nodes.new("CompositorNodeComposite")
    cn.links.new(rl.outputs["Image"], gl.inputs["Image"])
    cn.links.new(gl.outputs["Image"], co.inputs["Image"])
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", path)


if __name__ == "__main__":
    build()
    if "--preview" in sys.argv:
        k = sys.argv.index("--preview")
        out, view = sys.argv[k + 1], sys.argv[k + 2]
        spp = int(sys.argv[k + 3]) if len(sys.argv) > k + 3 else 24
        preview(out, view, spp)
    else:
        write_rbxmx(OUT)
        print(f"LobbyRuins: {len(parts)} parts -> {os.path.relpath(OUT, ROOT)}")
