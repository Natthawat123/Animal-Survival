"""
import_armor.py — เกราะ 3 ระดับจาก Creator Store -> assets/rbxm/Armor/<ItemId>.rbxmx (ReplicatedStorage.Assets.Armor)

  python tools/import_armor.py

  WoodArmor  (10875544933  Wood Armour)               : เสื้อเกราะไม้ (Part + SpecialMesh ขนาดลำตัว R6)
  IronArmor  (137930295074690 silver platebody)       : เกราะเหล็กเงินมีบ่า (MeshPart)
  GoldArmor  (160532987 The Great Redcliff Lord TORSO): เกราะทองลายสลัก (Part + SpecialMesh ขนาด 2 เท่าลำตัว)
ต้องดึงโมเดลก่อน: python tools/fetch_models.py 10875544933 137930295074690 160532987
การสวม/ย่อขยายให้พอดีตัว: src/ReplicatedStorage/Shared/ArmorModels.lua
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_to_rbxmx  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")
SRC = {"WoodArmor": "10875544933", "IronArmor": "137930295074690", "GoldArmor": "160532987"}
KEEP = {"Model", "Part", "MeshPart", "SpecialMesh"}

for name, aid in SRC.items():
    d = json.load(open(os.path.join(STORE, f"{aid}.json"), encoding="utf-8"))
    for i, it in enumerate(d["Items"], 1):
        if i == 1:
            it["C"] = "Model"  # ต้นฉบับบางชิ้นเป็น Tool (ใส่แบบหมวก) -> โมเดลธรรมดา
        elif it["C"] not in KEEP:
            it["C"] = "_drop"
        elif it["C"] in ("Part", "MeshPart"):
            it["N"] = "Armor"
            it["DoubleSided"] = True  # เกราะเหล็กเป็นเปลือกด้านเดียว -> มองจากหลังทะลุ
        for k in ("MeshId", "TextureId", "TextureID"):
            if isinstance(it.get(k), str):
                it[k] = it[k].strip()  # ต้นฉบับบางชิ้นมีช่องว่างท้าย URL -> เมชโหลดไม่ขึ้น (เกราะไม้ล่องหน)
    json.dump(d, open(os.path.join(STORE, f"{name}_src.json"), "w", encoding="utf-8"), ensure_ascii=False)
    store_to_rbxmx.convert(f"{name}_src", name, "Armor")
    print(name, "<-", aid)
