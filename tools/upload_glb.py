"""
upload_glb.py — อัปโหลดโมเดล GLB ที่เตรียมแล้ว (blender/exports/import/*.glb) ขึ้นบัญชีผู้สร้างเกม ผ่าน Open Cloud Assets API

    python tools/upload_glb.py              อัปทุกไฟล์ที่ยังไม่เคยอัป (จำไว้ใน build/import_ids.json ตาม hash ไฟล์)
    python tools/upload_glb.py Chest1 ...   อัปเฉพาะชื่อที่ระบุ

กุญแจอ่านจาก secrets/ (ไม่พิมพ์ออกจอ ส่งไปที่ apis.roblox.com เท่านั้น)
ได้ id แล้วดึงเข้าเกม: python tools/fetch_models.py <id ...> -> tools/store_to_rbxmx.py
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
SRC = os.path.join(ROOT, "blender", "exports", "import")
CACHE = os.path.join(ROOT, "build", "import_ids.json")
API = "https://apis.roblox.com/assets/v1/"


def secret(name):
    with open(os.path.join(ROOT, "secrets", name), encoding="utf-8") as f:
        return f.read().strip()


KEY = secret("roblox_api_key.txt")
USER = secret("roblox_user_id.txt")


def request(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:400]}") from None


def upload(path, name):
    boundary = uuid.uuid4().hex
    meta = {"assetType": "Model", "displayName": name[:50], "description": "Animal Survival",
            "creationContext": {"creator": {"userId": USER}}}
    data = open(path, "rb").read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(meta)}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: model/gltf-binary\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    op = request("POST", API + "assets", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    path_ = op.get("path")
    for _ in range(150):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", API + path_)
    if not op.get("done"):
        raise RuntimeError("upload still processing: " + name)
    aid = (op.get("response") or {}).get("assetId")
    if not aid:
        raise RuntimeError("no assetId: " + json.dumps(op)[:300])
    return int(aid)


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".glb"):
            continue
        name = f[:-4]
        if only and name not in only:
            continue
        path = os.path.join(SRC, f)
        h = hashlib.sha1(open(path, "rb").read()).hexdigest()
        if cache.get(name, {}).get("sha") == h:
            print(name, "=", cache[name]["id"], "(cached)")
            continue
        print("upload", name, "...", flush=True)
        try:
            aid = upload(path, "AS " + name)
        except Exception as e:
            print("   !!", e)
            continue
        cache[name] = {"id": aid, "sha": h}
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        json.dump(cache, open(CACHE, "w"), indent=1)
        print(name, "=", aid, flush=True)


main()
