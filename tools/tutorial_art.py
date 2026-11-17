"""
tutorial_art.py — ภาพประกอบหน้าวิธีเอาชีวิตรอด 8 ช่อง -> ReplicatedStorage/Shared/TutorialArt.lua
เกมวาดรูปเองตอนรันด้วย EditableImage (รูปแบบข้อมูลเดียวกับ menu_art.py) ไม่ต้องอัปโหลด

    python tools/tutorial_art.py      ตัดภาพจาก assets/ui/tutorial/reference.png (1280x640) -> tut1..8.png -> TutorialArt.lua
"""
import os

from PIL import Image

from menu_art import ROOT, write_lua

ART = os.path.join(ROOT, "assets", "ui", "tutorial")
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "TutorialArt.lua")
XS = [(62, 340), (358, 634), (652, 928), (945, 1224)]  # คอลัมน์ภาพในรูปต้นแบบ
YS = [(102, 229), (330, 446)]  # แถวภาพ (ตัดเหนือหัวข้อที่วาดติดมา)
WIDTH = 420


def main():
    ref = Image.open(os.path.join(ART, "reference.png")).convert("RGB")
    items, n = [], 1
    for y0, y1 in YS:
        for x0, x1 in XS:
            c = ref.crop((x0, y0, x1, y1))
            c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
            p = os.path.join(ART, f"tut{n}.png")
            c.save(p)
            items.append((f"Tut{n}", p, WIDTH))
            n += 1
    write_lua(OUT, "TutorialArt", "ภาพประกอบหน้าวิธีเอาชีวิตรอด 8 ช่อง (สร้างโดย tools/tutorial_art.py — อย่าแก้มือ)", items)


if __name__ == "__main__":
    main()
