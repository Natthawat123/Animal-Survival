"""ติดตั้งปลั๊กอิน Studio ของเกม: python tools/install_plugin.py (แล้วเปิด Studio ใหม่)"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(ROOT, "tools", "AnimalSurvivalStudio.plugin.lua")
dst_dir = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Plugins")
os.makedirs(dst_dir, exist_ok=True)
dst = os.path.join(dst_dir, "AnimalSurvivalStudio.lua")
shutil.copy2(src, dst)
print("Installed:", dst)
