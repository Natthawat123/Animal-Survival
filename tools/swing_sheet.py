"""รวมภาพท่าตีจาก --swingprobe (sw_<ท่า>_<อาวุธ>_<คีย์>.png) เป็นแถบภาพต่อท่า -> <dir>/sheet/<ท่า>.png
ใช้: python tools/swing_sheet.py [build/swingprobe]"""
import os
import re
import sys
from collections import defaultdict

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1] if len(sys.argv) > 1 else "build/swingprobe"
out = os.path.join(src, "sheet")
os.makedirs(out, exist_ok=True)
styles = defaultdict(list)
for f in os.listdir(src):
    m = re.match(r"sw_([A-Za-z]+)_([A-Za-z]+)_(\d+)\.png$", f)
    if m:
        styles[(m.group(1), m.group(2))].append((int(m.group(3)), f))
try:
    font = ImageFont.truetype("arialbd.ttf", 26)
except OSError:
    font = ImageFont.load_default()
FW, FH = 380, 400  # ขนาดเฟรมในชีท
for (style, weapon), frames in sorted(styles.items()):
    frames.sort()
    sheet = Image.new("RGB", (FW * len(frames), FH + 40), (24, 24, 28))
    for i, (k, f) in enumerate(frames):
        im = Image.open(os.path.join(src, f)).convert("RGB")
        # ช่องเกมในหน้าต่าง Studio ~ x 10..1900, y 215..990 · ตัวละครอยู่กลางจอ
        cx, cy = 955, 600
        crop = im.crop((cx - 360, cy - 380, cx + 360, cy + 378)).resize((FW, FH))
        sheet.paste(crop, (i * FW, 40))
    d = ImageDraw.Draw(sheet)
    d.text((10, 6), f"{style}  ({weapon})", fill=(255, 220, 60), font=font)
    for i in range(len(frames)):
        d.text((i * FW + FW - 40, 46), str(i + 1), fill=(255, 255, 255), font=font)
    sheet.save(os.path.join(out, f"{style}.png"))
    print(style, weapon, len(frames))
