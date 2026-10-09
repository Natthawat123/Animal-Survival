"""
fetch_models.py — ดึงโมเดลฟรีจาก Roblox Creator Store ผ่าน Studio (ใช้สิทธิ์ล็อกอินของ Studio)

  python tools/fetch_models.py <id> [<id> ...]      -> build + เปิด Studio โหมด ASFetch + เก็บผลจาก log
  python tools/fetch_models.py --parse               -> อ่าน log ล่าสุดอย่างเดียว

ผลลัพธ์: assets/store/<id>.json (โครงสร้างโมเดล: MeshId, TextureID, ขนาด, CFrame, Bone, Joint)
         assets/store/sheet_fetch.png (ภาพรวมจาก [SHOT] fetch_<id>)
"""
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")
SHOTS = os.path.join(ROOT, "build", "test_screenshots")
os.makedirs(STORE, exist_ok=True)


def latest_logs(n=3):
    logs = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "logs", "*Studio*"))
    logs.sort(key=os.path.getmtime, reverse=True)
    return logs[:n]


def parse():
    chunks = {}
    for log in latest_logs():
        mine = {}
        with open(log, encoding="utf-8", errors="replace") as f:
            for line in f:
                i = line.find("[FETCH] ")
                if i < 0:
                    continue
                rest = line[i + 8:].rstrip("\n")
                parts = rest.split(" ", 2)
                if len(parts) < 3 or "/" not in parts[1]:
                    continue
                aid, frac, text = parts
                k, n = map(int, frac.split("/"))
                mine.setdefault(aid, {})[k] = (n, text)
        for aid, d in mine.items():
            if aid not in chunks:  # log ใหม่สุดก่อน
                chunks[aid] = d
    done = []
    for aid, d in chunks.items():
        n = next(iter(d.values()))[0]
        if len(d) != n:
            print("incomplete", aid, len(d), "/", n)
            continue
        js = "".join(d[k][1] for k in range(1, n + 1))
        try:
            data = json.loads(js)
        except Exception as e:
            print("bad json", aid, e)
            continue
        if "Items" not in data:
            print("empty", aid)
            continue
        with open(os.path.join(STORE, aid + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f)
        cls = {}
        for it in data["Items"]:
            cls[it["C"]] = cls.get(it["C"], 0) + 1
        print(aid, data["Name"], "size", data["Size"], {k: v for k, v in sorted(cls.items(), key=lambda x: -x[1])[:8]})
        done.append(aid)
    return done


def sheet(ids):
    from PIL import Image, ImageDraw
    ims = []
    for aid in ids:
        p = os.path.join(SHOTS, f"fetch_{aid}.png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            w, h = im.size
            im = im.crop((int(w * 0.03), int(h * 0.2), int(w * 0.9), int(h * 0.9))).resize((420, 300))
            ImageDraw.Draw(im).text((6, 6), aid, fill=(255, 255, 0))
            ims.append(im)
    if not ims:
        return
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new("RGB", (cols * 420, rows * 300))
    for k, im in enumerate(ims):
        sh.paste(im, ((k % cols) * 420, (k // cols) * 300))
    sh.save(os.path.join(STORE, "sheet_fetch.png"))
    print("sheet", len(ims))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if args and args[0] != "--parse":
        ids = [a for a in args if a.isdigit()]
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_rbxlx.py"), "--fetch=" + ",".join(ids)], check=True)
        for p in glob.glob(os.path.join(SHOTS, "fetch_*.png")):
            os.remove(p)
        subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", os.path.join(ROOT, "tools", "run_studio_test.ps1"),
                        "-PlaceName", "AnimalSurvival_FETCH.rbxlx", "-TimeoutSec", str(120 + 50 * len(ids)), "-ShowMinimized"], check=False)
        done = parse()
        sheet(ids)
    else:
        done = parse()
        sheet(done)


main()
