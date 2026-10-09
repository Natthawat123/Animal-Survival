"""ภาพรวมโมเดล glb ทั้งโฟลเดอร์: เรนเดอร์ทีละตัว + พิมพ์ จำนวนสามเหลี่ยม/กระดูก/ท่า
blender -b --factory-startup --python survey_glb.py -- <dir> <outdir> [filter...]
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
FILT = args[2:]
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def render(path):
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 320
    sc.render.resolution_y = 320
    sc.render.filepath = path
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.32, 0.36, 0.42, 1)
    bg.inputs[1].default_value = 1.2
    sc.world = w
    bpy.ops.render.render(write_still=True)


report = {}
files = sorted(f for f in os.listdir(SRC) if f.endswith(".glb") and (not FILT or any(x.lower() in f.lower() for x in FILT)))
for f in files:
    reset()
    try:
        bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, f))
    except Exception as e:
        print("FAIL", f, e)
        continue
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    bones = sum(len(a.data.bones) for a in arms)
    acts = [a.name for a in bpy.data.actions]
    # ท่าแรก (idle ถ้ามี) เฟรมกลาง
    if arms and acts:
        idle = next((a for a in bpy.data.actions if "idle" in a.name.lower()), bpy.data.actions[0])
        ad = arms[0].animation_data or arms[0].animation_data_create()
        ad.action = idle
        try:
            if getattr(idle, "slots", None) and len(idle.slots) and ad.action_slot is None:
                ad.action_slot = idle.slots[0]
        except Exception:
            pass
        bpy.context.scene.frame_set(int(sum(idle.frame_range) / 2))
    bpy.context.view_layer.update()
    pts = []
    for o in meshes:
        ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    if not pts:
        continue
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    r = (mx - mn).length
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.location = c + Vector((r * 0.75, -r * 1.05, r * 0.45))
    d = c - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(45), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(sun)
    name = f[:-4]
    render(os.path.join(OUT, name + ".png"))
    report[name] = {"tris": tris, "bones": bones, "actions": acts, "size": [round(x, 2) for x in (mx - mn)]}
    print("OK", name, tris, bones, acts[:12])
json.dump(report, open(os.path.join(OUT, "report.json"), "w"), indent=1)
