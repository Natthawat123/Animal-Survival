"""รวมภาพ anim_<Id>_<n>.png เป็นแผ่นเดียวต่อชนิด -> build/test_screenshots/animsheet_<Id>.png"""
import os, re, sys
from PIL import Image
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "test_screenshots")
groups = {}
for f in os.listdir(D):
    m = re.match(r"anim_(\w+?)_(\d+)\.png$", f)
    if m:
        groups.setdefault(m.group(1), []).append((int(m.group(2)), f))
for gid, fs in groups.items():
    fs.sort()
    ims = []
    for _, f in fs:
        im = Image.open(os.path.join(D, f)).convert("RGB")
        w, h = im.size
        ims.append(im.crop((int(w * 0.01), int(h * 0.17), int(w * 0.9), int(h * 0.92))).resize((560, 360)))
    s = Image.new("RGB", (560 * 3, 360 * ((len(ims) + 2) // 3)))
    for k, im in enumerate(ims):
        s.paste(im, ((k % 3) * 560, (k // 3) * 360))
    s.save(os.path.join(D, "animsheet_" + gid + ".png"))
    print("sheet", gid, len(ims))
