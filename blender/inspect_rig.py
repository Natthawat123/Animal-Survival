"""
inspect_rig.py — พิมพ์โครงกระดูกของไฟล์ GLB (ชื่อกระดูก, พ่อแม่, ตำแหน่งหัว/หาง) ไว้เลือกกระดูกขา/หัว/หาง ทำท่าเดิน
รัน: blender -b --factory-startup --python blender/inspect_rig.py -- <in.glb>
"""
import sys

import bpy

SRC = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in bpy.context.scene.objects:
    if o.type == "ARMATURE":
        print("RIG", o.name, "scale", tuple(round(v, 4) for v in o.scale))
        for b in o.data.bones:
            h = o.matrix_world @ b.head_local
            t = o.matrix_world @ b.tail_local
            print("BONE", b.name, "| parent", b.parent.name if b.parent else "-", "| head", tuple(round(v, 3) for v in h), "| tail", tuple(round(v, 3) for v in t))
    elif o.type == "MESH":
        print("MESH", o.name, "verts", len(o.data.vertices), "dims", tuple(round(v, 3) for v in o.dimensions), "groups", len(o.vertex_groups))
