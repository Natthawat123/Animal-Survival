import sys
sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import rigged_export as rx
PP = r"E:\GAME\roblox\Animal Survival\assets\downloads\pp"
rx.export("Wolf", PP + r"\Wolf_P1gU3Qkr9r.glb", size=("length", 6.0),
          clips={"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack", "Death": "Death", "Eat": "Eating", "Hit": "HitReact"})
