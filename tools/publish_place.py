"""
publish_place.py — build แมพล่าสุดแล้วอัปขึ้นเกมบน Roblox (ทับเวอร์ชันเดิม เกม private ก็ใช้ได้) ผ่าน Open Cloud Place Publishing API

    python tools/publish_place.py                      build + publish (ใช้ id ที่จำไว้ใน secrets/roblox_place.txt)
    python tools/publish_place.py <universeId> <placeId>   ครั้งแรก: ระบุ id แล้วจำไว้ให้
    python tools/publish_place.py --saved              อัปเป็นเวอร์ชัน Saved (ยังไม่ปล่อยให้ผู้เล่น)
    python tools/publish_place.py --no-build           ไม่ build ใหม่ อัปไฟล์ build/AnimalSurvival.rbxlx ที่มีอยู่

กุญแจอ่านจาก secrets/roblox_api_key.txt (ไม่พิมพ์ออกจอ ส่งไปที่ apis.roblox.com เท่านั้น)
กุญแจต้องมีสิทธิ์ universe-places: write และเลือกเกมนี้ไว้ใน Experiences ของกุญแจ
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECRETS = os.path.join(ROOT, "secrets")
PLACE_FILE = os.path.join(SECRETS, "roblox_place.txt")
RBXLX = os.path.join(ROOT, "build", "AnimalSurvival.rbxlx")


def read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}

    key = read(os.path.join(SECRETS, "roblox_api_key.txt"))
    if not key:
        sys.exit("ยังไม่มีกุญแจ: วาง API key ลงไฟล์ secrets/roblox_api_key.txt ก่อน (ไม่ต้องส่งในแชต)")

    if len(args) == 2:
        universe, place = args
        os.makedirs(SECRETS, exist_ok=True)
        with open(PLACE_FILE, "w", encoding="utf-8") as f:
            f.write(f"{universe} {place}\n")
    else:
        parts = read(PLACE_FILE).split()
        if len(parts) != 2:
            sys.exit("ยังไม่รู้ว่าจะอัปเกมไหน: รัน  python tools/publish_place.py <universeId> <placeId>  ครั้งแรก")
        universe, place = parts
    if not (universe.isdigit() and place.isdigit()):
        sys.exit("universeId / placeId ต้องเป็นตัวเลข")

    if "--no-build" not in flags:
        print("กำลัง build แมพล่าสุด...")
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "build_rbxlx.py")], check=True)

    data = open(RBXLX, "rb").read()
    vtype = "Saved" if "--saved" in flags else "Published"
    url = f"https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType={vtype}"
    print(f"กำลังอัป {len(data) / 1e6:.1f} MB -> universe {universe} place {place} ({vtype})...")
    req = urllib.request.Request(url, data=data, method="POST", headers={"x-api-key": key, "Content-Type": "application/xml"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            res = json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        hint = {
            401: "กุญแจผิด/หมดอายุ หรือ IP ไม่อยู่ในรายการที่อนุญาตของกุญแจ",
            403: "กุญแจไม่มีสิทธิ์ universe-places: write หรือไม่ได้เลือกเกมนี้ในกุญแจ",
            404: "universeId / placeId ไม่ถูกต้อง",
        }.get(e.code, "")
        sys.exit(f"อัปไม่ผ่าน HTTP {e.code}: {body}\n{hint}")
    print(f"อัปสำเร็จ! เวอร์ชัน {res.get('versionNumber')}")
    print("ถ้ามีเซิร์ฟเวอร์เก่าเปิดค้างอยู่: Creator Hub > เกม > ... > Shut Down All Servers แล้วเข้าใหม่ถึงจะเห็นเวอร์ชันนี้")


if __name__ == "__main__":
    main()
