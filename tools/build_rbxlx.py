"""
build_rbxlx.py — แพ็คโค้ดใน src/ เป็นไฟล์ place ของ Roblox (.rbxlx) เปิดด้วย Roblox Studio ได้เลย (ไม่ต้องมี Rojo)

    python tools/build_rbxlx.py              -> build/AnimalSurvival.rbxlx         (ไฟล์เล่นจริง)
    python tools/build_rbxlx.py --test       -> build/AnimalSurvival_TEST.rbxlx    (เทสต์อัตโนมัติ: แมพเล็ก เวลาเร็ว)
    python tools/build_rbxlx.py --mapshot    -> build/AnimalSurvival_MAP.rbxlx     (สร้างแมพตอน Edit แล้วถ่ายภาพมุมสูง)
    python tools/build_rbxlx.py --sandbox    -> build/AnimalSurvival_SANDBOX.rbxlx (ของเต็มกระเป๋า ไว้ลองเล่น)

กติกาชื่อไฟล์ (เหมือน Rojo):
    *.server.lua -> Script        *.client.lua -> LocalScript        *.lua -> ModuleScript
    โฟลเดอร์     -> Folder
"""

import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT_DIR = os.path.join(ROOT, "build")
TESTS = os.path.join(ROOT, "tests")
MODELS = os.path.join(ROOT, "assets", "rbxm")  # โมเดลจาก Blender ที่แปลงเป็น .rbxmx แล้ว (ถ้ามี)

TEST = "--test" in sys.argv
MAPSHOT = "--mapshot" in sys.argv
ANIMALSHOT = "--animalshot" in sys.argv
SANDBOX = "--sandbox" in sys.argv
SHOTS = "--shots" in sys.argv  # เทสต์ + ถ่ายภาพฉากสวยๆ ระหว่างเล่น
SEED = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--seed=")), None)
FETCH = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--fetch=")), None)  # ดึงโมเดล Creator Store: --fetch=id,id
PROBE = "--probe" in sys.argv
CREATURES = "--creatures" in sys.argv  # เทสต์สั้น: ถ่ายภาพสัตว์ทุกตัวในเกม
GALLERY = "--gallery" in sys.argv  # สตูดิโอถ่ายภาพ: สัตว์/ไอเทม/คลาส ทีละตัว
ANIMTEST = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--anim=")), None)  # ดูท่าเดิน/วิ่ง/กัด: --anim=MossWolf,Deer  # ถ่ายภาพโมเดลใน Assets.Creatures/Characters ตอน Edit

if CREATURES or GALLERY or ANIMTEST:
    TEST = True
if TEST or SHOTS:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_TEST.rbxlx")
elif MAPSHOT:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_MAP.rbxlx")
elif ANIMALSHOT:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_ANIMALS.rbxlx")
elif FETCH or PROBE:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_FETCH.rbxlx")
elif SANDBOX:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_SANDBOX.rbxlx")
else:
    OUT = os.path.join(OUT_DIR, "AnimalSurvival.rbxlx")

_ref = 0


def next_ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children="", extra_props=""):
    return (
        f'<Item class="{cls}" referent="{next_ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>{extra_props}</Properties>{children}</Item>\n'
    )


def value_item(cls, name, value=None):
    props = ""
    if value is not None:
        tag = {"StringValue": "string", "IntValue": "int64", "NumberValue": "double", "BoolValue": "bool"}[cls]
        props = f'<{tag} name="Value">{escape(str(value))}</{tag}>'
    return item(cls, name, extra_props=props)


def script_item(path):
    fname = os.path.basename(path)
    if fname.endswith(".server.lua"):
        cls, name = "Script", fname[: -len(".server.lua")]
    elif fname.endswith(".client.lua"):
        cls, name = "LocalScript", fname[: -len(".client.lua")]
    else:
        cls, name = "ModuleScript", fname[: -len(".lua")]
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return item(cls, name, extra_props=f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')


def dir_children(path):
    out = ""
    if not os.path.isdir(path):
        return out
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out += item("Folder", entry, dir_children(full))
        elif entry.endswith(".lua") or entry.endswith(".luau"):
            out += script_item(full)
    return out


def model_items(sub):
    """โมเดล .rbxmx ใน assets/rbxm/<sub>/ -> ใส่ไว้ใน ReplicatedStorage.Assets.<sub>"""
    folder = os.path.join(MODELS, sub)
    out = ""
    if not os.path.isdir(folder):
        return out
    for i, f in enumerate(sorted(os.listdir(folder))):
        if f.endswith(".rbxmx"):
            xml = open(os.path.join(folder, f), encoding="utf-8").read()
            start = xml.index("<Item ")
            end = xml.rindex("</roblox>")
            body = xml[start:end]
            body = re.sub(r'referent="([^"]+)"', lambda m: f'referent="{sub}{i}_{m.group(1)}"', body)
            body = re.sub(r'(<Ref name="[^"]+">)(RBX[^<]+)(</Ref>)', lambda m: f"{m.group(1)}{sub}{i}_{m.group(2)}{m.group(3)}", body)
            out += body
    return out


def lint_strings():
    """กันพลาด: สตริง "..." ที่ขึ้นบรรทัดใหม่กลางสตริง (ทำให้สคริปต์ทั้งไฟล์พัง)"""
    bad = []
    for root, _, files in os.walk(SRC):
        for f in files:
            if f.endswith(".lua"):
                path = os.path.join(root, f)
                in_long = False
                for i, line in enumerate(open(path, encoding="utf-8"), 1):
                    if "[[" in line and "]]" not in line:
                        in_long = True
                    if in_long:
                        if "]]" in line:
                            in_long = False
                        continue
                    code = re.sub(r"\\.", "", line.split("--")[0])
                    code = re.sub(r"'[^']*'", "", code)
                    if code.count('"') % 2 == 1:
                        bad.append(f"{os.path.relpath(path, ROOT)}:{i}: {line.strip()[:80]}")
    if bad:
        print("!! found broken strings:")
        for b in bad:
            print("  " + b)
        sys.exit(1)


def main():
    lint_strings()
    rs = dir_children(os.path.join(SRC, "ReplicatedStorage"))
    assets = item("Folder", "Animals", model_items("Animals"))
    assets += item("Folder", "Props", model_items("Props"))
    assets += item("Folder", "Weapons", model_items("Weapons"))
    assets += item("Folder", "Creatures", model_items("Creatures"))  # โมเดลจาก Creator Store (tools/store_to_rbxmx.py)
    assets += item("Folder", "Characters", model_items("Characters"))
    rs += item("Folder", "Assets", assets)
    if TEST or SHOTS:
        rs += value_item("BoolValue", "ASAutoTest", "true")
        if SHOTS:
            rs += value_item("BoolValue", "ASShots", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        if CREATURES:
            rs += value_item("BoolValue", "ASCreatureShow", "true")
        if GALLERY:
            rs += value_item("BoolValue", "ASGallery", "true")
        if ANIMTEST:
            rs += value_item("StringValue", "ASAnimTest", ANIMTEST)
    if SANDBOX:
        rs += value_item("BoolValue", "ASSandbox", "true")
    if SEED:
        rs += value_item("IntValue", "ASSeed", SEED)

    sss = dir_children(os.path.join(SRC, "ServerScriptService"))
    sps = dir_children(os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts"))
    scs = ""
    sgui = os.path.join(SRC, "StarterGui")
    if os.path.isdir(sgui):
        scs = dir_children(sgui)
    if TEST or SHOTS:
        sss += script_item(os.path.join(TESTS, "ASAutoTestServer.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASAutoTestClient.client.lua"))

    ss = ""
    if MAPSHOT:
        ss += value_item("BoolValue", "ASMapShot", "true")
    if ANIMALSHOT:
        ss += value_item("BoolValue", "ASAnimalShot", "true")
    if FETCH:
        ss += value_item("StringValue", "ASFetch", FETCH)
    if PROBE:
        ss += value_item("BoolValue", "ASProbe", "true")

    workspace_props = (
        '<bool name="StreamingEnabled">true</bool>'
        '<int name="StreamingMinRadius">192</int>'
        '<int name="StreamingTargetRadius">900</int>'
        '<float name="Gravity">196.2</float>'
    )
    lighting_props = (
        '<token name="Technology">4</token>'  # Future
        '<float name="Brightness">2.4</float>'
        '<float name="EnvironmentDiffuseScale">1</float>'
        '<float name="EnvironmentSpecularScale">1</float>'
        '<bool name="GlobalShadows">true</bool>'
        '<float name="ShadowSoftness">0.18</float>'
        '<float name="ClockTime">8.5</float>'
        '<float name="GeographicLatitude">23</float>'
    )

    body = ""
    body += item("Workspace", "Workspace", extra_props=workspace_props)
    body += item("Lighting", "Lighting", extra_props=lighting_props)
    body += item("ReplicatedStorage", "ReplicatedStorage", rs)
    body += item("ServerScriptService", "ServerScriptService", sss)
    body += item("ServerStorage", "ServerStorage", ss)
    body += item("StarterGui", "StarterGui", scs, extra_props='<bool name="ResetPlayerGuiOnSpawn">false</bool>')
    body += item(
        "StarterPlayer",
        "StarterPlayer",
        item("StarterPlayerScripts", "StarterPlayerScripts", sps),
        extra_props='<float name="CharacterWalkSpeed">18</float><float name="CameraMaxZoomDistance">90</float>',
    )

    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "<External>null</External><External>nil</External>\n" + body + "</roblox>\n"
    )
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print("Built:", OUT, f"({len(xml) // 1024} KB)")


if __name__ == "__main__":
    sys.exit(main())
