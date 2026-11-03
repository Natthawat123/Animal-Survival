"""
extract_imported.py — ดึงโมเดลที่ Import 3D ใน Studio (ชื่อ "Scene" ใน Workspace ของไฟล์ที่เซฟ) ออกมาเป็น assets/rbxm/<Folder>/<Name>.rbxmx
แยกตัวด้วยขนาดเมช (InitialSize) + จำนวนกระดูก ตามตาราง TARGETS · พก SharedStrings ที่ใช้ไปด้วย

    python tools/extract_imported.py <ไฟล์ .rbxlx ที่เซฟหลัง Import>
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]
# (ชื่อ, โฟลเดอร์, ขนาดเมช X/Y/Z โดยประมาณ, จำนวนกระดูก)
TARGETS = [
    ("AirdropCrate", "Props", (1.394, 1.387, 1.920), 0),
    ("Chest1", "Props", (1.800, 1.217, 1.239), 0),
    ("Chest2", "Props", (1.775, 1.361, 1.227), 0),
    ("Chest3", "Props", (1.903, 1.289, 1.225), 0),
    ("EmberPup", "Animals", (1.433, 1.700, 2.339), 48),
    ("GalePup", "Animals", (1.354, 1.700, 2.658), 59),
    ("TerraPup", "Animals", (1.362, 1.701, 2.557), 20),
    ("TidePup", "Animals", (1.045, 1.700, 2.609), 43),
]

tree = ET.parse(SRC)
root = tree.getroot()
shared = {}
ss = root.find("SharedStrings")
if ss is not None:
    for s in ss.findall("SharedString"):
        shared[s.get("md5")] = s


def prop(it, name):
    p = it.find("Properties")
    for c in p if p is not None else []:
        if c.get("name") == name:
            return c
    return None


def name_of(it):
    c = prop(it, "Name")
    return c.text if c is not None else None


ws = next(i for i in root.findall("Item") if i.get("class") == "Workspace")
scenes = [i for i in ws.findall("Item") if name_of(i) == "Scene"]
done = set()
for sc in scenes:
    mp = next((d for d in sc.iter("Item") if d.get("class") == "MeshPart"), None)
    bones = sum(1 for d in sc.iter("Item") if d.get("class") == "Bone")
    v = prop(mp, "InitialSize")
    size = tuple(float(v.find(k).text) for k in "XYZ")
    best = min(TARGETS, key=lambda t: sum(abs(a - b) for a, b in zip(t[2], size)) + abs(t[3] - bones) * 0.5)
    nm, folder = best[0], best[1]
    if nm in done:
        print("!! ซ้ำ", nm, size, bones)
        continue
    done.add(nm)
    prop(sc, "Name").text = nm
    xml = ET.tostring(sc, encoding="unicode")
    keys = set(re.findall(r'<SharedString name="[^"]+">([^<]+)</SharedString>', xml))
    out = ['<roblox version="4">', xml]
    if keys:
        out.append("<SharedStrings>")
        for k in keys:
            if k in shared:
                out.append(ET.tostring(shared[k], encoding="unicode"))
        out.append("</SharedStrings>")
    out.append("</roblox>")
    dst = os.path.join(ROOT, "assets", "rbxm", folder, nm + ".rbxmx")
    open(dst, "w", encoding="utf-8").write("\n".join(out))
    print(nm, "->", os.path.relpath(dst, ROOT), f"{os.path.getsize(dst) // 1024} KB", "size", tuple(round(x, 3) for x in size), "bones", bones)
missing = [t[0] for t in TARGETS if t[0] not in done]
print("missing", missing)
