"""
chest_lid_rbxmx.py — เอาหีบฝาเปิดได้ (Chest1Open-3Open: MeshPart "Body" + "Lid") ที่ Import 3D ใน Studio แล้ว
ออกมาเป็น assets/rbxm/Props/ChestNOpen.rbxmx + ฝัง Attachment "Hinge" (บานพับ) ในฝา ตามข้อมูลจาก blender/split_chest_lid.py

  1) Studio: File > Import 3D เลือก blender/exports/import/Chest1Open.glb, Chest2Open.glb, Chest3Open.glb -> เซฟไฟล์ (.rbxlx)
  2) python tools/chest_lid_rbxmx.py <ไฟล์ .rbxlx ที่เซฟ>

จับคู่หีบจากขนาดชิ้น Body/Lid (blender/exports/import/ChestNOpen.json) · ตำแหน่งบานพับคิดเทียบระยะ Body -> Lid ในไฟล์จริง
"""
import json
import os
import re
import sys
import uuid
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]
INFO = {}
for n in (1, 2, 3):
    p = os.path.join(ROOT, "blender", "exports", "import", f"Chest{n}Open.json")
    if os.path.exists(p):
        INFO[f"Chest{n}Open"] = json.load(open(p))

tree = ET.parse(SRC)
root = tree.getroot()
shared = {s.get("md5"): s for s in (root.find("SharedStrings") or [])}


def prop(it, name):
    p = it.find("Properties")
    for c in p if p is not None else []:
        if c.get("name") == name:
            return c
    return None


def name_of(it):
    c = prop(it, "Name")
    return c.text if c is not None else ""


def vec(it, name):
    v = prop(it, name)
    return [float(v.find(k).text) for k in "XYZ"]


def cframe(it):
    c = prop(it, "CFrame")
    pos = [float(c.find(k).text) for k in "XYZ"]
    rot = [[float(c.find(f"R{r}{col}").text) for col in range(3)] for r in range(3)]
    return pos, rot


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def tmul(rot, v):  # rotᵀ · v (โลก -> พิกัดของชิ้น)
    return [sum(rot[r][c] * v[r] for r in range(3)) for c in range(3)]


def dist(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


# ทุกโมเดลที่มี MeshPart ชื่อ Body + Lid
found = []
for it in root.iter("Item"):
    if it.get("class") != "Model":
        continue
    kids = {name_of(k): k for k in it.findall("Item")}
    body, lid = kids.get("Body"), kids.get("Lid")
    if body is None or lid is None:
        # Import 3D บางครั้งห่อชั้นกลางไว้
        parts = {name_of(d): d for d in it.iter("Item") if d.get("class") == "MeshPart"}
        body, lid = parts.get("Body"), parts.get("Lid")
    if body is not None and lid is not None and body.get("class") == "MeshPart":
        found.append((it, body, lid))

# ตัดชั้นซ้อน (โมเดลแม่ที่มีโมเดลลูกตรงกันอยู่แล้ว)
found = [f for f in found if not any(g is not f and f[0] is not g[0] and g[0] in list(f[0].iter("Item")) for g in found)]
done = set()
for model, body, lid in found:
    bs, ls = vec(body, "InitialSize"), vec(lid, "InitialSize")
    best = min(INFO.items(), key=lambda kv: dist(kv[1]["Body"]["Size"], bs) + dist(kv[1]["Lid"]["Size"], ls), default=None)
    if not best:
        break
    nm, info = best
    if nm in done:
        print("!! ซ้ำ", nm)
        continue
    done.add(nm)
    bpos, _ = cframe(body)
    lpos, lrot = cframe(lid)
    # แกนจริงในไฟล์: ลองแบบตรง และแบบกลับ X/Z (เผื่อ Studio หมุนโมเดลตอนนำเข้า) เลือกที่ระยะ Body->Lid ตรงที่สุด
    want = sub(lpos, bpos)
    raw = sub(info["Lid"]["Center"], info["Body"]["Center"])
    maps = {"same": (1, 1, 1), "flipXZ": (-1, 1, -1)}
    mk = min(maps, key=lambda k: dist([a * b for a, b in zip(raw, maps[k])], want))
    m = maps[mk]
    hinge_rel_body = [a * b for a, b in zip(sub(info["Hinge"], info["Body"]["Center"]), m)]
    hinge_world = [bp + h for bp, h in zip(bpos, hinge_rel_body)]
    local = tmul(lrot, sub(hinge_world, lpos))
    flip = mk == "flipXZ"  # บานพับต้องหันแกน +Z ไปทางหลังหีบ: แบบกลับแกน = หมุน 180° รอบ Y
    r = (-1, 0, 0, 0, 1, 0, 0, 0, -1) if flip else (1, 0, 0, 0, 1, 0, 0, 0, 1)
    att = ET.SubElement(lid, "Item", {"class": "Attachment", "referent": "RBX" + uuid.uuid4().hex.upper()})
    props = ET.SubElement(att, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = "Hinge"
    cf = ET.SubElement(props, "CoordinateFrame", {"name": "CFrame"})
    for k, v in zip("XYZ", local):
        ET.SubElement(cf, k).text = repr(v)
    for i, v in enumerate(r):
        ET.SubElement(cf, f"R{i // 3}{i % 3}").text = str(v)
    ET.SubElement(props, "bool", {"name": "Visible"}).text = "false"
    prop(model, "Name").text = nm
    xml = ET.tostring(model, encoding="unicode")
    keys = set(re.findall(r'<SharedString name="[^"]+">([^<]+)</SharedString>', xml))
    out = ['<roblox version="4">', xml]
    if keys:
        out.append("<SharedStrings>")
        out += [ET.tostring(shared[k], encoding="unicode") for k in keys if k in shared]
        out.append("</SharedStrings>")
    out.append("</roblox>")
    dst = os.path.join(ROOT, "assets", "rbxm", "Props", nm + ".rbxmx")
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(nm, "->", os.path.relpath(dst, ROOT), "axes", mk, "hinge", [round(x, 3) for x in local])
print("missing", [n for n in INFO if n not in done])
