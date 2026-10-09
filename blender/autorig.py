"""
autorig.py — โมเดลนิ่ง (ไม่มีกระดูก) -> ใส่โครงกระดูกอัตโนมัติ + สร้างท่าเดิน/วิ่ง/โจมตี/ตาย/บิน ด้วยสูตร -> AnimRigs/<Id>
ใช้ข้อมูลรูปแบบเดียวกับ rigged_export (RigPlayer ในเกมเล่นได้ทันที)

ชนิดโครง (kind):
  quad    สี่ขา: ลำตัว, คอ+หัว, หาง 3 ท่อน, ขา 4 ข้าง (ต้นขา+แข้ง)
  winged  สี่ขา + ปีก 2 ข้าง (มังกร/กริฟฟิน)
  serpent ลำตัวยาว แบ่ง N ท่อนตามความยาว (งู/มังกรจีน/สัตว์น้ำ) + หัว
กระดูกทุกท่อนวางแนวเดียวกับแกนโมเดล (rest = เลื่อนอย่างเดียว) -> ท่าหมุนรอบแกน X/Y/Z ของโลกตรงๆ
พิกัดเกม (Roblox): X ขวา, Y ขึ้น, หัวไป -Z
"""
import base64
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import mesh_export
import rigged_export as rx

importlib.reload(mesh_export)
importlib.reload(rx)

OUT = rx.OUT
TAU = math.pi * 2


def rb(v):
    """Blender (หลังจัดแนว: หัว -Y, ขึ้น +Z) -> Roblox"""
    return Vector((-v.x, v.z, v.y))


def qaxis(axis, ang):
    """quaternion รอบแกน (พิกัด Roblox)"""
    return Quaternion(Vector(axis).normalized(), ang)


# ---------------------------------------------------------------- โหลด + จัดแนว
def load_static(src, yaw=0.0, size=("length", 6.0), drop=None, keep_only=None, keep_axis=False):
    rx.reset()
    rx.load(src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if drop:
        meshes = [o for o in meshes if not any(d.lower() in o.name.lower() for d in drop)]
    if keep_only:
        meshes = [o for o in meshes if any(d.lower() in o.name.lower() for d in keep_only)]
    dg = bpy.context.evaluated_depsgraph_get()
    bm_all = bmesh.new()
    mats = []
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        tmp = me.copy()
        tmp.transform(o.matrix_world)
        off = len(mats)
        for m in tmp.materials:
            mats.append(m)
        for p in tmp.polygons:
            p.material_index += off
        bm_all.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        ev.to_mesh_clear()
    me = bpy.data.meshes.new("SRC")
    bm_all.to_mesh(me)
    bm_all.free()
    for m in mats:
        me.materials.append(m)
    # ด้านยาวสุดแนวราบ -> แกน Y, หัว -Y (+yaw ปรับเอง)
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    me.transform(Matrix.Translation(Vector((-c.x, -c.y, -mn.z))))
    if (mx.x - mn.x) > (mx.y - mn.y) and not keep_axis:
        me.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
    me.transform(Matrix.Rotation(yaw, 4, "Z"))
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mode, val = size
    s = val / ((mx.y - mn.y) if mode == "length" else (mx.z - mn.z))
    me.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))))
    me.transform(Matrix.Scale(s, 4))
    me.update()
    ob = bpy.data.objects.new("SRC", me)
    bpy.context.scene.collection.objects.link(ob)
    for o in meshes:
        o.hide_render = True
    return ob


def bounds(me):
    pts = [v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def face_center(me, p):
    return sum((me.vertices[i].co for i in p.vertices), Vector()) / len(p.vertices)


# ---------------------------------------------------------------- สร้างโครง
class Rig:
    def __init__(self):
        self.bones = []  # {name, parent(index 0=root of model), pos(Blender), faces:set}
        self.index = {}

    def add(self, name, parent, pos):
        self.bones.append({"name": name, "parent": self.index.get(parent, 0), "pos": Vector(pos), "faces": []})
        self.index[name] = len(self.bones)
        return len(self.bones)

    def i(self, name):
        return self.index.get(name)


def build_quad(ob, cfg):
    me = ob.data
    mn, mx = bounds(me)
    L, H = mx.y - mn.y, mx.z
    legTop = cfg.get("leg_top", 0.45) * H
    neckY = mn.y + cfg.get("neck", 0.26) * L  # ด้านหน้าของเส้นนี้ = คอ/หัว
    tailY = mn.y + cfg.get("tail", 0.82) * L
    centers = [(p.index, face_center(me, p)) for p in me.polygons]
    # หาเท้า: จุดต่ำ (< 12% ความสูง) แบ่ง 4 กลุ่ม
    low = [c for _, c in centers if c.z < max(legTop * 0.35, H * 0.08)]
    legX0 = cfg.get("leg_inner", 0.0) * L
    if legX0 > 0:  # หาง/ท้องแนบพื้น -> ไม่นับเป็นเท้า
        low = [c for c in low if abs(c.x) > legX0 * 1.5 and c.y < tailY] or low
    ys = sorted(c.y for c in low) or [(mn.y + mx.y) / 2]
    midY = (ys[0] + ys[-1]) / 2 + cfg.get("leg_split", 0.0) * L  # กึ่งกลางระหว่างเท้าหน้า-หลัง (ไม่ใช้ความยาวตัวที่รวมเขา/หาง)
    feet = {}
    for key, fx, fy in (("FL", 1, -1), ("FR", -1, -1), ("BL", 1, 1), ("BR", -1, 1)):
        # Blender: x>0 = ซ้ายของสัตว์ที่หันหน้า -Y? หัวไป -Y -> ขวาของสัตว์ = -X ... ใช้ชื่อตามตำแหน่งพอ
        grp = [c for c in low if (c.x * fx >= 0) and ((c.y - midY) * fy >= 0)]
        if not grp:
            grp = [Vector((fx * 0.2 * L, midY + fy * 0.25 * L, 0))]
        feet[key] = sum(grp, Vector()) / len(grp)
    legR = cfg.get("leg_radius", 0.14) * L
    # หัวต้องไม่กินคอลัมน์ขาหน้า
    frontY = min(feet["FL"].y, feet["FR"].y)
    neckY = min(neckY, frontY - legR * 0.6)
    if 0: print("[autorig dbg] L=%.2f H=%.2f mnY=%.2f neckY=%.2f legTop=%.2f nlow=%d feet=%s" % (L, H, mn.y, neckY, legTop, len(low), {k: (round(v.x, 2), round(v.y, 2), round(v.z, 2)) for k, v in feet.items()}))
    rig = Rig()
    body = rig.add("Body", None, ((0), (mn.y + mx.y) / 2, legTop + (H - legTop) * 0.35))
    # คอ+หัว
    headTopZ = max((c.z for _, c in centers if c.y < neckY), default=H)
    neckZ = legTop + (headTopZ - legTop) * 0.45
    rig.add("Head", "Body", (0, neckY, neckZ))
    # หาง
    tails = []
    if cfg.get("tail_bones", 2) > 0:
        n = cfg.get("tail_bones", 2)
        prev = "Body"
        for k in range(n):
            ty = tailY + (mx.y - tailY) * k / n
            tz = max((c.z for _, c in centers if abs(c.y - ty) < L * 0.05), default=legTop) * 0.85
            name = "Tail%d" % (k + 1)
            rig.add(name, prev, (0, ty, tz))
            tails.append((name, ty))
            prev = name
    # ขา
    kneeZ = legTop * cfg.get("knee", 0.5)
    for key, f in feet.items():
        rig.add("Up" + key, "Body", (f.x, f.y, legTop))
        rig.add("Lo" + key, "Up" + key, (f.x, f.y, kneeZ))
    # ปีก
    if cfg.get("wings"):
        wx = cfg["wings"].get("root_x", 0.12) * L
        wy = mn.y + cfg["wings"].get("root_y", 0.4) * L
        wz = H * cfg["wings"].get("root_z", 0.7)
        rig.add("WingL", "Body", (wx, wy, wz))
        rig.add("WingR", "Body", (-wx, wy, wz))
    # ความสูงหลัง (ส่วนท้ายลำตัว) — อะไรที่อยู่สูงกว่านี้ครึ่งหน้า = เขา/หัว
    backTop = max((c.z for _, c in centers if midY < c.y < max(feet["BL"].y, midY + 0.01)), default=H) * 1.04
    backY = max(feet["BL"].y, feet["BR"].y)
    legX = cfg.get("leg_inner", 0.0) * L  # สัตว์เลื้อยคลาน: ท้องอยู่ต่ำ -> หน้าใกล้แนวกลางเป็นลำตัว
    # แจกหน้าให้กระดูก
    wingX = (cfg.get("wings") or {}).get("min_x", 0.2) * L
    for pi, c in centers:
        b = body
        if cfg.get("wings") and abs(c.x) > wingX and c.z > legTop * 0.9:
            b = rig.i("WingL") if c.x > 0 else rig.i("WingR")
        elif c.z < legTop:
            best, bd = None, 1e9
            for key, f in feet.items():
                d = math.hypot(c.x - f.x, c.y - f.y)
                if d < bd:
                    best, bd = key, d
            if (bd < legR * 1.6 or (c.z < legTop * 0.75 and c.y >= neckY)) and c.y <= backY + legR * 0.8 and abs(c.x) > legX:
                b = rig.i(("Lo" if c.z < kneeZ else "Up") + best)
        if b == body:
            if c.y < neckY or (c.y < midY and c.z > backTop):
                b = rig.i("Head")
            elif tails and c.y > tails[0][1]:
                for name, ty in tails:
                    if c.y >= ty:
                        b = rig.i(name)
        rig.bones[b - 1]["faces"].append(pi)
    absorb_islands(me, rig, cfg.get("island_frac", 0.12))
    rig.L, rig.H, rig.legTop = L, H, legTop
    return rig


def absorb_islands(me, rig, frac):
    """ชิ้นเมชแยก (เขา ตา หู) ขนาดเล็ก -> ให้ทั้งชิ้นตามกระดูกส่วนใหญ่ จะได้ไม่ขาดกลางชิ้น"""
    # ไฟล์แบบ flat มักแยก vertex ต่อหน้า -> รวมตามตำแหน่งก่อน
    keyid = {}
    vid = []
    for v in me.vertices:
        k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        vid.append(keyid.setdefault(k, len(keyid)))
    par = list(range(len(keyid)))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for p in me.polygons:
        vs = [vid[v] for v in p.vertices]
        for v in vs[1:]:
            ra, rb_ = find(vs[0]), find(v)
            if ra != rb_:
                par[ra] = rb_
    owner = {}
    for bi, bn in enumerate(rig.bones):
        for f in bn["faces"]:
            owner[f] = bi
    isl = {}
    for p in me.polygons:
        isl.setdefault(find(vid[p.vertices[0]]), []).append(p.index)
    total = len(me.polygons)
    moved = 0
    for faces in isl.values():
        if len(faces) > total * frac or len(faces) < 2:
            continue
        cnt = {}
        for f in faces:
            cnt[owner[f]] = cnt.get(owner[f], 0) + 1
        best = max(cnt, key=cnt.get)
        if len(cnt) > 1:
            for f in faces:
                if owner[f] != best:
                    rig.bones[owner[f]]["faces"].remove(f)
                    rig.bones[best]["faces"].append(f)
                    owner[f] = best
                    moved += 1
    print("[autorig] islands %d, moved %d faces" % (len(isl), moved))


def build_crab(ob, cfg):
    """ปู: ลำตัว + ก้าม 2 + ขา 6 (ขาละ 1 ท่อน)"""
    me = ob.data
    mn, mx = bounds(me)
    L, H = mx.y - mn.y, mx.z
    centers = [(p.index, face_center(me, p)) for p in me.polygons]
    halfW = max(abs(mn.x), abs(mx.x))
    bodyW = cfg.get("body_w", 0.4) * halfW  # ครึ่งความกว้างกระดอง
    shell = [c for _, c in centers if abs(c.x) < bodyW] or [c for _, c in centers]
    bodyY = sum(c.y for c in shell) / len(shell)
    print("[autorig] crab x %.2f..%.2f y %.2f..%.2f" % (mn.x, mx.x, mn.y, mx.y))
    frontCut = mn.y + cfg.get("claw_front", 0.38) * L
    clawIn = bodyW * cfg.get("claw_inner", 0.5)
    rig = Rig()
    rig.add("Body", None, (0, bodyY, H * 0.45))
    owner = {}
    groups = {"ClawL": [], "ClawR": [], "L": [], "R": []}
    for pi, c in centers:
        side = "L" if c.x > 0 else "R"
        if c.y < frontCut and abs(c.x) > clawIn and c.z < H * cfg.get("claw_top", 0.9):
            groups["Claw" + side].append((pi, c))
        elif abs(c.x) > bodyW:
            groups[side].append((pi, c))
        else:
            owner[pi] = "Body"
    for side in ("L", "R"):
        sgn = 1 if side == "L" else -1
        cl = groups["Claw" + side]
        if cl:
            near = sorted(cl, key=lambda t: math.hypot(t[1].x, t[1].y - bodyY))[:max(3, len(cl) // 10)]
            piv = sum((c for _, c in near), Vector()) / len(near)
            rig.add("Claw" + side, "Body", (piv.x, piv.y, piv.z))
            for pi, _ in cl:
                owner[pi] = "Claw" + side
        lg = sorted(groups[side], key=lambda t: t[1].y)
        n = len(lg)
        for k in range(3):
            chunk = lg[n * k // 3: n * (k + 1) // 3]
            if not chunk:
                continue
            my = sum(c.y for _, c in chunk) / len(chunk)
            inner = [c for _, c in chunk if abs(c.x) < bodyW * 1.35] or [c for _, c in chunk]
            mz = sum(c.z for c in inner) / len(inner)
            name = "Leg%d%s" % (k + 1, side)
            rig.add(name, "Body", (sgn * bodyW, my, mz))
            for pi, _ in chunk:
                owner[pi] = name
    for pi, name in owner.items():
        rig.bones[rig.i(name) - 1]["faces"].append(pi)
    if cfg.get("dump"):
        import json
        json.dump([[c.x, c.y, c.z, owner.get(pi, "?")] for pi, c in centers], open(cfg["dump"], "w"))
    absorb_islands(me, rig, cfg.get("island_frac", 0.12))
    print("[autorig] crab bodyW=%.2f L=%.2f H=%.2f" % (bodyW, L, H))
    rig.L, rig.H, rig.legTop = L, H, H * 0.45
    return rig


def build_serpent(ob, cfg):
    me = ob.data
    mn, mx = bounds(me)
    L, H = mx.y - mn.y, mx.z
    n = cfg.get("segments", 8)
    headFrac = cfg.get("head", 0.14)
    centers = [(p.index, face_center(me, p)) for p in me.polygons]
    rig = Rig()
    # ราก = กลางลำตัว; ไล่ไปข้างหน้า (หัว) และข้างหลัง (หาง)
    edges = [mn.y + headFrac * L + (L * (1 - headFrac)) * k / n for k in range(n + 1)]
    mid = n // 2
    def zat(y):
        zs = [c.z for _, c in centers if abs(c.y - y) < L / (n * 2)]
        return (min(zs) + max(zs)) / 2 if zs else H / 2
    def xat(y):
        xs = [c.x for _, c in centers if abs(c.y - y) < L / (n * 2)]
        return (min(xs) + max(xs)) / 2 if xs else 0
    root = rig.add("Seg%d" % mid, None, (xat(edges[mid]), edges[mid], zat(edges[mid])))
    prev = "Seg%d" % mid
    for k in range(mid - 1, -1, -1):  # ไปทางหัว
        y = edges[k]
        prev = rig.bones[rig.add("Seg%d" % k, prev, (xat(y), y, zat(y))) - 1]["name"]
    rig.add("Head", prev, (xat(edges[0]), edges[0], zat(edges[0])))
    prev = "Seg%d" % mid
    for k in range(mid + 1, n):
        y = edges[k]
        prev = rig.bones[rig.add("Seg%d" % k, prev, (xat(y), y, zat(y))) - 1]["name"]
    for pi, c in centers:
        if c.y < edges[0]:
            b = rig.i("Head")
        else:
            k = max(0, min(n - 1, int((c.y - edges[0]) / ((mx.y - edges[0]) / n))))
            b = rig.i("Seg%d" % k)
        rig.bones[b - 1]["faces"].append(pi)
    rig.L, rig.H, rig.n, rig.mid = L, H, n, mid
    return rig


# ---------------------------------------------------------------- ท่าทาง (สูตร)
def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def clips_quad(rig, cfg):
    """คืน {clip: (dur, loop, fn(t)->{bone: (quat, Vector pos Roblox)})}"""
    L, H = rig.L, rig.H
    amp = math.radians(cfg.get("stride_deg", 28))
    has = lambda n: rig.i(n) is not None
    wings = has("WingL")
    sprawl = cfg.get("sprawl", False)

    def legs(pose, ph, a, knee, gallop=False):
        for key, off in (("FL", 0), ("BR", 0), ("FR", math.pi), ("BL", math.pi)):
            if gallop:
                off = {"FL": 0, "FR": 0.35, "BL": math.pi, "BR": math.pi + 0.35}[key]
            s = math.sin(ph + off)
            if sprawl:
                # สัตว์เลื้อยคลาน: ขากางข้าง กวาดหน้า-หลังรอบแกนตั้ง + ยกขาตอนกวาดไปหน้า
                side = 1 if key.endswith("L") else -1
                up = max(0.0, math.cos(ph + off))
                pose["Up" + key] = (qaxis((0, 1, 0), -s * a * 1.3 * side) @ qaxis((0, 0, 1), up * 0.45 * side), Vector())
                pose["Lo" + key] = (qaxis((0, 0, 1), -up * 0.3 * side), Vector())
                continue
            pose["Up" + key] = (qaxis((1, 0, 0), s * a), Vector())
            # เข่างอตอนยกขากลับไปข้างหน้า
            lift = max(0.0, math.cos(ph + off))
            kq = qaxis((1, 0, 0), -lift * knee if key.startswith("F") else lift * knee)
            pose["Lo" + key] = (kq, Vector())

    def tail(pose, t, freq, a):
        for k in range(1, 4):
            if has("Tail%d" % k):
                pose["Tail%d" % k] = (qaxis((0, 1, 0), math.sin(t * freq * TAU - k * 0.7) * a * (0.6 + 0.3 * k)) @ qaxis((1, 0, 0), 0.08), Vector())

    def wing(pose, t, freq, a, base=0.0):
        if wings:
            f = math.sin(t * freq * TAU) * a + base
            pose["WingL"] = (qaxis((0, 0, 1), f), Vector())
            pose["WingR"] = (qaxis((0, 0, 1), -f), Vector())

    def idle(t):
        p = {}
        b = math.sin(t / 3 * TAU)
        p["Body"] = (qaxis((1, 0, 0), b * 0.015), Vector((0, b * 0.012 * H, 0)))
        p["Head"] = (qaxis((0, 1, 0), math.sin(t / 3 * TAU * 0.5) * 0.22) @ qaxis((1, 0, 0), b * 0.04), Vector())
        tail(p, t, 1 / 3 * 2, 0.18)
        wing(p, t, 1 / 3, 0.06, 0.15)
        return p

    def walk(t):
        p = {}
        ph = t / 1.0 * TAU
        legs(p, ph, amp, math.radians(35))
        bob = abs(math.sin(ph)) * 0.035 * H
        p["Body"] = (qaxis((0, 0, 1), math.sin(ph) * 0.03), Vector((0, bob, 0)))
        if sprawl:
            p["Body"] = (qaxis((0, 1, 0), math.sin(ph) * 0.12), Vector((0, abs(math.sin(ph)) * 0.015 * H, 0)))
            p["Head"] = (qaxis((0, 1, 0), -math.sin(ph) * 0.14), Vector())
            tail(p, t, 1.0, 0.45)
            return p
        p["Head"] = (qaxis((1, 0, 0), math.sin(ph * 2) * 0.05), Vector())
        tail(p, t, 1.0, 0.25)
        wing(p, t, 1.0, 0.05, 0.12)
        return p

    def run(t):
        p = {}
        ph = t / 0.6 * TAU
        legs(p, ph, amp * 1.6, math.radians(55), gallop=not sprawl)
        if sprawl:
            p["Body"] = (qaxis((0, 1, 0), math.sin(ph) * 0.16), Vector((0, abs(math.sin(ph)) * 0.02 * H, 0)))
            p["Head"] = (qaxis((0, 1, 0), -math.sin(ph) * 0.18), Vector())
            tail(p, t, 1 / 0.6, 0.5)
            return p
        p["Body"] = (qaxis((1, 0, 0), math.sin(ph) * 0.09), Vector((0, (0.5 + 0.5 * math.sin(ph - 0.6)) * 0.07 * H, 0)))
        p["Head"] = (qaxis((1, 0, 0), -math.sin(ph) * 0.12), Vector())
        tail(p, t, 1 / 0.6, 0.18)
        wing(p, t, 1 / 0.6, 0.2, 0.2)
        return p

    def attack(t):
        p = {}
        u = t / 0.9
        crouch = smooth(min(1, u / 0.35)) * (1 - smooth(max(0, (u - 0.35) / 0.2)))
        lunge = math.sin(math.pi * min(1, max(0, (u - 0.35) / 0.45)))
        p["Body"] = (qaxis((1, 0, 0), -crouch * 0.18 + lunge * 0.22), Vector((0, -crouch * 0.08 * H + lunge * 0.05 * H, -lunge * 0.18 * L)))
        p["Head"] = (qaxis((1, 0, 0), lunge * 0.35 - crouch * 0.2), Vector())
        for key in ("FL", "FR"):
            p["Up" + key] = (qaxis((1, 0, 0), lunge * 0.7), Vector())
            p["Lo" + key] = (qaxis((1, 0, 0), -lunge * 0.6), Vector())
        for key in ("BL", "BR"):
            p["Up" + key] = (qaxis((1, 0, 0), -lunge * 0.35 + crouch * 0.2), Vector())
        tail(p, t, 2.0, 0.3)
        wing(p, t, 2.0, 0.35 * lunge, 0.4 * lunge)
        return p

    def death(t):
        p = {}
        u = smooth(min(1, t / 0.9))
        p["Body"] = (qaxis((0, 0, 1), u * 1.45), Vector((0, -u * (rig.legTop * 0.55), 0)))
        p["Head"] = (qaxis((1, 0, 0), u * 0.3), Vector())
        for key in ("FL", "FR", "BL", "BR"):
            p["Up" + key] = (qaxis((1, 0, 0), u * (0.35 if key[0] == "F" else -0.35)), Vector())
        wing(p, 0, 1, 0, -0.3 * u)
        return p

    def eat(t):
        p = idle(t)
        d = smooth(min(1, t / 0.5)) if t < 2.0 else smooth(max(0, (2.5 - t) / 0.5))
        p["Head"] = (qaxis((1, 0, 0), 0.75 * d + math.sin(t * 7) * 0.05 * d), Vector())
        return p

    if cfg.get("hop"):
        def hopper(period, height):
            def fn(t):
                p = {}
                u = (t / period) % 1
                air = math.sin(math.pi * u)
                p["Body"] = (qaxis((1, 0, 0), math.sin(u * TAU) * 0.22), Vector((0, air * height * H, 0)))
                p["Head"] = (qaxis((1, 0, 0), -math.sin(u * TAU) * 0.15), Vector())
                for key in ("BL", "BR"):
                    p["Up" + key] = (qaxis((1, 0, 0), -air * 0.9), Vector())
                    p["Lo" + key] = (qaxis((1, 0, 0), air * 0.5), Vector())
                for key in ("FL", "FR"):
                    p["Up" + key] = (qaxis((1, 0, 0), air * 0.7), Vector())
                tail(p, t, 2, 0.1)
                return p
            return fn
        walk, run = hopper(0.55, 0.25), hopper(0.4, 0.45)
    out = {"Idle": (3.0, True, idle), "Walk": (0.55 if cfg.get("hop") else 1.0, True, walk), "Run": (0.4 if cfg.get("hop") else 0.6, True, run),
           "Attack": (0.9, False, attack), "Death": (1.0, False, death), "Eat": (2.5, True, eat)}
    if wings:
        def fly(t):
            p = {}
            ph = t / 0.9 * TAU
            f = math.sin(ph)
            p["Body"] = (qaxis((1, 0, 0), -0.12), Vector((0, -f * 0.06 * H, 0)))
            p["Head"] = (qaxis((1, 0, 0), -0.12 + f * 0.05), Vector())
            pose_l = qaxis((0, 0, 1), f * 0.75 + 0.1)
            p["WingL"] = (pose_l, Vector())
            p["WingR"] = (qaxis((0, 0, 1), -(f * 0.75 + 0.1)), Vector())
            for key in ("FL", "FR", "BL", "BR"):
                p["Up" + key] = (qaxis((1, 0, 0), 0.6 if key[0] == "B" else -0.5), Vector())
                p["Lo" + key] = (qaxis((1, 0, 0), 0.5 if key[0] == "F" else -0.4), Vector())
            tail(p, t, 1 / 0.9, 0.15)
            return p

        def roar(t):
            p = idle(t)
            u = math.sin(math.pi * min(1, t / 1.4))
            p["Body"] = (qaxis((1, 0, 0), -u * 0.35), Vector((0, u * 0.05 * H, u * 0.05 * L)))
            p["Head"] = (qaxis((1, 0, 0), -u * 0.45) @ qaxis((0, 1, 0), math.sin(t * 9) * 0.06 * u), Vector())
            p["WingL"] = (qaxis((0, 0, 1), u * 0.9), Vector())
            p["WingR"] = (qaxis((0, 0, 1), -u * 0.9), Vector())
            return p

        out["Fly"] = (0.9, True, fly)
        out["FlyFast"] = (0.55, True, fly)
        out["Roar"] = (1.4, False, roar)
    return out


def clips_crab(rig, cfg):
    """ท่าปู (พิกัด Roblox: ซ้ายตัว = -X, หน้า = -Z)"""
    H = rig.H
    has = lambda n: rig.i(n) is not None

    def legs(p, ph, a, lift):
        for k in (1, 2, 3):
            for side in ("L", "R"):
                n = "Leg%d%s" % (k, side)
                if not has(n):
                    continue
                off = (k % 2) * math.pi + (math.pi if side == "R" else 0)
                s = math.sin(ph + off)
                up = max(0.0, math.cos(ph + off)) * lift
                sg = -1 if side == "L" else 1
                p[n] = (qaxis((0, 1, 0), s * a * sg) @ qaxis((0, 0, 1), up * sg), Vector())

    def claws(p, open_, raise_, snap=0.0):
        for side in ("L", "R"):
            n = "Claw" + side
            if has(n):
                sg = -1 if side == "L" else 1
                p[n] = (qaxis((1, 0, 0), raise_) @ qaxis((0, 1, 0), (open_ + snap) * sg), Vector())

    def idle(t):
        p = {}
        b = math.sin(t / 2 * TAU)
        p["Body"] = (qaxis((1, 0, 0), b * 0.02), Vector((0, b * 0.02 * H, 0)))
        claws(p, 0.1 + 0.1 * max(0, math.sin(t * TAU)), 0.1 + b * 0.05)
        legs(p, t / 2 * TAU, 0.04, 0.05)
        return p

    def walk(t):
        p = {}
        ph = t / 0.6 * TAU
        legs(p, ph, 0.35, 0.35)
        p["Body"] = (qaxis((0, 0, 1), math.sin(ph) * 0.05), Vector((0, abs(math.sin(ph)) * 0.04 * H, 0)))
        claws(p, 0.15, 0.2 + math.sin(ph) * 0.06)
        return p

    def run(t):
        p = {}
        ph = t / 0.36 * TAU
        legs(p, ph, 0.45, 0.45)
        p["Body"] = (qaxis((0, 0, 1), math.sin(ph) * 0.07), Vector((0, abs(math.sin(ph)) * 0.06 * H, 0)))
        claws(p, 0.1, 0.35)
        return p

    def attack(t):
        p = idle(t)
        u = t / 0.8
        up = smooth(u / 0.4)
        down = smooth((u - 0.4) / 0.2)
        back = smooth((u - 0.75) / 0.25)
        r = up * 0.55 - down * 0.75 + back * 0.2
        claws(p, 0.35 * up * (1 - down), r, -0.3 * down)
        p["Body"] = (qaxis((1, 0, 0), -up * 0.15 + down * 0.2 - back * 0.05), Vector((0, up * 0.08 * H, -down * 0.1 * H)))
        return p

    def death(t):
        p = {}
        u = smooth(t / 0.8)
        p["Body"] = (qaxis((0, 0, 1), u * math.pi), Vector((0, math.sin(u * math.pi) * 0.6 * H + u * 0.55 * H, 0)))
        for k in (1, 2, 3):
            for side, sg in (("L", -1), ("R", 1)):
                n = "Leg%d%s" % (k, side)
                if has(n):
                    p[n] = (qaxis((0, 0, 1), u * 0.8 * sg + math.sin(t * 18 + k) * 0.15 * u), Vector())
        claws(p, 0.4 * u, -0.3 * u)
        return p

    def eat(t):
        p = idle(t)
        for side, ph in (("L", 0), ("R", math.pi)):
            n = "Claw" + side
            if has(n):
                sg = -1 if side == "L" else 1
                v = max(0, math.sin(t * 5 + ph))
                p[n] = (qaxis((1, 0, 0), 0.3 + v * 0.4) @ qaxis((0, 1, 0), -v * 0.6 * sg), Vector())
        return p

    return {"Idle": (2.0, True, idle), "Walk": (0.6, True, walk), "Run": (0.36, True, run),
            "Attack": (0.8, False, attack), "Death": (1.0, False, death), "Eat": (2.4, True, eat)}


def clips_serpent(rig, cfg):
    n, mid, H, L = rig.n, rig.mid, rig.H, rig.L
    waveAmp = cfg.get("wave", 0.32)
    axis = (0, 1, 0) if not cfg.get("vertical") else (1, 0, 0)

    def wave(p, t, freq, amp, lift=0.0):
        for k in range(n):
            name = "Seg%d" % k
            if rig.i(name) is None:
                continue
            ph = t * freq * TAU + k * 0.75
            a = math.sin(ph) * amp * (0.35 if k == mid else 1)
            q = qaxis(axis, a)
            if lift and k < mid:
                q = qaxis((1, 0, 0), lift * (mid - k) / mid) @ q
            p[name] = (q, Vector())
        return p

    def idle(t):
        p = wave({}, t, 0.35, waveAmp * 0.35, cfg.get("rear", 0.0))
        p["Head"] = (qaxis((0, 1, 0), math.sin(t * 0.7) * 0.25), Vector())
        return p

    def walk(t):
        p = wave({}, t, 1.0, waveAmp, cfg.get("rear", 0.0) * 0.5)
        p["Head"] = (qaxis((0, 1, 0), -math.sin(t * TAU) * 0.15), Vector())
        return p

    def run(t):
        return wave({}, t, 1.8, waveAmp * 1.15, cfg.get("rear", 0.0) * 0.3)

    def attack(t):
        u = math.sin(math.pi * min(1, t / 0.9))
        p = wave({}, t, 1.2, waveAmp * 0.4, cfg.get("rear", 0.0) + u * 0.35)
        p["Head"] = (qaxis((1, 0, 0), u * 0.5), Vector((0, 0, -u * 0.12 * L)))
        return p

    def death(t):
        u = smooth(min(1, t / 1.0))
        p = wave({}, 0.3, 0, 0)
        p["Seg%d" % mid] = (qaxis((0, 0, 1), u * 1.4), Vector((0, -u * H * 0.3, 0)))
        return p

    return {"Idle": (3.0, True, idle), "Walk": (1.0, True, walk), "Run": (0.6, True, run), "Attack": (0.9, False, attack),
            "Death": (1.0, False, death), "Roar": (1.2, False, attack), "Swim": (1.2, True, walk)}


# ---------------------------------------------------------------- เขียนข้อมูล
def export(rid, src, kind="quad", yaw=0.0, size=("length", 6.0), recolor=None, tint=None, glow=None, fps=20, drop=None,
           keep_only=None, attach=None, keep_axis=False, **cfg):
    ob = load_static(src, yaw, size, drop, keep_only, keep_axis)
    if attach:
        for a in attach:
            a(ob)
    me = ob.data
    # สีใหม่
    for i, m in enumerate(me.materials):
        if m is None:
            continue
        nm = m.name.lower()
        col = list(rx.mat_srgb(m))
        _, _, img = mesh_export.mat_info(m)
        nmat = bpy.data.materials.new("AR_%s_%d" % (rid, i))
        textured = img is not None
        for k, c in (recolor or {}).items():
            if k.lower() in nm or k == "*":
                col = list(c)
                textured = False
        if tint:
            col = [min(1, a * b) for a, b in zip(col, tint)]
        nmat["as_color"] = col
        if rx.vcol_direct(m) and not any(k.lower() in nm or k == "*" for k in (recolor or {})):
            nmat["as_vcol"] = True
            if tint:
                nmat["as_tint"] = list(tint)
        if textured:
            nmat.use_nodes = True
            nmat.node_tree.nodes.new("ShaderNodeTexImage").image = img
            if tint:
                nmat["as_tint"] = list(tint)
        for k, c in (glow or {}).items():
            if k.lower() in nm:
                nmat["as_color"] = list(c)
                nmat["as_glow"] = list(c)
        me.materials[i] = nmat
    gp = cfg.pop("glow_pick", None)
    if gp:
        pred, gcol = gp
        cols, _ = mesh_export.face_colors(ob)
        gm = bpy.data.materials.new("AR_%s_glow" % rid)
        gm["as_color"] = list(gcol)
        gm["as_glow"] = list(gcol)
        me.materials.append(gm)
        gi = len(me.materials) - 1
        n = 0
        for p, c in zip(me.polygons, cols):
            if pred(c):
                p.material_index = gi
                n += 1
        print("  glow faces", n)
    rig = {"serpent": build_serpent, "crab": build_crab}.get(kind, build_quad)(ob, cfg)
    # ชิ้นเมชต่อกระดูก
    parts = {}
    for bi, b in enumerate(rig.bones, 1):
        if not b["faces"]:
            continue
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        keep = set(b["faces"])
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        nm_ = bpy.data.meshes.new("B%d" % bi)
        bm.to_mesh(nm_)
        bm.free()
        for m in me.materials:
            nm_.materials.append(m)
        # ชิ้นเรืองแสงแยก
        gidx = {i for i, m in enumerate(nm_.materials) if m and m.get("as_glow") is not None}
        o = bpy.data.objects.new("B%d" % bi, nm_)
        bpy.context.scene.collection.objects.link(o)
        if gidx and any(p.material_index in gidx for p in nm_.polygons):
            col = nm_.materials[next(iter(gidx))]["as_glow"]
            gfaces = {p.index for p in nm_.polygons if p.material_index in gidx}
            for keepglow in (True, False):
                bm = bmesh.new()
                bm.from_mesh(nm_)
                bm.faces.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.index in gfaces) != keepglow], context="FACES")
                mm = bpy.data.meshes.new("x")
                bm.to_mesh(mm)
                bm.free()
                for m in nm_.materials:
                    mm.materials.append(m)
                if len(mm.polygons) == 0:
                    continue
                name = ("Glow_%02x%02x%02x_B%d" % (int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), bi)) if keepglow else "B%d" % bi
                oo = bpy.data.objects.new(name, mm)
                bpy.context.scene.collection.objects.link(oo)
                parts[name] = oo
        else:
            parts["B%d" % bi] = o
    ob.hide_render = True
    rx.render_preview(rid, list(parts.values()))
    # ภาพตรวจการแบ่งชิ้น: สีละกระดูก
    import colorsys
    saved = {}
    for k, (name, o) in enumerate(sorted(parts.items())):
        saved[o.name] = (list(o.data.materials), [pp.material_index for pp in o.data.polygons])
        dm = bpy.data.materials.new("DBG%d" % k)
        dm.use_nodes = True
        bs = next(n for n in dm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        r, g, bb = colorsys.hsv_to_rgb((k * 0.17) % 1, 0.8, 0.9)
        bs.inputs["Base Color"].default_value = (r, g, bb, 1)
        dm["as_color"] = [r, g, bb]
        o.data.materials.clear()
        o.data.materials.append(dm)
        for pp in o.data.polygons:
            pp.material_index = 0
    rx.render_preview(rid + "_seg", list(parts.values()))
    for o in parts.values():
        mats_, idx_ = saved[o.name]
        o.data.materials.clear()
        for m in mats_:
            o.data.materials.append(m)
        for pp, mi in zip(o.data.polygons, idx_):
            pp.material_index = mi
    # ท่า
    clipdefs = {"serpent": clips_serpent, "crab": clips_crab}.get(kind, clips_quad)(rig, cfg)
    nb = len(rig.bones)
    clip_lines = []
    for cname, (dur, loop, fn) in clipdefs.items():
        nf = max(2, int(round(dur * fps)) + 1)
        qbuf = bytearray()
        tv = []
        for f in range(nf):
            t = dur * f / (nf - 1)
            pose = fn(t)
            for b in rig.bones:
                q, pos = pose.get(b["name"], (Quaternion(), Vector()))
                q = q.normalized()
                if q.w < 0:
                    q = -q
                qbuf += struct.pack("<4h", *(int(round(max(-1, min(1, x)) * 32767)) for x in (q.x, q.y, q.z, q.w)))
                tv.append((pos.x, pos.y, pos.z))
        tmax = max(1e-6, max(abs(v) for t3 in tv for v in t3))
        tbuf = bytearray()
        for t3 in tv:
            tbuf += struct.pack("<3h", *(int(round(v / tmax * 32767)) for v in t3))
        clip_lines.append('\t\t%s = { Fps = %d, N = %d, Dur = %.4f, TS = %.6f, Src = "autorig",' % (cname, fps, nf, dur, tmax))
        clip_lines.append('\t\t\tQ = "%s",' % base64.b64encode(bytes(qbuf)).decode())
        clip_lines.append('\t\t\tT = "%s",' % base64.b64encode(bytes(tbuf)).decode())
        clip_lines.append("\t\t},")
    path = mesh_export.export(rid, parts, out_dir=OUT)
    txt = open(path, encoding="utf-8").read().rstrip()[:-1]
    mn, mx = bounds(me)
    lines = ["\tRig = {", "\t\tHeight = %.3f," % (mx.z - mn.z), "\t\tLength = %.3f," % (mx.y - mn.y), "\t\tBones = {"]
    for b in rig.bones:
        par = rig.bones[b["parent"] - 1]["pos"] if b["parent"] else Vector()
        d = rb(b["pos"] - par)
        lines.append('\t\t\t{ Name = "%s", Parent = %d, C0 = { %.5f, %.5f, %.5f, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },' % (b["name"], b["parent"], d.x, d.y, d.z))
    lines += ["\t\t},", "\t},", "\tClips = {"] + clip_lines + ["\t},"]
    open(path, "w", encoding="utf-8", newline="\n").write(txt + "\n".join(lines) + "\n}\n")
    counts = {b["name"]: len(b["faces"]) for b in rig.bones}
    print(f"[autorig] {rid}: {len(rig.bones)} bones, parts {len(parts)}, faces {counts} -> {os.path.getsize(path)//1024} KB")
    return path
