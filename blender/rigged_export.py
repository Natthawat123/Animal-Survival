"""
rigged_export.py — โมเดลมีโครงกระดูก + แอนิเมชันจริง (glb/blend) -> ข้อมูลในเกม (ReplicatedStorage.AnimRigs/<Id>)

  1) จัดท่า REST, หันหัวไป -Y (= -Z ของ Roblox), เท้าที่ z=0, ย่อ/ขยายตามขนาดที่กำหนด
  2) แบ่งเมชเป็นชิ้นตามกระดูก (หน้าไหนกระดูกไหนมีน้ำหนักมากสุด = ชิ้นของกระดูกนั้น) -> MeshPart ต่อกระดูก
  3) สุ่มตัวอย่างทุกท่า (Idle/Walk/Run/Attack/Death/…) เป็นการหมุน/เลื่อน "สัมพัทธ์กับท่า rest" ของแต่ละกระดูก
     = Motor6D.Transform ในเกม (C0 = ตำแหน่ง rest เทียบกระดูกแม่, C1 = identity)

ผลลัพธ์ Lua: เหมือน mesh_export (Parts/Palette) + Rig = { Bones = {{Name, Parent, C0={12}}}, Height, Length } + Clips
พิกัด Roblox: x=-bx, y=bz, z=by (เมทริกซ์ M หมุนแท้ det=+1)
"""
import base64
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, r"E:\GAME\roblox\Animal Survival\blender")
import importlib

import mesh_export

importlib.reload(mesh_export)

ROOT = r"E:\GAME\roblox\Animal Survival"
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "AnimRigs")
PREVIEW = os.path.join(ROOT, "art", "rigs")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)
M3 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Blender -> Roblox


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    if path.lower().endswith(".glb") or path.lower().endswith(".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
            dst.actions = list(src.actions)
        for o in dst.objects:
            if o:
                bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.update()


def rigid(m):
    """แยก loc/rot (ทิ้ง scale)"""
    loc, rot, _ = m.decompose()
    return loc, rot.normalized()


def to_rbx_cf(loc, rot):
    """(loc, quat) Blender -> 12 ค่า CFrame Roblox (x,y,z,R00..R22)"""
    r = M3 @ rot.to_matrix() @ M3.transposed()
    p = M3 @ loc
    return [p.x, p.y, p.z, r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]]


def rbx_quat(rot):
    q = (M3 @ rot.to_matrix() @ M3.transposed()).to_quaternion()
    if q.w < 0:
        q = -q
    return q


def lin2srgb(x):
    return ((x * 1.055) ** (1 / 2.4) - 0.055) if x > 0.0031308 else x * 12.92


def mat_srgb(mat):
    c, _, _ = mesh_export.mat_info(mat)
    return c


# ---------------------------------------------------------------- ส่งออกหนึ่งตัว
def vcol_direct(m):
    """สีมาจาก vertex color ตรงๆ (ไม่ใช่ Mix กับค่าสีคงที่ เช่น Quaternius ที่ใช้ vcol เป็นแค่เงา)"""
    if not m.use_nodes:
        return False
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None or not bsdf.inputs["Base Color"].links:
        return False
    return bsdf.inputs["Base Color"].links[0].from_node.type in ("VERTEX_COLOR", "ATTRIBUTE")


def export(rid, src, size=("length", 6.0), clips=None, recolor=None, tint=None, glow=None, drop_mesh=None, head_bone=None,
           yaw=0.0, fps=20, preview=True, extra=None):
    """
    size: ("length"|"height", studs)
    clips: {"Idle": "action substring", ...} ชื่อในเกม -> ชื่อท่าในไฟล์ (หาแบบ contains, ไม่สนตัวพิมพ์)
    recolor: {material substring: (r,g,b) sRGB 0-1} · tint: (r,g,b) คูณทุกสี · glow: {material substring: (r,g,b)} -> Neon
    """
    reset()
    load(src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    def rigged(o):
        if any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers):
            return True
        p = o.parent
        while p is not None:
            if p == arm:
                return True
            p = p.parent
        return False
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and rigged(o) and not (drop_mesh and any(d.lower() in o.name.lower() for d in drop_mesh))]
    actions = list(bpy.data.actions)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()

    # ---- เมช rest ในพิกัดโลก
    rest_pts = []
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        rest_pts += [o.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    mn = Vector((min(p.x for p in rest_pts), min(p.y for p in rest_pts), min(p.z for p in rest_pts)))
    mx = Vector((max(p.x for p in rest_pts), max(p.y for p in rest_pts), max(p.z for p in rest_pts)))
    center = (mn + mx) / 2
    # ---- ทิศหัว: กระดูกหัว (หรือชื่อที่มี head) เทียบจุดกลาง
    bones = arm.data.bones
    hb = None
    if head_bone:
        hb = bones.get(head_bone)
    if hb is None:
        hb = next((b for b in bones if "head" in b.name.lower() and "end" not in b.name.lower()), None)
    fwd = Vector((0, -1, 0))
    if hb is not None:
        hp = arm.matrix_world @ hb.head_local
        d = Vector((hp.x - center.x, hp.y - center.y, 0))
        if d.length > 1e-4:
            fwd = d.normalized()
    ang = math.atan2(fwd.x, -fwd.y)  # หมุนให้ fwd -> -Y
    rotz = Matrix.Rotation(ang + yaw, 4, "Z")
    # ขนาด
    pts2 = [rotz @ (p - Vector((center.x, center.y, mn.z))) for p in rest_pts]
    mn2 = Vector((min(p.x for p in pts2), min(p.y for p in pts2), min(p.z for p in pts2)))
    mx2 = Vector((max(p.x for p in pts2), max(p.y for p in pts2), max(p.z for p in pts2)))
    dims = mx2 - mn2
    mode, val = size
    s = val / (dims.y if mode == "length" else dims.z)
    N = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(mn2.x + mx2.x) / 2, -(mn2.y + mx2.y) / 2, 0))) @ rotz @ Matrix.Translation(-Vector((center.x, center.y, mn.z)))
    height, length = dims.z * s, dims.y * s

    # ---- กระดูกที่ใช้: มีเมช หรือเป็นบรรพบุรุษของกระดูกที่มีเมช
    face_bone = {}  # (obj name, poly index) -> bone name
    used = set()
    for o in meshes:
        vg = {g.index: g.name for g in o.vertex_groups}
        parent_bone = o.parent_bone if (o.parent_type == "BONE" and o.parent_bone) else None
        me = o.data
        for p in me.polygons:
            acc = {}
            for vi in p.vertices:
                for g in me.vertices[vi].groups:
                    n = vg.get(g.group)
                    if n and n in bones and g.weight > 0:
                        acc[n] = acc.get(n, 0) + g.weight
            b = max(acc, key=acc.get) if acc else (parent_bone or bones[0].name)
            face_bone[(o.name, p.index)] = b
            used.add(b)
    keep = set()
    for name in used:
        b = bones[name]
        while b is not None:
            keep.add(b.name)
            b = b.parent
    order = [b.name for b in bones if b.name in keep]  # ตามลำดับลำดับชั้น (แม่มาก่อน)
    index = {n: i + 1 for i, n in enumerate(order)}

    # ---- frame rest ของกระดูก (หลัง N) แบบ rigid
    def rest_frame(name):
        return rigid(N @ arm.matrix_world @ bones[name].matrix_local)

    rest = {n: rest_frame(n) for n in order}

    def mat_of(lr):
        loc, rot = lr
        return Matrix.Translation(loc) @ rot.to_matrix().to_4x4()

    rest_m = {n: mat_of(rest[n]) for n in order}
    c0 = {}
    for n in order:
        par = bones[n].parent
        pm = rest_m[par.name] if (par is not None and par.name in keep) else Matrix.Identity(4)
        c0[n] = rigid(pm.inverted() @ rest_m[n])

    # ---- ชิ้นเมชต่อกระดูก (ในพิกัดหลัง N, rest)
    newmats = {}

    def remat(m):
        if m is None:
            return None
        key = m.name
        if key in newmats:
            return newmats[key]
        nm = m.name.lower()
        col = list(mat_srgb(m))
        _, _, img = mesh_export.mat_info(m)
        nmat = bpy.data.materials.new("RX_" + m.name)
        textured = img is not None
        for k, c in (recolor or {}).items():
            if k.lower() in nm:
                col = list(c)
                textured = False
        if tint:
            col = [min(1, a * b) for a, b in zip(col, tint)]
        nmat["as_color"] = col
        if vcol_direct(m) and not any(k.lower() in nm or k == "*" for k in (recolor or {})):
            nmat["as_vcol"] = True
            if tint:
                nmat["as_tint"] = list(tint)
        if textured:
            nmat.use_nodes = True
            t = nmat.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = img
            if tint:
                nmat["as_tint"] = list(tint)
        for k, c in (glow or {}).items():
            if k.lower() in nm:
                nmat["as_color"] = list(c)
                nmat["as_glow"] = list(c)
        newmats[key] = nmat
        return nmat

    groups = {}  # bone -> list of (obj, poly set)
    for (oname, pi), b in face_bone.items():
        groups.setdefault(b, {}).setdefault(oname, []).append(pi)
    parts = {}
    for b, per_obj in groups.items():
        bm_all = bmesh.new()
        mats = []
        for oname, polys in per_obj.items():
            o = bpy.data.objects[oname]
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            bm = bmesh.new()
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            keepset = set(polys)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keepset], context="FACES")
            bm.transform(N @ o.matrix_world)
            # รวมวัสดุ
            offset = len(mats)
            for m in me.materials:
                mats.append(remat(m))
            for f in bm.faces:
                f.material_index += offset
            tmp = bpy.data.meshes.new("tmp")
            bm.to_mesh(tmp)
            bm.free()
            bm_all.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
            ev.to_mesh_clear()
        mesh = bpy.data.meshes.new("P_" + b)
        bm_all.to_mesh(mesh)
        bm_all.free()
        for m in mats:
            mesh.materials.append(m)
        if len(mesh.polygons) == 0:
            continue
        for p in mesh.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new("B%d" % index[b], mesh)
        bpy.context.scene.collection.objects.link(ob)
        parts["B%d" % index[b]] = ob
    # ชิ้นเรืองแสง: แยกหน้าของวัสดุ glow ออกเป็นชิ้น Glow_xxx ติดกับกระดูกเดียวกัน
    glow_parts = {}
    for pname, ob in list(parts.items()):
        me = ob.data
        gidx = {i for i, m in enumerate(me.materials) if m and m.get("as_glow") is not None}
        if not gidx:
            continue
        gfaces = [p.index for p in me.polygons if p.material_index in gidx]
        if not gfaces:
            continue
        col = me.materials[next(iter(gidx))]["as_glow"]
        gname = "Glow_%02x%02x%02x_%s" % (int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), pname)
        for keepglow, target in ((True, gname), (False, pname)):
            bm = bmesh.new()
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            gs = set(gfaces)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.index in gs) != keepglow], context="FACES")
            nm = bpy.data.meshes.new(target)
            bm.to_mesh(nm)
            bm.free()
            for m in me.materials:
                nm.materials.append(m)
            if keepglow:
                glow_parts[target] = (nm, col)
            elif len(nm.polygons) > 0:
                ob.data = nm
            else:
                del parts[pname]
    for gname, (nm, col) in glow_parts.items():
        ob = bpy.data.objects.new(gname, nm)
        bpy.context.scene.collection.objects.link(ob)
        parts[gname] = ob
    if preview:
        render_preview(rid, list(parts.values()))

    # ---- ท่าทาง
    arm.data.pose_position = "POSE"
    clip_data = {}
    for game_name, want in (clips or {}).items():
        wants = want if isinstance(want, (list, tuple)) else [want]
        act = None
        for w in wants:
            act = next((a for a in actions if a.name.lower().split("|")[-1] == w.lower()), None) or \
                next((a for a in actions if w.lower() in a.name.lower()), None)
            if act:
                break
        if not act:
            print("  (ไม่มีท่า)", game_name, wants)
            continue
        ad.action = act
        try:
            if getattr(act, "slots", None) and len(act.slots) and ad.action_slot is None:
                ad.action_slot = act.slots[0]
        except Exception:
            pass
        f0, f1 = act.frame_range
        scene_fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
        dur = (f1 - f0) / scene_fps
        nframes = max(2, int(round(dur * fps)) + 1)
        qbuf = bytearray()
        tvals = []
        for k in range(nframes):
            fr = f0 + (f1 - f0) * k / (nframes - 1)
            bpy.context.scene.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
            posed = {}
            for n in order:
                pb = arm.pose.bones[n]
                posed[n] = mat_of(rigid(N @ arm.matrix_world @ pb.matrix))
            for n in order:
                par = bones[n].parent
                pm = posed[par.name] if (par is not None and par.name in keep) else Matrix.Identity(4)
                c0m = mat_of(c0[n])
                t = c0m.inverted() @ pm.inverted() @ posed[n]
                loc, rot = rigid(t)
                q = rbx_quat(rot)
                qbuf += struct.pack("<4h", *(int(round(max(-1, min(1, x)) * 32767)) for x in (q.x, q.y, q.z, q.w)))
                p = M3 @ loc
                tvals.append((p.x, p.y, p.z))
        tmax = max(1e-6, max(abs(v) for t3 in tvals for v in t3))
        tbuf = bytearray()
        for t3 in tvals:
            tbuf += struct.pack("<3h", *(int(round(v / tmax * 32767)) for v in t3))
        clip_data[game_name] = {"Fps": fps, "N": nframes, "Dur": dur, "Q": base64.b64encode(bytes(qbuf)).decode(),
                                "T": base64.b64encode(bytes(tbuf)).decode(), "TS": tmax, "Src": act.name}
        print("  clip", game_name, "<-", act.name, nframes, "frames", round(dur, 2), "s")
    ad.action = None

    # ---- เขียนไฟล์
    path = mesh_export.export(rid, parts, out_dir=OUT)
    lines = open(path, encoding="utf-8").read().rstrip()
    assert lines.endswith("}")
    lines = lines[:-1]
    rig = ["\tRig = {", f"\t\tHeight = {height:.3f},", f"\t\tLength = {length:.3f},", "\t\tBones = {"]
    for n in order:
        par = bones[n].parent
        pi = index[par.name] if (par is not None and par.name in keep) else 0
        cf = to_rbx_cf(*c0[n])
        rig.append('\t\t\t{ Name = "%s", Parent = %d, C0 = { %s } },' % (n.replace('"', ""), pi, ", ".join("%.5f" % x for x in cf)))
    rig += ["\t\t},", "\t},", "\tClips = {"]
    for g, c in clip_data.items():
        rig.append('\t\t%s = { Fps = %d, N = %d, Dur = %.4f, TS = %.6f, Src = "%s",' % (g, c["Fps"], c["N"], c["Dur"], c["TS"], c["Src"].replace('"', "")))
        rig.append('\t\t\tQ = "%s",' % c["Q"])
        rig.append('\t\t\tT = "%s",' % c["T"])
        rig.append("\t\t},")
    rig.append("\t},")
    if extra:
        for k, v in extra.items():
            rig.append(f"\t{k} = {v},")
    out = lines + "\n".join(rig) + "\n}\n"
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    print(f"[rigged_export] {rid}: bones {len(order)} parts {len(parts)} clips {list(clip_data)} -> {os.path.getsize(path)//1024} KB")
    return path


def render_preview(rid, objs):
    pts = []
    for o in objs:
        pts += [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    r = (mx - mn).length
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 360
    sc.render.filepath = os.path.join(PREVIEW, rid + ".png")
    # สีแบบที่เกมจะเห็น (สีฐาน + texture) ใช้วัสดุเดิมอยู่แล้ว / ชิ้น glow ใส่ emission
    for o in objs:
        for m in o.data.materials:
            if m and m.get("as_glow") is not None and not m.use_nodes:
                m.use_nodes = True
            if m and not m.use_nodes:
                m.use_nodes = True
            if m:
                bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                tex = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None)
                if bsdf is None:
                    bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
                    outn = next((n for n in m.node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None) or m.node_tree.nodes.new("ShaderNodeOutputMaterial")
                    m.node_tree.links.new(bsdf.outputs[0], outn.inputs[0])
                if m.get("as_vcol"):
                    vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
                    m.node_tree.links.new(vc.outputs[0], bsdf.inputs["Base Color"])
                elif tex is not None and len(bsdf.inputs["Base Color"].links) == 0:
                    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
                elif tex is None:
                    cc = m.get("as_color") or (0.8, 0.8, 0.8)
                    bsdf.inputs["Base Color"].default_value = (*[(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in cc[:3]], 1)
                if m.get("as_glow") is not None:
                    g = m["as_glow"]
                    try:
                        bsdf.inputs["Emission Color"].default_value = (*g[:3], 1)
                        bsdf.inputs["Emission Strength"].default_value = 3
                    except Exception:
                        pass
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.32, 0.36, 0.42, 1)
    sc.world = w
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.location = c + Vector((r * 0.8, -r * 1.0, r * 0.5))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(45), 0, math.radians(35))
    sc.collection.objects.link(sun)
    # ซ่อนของเดิม
    for o in bpy.data.objects:
        if o.type in ("MESH", "ARMATURE") and o not in objs:
            o.hide_render = True
    bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        o.hide_render = False
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)
