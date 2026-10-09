"""รวมภาพ creatures_*.png จากเทสต์ --creatures เป็น cs1/cs2/cs3.png"""
import os

from PIL import Image, ImageDraw

D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "test_screenshots")


def sheet(ids, out, cols=2):
    ims = []
    for i in ids:
        p = os.path.join(D, "creatures_" + i + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        w, h = im.size
        im = im.crop((int(w * 0.005), int(h * 0.16), int(w * 0.905), int(h * 0.93))).resize((880, 540))
        ImageDraw.Draw(im).text((8, 8), i, fill=(255, 255, 0))
        ims.append(im)
    if not ims:
        return
    rows = (len(ims) + cols - 1) // cols
    s = Image.new("RGB", (880 * cols, 540 * rows))
    for k, im in enumerate(ims):
        s.paste(im, ((k % cols) * 880, (k // cols) * 540))
    s.save(os.path.join(D, out))


sheet(["small", "small_side", "mid", "mid_side"], "cs1.png")
sheet(["mid2", "mid2_side", "misc", "misc_side"], "cs2.png")
sheet(["boss_fire", "boss_water", "boss_air", "boss_earth"], "cs3.png")
print("sheets ok")
