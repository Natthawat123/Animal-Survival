"""
render_cli.py — เรนเดอร์ไฟล์ .blend แบบไม่เปิดหน้าต่าง (รันเบื้องหลังได้)
  blender -b blender/keyart_bonfire.blend --python blender/render_cli.py -- art/out.png 1920 1080 96 [camera_name]
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "//render.png"
w = int(args[1]) if len(args) > 1 else 1920
h = int(args[2]) if len(args) > 2 else 1080
samples = int(args[3]) if len(args) > 3 else 64
cam = args[4] if len(args) > 4 else None

sc = bpy.context.scene
sc.render.resolution_x = w
sc.render.resolution_y = h
sc.render.resolution_percentage = 100
try:
    sc.eevee.taa_render_samples = samples
except Exception:
    pass
if cam and cam in bpy.data.objects:
    sc.camera = bpy.data.objects[cam]
sc.render.filepath = out
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
