"""
upload_assets.py — อัปโหลดโมเดลสัตว์ (FBX จาก Blender) ขึ้นบัญชี Roblox ของผู้สร้างเกม ผ่าน Open Cloud Assets API

    python tools/upload_assets.py            อัปทุกไฟล์ที่เปลี่ยน (จำไฟล์ที่อัปแล้วใน build/asset_ids.json)
    python tools/upload_assets.py MossWolf   อัปเฉพาะตัวที่ระบุ
    python tools/upload_assets.py --check    ตรวจว่ากุญแจอ่านได้

กุญแจอ่านจาก secrets/roblox_api_key.txt + secrets/roblox_user_id.txt (ไม่พิมพ์ออกจอ ส่งไปที่ apis.roblox.com เท่านั้น)
ผลลัพธ์: src/ReplicatedStorage/Shared/AssetIds.lua  (เกม/ปลั๊กอินโหลดโมเดลจาก id นี้)
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECRETS = os.path.join(ROOT, "secrets")
CACHE = os.path.join(ROOT, "build", "asset_ids.json")
LUA_OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "AssetIds.lua")
API = "https://apis.roblox.com/assets/v1/"
CONTENT = {".glb": "model/gltf-binary", ".fbx": "model/fbx", ".png": "image/png", ".rbxm": "model/x-rbxm"}


def secret(name):
    with open(os.path.join(SECRETS, name), encoding="utf-8") as f:
        return f.read().strip()


KEY = secret("roblox_api_key.txt")
USER = secret("roblox_user_id.txt")


def request(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:400]}") from None


def upload(path, asset_type, name):
    boundary = uuid.uuid4().hex
    meta = {"assetType": asset_type, "displayName": name[:50], "description": "Animal Survival: 99 Nights of the Elements",
            "creationContext": {"creator": {"userId": USER}}}
    data = open(path, "rb").read()
    ext = os.path.splitext(path)[1].lower()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: {CONTENT[ext]}\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    op = request("POST", API + "assets", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    path_ = op.get("path")
    for _ in range(120):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + path_)
    if not op.get("done"):
        raise RuntimeError("อัปโหลดค้าง: " + name)
    resp = op.get("response") or {}
    aid = resp.get("assetId")
    if not aid:
        raise RuntimeError("ไม่ได้ assetId: " + json.dumps(op)[:300])
    return int(aid)


def sha(path):
    return hashlib.sha1(open(path, "rb").read()).hexdigest()


def main():
    if "--check" in sys.argv:
        print("กุญแจอ่านได้ (User", USER + ")" if USER.isdigit() else "User ID ไม่ถูกต้อง")
        return
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    out = {"Animals": {}}
    if os.path.exists(os.path.join(ROOT, "build", "asset_map.json")):
        out = json.load(open(os.path.join(ROOT, "build", "asset_map.json")))
    adir = os.path.join(ROOT, "blender", "exports", "animals")
    for f in sorted(os.listdir(adir)):
        if not f.endswith(".fbx"):
            continue
        aid_name = f[:-4]
        if only and aid_name not in only:
            continue
        path = os.path.join(adir, f)
        h = sha(path)
        if h in cache:
            out["Animals"][aid_name] = cache[h]
            continue
        print("อัปโหลด", aid_name, "...", flush=True)
        try:
            asset = upload(path, "Model", "AS " + aid_name)
        except Exception as e:
            print("   !!", e)
            continue
        cache[h] = asset
        out["Animals"][aid_name] = asset
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        json.dump(cache, open(CACHE, "w"), indent=1)
        print("   ->", asset, flush=True)
    json.dump(out, open(os.path.join(ROOT, "build", "asset_map.json"), "w"), indent=1)
    lines = ["-- สร้างโดย tools/upload_assets.py — id โมเดลที่อัปขึ้นบัญชีผู้สร้างเกม", "return {", "\tAnimals = {"]
    for k in sorted(out["Animals"]):
        lines.append(f"\t\t{k} = {out['Animals'][k]},")
    lines += ["\t},", "}", ""]
    open(LUA_OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("เขียน", LUA_OUT, len(out["Animals"]), "ตัว")


main()
