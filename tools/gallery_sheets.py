"""ตัดภาพแกลเลอรี (gal_*.png จาก build --gallery) เป็นการ์ด + ทำภาพรวมพร้อมชื่อภาษาไทย -> art/gallery/"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "build", "test_screenshots")
OUT = os.path.join(ROOT, "art", "gallery")
os.makedirs(OUT, exist_ok=True)
FONT = "C:/Windows/Fonts/tahoma.ttf"
FONTB = "C:/Windows/Fonts/tahomabd.ttf"


def lua_field(path, key):
    """อ่าน id -> Thai จากไฟล์ข้อมูล lua แบบง่าย"""
    out = {}
    cur = None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^\t(\w+) = \{", line)
        if m:
            cur = m.group(1)
        m2 = re.search(key + r' = "([^"]+)"', line)
        if cur and m2 and cur not in out:
            out[cur] = m2.group(1)
    return out


SH = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
ANIMAL_TH = lua_field(os.path.join(SH, "Animals.lua"), "Thai")
CLASS_TH = lua_field(os.path.join(SH, "Classes.lua"), "Thai")
ITEM_TH = {}
for line in open(os.path.join(SH, "Items.lua"), encoding="utf-8"):
    m = re.match(r'^\t(\w+) = \{ Name = "[^"]+", Thai = "([^"]+)"', line)
    if m:
        ITEM_TH[m.group(1)] = m.group(2)


def card(src, title, sub=None, size=(420, 360)):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # ตัดแถบเมนู Studio ด้านบน/ขวา: เอาเฉพาะช่องมองภาพ
    box = (int(w * 0.006), int(h * 0.165), int(w * 0.903), int(h * 0.925))
    im = im.crop(box)
    cw, ch = im.size
    # ตัดตรงกลางให้ได้สัดส่วนการ์ด
    tw = int(ch * size[0] / size[1])
    if tw < cw:
        x0 = (cw - tw) // 2
        im = im.crop((x0, 0, x0 + tw, ch))
    im = im.resize(size)
    canvas = Image.new("RGB", (size[0], size[1] + 58), (22, 22, 26))
    canvas.paste(im, (0, 0))
    d = ImageDraw.Draw(canvas)
    d.text((12, size[1] + 6), title, font=ImageFont.truetype(FONTB, 22), fill=(255, 226, 140))
    if sub:
        d.text((12, size[1] + 34), sub, font=ImageFont.truetype(FONT, 15), fill=(190, 190, 200))
    return canvas


def sheet(cards, cols, path, header):
    cw, chh = cards[0].size
    rows = (len(cards) + cols - 1) // cols
    pad = 10
    W = cols * (cw + pad) + pad
    H = rows * (chh + pad) + pad + 70
    s = Image.new("RGB", (W, H), (12, 12, 15))
    ImageDraw.Draw(s).text((pad + 4, 16), header, font=ImageFont.truetype(FONTB, 36), fill=(255, 255, 255))
    for k, c in enumerate(cards):
        s.paste(c, (pad + (k % cols) * (cw + pad), 70 + pad + (k // cols) * (chh + pad)))
    s.save(path, quality=88)
    print("saved", os.path.relpath(path, ROOT), s.size)


def run():
    groups = {"animal": [], "item": [], "class": []}
    for f in sorted(os.listdir(SHOTS)):
        m = re.match(r"gal_(animal|item|class)_(\w+)\.png", f)
        if m:
            groups[m.group(1)].append(m.group(2))
    order = {
        "animal": ["Rabbit", "Deer", "MossWolf", "Thornboar", "StoneBear", "ReefCrab", "RiptideCroc", "GaleHawk", "SkyLynx", "StormRam", "EmberFox",
                   "MagmaRhino", "LavaSalamander", "HollowStag", "TerraPup", "TidePup", "GalePup", "EmberPup", "Solfang", "Leviathan", "TempestRoc", "Terragon"],
        "item": ["OldAxe", "StoneAxe", "IronAxe", "Pickaxe", "Spear", "Torch", "Bow", "TerraHammer", "TidalTrident", "GaleBow", "EmberBlade", "FourfoldBlade",
                 "LogWall", "StoneWall", "SpikeTrap", "Lantern", "Ballista", "Bed", "FarmPlot", "CookPot", "TerraTotem", "TideTotem", "GaleTotem", "EmberTotem", "SunBeacon"],
        "class": ["Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Firekeeper", "Elementalist", "Beastwarden"],
    }
    cards = {"animal": [], "item": [], "class": []}
    for g, ids in order.items():
        for i in ids:
            src = os.path.join(SHOTS, f"gal_{g}_{i}.png")
            if not os.path.exists(src):
                continue
            th = (ANIMAL_TH if g == "animal" else ITEM_TH if g == "item" else CLASS_TH).get(i, i)
            c = card(src, th, i)
            c.save(os.path.join(OUT, f"{g}_{i}.jpg"), quality=86)
            cards[g].append(c)
    sheet(cards["animal"][:18], 6, os.path.join(OUT, "sheet_animals.jpg"), "สัตว์ทั้งหมด (18 ชนิด)")
    sheet(cards["animal"][18:], 4, os.path.join(OUT, "sheet_bosses.jpg"), "บอส 4 ไบโอม")
    sheet(cards["item"][:12], 6, os.path.join(OUT, "sheet_tools.jpg"), "อาวุธ / เครื่องมือ (12)")
    sheet(cards["item"][12:], 5, os.path.join(OUT, "sheet_structures.jpg"), "สิ่งก่อสร้าง (13)")
    sheet(cards["class"], 5, os.path.join(OUT, "sheet_classes.jpg"), "คลาสทั้งหมด (10)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    run()
