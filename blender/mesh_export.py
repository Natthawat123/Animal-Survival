"""
mesh_export.py — ส่งข้อมูลเมชสัตว์ (จาก game_animals.py) ไปเป็น ModuleScript ให้เกมสร้าง EditableMesh เอง (ไม่ต้องอัปโหลด)

ผลลัพธ์: src/ReplicatedStorage/AnimalMeshData/<Id>.lua
  return {
    Name, Height,
    Palette = base64(RLE RGB: u16 w, u16 h, [u16 count, u8 r,g,b]...),
    Parts = { { Name, Attach, Center = {x,y,z}, Size = {x,y,z}, Color = {r,g,b}, Glow = {r,g,b}|nil, Mesh = base64 }, ... }
  }
Mesh (little-endian, เหมือน CharacterMeshes ของ Anime Run):
  u16 nV, nUV, nN, nF | verts i16x3 (studs*1000, รอบจุดกลางชิ้น) | uvs u16x2 | normals i8x3 | faces u16x9
พิกัด Roblox: x = -bx, y = bz, z = by  (หัวไป -Z, เท้า y = 0)
"""
import base64
import os
import struct

import bpy
from mathutils import Vector

ROOT = r"E:\GAME\roblox\Animal Survival"
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "AnimalMeshData")
os.makedirs(OUT, exist_ok=True)

MAIN = ("Body", "Head", "Jaw", "LegFL", "LegFR", "LegBL", "LegBR", "Tail1", "WingL", "WingR")


def to_rbx(v):
    return (-v.x, v.z, v.y)


def mat_info(mat):
    """(สีฐาน sRGB, สีเรืองแสง sRGB|None, image|None)"""
    if mat is None:
        return (0.8, 0.8, 0.8), None, None
    c = mat.get("as_color")
    emissive = mat.get("as_emissive")
    img = None
    if mat.use_nodes:
        img = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0 and n.image.has_data), None)
    if c is None:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if mat.use_nodes else None
        lc = bsdf.inputs["Base Color"].default_value[:3] if bsdf else mat.diffuse_color[:3]
        # Base Color ต่อจากโหนดอื่น (Mix/RGB) -> ไล่หาค่าสีจริง
        if bsdf and bsdf.inputs["Base Color"].links:
            node = bsdf.inputs["Base Color"].links[0].from_node
            for _ in range(4):
                if node.type == "RGB":
                    lc = node.outputs[0].default_value[:3]
                    break
                cand = [i for i in node.inputs if i.type == "RGBA"]
                nxt = None
                for i in cand:
                    if i.links:
                        nxt = nxt or i.links[0].from_node
                    else:
                        lc = i.default_value[:3]
                        nxt = None
                        break
                if nxt is None:
                    break
                node = nxt
        c = tuple(((x * 1.055) ** (1 / 2.4) - 0.055) if x > 0.0031308 else x * 12.92 for x in lc)  # linear -> sRGB โดยประมาณ
    return tuple(c[:3]), (tuple(c[:3]) if emissive else None), img


_img_cache = {}


def sample_image(img, uv):
    import numpy as np
    key = img.name
    if key not in _img_cache:
        w, h = img.size
        _img_cache[key] = (np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h)
    px, w, h = _img_cache[key]
    u, v = uv
    x = int((u % 1.0) * (w - 1))
    y = int((v % 1.0) * (h - 1))
    x0, x1 = max(0, x - 1), min(w, x + 2)
    y0, y1 = max(0, y - 1), min(h, y + 2)
    c = px[y0:y1, x0:x1, :3].reshape(-1, 3).mean(axis=0)
    # ภาพ byte เก็บเป็น sRGB ใน pixels แล้ว (Blender แปลงให้ตามชนิดภาพ) -> ใช้ตรงๆ
    return tuple(float(x) for x in c)


def face_colors(ob):
    """สีของแต่ละหน้า (sRGB 0-1)"""
    me = ob.data
    uv = me.uv_layers.active.data if me.uv_layers else None
    infos = [mat_info(m) for m in me.materials] or [((0.8, 0.8, 0.8), None, None)]
    # as_notex = ใช้สีฐานแทนลาย texture, as_tint = คูณสี (sRGB) — ใช้แต่งสีตัวละครตามคลาส
    flags = [((m.get("as_notex") if m else None), (tuple(m["as_tint"]) if m and m.get("as_tint") is not None else None)) for m in me.materials] or [(None, None)]
    out = []
    vcol = me.color_attributes.active_color if getattr(me, "color_attributes", None) and len(me.color_attributes) else None
    vflags = [bool(m and m.get("as_vcol")) for m in me.materials] or [False]
    for p in me.polygons:
        mi = min(p.material_index, len(infos) - 1)
        if vcol is not None and vflags[min(mi, len(vflags) - 1)]:
            acc = [0.0, 0.0, 0.0]
            idxs = p.loop_indices if vcol.domain == "CORNER" else p.vertices
            for li in idxs:
                d = vcol.data[li]
                col = d.color_srgb if hasattr(d, "color_srgb") else d.color
                for k in range(3):
                    acc[k] += col[k]
            c = tuple(a / len(idxs) for a in acc)
            tint_ = flags[min(mi, len(flags) - 1)][1] if flags else None
            if tint_:
                c = tuple(min(1.0, x * t) for x, t in zip(c, tint_))
            out.append(c)
            continue
        base, glow, img = infos[mi]
        notex, tint = flags[min(mi, len(flags) - 1)]
        if img is not None and uv is not None and not notex:
            us = [uv[li].uv for li in p.loop_indices]
            cu = sum(u.x for u in us) / len(us)
            cv = sum(u.y for u in us) / len(us)
            c = sample_image(img, (cu, cv))
        else:
            c = base
        if tint:
            c = tuple(min(1.0, x * t) for x, t in zip(c, tint))
        out.append(c)
    return out, infos


def quant(c, bits=5):
    q = (1 << bits) - 1
    return tuple(int(round(max(0, min(1, x)) * q)) * 255 // q for x in c)


def build_palette(all_colors, cols=32, cell=2):
    index = {}
    order = []
    for c in all_colors:
        if c not in index:
            index[c] = len(order)
            order.append(c)
    n = max(1, len(order))
    rows = (n + cols - 1) // cols
    w, h = cols * cell, rows * cell
    pix = [(0, 0, 0)] * (w * h)
    for i, c in enumerate(order):
        cx, cy = (i % cols) * cell, (i // cols) * cell
        for y in range(cy, cy + cell):
            for x in range(cx, cx + cell):
                pix[y * w + x] = c
    # RLE (แถวบนก่อน = แบบ Roblox; เราใช้แถว y=0 เป็นบน และ uv v = y/h ตรงๆ)
    buf = bytearray(struct.pack("<2H", w, h))
    i = 0
    while i < len(pix):
        j = i + 1
        while j < len(pix) and j - i < 65535 and pix[j] == pix[i]:
            j += 1
        buf += struct.pack("<H3B", j - i, *pix[i])
        i = j
    uvs = {c: (((i % cols) * cell + cell / 2) / w, ((i // cols) * cell + cell / 2) / h) for c, i in index.items()}
    return bytes(buf), uvs


def mesh_bytes(ob, colors, uvmap):
    me = ob.data
    me.calc_loop_triangles()
    mw = ob.matrix_world
    wverts = [to_rbx(mw @ v.co) for v in me.vertices]
    mn = [min(v[i] for v in wverts) for i in range(3)]
    mx = [max(v[i] for v in wverts) for i in range(3)]
    center = [(mn[i] + mx[i]) / 2 for i in range(3)]
    size = [max(mx[i] - mn[i], 0.05) for i in range(3)]
    verts = [(v[0] - center[0], v[1] - center[1], v[2] - center[2]) for v in wverts]
    uv_index, uvs, n_index, ns, faces = {}, [], {}, [], []
    for tri in me.loop_triangles:
        c = colors[tri.polygon_index]
        u, v = uvmap[c]
        key = (int(round(u * 65535)), int(round(v * 65535)))
        if key not in uv_index:
            uv_index[key] = len(uvs)
            uvs.append(key)
        n = (mw.to_3x3() @ tri.normal).normalized()
        nk = tuple(int(round(max(-1, min(1, x)) * 127)) for x in (-n.x, n.z, n.y))
        if nk not in n_index:
            n_index[nk] = len(ns)
            ns.append(nk)
        vids = [me.loops[li].vertex_index for li in tri.loops]
        faces.append((vids, [uv_index[key]] * 3, [n_index[nk]] * 3))
    assert len(verts) < 65536
    buf = bytearray(struct.pack("<4H", len(verts), len(uvs), len(ns), len(faces)))
    for x, y, z in verts:
        buf += struct.pack("<3h", *(max(-32767, min(32767, int(round(c * 1000)))) for c in (x, y, z)))
    for u, v in uvs:
        buf += struct.pack("<2H", u, v)
    for n in ns:
        buf += struct.pack("<3b", *n)
    for vids, uids, nids in faces:
        buf += struct.pack("<9H", *vids, *uids, *nids)
    return bytes(buf), center, size, len(faces)


def b64_lua(data):
    b = base64.b64encode(data).decode("ascii")
    chunks = [b[i:i + 2000] for i in range(0, len(b), 2000)]
    return "table.concat({\n\t\t\t" + ",\n\t\t\t".join('"%s"' % c for c in chunks) + "\n\t\t})"


def attach_of(name, ob, mains):
    if name in MAIN:
        return name
    # ชิ้นตกแต่ง -> ติดกับชิ้นหลักที่ใกล้จุดกลางมากที่สุด (ระยะถึงกล่อง)
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    c = sum(pts, Vector()) / max(len(pts), 1)
    best, bd = "Body", 1e9
    for nm, m in mains.items():
        mp = [m.matrix_world @ v.co for v in m.data.vertices]
        lo = Vector((min(p.x for p in mp), min(p.y for p in mp), min(p.z for p in mp)))
        hi = Vector((max(p.x for p in mp), max(p.y for p in mp), max(p.z for p in mp)))
        q = Vector((max(lo.x, min(c.x, hi.x)), max(lo.y, min(c.y, hi.y)), max(lo.z, min(c.z, hi.z))))
        d = (q - c).length
        if nm in ("LegFL", "LegFR", "LegBL", "LegBR"):
            d += 0.5  # ไม่อยากให้ของตกแต่งติดขา
        if d < bd:
            best, bd = nm, d
    return best


def export(animal_id, parts, out_dir=None):
    bpy.context.view_layer.update()
    per = {}
    allc = []
    for nm, ob in parts.items():
        cols, infos = face_colors(ob)
        cols = [quant(c) for c in cols]
        per[nm] = (cols, infos)
        allc += cols
    pal, uvmap = build_palette(allc)
    mains = {nm: ob for nm, ob in parts.items() if nm in MAIN}
    lines = [f"-- สร้างโดย blender/mesh_export.py — {animal_id} (โมเดลจริงจาก Blender, ประกอบเป็น EditableMesh ตอนเล่น)", "return {",
             f'\tName = "{animal_id}",']
    height = 0
    entries = []
    for nm, ob in parts.items():
        cols, infos = per[nm]
        data, center, size, nf = mesh_bytes(ob, cols, uvmap)
        height = max(height, center[1] + size[1] / 2)
        avg = [sum(c[i] for c in cols) / len(cols) / 255 for i in range(3)] if cols else [0.8, 0.8, 0.8]
        glow = None
        if nm.startswith("Glow_"):
            hx = nm[5:11]
            glow = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        e = [f'\t\t{{\n\t\t\tName = "{nm}",', f'\t\t\tAttach = "{attach_of(nm, ob, mains)}",',
             "\t\t\tCenter = {%.4f, %.4f, %.4f}," % tuple(center), "\t\t\tSize = {%.4f, %.4f, %.4f}," % tuple(size),
             "\t\t\tColor = {%.3f, %.3f, %.3f}," % tuple(avg)]
        if glow:
            e.append("\t\t\tGlow = {%.3f, %.3f, %.3f}," % tuple(glow))
        e.append("\t\t\tMesh = " + b64_lua(data) + ",\n\t\t},")
        entries.append("\n".join(e))
    lines.append(f"\tHeight = {height:.3f},")
    lines.append("\tPalette = " + b64_lua(pal) + ",")
    lines.append("\tParts = {")
    lines += entries
    lines.append("\t},")
    lines.append("}")
    od = out_dir or OUT
    os.makedirs(od, exist_ok=True)
    path = os.path.join(od, animal_id + ".lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[mesh_export] {animal_id}: {len(parts)} parts, palette {len(set(allc))} colors -> {os.path.getsize(path)//1024} KB")
    return path
