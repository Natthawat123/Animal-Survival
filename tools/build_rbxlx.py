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
ARMORPROBE = "--armorprobe" in sys.argv
MEDPROBE = "--medprobe" in sys.argv  # ถือยา + ท่าพันแผล/ช่วยเพื่อน (tests/ASMedProbe.*.lua)  # คราฟต์เกราะ 3 ระดับ + ภาพบนตัว (tests/ASArmorProbe.*.lua)
PADPROBE = "--padprobe" in sys.argv  # แท่นเริ่มเกม: เลือกจำนวนก่อนค่อยนับ (tests/ASPadProbe.client.lua)
COOKPROBE = "--cookprobe" in sys.argv  # ย่างเนื้อที่กองไฟ + ไม่ดูดของจากไกล (tests/ASCookProbe.*.lua)
BERRYPROBE = "--berryprobe" in sys.argv  # พุ่มเบอร์รี่ เก็บ/กิน + ปุ่มกินบน HUD (tests/ASBerryProbe.*.lua)
REJOINPROBE = "--rejoinprobe" in sys.argv  # จำลองทุกคนหลุด -> เซฟรอบ -> คืนรอบ (tests/ASRejoinProbe.server.lua)
SKIPPROBE = "--skipprobe" in sys.argv  # นับคืน + ข้ามวัน + ฝูงบุก + คืนบอส (tests/ASSkipProbe.server.lua)
GATEPROBE = "--gateprobe" in sys.argv  # ซุ้มประตูมิติ 8 แบบ (tests/ASGateProbe.*.lua)
SHRINEPROBE = "--shrineprobe" in sys.argv  # ฉากเปิด/จบศาลเจ้า + เสาผลึก + ลูกสัตว์ที่แคมป์ + ขี่ (tests/ASShrineProbe.*.lua)
MONPROBE = any(a.startswith("--monprobe") for a in sys.argv)
MONIDS = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--monprobe=")), "")  # --monprobe=Id,Id เลือกตัว  # สัตว์ไบโอมน้ำ ยืน/เดิน/โจมตี/ตาย (tests/ASMonProbe.*.lua)
SACKPROBE = "--sackprobe" in sys.argv  # ภาพถือกระสอบ 3 แบบ (tests/ASSackProbe.*.lua)
FOGPROBE = "--fogprobe" in sys.argv  # เช็กกำแพงหมอกตามเลเวลกองไฟ (tests/ASFogProbe.*.lua)
BOSSSKILL = next((a for a in sys.argv if a.startswith("--bossskill")), None)  # ใช้ทุกสกิลบอส + ถ่ายภาพ (tests/ASBossSkill.*.lua) · =Id,Id เฉพาะตัว
REALMPROBE = any(a.startswith("--realmprobe") for a in sys.argv)  # เดินผ่านประตูมิติศาลเจ้า/วิหาร + สู้บอสในรังจริง (tests/ASRealmProbe.*.lua) แมพขนาดจริง
BOSSPROBE = "--bossprobe" in sys.argv  # ถ่ายภาพฉากเปิดตัวบอสทั้ง 4 (tests/ASBossProbe.*.lua)
CLASSPROBE = "--classprobe" in sys.argv  # ถ่ายภาพร้านคลาสทีละคลาส (tests/ASClassProbe.client.lua)
PROPPROBE = "--propprobe" in sys.argv  # วัดขนาดพุ่ม/เห็ด/ต้นไม้ในแมพจริง + ถ่ายภาพ (tests/ASPropProbe.server.lua)
UIAUDIT = next((a for a in sys.argv if a.startswith("--uiaudit")), None)  # จำลองจอหลายขนาด ตรวจ UI ล้น/ทับ/ตัวเล็ก (tests/ASUIAudit.*.lua) · =touch มือถือ/แท็บเล็ต
UIPROBE = "--uiprobe" in sys.argv  # ถ่ายภาพหน้าต่าง ภารกิจ/ป้าย/ร้านค้า/ตั้งค่า (tests/ASUIProbe.client.lua)
SITEPROBE = "--siteprobe" in sys.argv  # ถ่ายภาพศาลเจ้า/ฐานบอส/วิหาร ทุกธาตุ (tests/ASSiteProbe.*.lua)
LOOTPROBE = "--lootprobe" in sys.argv  # กติกาดรอปใหม่: AnyEssence/บอสรัง/วิหารออร่า/เกราะหน่วยลาดตระเวน (tests/ASLootProbe.*.lua)
BREAKPROBE = "--breakprobe" in sys.argv  # วาง/พังสิ่งก่อสร้างทุกแบบ + โค่นต้นไม้/หิน/คริสตัล (tests/ASBreakProbe.*.lua)
TOOLSPAM = "--toolspam" in sys.argv  # กดสลับของในแถบเครื่องมือรัวๆ เช็ก Tool งอก + ช่องยา (tests/ASToolSpam.*.lua)
DROPPROBE = "--dropprobe" in sys.argv  # เสกของตกหน้าผู้เล่น เช็กว่ามองเห็น/อยู่บนพื้น/เก็บได้ (tests/ASDropProbe.*.lua)
CAMPPROBE = "--campprobe" in sys.argv  # ถ่ายภาพกองไฟล็อบบี้/แคมป์ (tests/ASCampProbe.client.lua)
LOBBYPROBE = "--lobbyprobe" in sys.argv  # วัดของจม/ลอยในล็อบบี้เทียบพื้นจริง (tests/ASLobbyProbe.client.lua)
GALLERY = "--gallery" in sys.argv  # สตูดิโอถ่ายภาพ: สัตว์/ไอเทม/คลาส ทีละตัว
VFXSHOW = next((a.split("=", 1)[1] if "=" in a else "*" for a in sys.argv if a.startswith("--vfxshow")), None)  # เทสต์: เล่น VFX ทีละตัวแล้วถ่ายภาพ (--vfxshow=Massive = เฉพาะแพ็ก)

if GALLERY or VFXSHOW:
    TEST = True
if TEST or SHOTS or TOOLSPAM or BREAKPROBE or LOOTPROBE or DROPPROBE or LOBBYPROBE or SITEPROBE or CLASSPROBE or UIPROBE or UIAUDIT or PROPPROBE or BOSSPROBE or FOGPROBE or SACKPROBE or BOSSSKILL or REALMPROBE or MONPROBE or SHRINEPROBE or GATEPROBE or REJOINPROBE or SKIPPROBE or BERRYPROBE or COOKPROBE or PADPROBE or ARMORPROBE or MEDPROBE:
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
if MONIDS:  # เลือกตัวเอง = เช็กเฉพาะกิจ ใช้ไฟล์แยกเหมือนกัน
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_MON.rbxlx")
if SHRINEPROBE:  # ไฟล์แยก: หลายเซสชันเทสพร้อมกัน ไม่ทับ AnimalSurvival_TEST ของกันและกัน
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_SHRINE.rbxlx")
if UIAUDIT:  # ไฟล์แยกเหมือนกัน
    OUT = os.path.join(OUT_DIR, "AnimalSurvival_UIAUDIT.rbxlx")

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


SHARED = {}  # SharedStrings จากโมเดล Import 3D (ข้อมูลเมช/รูปทรงชน) -> รวมไว้ท้ายไฟล์ place


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
            # SharedStrings ต้องอยู่ระดับบนสุดของไฟล์ ไม่ใช่ในโฟลเดอร์ -> แยกเก็บไว้ใส่ท้ายไฟล์
            m = re.search(r"<SharedStrings>(.*?)</SharedStrings>", body, re.S)
            if m:
                # รวมแบบปิดตัวเอง <SharedString md5="..." /> (สตริงว่าง) ด้วย -> ไม่งั้น Studio เปิดไม่ได้ (Unknown referenced shared string)
                for ss in re.finditer(r'<SharedString md5="([^"]+)"\s*(?:/>|>(.*?)</SharedString>)', m.group(1), re.S):
                    SHARED[ss.group(1)] = f'<SharedString md5="{ss.group(1)}">{ss.group(2) or ""}</SharedString>'
                body = body[: m.start()] + body[m.end():]
            body = re.sub(r'referent="([^"]+)"', lambda m: f'referent="{sub}{i}_{m.group(1)}"', body)
            body = re.sub(r'(<Ref name="[^"]+">)(RBX[^<]+)(</Ref>)', lambda m: f"{m.group(1)}{sub}{i}_{m.group(2)}{m.group(3)}", body)
            if sub == "Animals":  # โมเดล Store (store_to_rbxmx) ใช้รหัส S...: ไม่แก้ด้วย ข้อต่อ Motor6D จะชี้ไปชิ้นที่ไม่มีอยู่
                body = re.sub(r'(<Ref name="Part[01]">)(S\d[^<]*)(</Ref>)', lambda m: f"{m.group(1)}{sub}{i}_{m.group(2)}{m.group(3)}", body)
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
    assets += item("Folder", "Items", model_items("Items"))
    assets += item("Folder", "Armor", model_items("Armor"))  # เกราะ 3 ระดับจาก Creator Store (tools/import_armor.py)
    assets += item("Folder", "Characters", model_items("Characters"))
    assets += item("Folder", "VFX", model_items("VFX"))  # เอฟเฟกต์อนุภาคจาก Creator Store (ใช้กับสกิลบอส)
    rs += item("Folder", "Assets", assets)
    if TEST or SHOTS:
        rs += value_item("BoolValue", "ASAutoTest", "true")
        if SHOTS:
            rs += value_item("BoolValue", "ASShots", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        if GALLERY:
            rs += value_item("BoolValue", "ASGallery", "true")
        if VFXSHOW:
            rs += value_item("StringValue", "ASVFXShow", VFXSHOW)
    if CAMPPROBE:
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASCampProbe", "true")
    if LOBBYPROBE:
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        rs += value_item("BoolValue", "ASLobbyProbe", "true")
    if PROPPROBE:
        rs += value_item("BoolValue", "ASPropProbe", "true")
        rs += value_item("BoolValue", "ASSiteProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if UIAUDIT:
        rs += value_item("BoolValue", "ASUIAudit", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        if UIAUDIT == "--uiaudit=touch":
            rs += value_item("BoolValue", "ASSimTouch", "true")
    if UIPROBE:
        rs += value_item("BoolValue", "ASUIProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if CLASSPROBE:
        rs += value_item("BoolValue", "ASClassProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if LOOTPROBE:
        rs += value_item("BoolValue", "ASLootProbe", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if BREAKPROBE:
        rs += value_item("BoolValue", "ASBreakProbe", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if TOOLSPAM:
        rs += value_item("BoolValue", "ASToolSpam", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if DROPPROBE:
        rs += value_item("BoolValue", "ASDropProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
    if MEDPROBE:
        rs += value_item("BoolValue", "ASMedProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if ARMORPROBE:
        rs += value_item("BoolValue", "ASArmorProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if PADPROBE:
        rs += value_item("BoolValue", "ASPadProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if COOKPROBE:
        rs += value_item("BoolValue", "ASCookProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if BERRYPROBE:
        rs += value_item("BoolValue", "ASBerryProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if REJOINPROBE:
        rs += value_item("BoolValue", "ASRejoinProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if SKIPPROBE:
        rs += value_item("BoolValue", "ASSkipProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if GATEPROBE:
        rs += value_item("BoolValue", "ASGateProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if SHRINEPROBE:
        rs += value_item("BoolValue", "ASShrineProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")
    if MONPROBE:
        rs += value_item("BoolValue", "ASMonProbe", "true")
        rs += value_item("StringValue", "ASMonIds", MONIDS)
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")  # ไม่ต้องรอคำนวณกล่องชนอาคาร (หลายนาที)
    if SACKPROBE:
        rs += value_item("BoolValue", "ASSackProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
    if FOGPROBE:
        rs += value_item("BoolValue", "ASFogProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
    if BOSSSKILL:
        rs += value_item("BoolValue", "ASBossSkill", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
        if "=" in BOSSSKILL:
            rs += value_item("StringValue", "ASBossOnly", BOSSSKILL.split("=", 1)[1])
    if REALMPROBE:
        rs += value_item("BoolValue", "ASRealmProbe", "true")
        rs += value_item("BoolValue", "ASSiteProbe", "true")  # แมพขนาดจริง (ไม่ใช่แมพเล็กของเทสต์)
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
        rs += value_item("StringValue", "ASSiteKinds", "None")  # สคริปต์ siteprobe ไม่ต้องเดินเอง
        _rp = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--realmprobe=lairs")), None)
        if _rp:
            rs += value_item("StringValue", "ASRealmOnly", _rp)
        elif "--realmprobe=realms" in sys.argv:
            rs += value_item("StringValue", "ASRealmOnly", "realms")
    if BOSSPROBE:
        rs += value_item("BoolValue", "ASBossProbe", "true")
        rs += value_item("BoolValue", "ASAutoTest", "true")
    if SITEPROBE:
        rs += value_item("BoolValue", "ASSiteProbe", "true")
        kinds = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--sitekinds=")), "")
        if kinds:
            rs += value_item("StringValue", "ASSiteKinds", kinds)
        rs += value_item("BoolValue", "ASAutoTest", "true")
        rs += value_item("BoolValue", "ASLobbyTest", "true")
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
    if CLASSPROBE:
        sps += script_item(os.path.join(TESTS, "ASClassProbe.client.lua"))
    if PROPPROBE:
        sss += script_item(os.path.join(TESTS, "ASPropProbe.server.lua"))
    if UIAUDIT:
        sss += script_item(os.path.join(TESTS, "ASUIAudit.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASUIAudit.client.lua"))
    if UIPROBE:
        sps += script_item(os.path.join(TESTS, "ASUIProbe.client.lua"))
    if MEDPROBE:
        sss += script_item(os.path.join(TESTS, "ASMedProbe.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASMedProbe.client.lua"))
    if ARMORPROBE:
        sss += script_item(os.path.join(TESTS, "ASArmorProbe.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASArmorProbe.client.lua"))
    if PADPROBE:
        sps += script_item(os.path.join(TESTS, "ASPadProbe.client.lua"))
    if COOKPROBE:
        sss += script_item(os.path.join(TESTS, "ASCookProbe.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASCookProbe.client.lua"))
    if BERRYPROBE:
        sss += script_item(os.path.join(TESTS, "ASBerryProbe.server.lua"))
        sps += script_item(os.path.join(TESTS, "ASBerryProbe.client.lua"))
    if REJOINPROBE:
        sss += script_item(os.path.join(TESTS, "ASRejoinProbe.server.lua"))
    if SKIPPROBE:
        sss += script_item(os.path.join(TESTS, "ASSkipProbe.server.lua"))
    if GATEPROBE:
        sps += script_item(os.path.join(TESTS, "ASGateProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASGateProbe.server.lua"))
    if SHRINEPROBE:
        sps += script_item(os.path.join(TESTS, "ASShrineProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASShrineProbe.server.lua"))
    if MONPROBE:
        sps += script_item(os.path.join(TESTS, "ASMonProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASMonProbe.server.lua"))
    if SACKPROBE:
        sps += script_item(os.path.join(TESTS, "ASSackProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASSackProbe.server.lua"))
    if FOGPROBE:
        sps += script_item(os.path.join(TESTS, "ASFogProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASFogProbe.server.lua"))
    if BOSSSKILL:
        sps += script_item(os.path.join(TESTS, "ASBossSkill.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASBossSkill.server.lua"))
    if REALMPROBE:
        sps += script_item(os.path.join(TESTS, "ASRealmProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASRealmProbe.server.lua"))
    if BOSSPROBE:
        sps += script_item(os.path.join(TESTS, "ASBossProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASBossProbe.server.lua"))
    if SITEPROBE:
        sps += script_item(os.path.join(TESTS, "ASSiteProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASSiteProbe.server.lua"))
    if LOOTPROBE:
        sps += script_item(os.path.join(TESTS, "ASLootProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASLootProbe.server.lua"))
    if BREAKPROBE:
        sps += script_item(os.path.join(TESTS, "ASBreakProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASBreakProbe.server.lua"))
    if TOOLSPAM:
        sps += script_item(os.path.join(TESTS, "ASToolSpam.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASToolSpam.server.lua"))
    if DROPPROBE:
        sps += script_item(os.path.join(TESTS, "ASDropProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASDropProbe.server.lua"))
    if CAMPPROBE:
        sps += script_item(os.path.join(TESTS, "ASCampProbe.client.lua"))
    if LOBBYPROBE:
        sps += script_item(os.path.join(TESTS, "ASLobbyProbe.client.lua"))
        sss += script_item(os.path.join(TESTS, "ASWeaponProbe.server.lua"))

    ss = item("Folder", "LobbyArt", model_items("LobbyArt"))  # ฉากล็อบบี้ป่าโบราณ (tools/lobby_art.py)
    ss += item("Folder", "WorldArt", model_items("WorldArt"))  # วิหารโบราณ 4 ธาตุ (tools/world_art.py)
    if MAPSHOT:
        ss += value_item("BoolValue", "ASMapShot", "true")
    if ANIMALSHOT:
        ss += value_item("BoolValue", "ASAnimalShot", "true")
        rs += value_item("BoolValue", "ASSkipCollision", "true")  # ถ่ายรูปสัตว์ไม่ต้องรอคำนวณกล่องชน (หลายนาที)
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
        item("StarterPlayerScripts", "StarterPlayerScripts", sps)
        + item("StarterCharacterScripts", "StarterCharacterScripts", dir_children(os.path.join(SRC, "StarterPlayer", "StarterCharacterScripts"))),
        extra_props='<float name="CharacterWalkSpeed">18</float><float name="CameraMaxZoomDistance">90</float>',
    )

    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "<External>null</External><External>nil</External>\n" + body
        + (("<SharedStrings>" + "".join(SHARED.values()) + "</SharedStrings>\n") if SHARED else "")
        + "</roblox>\n"
    )
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print("Built:", OUT, f"({len(xml) // 1024} KB)")


if __name__ == "__main__":
    sys.exit(main())
