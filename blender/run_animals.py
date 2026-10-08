import sys
sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import game_animals as ga
ids = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else None
ga.build_all(ids or None)
