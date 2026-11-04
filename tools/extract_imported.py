"""
extract_imported.py — ดึงโมเดลที่ Import 3D ใน Studio (ชื่อ "Scene" ใน Workspace ของไฟล์ที่เซฟ) ออกมาเป็น assets/rbxm/<Folder>/<Name>.rbxmx
แยกตัวด้วยขนาดเมช (InitialSize) + จำนวนกระดูก ตามตาราง TARGETS · พก SharedStrings ที่ใช้ไปด้วย

    python tools/extract_imported.py <ไฟล์ .rbxlx ที่เซฟหลัง Import> [ชื่อ ...]   (ระบุชื่อ = ดึงเฉพาะตัวนั้น ไม่ทับตัวอื่น)
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]
ONLY = set(sys.argv[2:])
# (ชื่อ, โฟลเดอร์, ขนาดเมช X/Y/Z โดยประมาณ, จำนวนกระดูก)
TARGETS = [
    ("AirdropCrate", "Props", (1.394, 1.387, 1.920), 0),
    ("CampWorkbench", "Props", (1.886, 1.276, 1.283), 0),  # โต๊ะคราฟต์แคมป์ (Meshy Artisan Workbench) — Import 3D ตั้งชื่อ "Scene"
    ("CampForge", "Props", (1.820, 1.800, 1.899), 0),  # เครื่องย่อยแคมป์ (Meshy Miner's Forge)
    ("Chest1", "Props", (1.800, 1.217, 1.239), 0),
    ("Chest2", "Props", (1.775, 1.361, 1.227), 0),
    ("Chest3", "Props", (1.903, 1.289, 1.225), 0),
    ("EmberPup", "Animals", (1.433, 1.700, 2.339), 48),
    ("GalePup", "Animals", (1.354, 1.700, 2.658), 59),
    ("TerraPup", "Animals", (1.362, 1.701, 2.557), 20),
    ("TidePup", "Animals", (1.045, 1.700, 2.609), 43),
    ("InkOctopus", "Animals", (0.733, 1.097, 1.667), 23),  # ช้างวารี (Meshy Azure Royal Elephant) แทนหมึกเดิม
    ("Moonfang", "Animals", (1.284, 1.700, 2.115), 62),
    ("Bed", "Items", (1.624, 1.247, 1.903), 0),  # เตียง 1 ไม้ — blender/exports/import/Bed.glb (3D Model/bad)
    ("Bed2", "Items", (1.827, 1.440, 1.903), 0),  # เตียง 2 ม่านม่วง — blender/exports/import/Bed2.glb
    # อนุสาวรีย์ลูกสัตว์ธาตุ (Import 3D ตั้งชื่อ "Scene" ทั้งหมด -> แยกด้วยขนาด) — 3D Model/for_studio/monument
    ("MonumentEarth", "Props", (1.645, 1.902, 1.429), 0),
    ("MonumentFire", "Props", (1.519, 1.898, 1.082), 0),
    ("MonumentAir", "Props", (1.740, 1.903, 1.422), 0),
    ("MonumentWater", "Props", (1.706, 1.901, 1.501), 0),  # จิ้งจอกจันทรา (ตัวไล่) — blender/exports/import/MoonFox.glb
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


# ตั้งชื่อตามไฟล์ได้เลย (Import 3D รุ่นใหม่ใช้ชื่อไฟล์เป็นชื่อโมเดล): ชื่อนี้ -> โฟลเดอร์ ไม่ต้องเดาจากขนาด
BY_NAME = {"CampWorkbench": "Props", "CampForge": "Props",
           # อนุสาวรีย์ลูกสัตว์ธาตุ: ถ้า Import 3D ตั้งชื่อตามไฟล์ก็ใช้ชื่อเลย (ไม่งั้นแยกด้วยขนาดใน TARGETS)
           "MonumentEarth": "Props", "MonumentFire": "Props", "MonumentAir": "Props", "MonumentWater": "Props"}  # โต๊ะคราฟต์ / เครื่องย่อย ที่แคมป์ — 3D Model/home/เครื่องย่อยเหล็กกับไม้/พร้อมอัป Roblox
# ตัวละครคลาส + คนขายคลาส (Arbang) — 3D Model/for_studio/class/<ชื่อคลาส>.glb (ต้นฉบับ 3D Model/class, 3D Model/home/arbang.glb)
for _n in ("Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Elementalist", "Vampire", "Sage", "Arbang"):
    BY_NAME[_n] = "Characters"
ws = next(i for i in root.findall("Item") if i.get("class") == "Workspace")
scenes = [i for i in ws.findall("Item") if name_of(i) == "Scene" or name_of(i) in BY_NAME]
done = set()
for sc in scenes:
    if name_of(sc) in BY_NAME:
        nm, folder = name_of(sc), BY_NAME[name_of(sc)]
        done.add(nm)
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
        print(nm, "->", os.path.relpath(dst, ROOT), f"{os.path.getsize(dst) // 1024} KB")
        continue
    mp = next((d for d in sc.iter("Item") if d.get("class") == "MeshPart"), None)
    bones = sum(1 for d in sc.iter("Item") if d.get("class") == "Bone")
    v = prop(mp, "InitialSize")
    size = tuple(float(v.find(k).text) for k in "XYZ")
    best = min(TARGETS, key=lambda t: sum(abs(a - b) for a, b in zip(t[2], size)) + abs(t[3] - bones) * 0.5)
    nm, folder = best[0], best[1]
    if ONLY and nm not in ONLY:
        continue
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
missing = [t[0] for t in TARGETS if t[0] not in done and (not ONLY or t[0] in ONLY)] + [n for n in BY_NAME if n not in done]
print("missing", missing)
