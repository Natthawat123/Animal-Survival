import sys
sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import autorig as ar
S = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp_static\\"
ids = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None
JOBS = {
    "T_Bear": dict(src=S + "Bear_kLLBpmcw0w.glb"),
    "T_Boar": dict(src=S + "Boar_57fSWum6F1P.glb"),
    "T_Lynx": dict(src=S + "Bobcat_bvsVdF1hLme.glb"),
    "T_Caiman": dict(src=S + "Blackcaiman_5etIv4omd7Z.glb", leg_top=0.35),
    "T_Ram": dict(src=S + "Ram_fm86jjk4m7D.glb"),
    "T_Salamander": dict(src=S + "Salamander_eqjMAgmr-pM.glb", leg_top=0.4),
}
for k, v in JOBS.items():
    if ids and k not in ids:
        continue
    try:
        ar.export(k, **v)
    except Exception:
        import traceback; traceback.print_exc()
