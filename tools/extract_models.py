"""
extract_models.py — ดึงโมเดลที่ Import ใน Studio ออกจากไฟล์แมพที่เซฟแล้ว (.rbxlx) เป็นไฟล์ .rbxmx ของโปรเจกต์

    python tools/extract_models.py <Folder> <Name> [<Name> ...]
    เช่น  python tools/extract_models.py Animals Terragon Leviathan

อ่าน build/AnimalSurvival.rbxlx -> หา Workspace.<Name> -> เขียน assets/rbxm/<Folder>/<Name>.rbxmx
(ตัดค่า SharedString ที่เป็นแคช เช่น MeshData/PhysicsData ออก Roblox สร้างใหม่เองจาก MeshId)
"""
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACE = os.path.join(ROOT, "build", "AnimalSurvival.rbxlx")


def name_of(item):
    for c in item.find("Properties"):
        if c.get("name") == "Name":
            return c.text
    return None


def strip(item):
    for it in item.iter("Item"):
        props = it.find("Properties")
        for c in list(props):
            if c.tag == "SharedString":
                props.remove(c)


def main():
    folder, names = sys.argv[1], sys.argv[2:]
    root = ET.parse(PLACE).getroot()
    ws = next(it for it in root.findall("Item") if it.get("class") == "Workspace")
    found = {name_of(it): it for it in ws.findall("Item")}
    out_dir = os.path.join(ROOT, "assets", "rbxm", folder)
    os.makedirs(out_dir, exist_ok=True)
    for n in names:
        item = found.get(n)
        if item is None:
            print("ไม่เจอ", n, "ใน Workspace")
            continue
        strip(item)
        body = ET.tostring(item, encoding="unicode")
        xml = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n' + body + "\n</roblox>\n"
        path = os.path.join(out_dir, n + ".rbxmx")
        with open(path, "w", encoding="utf-8") as f:
            f.write(xml)
        print(n, "->", os.path.relpath(path, ROOT), "%d KB" % (len(xml) // 1024))


if __name__ == "__main__":
    main()
