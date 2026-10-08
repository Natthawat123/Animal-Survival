"""พิมพ์ข้อมูลไฟล์ตัวละคร (วัตถุ วัสดุ แอนิเมชัน) — blender -b --factory-startup --python inspect_chars.py -- <file.blend> ..."""
import sys

import bpy

files = sys.argv[sys.argv.index("--") + 1:]
for f in files:
    with bpy.data.libraries.load(f, link=False) as (src, dst):
        dst.objects = list(src.objects)
        dst.actions = list(src.actions)
    print("=====", f.split("\\")[-1].split("/")[-1])
    for o in dst.objects:
        if o is None:
            continue
        extra = ""
        if o.type == "MESH":
            extra = f" verts={len(o.data.vertices)} mats={[m.name for m in o.data.materials if m]}"
        print(f"  {o.type:9} {o.name}{extra} parent={o.parent.name if o.parent else None}")
    print("  actions:", [a.name for a in dst.actions][:40])
    for m in bpy.data.materials:
        img = None
        if m.use_nodes:
            img = next((n.image.name for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
        print("   mat", m.name, tuple(round(x, 2) for x in m.diffuse_color[:3]), "img=", img)
    for o in list(dst.objects):
        if o:
            bpy.data.objects.remove(o)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
