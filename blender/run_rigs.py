"""ส่งออกสัตว์ทั้งหมด -> ReplicatedStorage/AnimRigs  (blender -b --factory-startup --python blender/run_rigs.py -- [Id ...])"""
import sys
import traceback

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import autorig as ar
import rigged_export as rx

PP = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp\\"
ST = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp_static\\"
RB = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp_rabbit\\"
CR = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp_crab\\"
C = lambda r, g, b: (r / 255, g / 255, b / 255)

ANIMAL = {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": ["Attack_Headbutt", "Attack"], "Death": "Death", "Eat": "Eating"}
FOX = {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack", "Death": "Death", "Eat": "Eating"}


def pup(color, light, eye):
    return dict(src=PP + "Fox_Bc97C66HKi.glb", size=("length", 3.2), clips=FOX,
                recolor={"Main": color, "Main_Light": light, "Grey": light, "Black": C(40, 40, 50)}, glow={"Eyes": eye})


JOBS = {
    # ---------------- มีกระดูก+ท่าในไฟล์ (Quaternius CC0)
    "Deer": ("rx", dict(src=PP + "Deer_T6Cs7tmMHJ.glb", size=("length", 7.0), clips=ANIMAL)),
    "Stag": ("rx", dict(src=PP + "Stag_tQdzbZ1Cmw.glb", size=("length", 8.0), clips=ANIMAL, tint=(0.2, 0.17, 0.22))),
    "Wolf": ("rx", dict(src=PP + "Wolf_P1gU3Qkr9r.glb", size=("length", 6.0), clips=FOX, tint=(0.9, 1.02, 0.88))),
    "Fox": ("rx", dict(src=PP + "Fox_Bc97C66HKi.glb", size=("length", 4.6), clips=FOX)),
    "PupTerra": ("rx", pup(C(110, 200, 80), C(200, 240, 170), C(160, 255, 120))),
    "PupTide": ("rx", pup(C(60, 160, 230), C(180, 225, 255), C(120, 230, 255))),
    "PupGale": ("rx", pup(C(215, 225, 245), C(250, 252, 255), C(170, 220, 255))),
    "PupEmber": ("rx", pup(C(240, 110, 40), C(255, 210, 150), C(255, 220, 90))),
    "Crab": ("ar", dict(src=CR + "Crab_bmZ6-LnPmp0.glb", kind="crab", keep_axis=True, yaw=-1.5708, size=("height", 2.2))),
    "Bull": ("rx", dict(src=PP + "Bull_a8PIIYwF7r.glb", size=("length", 8.0), clips=ANIMAL,
                        recolor={"Main": C(46, 34, 32), "Main_Light": C(70, 50, 44), "Muzzle": C(40, 30, 28), "Hooves": C(30, 24, 24)},
                        glow={"Horns": C(255, 130, 40), "Eye_White": C(255, 200, 80)})),
    # ---------------- โมเดลนิ่ง -> ใส่โครง+ท่าเอง (Poly by Google / madtrollstudio, CC-BY)
    "Rabbit": ("ar", dict(src=RB + "Rabbit_9OBTRVYUSmt.glb", size=("length", 2.4), hop=True, leg_top=0.38, tail_bones=1)),
    "Boar": ("ar", dict(src=ST + "Boar_57fSWum6F1P.glb", size=("length", 5.0), stride_deg=26)),
    "Bear": ("ar", dict(src=ST + "Bear_kLLBpmcw0w.glb", size=("length", 7.5), tint=(0.95, 1.0, 0.92), stride_deg=24, tail_bones=1, tail=0.93)),
    "Caiman": ("ar", dict(src=ST + "Blackcaiman_5etIv4omd7Z.glb", size=("length", 8.0), leg_top=0.35, neck=0.3, tail=0.6, tail_bones=3,
                         tint=(0.8, 1.05, 1.1), stride_deg=22, sprawl=True, leg_inner=0.05)),
    "Lynx": ("ar", dict(src=ST + "Bobcat_bvsVdF1hLme.glb", size=("length", 5.2), tint=(1.05, 1.1, 1.25))),
    "Ram": ("ar", dict(src=ST + "Ram_fm86jjk4m7D.glb", size=("length", 5.0), tint=(1.25, 1.3, 1.45))),
    "Salamander": ("ar", dict(src=ST + "Lizard_0z3NJc5zAE.glb", size=("length", 5.0), leg_top=0.4, neck=0.22, tail=0.55, tail_bones=3, sprawl=True, leg_inner=0.06, leg_radius=0.08,
                             glow_pick=(lambda c: c[0] > 0.55 and c[1] > 0.4 and c[2] < 0.35, C(255, 120, 30)))),
}


def run(ids=None):
    for rid, (kind, kw) in JOBS.items():
        if ids and rid not in ids:
            continue
        try:
            if kind == "rx":
                rx.export(rid, **kw)
            else:
                ar.export(rid, **kw)
        except Exception:
            print("FAILED", rid)
            traceback.print_exc()


if __name__ == "__main__":
    run(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None)
