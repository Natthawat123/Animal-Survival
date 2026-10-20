"""
bake_clip.py — ดึงท่า (แอนิเมชันกระดูก) จากไฟล์ GLB -> ReplicatedStorage/Shared/AnimalClips/<Id>.lua
เกมเล่นท่าเองด้วย Bone.Transform (ไม่ต้องอัปโหลดแอนิเมชันขึ้น Roblox)

    python tools/bake_clip.py <file.glb> <AnimalId> [fps=30]

Transform ของแต่ละกระดูก = (ท่ายืนเดิม)^-1 * (ท่าที่เฟรมนั้น) ในแกนของกระดูกแม่ — ตรงกับที่ Roblox ใช้ (Bone.CFrame * Bone.Transform)
เก็บต่อเฟรม: ตำแหน่ง x,y,z + quaternion x,y,z,w (ปัดทศนิยม 4 ตำแหน่ง) · ข้ามกระดูกที่ไม่ขยับเลย
"""
import json
import os
import struct
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, AID = sys.argv[1], sys.argv[2]
FPS = int(sys.argv[3]) if len(sys.argv) > 3 else 30
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "AnimalClips", AID + ".lua")

raw = open(SRC, "rb").read()
jl = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jl])
bin_off = 20 + jl
binl = struct.unpack_from("<I", raw, bin_off)[0]
BIN = raw[bin_off + 8: bin_off + 8 + binl]
NCOMP = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}


def accessor(i):
    a = gl["accessors"][i]
    bv = gl["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = NCOMP[a["type"]]
    assert a["componentType"] == 5126, "ต้องเป็น float"
    arr = np.frombuffer(BIN, dtype="<f4", count=a["count"] * n, offset=off)
    return arr.reshape(a["count"], n) if n > 1 else arr


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]]) / np.dot(q, q)


def qrot(q, v):
    return qmul(qmul(q, np.array([v[0], v[1], v[2], 0.0])), qinv(q))[:3]


def slerp(a, b, t):
    d = np.dot(a, b)
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * t
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)


nodes = gl["nodes"]
joints = gl["skins"][0]["joints"]
anim = gl["animations"][0]
tracks = {}  # node -> {path: (times, values)}
for ch in anim["channels"]:
    smp = anim["samplers"][ch["sampler"]]
    tracks.setdefault(ch["target"]["node"], {})[ch["target"]["path"]] = (accessor(smp["input"]), accessor(smp["output"]))
t_end = max(float(v[0][-1]) for tr in tracks.values() for v in tr.values())
nf = max(2, int(round(t_end * FPS)) + 1)


def sample(times, vals, t, quat):
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    k = int(np.searchsorted(times, t)) - 1
    u = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
    return slerp(vals[k], vals[k + 1], u) if quat else vals[k] + (vals[k + 1] - vals[k]) * u


out = {}
for j in joints:
    nd = nodes[j]
    name = nd.get("name", "joint%d" % j)
    rt = np.array(nd.get("translation", [0, 0, 0]), float)
    rq = np.array(nd.get("rotation", [0, 0, 0, 1]), float)
    tr = tracks.get(j, {})
    frames, moving = [], False
    for f in range(nf):
        t = min(f / FPS, t_end)
        at = sample(*tr["translation"], t, False) if "translation" in tr else rt
        # Meshy ใส่ scale คงที่ที่กระดูกสะโพก (ทั้งตัวย่อ/ขยายรอบสะโพก) แต่ Roblox ไม่รองรับ scale
        # -> ไม่ใช้ scale แต่หารตำแหน่งสะโพกด้วย scale แทน = ทั้งท่าย่อ/ขยายรอบจุดกำเนิด (พื้น) เท้ายังแตะพื้นพอดี
        if "scale" in tr:
            sc = float(np.mean(sample(*tr["scale"], t, False)))
            if abs(sc - 1) > 1e-3:
                at = at / sc
        aq = sample(*tr["rotation"], t, True) if "rotation" in tr else rq
        # Transform = Rest^-1 * Anim
        iq = qinv(rq)
        q = qmul(iq, aq)
        p = qrot(iq, at - rt)
        if q[3] < 0:
            q = -q
        if np.abs(p).max() > 1e-4 or abs(q[3]) < 0.99999:
            moving = True
        frames.append([round(float(x), 4) for x in (*p, *q)])
    if moving:
        out[name] = frames

lines = [
    "-- %s — ท่าจาก %s (สร้างโดย tools/bake_clip.py — อย่าแก้มือ)" % (AID, os.path.basename(SRC)),
    "-- Bones[ชื่อ] = { {px,py,pz, qx,qy,qz,qw} ต่อเฟรม } = Bone.Transform (ตำแหน่งที่ขนาดตอน Import)",
    "return {",
    "\tFps = %d," % FPS,
    "\tFrames = %d," % nf,
    "\tBones = {",
]
for name, frames in out.items():
    lines.append('\t\t["%s"] = {' % name)
    for fr in frames:
        lines.append("\t\t\t{ %s }," % ", ".join(repr(x) for x in fr))
    lines.append("\t\t},")
lines += ["\t},", "}", ""]
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
print("baked", AID, "bones", len(out), "/", len(joints), "frames", nf, "len %.2fs" % t_end, "->", OUT, os.path.getsize(OUT) // 1024, "KB")
