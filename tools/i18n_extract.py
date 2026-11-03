"""
i18n_extract.py — ดึงข้อความที่ผู้เล่นเห็น (สตริงในโค้ด Lua) -> build/i18n_source.json
ใช้เป็นต้นฉบับภาษาอังกฤษของระบบแปลในเกม (Shared/Lang) · คัดตัวที่เป็นชื่อในโค้ด/ไฟล์/asset ออก

    python tools/i18n_extract.py            -> พิมพ์จำนวน + เขียน build/i18n_source.json
    python tools/i18n_extract.py --missing  -> เทียบกับ src/ReplicatedStorage/Shared/Lang/*.lua บอกตัวที่ยังไม่มีคำแปล
"""
import glob
import json
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = ("PropMeshData", "AnimalClips", "SkelClips", "PanelArt", "MenuArt", "LoadingArt", "ItemThumbs", "AssetIds", "Shared/Lang", "Shared\\Lang",
        "BossAnimator", "AnimalAnimator", "ClipAnimator", "SkelAnimator", "BossFX", "VFXLib", "MeshProps", "AnimalModels", "ClassAvatars",
        "SoundController", "Audio.lua", "PropBuilder", "MapGenerator", "MapLayout", "SiteSpec", "WoodKit", "UIKit.lua",
        "DevService", "DevPanel", "Lang.lua", "Localizer.lua")
# คำเดียว (เช่น "Craft", "Iron") เอาเฉพาะจากไฟล์ที่เป็นหน้าจอ/ข้อมูลที่ผู้เล่นเห็น (ไฟล์อื่นมักเป็นชื่อภายในโค้ด เช่น "Idle", "Raid")
DISPLAY = ("Menus", "HUD", "StoreUI", "SettingsUI", "ClassShop", "QuestUI", "LobbyUI", "PadUI", "Tutorial", "MapUI", "Backpack", "ItemTooltip",
           "Items", "Classes", "Biomes", "Animals", "Quests", "Shop", "Recipes", "Badges", "Cinematics", "RejoinUI", "DeathClient", "MobileControls",
           "WorldEventsClient", "TeamPing", "LobbyService", "MedAnim", "Nights")


def strings(src):
    """โทเคนสตริงของ Lua (ข้ามคอมเมนต์ · รองรับ '...' "..." [[...]])"""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                end = src.find("]" + m.group(1) + "]", i)
                i = n if end < 0 else end + len(m.group(1)) + 2
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        if c in "\"'":
            j, buf = i + 1, []
            while j < n and src[j] != c and src[j] != "\n":
                if src[j] == "\\" and j + 1 < n:
                    nx = src[j + 1]
                    buf.append({"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}.get(nx, "\\" + nx))
                    j += 2
                    continue
                buf.append(src[j])
                j += 1
            yield "".join(buf)
            i = j + 1
            continue
        m = re.match(r"\[(=*)\[", src[i:i + 10])
        if m and (i == 0 or not re.match(r"[\w\]\)]", src[i - 1])):
            end = src.find("]" + m.group(1) + "]", i)
            i = n if end < 0 else end + len(m.group(1)) + 2
            continue
        i += 1


def userfacing(t, fname=""):
    t2 = t.strip()
    if t2.startswith("[AS]") or re.match(r"^\[[A-Za-z]+\]", t2):
        return False  # log
    if len(t2) < 2 or not re.search(r"[A-Za-z]", t2):
        return False
    if re.search(r"rbxasset|rbxthumb|http|\.png|\.ogg|\.mp3|\.lua|^Enum\.|Service$|^%[-\d.]*[sdf]$", t2):
        return False
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", t2):
        # คำเดียว: เอาเฉพาะคำที่ขึ้นต้นตัวใหญ่ ตามด้วยตัวเล็กล้วน (Craft, Shop) · ตัด CamelCase/snake (HumanoidRootPart)
        return bool(re.match(r"^[A-Z][a-z]{2,}$", t2)) and any(fname.startswith(d) for d in DISPLAY)
    if re.match(r"^[A-Za-z0-9_./]+$", t2) and "/" in t2:
        return False  # path
    if re.match(r"^[\w.]+:[\w.]+$", t2):
        return False
    return True


def collect():
    found = {}
    for f in glob.glob(os.path.join(ROOT, "src", "**", "*.lua"), recursive=True):
        rel = os.path.relpath(f, ROOT)
        if any(s in rel for s in SKIP):
            continue
        src = open(f, encoding="utf-8", errors="replace").read()
        for t in strings(src):
            if userfacing(t, os.path.basename(f)):
                found.setdefault(t, set()).add(os.path.basename(f))
    return found


# ข้อความที่โค้ดต่อสตริงเอง (ดึงอัตโนมัติไม่ได้) — เขียนเป็นแม่แบบ string.format ให้ Lang จับคู่
EXTRA = [
    "%d players", "Popular", "Confirm", "Combat", "Enter Shrine", "Go Back Outside", "Grinder",
    "Night of %s", "%s Sanctum", "%s Sanctum Chest", "%s Shrine", "Lv.%d", "Needs bench Lv.%d",
    "Resets in %s", "Quest complete! %s - go back to the lobby to claim your reward", "Camp", "On", "Open",
    "[Click] Hit/Chop   [Shift] Sprint   [Ctrl] Lock camera   [C] Craft   [B] Build   [E] Pick up (hold sack)   [F] Take out   [M] Map   [1-9] Select item",
]


def main():
    found = collect()
    out = {k: sorted(v) for k, v in sorted(found.items())}
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    json.dump(out, open(os.path.join(ROOT, "build", "i18n_source.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    # รายการมีเลขกำกับ (ไว้แปล): เลข<TAB>ข้อความ (ขึ้นบรรทัดเขียนเป็น \n)
    # เลขเดิมห้ามเปลี่ยน (ไฟล์แปล assets/i18n/<code>.txt อ้างเลข) — ข้อความใหม่ต่อท้ายเลขถัดไป
    path = os.path.join(ROOT, "assets", "i18n", "source.txt")
    old = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            m = re.match(r"^(\d+)\t(.*)$", line.rstrip("\n"))
            if m:
                old[m.group(2).replace("\\n", "\n")] = int(m.group(1))
    rows = {i: k for k, i in old.items()}
    nxt = max(rows, default=-1) + 1
    for k in list(out) + EXTRA:
        if k not in old:
            old[k] = nxt
            rows[nxt] = k
            nxt += 1
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for i in sorted(rows):
            f.write(str(i) + "\t" + rows[i].replace("\n", "\\n") + "\n")
    print("strings", len(out), "chars", sum(len(k) for k in out))
    if "--missing" in sys.argv:
        for f in sorted(glob.glob(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Lang", "*.lua"))):
            src = open(f, encoding="utf-8").read()
            have = set(re.findall(r'\[("(?:[^"\\]|\\.)*")\]\s*=', src))
            have = {json.loads(h) for h in have}
            miss = [k for k in out if k not in have]
            print(os.path.basename(f), "missing", len(miss))


if __name__ == "__main__":
    main()
