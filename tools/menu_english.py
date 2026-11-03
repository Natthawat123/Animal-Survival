"""
menu_english.py — เปลี่ยนตัวหนังสือบนรูปปุ่มเมนูล็อบบี้ (assets/ui/menu/*.png) จากไทยเป็นอังกฤษ
  ลบตัวหนังสือเดิมบนแผ่นไม้ (inpaint) แล้วเขียนใหม่ด้วย Fredoka ตัวหนา สีครีม ขอบน้ำตาลเข้ม + เงา
  รูปต้นฉบับภาษาไทยเก็บไว้ที่ assets/ui/menu_th/ (ใช้ซ้ำทุกครั้ง ไม่ลบทับกันเอง)

    python tools/menu_english.py           แล้วรัน python tools/menu_art.py เพื่อสร้าง MenuArt.lua ใหม่
"""
import os
import shutil

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MENU = os.path.join(ROOT, "assets", "ui", "menu")
ORIG = os.path.join(ROOT, "assets", "ui", "menu_th")
FONT = os.path.join(ROOT, "assets", "fonts", "Fredoka-Variable.ttf")
LABELS = {"Classes": "CLASSES", "Quests": "QUESTS", "Badges": "BADGES", "Shop": "SHOP", "Settings": "SETTINGS"}
SIZE = 30  # ทุกปุ่มตัวหนังสือขนาดเดียวกัน (SETTINGS ยาวสุดยังพอดีแผ่นไม้)
FILL_TOP, FILL_BOT = (255, 248, 230), (240, 214, 160)
STROKE = (52, 26, 10)


def font(size):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([700, 100])  # Weight, Width -> ตัวหนาเหมือน FredokaOne
    return f


def text_box(rgb):
    """กรอบตัวหนังสือครีมบนแผ่นไม้ (ไม่นับธงฟ้า/แดง ตะเกียง และไอคอนกลมด้านซ้าย)"""
    h, w, _ = rgb.shape
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    cream = (r > 195) & (g > 190) & (b > 185) & (np.abs(r - b) < 35)  # ตัวหนังสือขาวบนแผ่นไม้
    cream[:, : int(w * 0.36)] = False
    cream[:, int(w * 0.86):] = False
    ys, xs = np.nonzero(cream)
    # ตัดจุดหลงทาง: ใช้แถว/คอลัมน์ที่มีพิกเซลครีมพอสมควร
    cols = np.bincount(xs, minlength=w)
    rows = np.bincount(ys, minlength=h)
    xs_ok = np.nonzero(cols >= 2)[0]
    ys_ok = np.nonzero(rows >= 3)[0]
    return (xs_ok.min(), ys_ok.min(), xs_ok.max(), ys_ok.max()), cream


def process(name):
    src = os.path.join(ORIG, name + ".png")
    im = Image.open(src).convert("RGBA")
    rgba = np.array(im)
    rgb = rgba[..., :3].copy()
    (x0, y0, x1, y1), cream = text_box(rgb)
    pad = 7
    # ลบเฉพาะตัวอักษรเดิม + ขอบน้ำตาลรอบตัว (ขยาย 6 px) บนส่วนที่ทึบ ไม่แตะพื้นโปร่งใส
    sub = np.zeros_like(cream)
    sub[max(0, y0 - 2):y1 + 3, max(0, x0 - 2):x1 + 3] = cream[max(0, y0 - 2):y1 + 3, max(0, x0 - 2):x1 + 3]
    # ตัดจุดขาวที่ไม่ใช่ตัวหนังสือ (ประกายบนไอคอน/ธง): เอาเฉพาะช่วงที่ตัวหนังสือหนาแน่นจริง
    def span(vals, size, gap):
        # ช่วงต่อเนื่องรอบค่ากลาง (ช่องว่างไม่เกิน gap px) -> ตัดกลุ่มขาวที่แยกอยู่ไกล เช่น ประแจ/ธง
        hist = np.bincount(vals, minlength=size) > 0
        mid = int(np.median(vals))
        lo = hi = mid
        while lo > 0 and hist[max(0, lo - gap):lo].any():
            lo -= 1
        while hi < size - 1 and hist[hi + 1:hi + 1 + gap].any():
            hi += 1
        return lo, hi
    ys0, xs0 = np.nonzero(sub)
    ax, bx = span(xs0, sub.shape[1], 10)
    ay, by = span(ys0, sub.shape[0], 6)
    ax, bx, ay, by = ax - 3, bx + 3, ay - 3, by + 3
    yy, xx = np.mgrid[0:sub.shape[0], 0:sub.shape[1]]
    sub &= (xx >= ax) & (xx <= bx) & (yy >= ay) & (yy <= by)
    mask = cv2.dilate(sub.astype(np.uint8) * 255, np.ones((15, 15), np.uint8))
    mask = np.maximum(mask, np.roll(mask, 5, axis=0))  # เงาตัวหนังสือเดิมเลื่อนลงล่าง
    mask[rgba[..., 3] < 200] = 0
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    fixed = cv2.inpaint(bgr, mask, 9, cv2.INPAINT_TELEA)
    # ลายไม้: เติมลายเส้นแนวนอนจากแถวเดียวกันนอกกรอบ ให้ไม่เป็นก้อนเบลอ
    fixed = cv2.cvtColor(fixed, cv2.COLOR_BGR2RGB)
    out = rgba.copy()
    out[..., :3] = np.where(mask[..., None] > 0, fixed, rgb)
    base = Image.fromarray(out, "RGBA")

    label = LABELS[name]
    # กลางตัวหนังสือเดิม (ค่ากลางของพิกเซล ไม่โดนสระบน/ล่างดึง) · กลางแนวนอน = กลางช่วงแผ่นไม้แถวนั้น
    ys, xs = np.nonzero(sub)
    cy = float(np.median(ys))
    lo, hi = np.percentile(xs, 2), np.percentile(xs, 98)  # ตัวหนังสือเดิมวางกลางแผ่นไม้อยู่แล้ว
    cx = (lo + hi) / 2
    f = font(SIZE)
    sw = max(2, SIZE // 9)
    l, t, r, b = f.getbbox(label, stroke_width=sw)
    tx, ty = cx - (r - l) / 2 - l, cy - (b - t) / 2 - t
    size = SIZE
    w, h = base.size
    shadow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shadow).text((tx + 2, ty + 4), label, font=f, fill=200, stroke_width=sw, stroke_fill=200)
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    base.alpha_composite(Image.merge("RGBA", [Image.new("L", (w, h), 0)] * 3 + [shadow]))

    stroke = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(stroke).text((tx, ty), label, font=f, fill=STROKE + (255,), stroke_width=sw, stroke_fill=STROKE + (255,))
    base.alpha_composite(stroke)
    # ตัวอักษร: ไล่สีครีมบน -> เหลืองทองล่าง
    glyph = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glyph).text((tx, ty), label, font=f, fill=255)
    grad = Image.new("RGBA", (w, h))
    gt, gb = int(ty + t), int(ty + b)
    for yy in range(h):
        k = min(1, max(0, (yy - gt) / max(1, gb - gt)))
        c = tuple(int(FILL_TOP[i] + (FILL_BOT[i] - FILL_TOP[i]) * k) for i in range(3))
        ImageDraw.Draw(grad).line([(0, yy), (w, yy)], fill=c + (255,))
    grad.putalpha(glyph)
    base.alpha_composite(grad)
    base.save(os.path.join(MENU, name + ".png"))
    print(name, "plank", (lo, hi), "center", (round(cx), round(cy)), "text w", r - l)


if __name__ == "__main__":
    os.makedirs(ORIG, exist_ok=True)
    for n in LABELS:
        keep = os.path.join(ORIG, n + ".png")
        if not os.path.exists(keep):
            shutil.copy2(os.path.join(MENU, n + ".png"), keep)
        process(n)
