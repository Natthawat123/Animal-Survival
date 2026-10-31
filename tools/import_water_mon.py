"""
import_water_mon.py — สัตว์ไบโอมน้ำจาก Creator Store -> assets/rbxm/Animals + ท่าปู (AnimalClips)

  python tools/import_water_mon.py

  ReefCrab   (99896734196325 CrabBoss_rigged) : เมชผูกกระดูก + ท่าในโมเดล 8 ท่า -> AnimalClips/ReefCrab.lua (Clips)
  TideOrca   (14820174686 Orca)               : ชิ้นแยก -> ตั้งชื่อชิ้นตามโครง (Body/Jaw/Tail1-2/FinL/FinR) หน้าหัน -Z
  InkOctopus (12587850050 Octopus)            : หนวด 8 คู่ -> Tent1..8 (+ ชั้นในติดตามด้วยชื่อ @) · ตาเป็น Union -> ทำลูกตาใหม่

ชื่อชิ้น "อะไรก็ได้@Target" = เชื่อมติดกับชิ้นชื่อ Target (AnimalModels.buildParts)
ต้องดึงโมเดลก่อน: python tools/fetch_models.py 99896734196325 14820174686 12587850050
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_to_rbxmx  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")
CLIPS = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "AnimalClips")


def load(aid):
    return json.load(open(os.path.join(STORE, f"{aid}.json"), encoding="utf-8"))


def save(data, aid):
    json.dump(data, open(os.path.join(STORE, f"{aid}.json"), "w", encoding="utf-8"), ensure_ascii=False)


def rot_y(cf, deg):
    """หมุน CFrame (12 ค่า) รอบแกน Y ของโลก"""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    R = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    x, y, z = cf[:3]
    m = [cf[3:6], cf[6:9], cf[9:12]]
    p = [R[0][0] * x + R[0][2] * z, y, R[2][0] * x + R[2][2] * z]
    nm = [[sum(R[i][k] * m[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return p + nm[0] + nm[1] + nm[2]


DROP = {"Weld", "Motor6D", "Humanoid", "ManualWeld", "WeldConstraint", "Snap"}


# ---------------------------------------------------------------- ออร์กา
def orca():
    d = load("14820174686")
    names = {
        "Head": "Body", "Jaw": "Jaw", "Tongue": "Tongue@Jaw", "UpperTail": "Tail1", "LowerTail": "TailLow@Tail1",
        "UpperFlukes": "Tail2", "LowerFlukes": "FlukeLow@Tail2", "Left(Black)Fins": "FinL", "Left(White)Fins": "FinLW@FinL",
        "Right(Black)Fins": "FinR", "Right(White)Fins": "FinRW@FinR",
    }
    for it in d["Items"]:
        if it["C"] in DROP or it.get("N") in ("HumanoidRootPart", "Middle"):
            it["C"] = "_drop"
            continue
        if it.get("N") in names and it["C"] in ("MeshPart", "Part"):
            it["N"] = names[it["N"]]
        if "CF" in it:
            it["CF"] = rot_y(it["CF"], 90)  # หัวเดิมไป +X -> หัน -Z
    save(d, "TideOrca_src")
    store_to_rbxmx.convert("TideOrca_src", "TideOrca", "Animals")


# ---------------------------------------------------------------- ปลาหมึก
def octopus():
    d = load("12587850050")
    items = d["Items"]
    outer, inner = [], []
    for i, it in enumerate(items, 1):
        if it["C"] == "UnionOperation":
            it["C"] = "_drop"
        if it.get("N") == "Meshes/tentacle3":
            (outer if it["P"] == 2 else inner).append(it)
    # จับคู่หนวดนอก-ใน ตามมุมรอบตัว · ชั้นนอกสีส้มเข้ม = ข้อ (Tent1..8) ชั้นใน (ท้องหนวดสีอ่อน) ติดตาม
    ang = lambda it: math.atan2(it["CF"][0], it["CF"][2])
    outer.sort(key=ang)
    for k, o in enumerate(outer, 1):
        o["N"] = f"Tent{k}"
        best = min(inner, key=lambda q: (q["CF"][0] - o["CF"][0]) ** 2 + (q["CF"][2] - o["CF"][2]) ** 2)
        inner.remove(best)
        best["N"] = f"TentIn{k}@Tent{k}"
    for it in items:
        if it.get("N") == "Meshes/Egg":
            it["N"] = "Body"  # ถุงลำตัว (แมนเทิล)
        elif it.get("N") == "Roblox Head" and it["P"] == 2:
            it["N"] = "Head@Body"
    # ลูกตาใหม่ (เดิมเป็น Union) : ตาเหลืองทอง + ม่านตาดำแนวนอน แบบหมึกจริง
    for sx in (-1, 1):
        x = 0.62 * sx
        items.append({"P": 2, "C": "Part", "N": f"Eye@Body", "Shape": "Ball", "Mat": "SmoothPlastic", "CF": [x, 0.24, 0.06, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                      "Size": [0.42, 0.42, 0.42], "Color": [0.95, 0.72, 0.25], "Refl": 0.15})
        items.append({"P": 2, "C": "Part", "N": f"Pupil@Body", "Mat": "SmoothPlastic", "CF": [x + 0.17 * sx, 0.24, 0.06, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                      "Size": [0.1, 0.12, 0.3], "Color": [0.05, 0.05, 0.06]})
    save(d, "InkOctopus_src")
    store_to_rbxmx.convert("InkOctopus_src", "InkOctopus", "Animals")


# ---------------------------------------------------------------- ปู + ท่า
CLIP_MAP = {"Walk": "CrabBoss_Rig|Walk", "Idle": "CrabBoss_Rig|Idle", "AttackL": "CrabBoss_Rig|Attack_Left",
            "AttackR": "CrabBoss_Rig|Attack_Right", "Heavy": "CrabBoss_Rig|Attack_Heavy", "Roar": "CrabBoss_Rig|Roar", "Dead": "CrabBoss_Rig|Dead"}


def crab():
    d = load("99896734196325")
    items = d["Items"]
    store_to_rbxmx.convert("99896734196325", "ReefCrab", "Animals")
    bones = {it["N"] for it in items if it["C"] == "Bone"}
    seq = {it["N"]: i for i, it in enumerate(items, 1) if it["C"] == "KeyframeSequence"}
    kids = {}
    for i, it in enumerate(items, 1):
        kids.setdefault(it.get("P", 0), []).append(i)
    out = ["-- ReefCrab — ท่าจากโมเดล CrabBoss_rigged (Creator Store 99896734196325) · สร้างโดย tools/import_water_mon.py — อย่าแก้มือ",
           "-- Clips[ชื่อ].Bones[กระดูก] = { {px,py,pz, qx,qy,qz,qw} ต่อเฟรม } = Bone.Transform (ตำแหน่งที่ขนาดตอนดึง)",
           "return {", "\tFps = 30,", '\tRootBone = "root",', "\tClips = {"]

    def quat(m):
        # เมทริกซ์หมุน (row-major) -> quaternion x,y,z,w
        r00, r01, r02, r10, r11, r12, r20, r21, r22 = m
        tr = r00 + r11 + r22
        if tr > 0:
            s = math.sqrt(tr + 1) * 2
            return ((r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s, 0.25 * s)
        if r00 > r11 and r00 > r22:
            s = math.sqrt(1 + r00 - r11 - r22) * 2
            return (0.25 * s, (r01 + r10) / s, (r02 + r20) / s, (r21 - r12) / s)
        if r11 > r22:
            s = math.sqrt(1 + r11 - r00 - r22) * 2
            return ((r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r02 - r20) / s)
        s = math.sqrt(1 + r22 - r00 - r11) * 2
        return ((r02 + r20) / s, (r12 + r21) / s, 0.25 * s, (r10 - r01) / s)

    for key, name in CLIP_MAP.items():
        kfs = [i for i in kids.get(seq[name], []) if items[i - 1]["C"] == "Keyframe"]
        kfs.sort(key=lambda i: items[i - 1].get("T", 0))
        frames = {}
        for fi, k in enumerate(kfs):
            stack = list(kids.get(k, []))
            while stack:
                j = stack.pop()
                p = items[j - 1]
                if p["C"] != "Pose":
                    continue
                stack.extend(kids.get(j, []))
                if p["N"] in bones and p.get("CF"):
                    frames.setdefault(p["N"], [None] * len(kfs))[fi] = p["CF"]
        # ตัดกระดูกที่ไม่ขยับเลยทั้งท่า
        rows = []
        for b, fl in sorted(frames.items()):
            last = None
            for i in range(len(fl)):
                fl[i] = fl[i] or last or [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
                last = fl[i]
            if all(max(abs(a - b2) for a, b2 in zip(f, [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])) < 1e-4 for f in fl):
                continue
            vals = []
            for f in fl:
                q = quat(f[3:])
                vals.append("{ %s }" % ", ".join(f"{v:.4g}" for v in (*f[:3], *q)))
            rows.append(f'\t\t\t\t["{b}"] = {{ {", ".join(vals)} }},')
        out.append(f"\t\t{key} = {{ Frames = {len(kfs)}, Bones = {{")
        out.extend(rows)
        out.append("\t\t} },")
        print(key, len(kfs), "frames", len(rows), "bones")
    out += ["\t},", "}", ""]
    path = os.path.join(CLIPS, "ReefCrab.lua")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("clips ->", os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    orca()
    octopus()
    crab()
