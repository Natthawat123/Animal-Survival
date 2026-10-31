"""
import_pets.py — สัตว์ที่ช่วยจากศาลเจ้า 4 ตัว (Creator Store ฟรี มี rig) -> assets/rbxm/Animals + ท่าจากไฟล์ (Shared/SkelClips)

  python tools/import_pets.py

  TerraPup (13265462332 Horse)        : Motor6D 21 จุด + KeyframeSequence (idle/walk/trot/gallop) -> SkelClips/TerraPup.lua
  TidePup  (6806168763 Crocodile)     : Bone 107 ชิ้น -> ท่าคำนวณสด (SkelAnimator)
  GalePup  (4699080619 Wolf)          : Motor6D 26 จุด -> ท่าคำนวณสด
  EmberPup (11890952798 Wild Red Fox) : แยกชิ้นไม่มีข้อต่อ -> AnimalModels.buildSkeleton ต่อเอง -> ท่าคำนวณสด

ต้องดึงโมเดลก่อน: python tools/build_rbxlx.py --fetch=<ids> แล้ว tools/fetch_models.py --parse
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_to_rbxmx  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")
CLIPS = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "SkelClips")
PETS = {"13265462332": "TerraPup", "6806168763": "TidePup", "4699080619": "GalePup", "11890952798": "EmberPup"}
HORSE_CLIPS = {"Idle": "idle", "Walk": "walk", "Trot": "trot", "Run": "gallop"}
FPS = 20


def quat(m):
    r00, r01, r02, r10, r11, r12, r20, r21, r22 = m
    tr = r00 + r11 + r22
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        q = ((r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s, 0.25 * s)
    elif r00 > r11 and r00 > r22:
        s = math.sqrt(1 + r00 - r11 - r22) * 2
        q = (0.25 * s, (r01 + r10) / s, (r02 + r20) / s, (r21 - r12) / s)
    elif r11 > r22:
        s = math.sqrt(1 + r11 - r00 - r22) * 2
        q = ((r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r02 - r20) / s)
    else:
        s = math.sqrt(1 + r22 - r00 - r11) * 2
        q = ((r02 + r20) / s, (r12 + r21) / s, 0.25 * s, (r10 - r01) / s)
    return q


def lerp_pose(a, b, u):
    pos = [a[i] + (b[i] - a[i]) * u for i in range(3)]
    qa, qb = a[3:], b[3:]
    if sum(x * y for x, y in zip(qa, qb)) < 0:
        qb = [-x for x in qb]
    q = [x + (y - x) * u for x, y in zip(qa, qb)]
    n = math.sqrt(sum(x * x for x in q)) or 1
    return pos + [x / n for x in q]


def bake_clip(items, kids, seq_index, parts):
    """Keyframe เวลาไม่เท่ากัน -> สุ่มใหม่เป็นเฟรมเท่ากัน FPS (ท่าเดินไม่กระตุก)"""
    keys = [i for i in kids.get(seq_index, []) if items[i - 1]["C"] == "Keyframe"]
    keys.sort(key=lambda i: items[i - 1].get("T", 0))
    times = [items[i - 1].get("T", 0) for i in keys]
    length = max(times[-1], 1 / FPS)
    tracks = {}
    for fi, k in enumerate(keys):
        stack = list(kids.get(k, []))
        while stack:
            j = stack.pop()
            p = items[j - 1]
            if p["C"] != "Pose":
                continue
            stack.extend(kids.get(j, []))
            if p["N"] in parts and p.get("CF"):
                tracks.setdefault(p["N"], {})[fi] = list(p["CF"][:3]) + list(quat(p["CF"][3:]))
    frames = max(2, round(length * FPS))
    rows = {}
    for name, known in tracks.items():
        idx = sorted(known)
        out = []
        for f in range(frames):
            t = f / frames * length
            prev = idx[0]
            nxt = idx[-1]
            for i in idx:
                if times[i] <= t:
                    prev = i
                if times[i] >= t:
                    nxt = i
                    break
            span = times[nxt] - times[prev]
            u = (t - times[prev]) / span if span > 1e-5 else 0
            out.append(lerp_pose(known[prev], known[nxt], u))
        rest = [0, 0, 0, 0, 0, 0, 1]
        if all(max(abs(a - b) for a, b in zip(fr, rest)) < 1e-3 for fr in out):
            continue
        rows[name] = out
    return frames, rows


def horse_clips():
    d = json.load(open(os.path.join(STORE, "13265462332.json"), encoding="utf-8"))
    items = d["Items"]
    kids = {}
    for i, it in enumerate(items, 1):
        kids.setdefault(it.get("P", 0), []).append(i)
    seq = {it["N"].strip(): i for i, it in enumerate(items, 1) if it["C"] == "KeyframeSequence"}
    parts = {it["N"] for it in items if it["C"] in ("MeshPart", "Part")}
    out = ["-- TerraPup — ท่าจากโมเดล Horse (Creator Store 13265462332) · สร้างโดย tools/import_pets.py — อย่าแก้มือ",
           "-- Clips[ชื่อ].Joints[ชื่อชิ้น Part1] = { {px,py,pz, qx,qy,qz,qw} ต่อเฟรม } = Motor6D.Transform (ตำแหน่งที่ขนาดตอนดึง)",
           "return {", f"\tFps = {FPS},", "\tClips = {"]
    for key, name in HORSE_CLIPS.items():
        frames, rows = bake_clip(items, kids, seq[name], parts)
        print(key, frames, "frames", len(rows), "joints")
        out.append(f"\t\t{key} = {{ Frames = {frames}, Joints = {{")
        for j, fr in sorted(rows.items()):
            vals = ", ".join("{ " + ", ".join(f"{v:.4g}" for v in f) + " }" for f in fr)
            out.append(f'\t\t\t["{j}"] = {{ {vals} }},')
        out.append("\t\t} },")
    out += ["\t},", "}", ""]
    os.makedirs(CLIPS, exist_ok=True)
    path = os.path.join(CLIPS, "TerraPup.lua")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("clips ->", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    for aid, name in PETS.items():
        store_to_rbxmx.convert(aid, name, "Animals")
    horse_clips()
