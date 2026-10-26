"""
panel_art.py — ภาพประดับหน้าต่างธีมไม้ (หัวหมาป่า/อินทรีบนกรอบ, ถุง/หีบ Ruby ในร้านค้า) -> ReplicatedStorage/Shared/PanelArt.lua
เกมวาดรูปเองตอนรันด้วย EditableImage (รูปแบบข้อมูลเดียวกับ menu_art.py)

    python tools/panel_art.py      สร้าง PanelArt.lua ใหม่จาก assets/ui/panel/*.png (พื้นหลังโปร่งใสแล้ว)
"""
import os

from menu_art import ROOT, write_lua

ART = os.path.join(ROOT, "assets", "ui", "panel")
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "PanelArt.lua")
# ชื่อ -> ความกว้างที่เก็บ (จอแสดงราวๆ ครึ่งหนึ่ง-เท่าตัว)
ITEMS = {"Wolf": 240, "Eagle": 220, "Pack1": 170, "Pack2": 200, "Pack3": 190, "Pack4": 220}


def main():
    items = [(n, os.path.join(ART, n + ".png"), w) for n, w in ITEMS.items()]
    write_lua(OUT, "PanelArt", "ภาพประดับหน้าต่างธีมไม้ + ภาพแพ็ก Ruby (สร้างโดย tools/panel_art.py — อย่าแก้มือ)", items)


if __name__ == "__main__":
    main()
