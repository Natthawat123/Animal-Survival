import sys
sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import characters_export as ce
ids = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None
ce.build_all(ids or None)
