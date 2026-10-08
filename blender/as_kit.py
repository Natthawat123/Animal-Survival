"""
as_kit.py — ชุดเครื่องมือ Blender ของ ANIMAL SURVIVAL
ใช้ได้ทั้งแบบ MCP (exec ใน Blender ที่เปิดอยู่) และแบบ headless:  blender -b --python blender/xxx.py

หน่วย: 1 Blender unit = 1 stud (Roblox)   หันหน้า: -Y (Blender)  -> -Z (Roblox, LookVector)
ชิ้นส่วนของสัตว์ตั้งชื่อตามกระดูกในเกม: Body, Head, Jaw, LegFL/LegFR/LegBL/LegBR, Tail1, WingL/WingR, ...
"""

import math
import os
import random

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if "__file__" in globals() else r"E:\GAME\roblox\Animal Survival"
EXPORTS = os.path.join(ROOT, "blender", "exports")
ART = os.path.join(ROOT, "art")
os.makedirs(EXPORTS, exist_ok=True)
os.makedirs(ART, exist_ok=True)

V = Vector


# ---------------------------------------------------------------- ฉาก
def reset_scene():
    """ล้างฉากทั้งหมด (object, mesh, material, light, camera, world)"""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.metaballs, bpy.data.lights, bpy.data.cameras,
                 bpy.data.curves, bpy.data.images, bpy.data.node_groups, bpy.data.textures):
        for block in list(coll):
            if block.users == 0 or coll in (bpy.data.metaballs,):
                try:
                    coll.remove(block)
                except Exception:
                    pass
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    sc = bpy.context.scene
    sc.unit_settings.system = "NONE"
    return sc


def collection(name, parent=None):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(c)
    return c


def link(ob, coll=None):
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


# ---------------------------------------------------------------- วัสดุ
def lin(c):
    """sRGB (0-1) -> linear"""
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c[:3])


def principled(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def set_input(node, names, value):
    """ตั้งค่า input ตามชื่อ (รองรับชื่อที่เปลี่ยนไปในแต่ละเวอร์ชัน)"""
    for n in names if isinstance(names, (list, tuple)) else [names]:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


def material(name, color, roughness=0.6, metallic=0.0, emission=None, strength=0.0, noise=0.0, subsurface=0.0, sheen=0.0):
    """วัสดุ PBR สีเดียว (+ จุดด่างจาก noise ให้ดูมีพื้นผิว)"""
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = principled(mat)
    srgb = tuple(color[:3])
    color = lin(srgb)  # สีที่ส่งมาเป็น sRGB (0-1) -> โหนดใช้ linear
    if emission:
        emission = lin(emission)
    rgba = (*color, 1.0)
    set_input(bsdf, "Base Color", rgba)
    set_input(bsdf, "Roughness", roughness)
    set_input(bsdf, "Metallic", metallic)
    if subsurface > 0:
        set_input(bsdf, ["Subsurface Weight", "Subsurface"], subsurface)
    if sheen > 0:
        set_input(bsdf, ["Sheen Weight", "Sheen"], sheen)
    if emission:
        set_input(bsdf, ["Emission Color", "Emission"], (*emission, 1.0))
        set_input(bsdf, "Emission Strength", strength)
    if noise > 0:
        # สีด่าง + ขรุขระเล็กน้อย
        tex = nt.nodes.new("ShaderNodeTexNoise")
        set_input(tex, "Scale", 6.0)
        set_input(tex, "Detail", 8.0)
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        dark = tuple(max(0.0, c * (1 - noise)) for c in color)
        light = tuple(min(1.0, c * (1 + noise * 0.6)) for c in color)
        ramp.color_ramp.elements[0].color = (*dark, 1)
        ramp.color_ramp.elements[1].color = (*light, 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bump = nt.nodes.new("ShaderNodeBump")
        set_input(bump, "Strength", 0.25 * noise + 0.05)
        nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    mat["as_color"] = list(srgb)
    mat.diffuse_color = (*color, 1.0)
    mat["as_emissive"] = bool(emission)
    return mat


def fur_material(name, top, belly, roughness=0.85, noise=0.35):
    """ขนสองโทน: บนเข้ม -> ท้องอ่อน ไล่สีนุ่มตามทิศของผิว (ใช้เรนเดอร์) / as_color = สีบน (ใช้ส่ง Roblox)"""
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = material(name, top, roughness=roughness, noise=noise, sheen=0.4)
    nt = mat.node_tree
    bsdf = principled(mat)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.75
    mr.inputs["From Max"].default_value = 0.05
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 0.0
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    prev = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].links else None
    if prev:
        nt.links.new(prev, mix.inputs[6])
    else:
        mix.inputs[6].default_value = (*lin(top), 1)
    mix.inputs[7].default_value = (*lin(belly), 1)
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    mat["as_belly"] = list(belly)
    return mat


def assign(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


# ---------------------------------------------------------------- ปั้นด้วย metaball
def _q(rot):
    if rot is None:
        return Quaternion()
    if isinstance(rot, Quaternion):
        return rot
    return Euler(rot).to_quaternion()


FIELD = 1.6  # ชดเชยรัศมี metaball (ก้อนที่ติดกันจะพองขึ้นเล็กน้อยเอง)


def blob(name, elements, mat=None, resolution=0.12, threshold=0.6, coll=None, smooth=True, decimate=None):
    """
    ปั้นก้อนเนื้อจาก metaball แล้วแปลงเป็น mesh
    elements: [("ellipsoid", (x,y,z), (sx,sy,sz), rot), ("ball", (x,y,z), r), ("capsule", (x,y,z), length, r, rot)]
      - ellipsoid: sx,sy,sz = รัศมีแต่ละแกน (studs)
      - capsule: ยาวตามแกน X ของมัน (หมุนด้วย rot)
      - ใส่ "-" นำหน้าชนิดเพื่อเป็นแบบลบ (เจาะ)
    """
    mb = bpy.data.metaballs.new(name + "_MB")
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    for e in elements:
        kind = e[0]
        neg = kind.startswith("-")
        kind = kind.lstrip("-")
        el = mb.elements.new()
        el.use_negative = neg
        el.co = V(e[1])
        # วัดจริง: threshold 0.6 -> รัศมีที่เห็น = radius * 0.574  จึงคูณ FIELD ให้ได้ขนาดตามที่สั่ง
        if kind == "ball":
            el.type = "BALL"
            el.radius = e[2] * FIELD
        elif kind == "ellipsoid":
            el.type = "ELLIPSOID"
            sx, sy, sz = e[2]
            r = max(sx, sy, sz)
            el.radius = r * FIELD
            el.size_x, el.size_y, el.size_z = sx / r, sy / r, sz / r
            el.rotation = _q(e[3] if len(e) > 3 else None)
        elif kind == "capsule":
            el.type = "CAPSULE"
            length, r = e[2], e[3]
            el.radius = r * FIELD
            el.size_x = length / 2  # ครึ่งความยาวแกน (สัมบูรณ์)
            el.rotation = _q(e[4] if len(e) > 4 else None)
        el.stiffness = 2.0
    tmp = bpy.data.objects.new(name + "_MBObj", mb)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.metaballs.remove(mb)
    mesh.name = name
    ob = bpy.data.objects.new(name, mesh)
    link(ob, coll)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    if decimate:
        decimate_to(ob, decimate)
    if mat:
        assign(ob, mat)
    return ob


def apply_modifiers(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    mats = list(old.materials)
    ob.modifiers.clear()
    ob.data = mesh
    for m in mats:
        if m.name not in [x.name for x in mesh.materials]:
            mesh.materials.append(m)
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def decimate_to(ob, target_tris):
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris <= target_tris:
        return ob
    m = ob.modifiers.new("Dec", "DECIMATE")
    m.ratio = target_tris / tris
    apply_modifiers(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def join(name, obs, coll=None):
    """รวมหลาย mesh เป็นชิ้นเดียว (เก็บวัสดุไว้)"""
    obs = [o for o in obs if o]
    bpy.context.view_layer.update()  # ให้ matrix_world ตรงกับ location ที่เพิ่งตั้ง
    if len(obs) == 1:
        obs[0].name = name
        obs[0].data.name = name
        return obs[0]
    import bmesh
    bm = bmesh.new()
    mats = []
    for o in obs:
        me = o.data
        offset = len(mats)
        for m in me.materials:
            mats.append(m)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(o.matrix_world)
        for f in tmp.faces:
            f.material_index += offset
        me2 = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me2)
        tmp.free()
        bm.from_mesh(me2)
        bpy.data.meshes.remove(me2)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    for o in obs:
        bpy.data.objects.remove(o, do_unlink=True)
    ob = bpy.data.objects.new(name, mesh)
    link(ob, coll)
    for p in mesh.polygons:
        p.use_smooth = True
    return ob


# ---------------------------------------------------------------- รูปทรงพื้นฐาน (mesh)
def cone(name, base_r, height, loc, rot=(0, 0, 0), mat=None, verts=8, coll=None, tip_r=0.0):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=base_r, radius2=tip_r, depth=height)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, height / 2))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    link(ob, coll)
    if mat:
        assign(ob, mat)
    return ob


def sphere(name, r, loc, mat=None, segments=16, scale=(1, 1, 1), coll=None):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=max(6, segments // 2), radius=r)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.scale = scale
    link(ob, coll)
    if mat:
        assign(ob, mat)
    return ob


def cube(name, size, loc, rot=(0, 0, 0), mat=None, coll=None, bevel=0.0):
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    link(ob, coll)
    if bevel > 0:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        apply_modifiers(ob)
    if mat:
        assign(ob, mat)
    return ob


def crystal(name, r, h, loc, rot=(0, 0, 0), mat=None, coll=None):
    """คริสตัลแปดเหลี่ยมปลายแหลม"""
    body = cone(name + "_b", r, h * 0.7, (0, 0, 0), mat=mat, verts=6, tip_r=r * 0.85)
    tip = cone(name + "_t", r * 0.85, h * 0.3, (0, 0, h * 0.7), mat=mat, verts=6)
    ob = join(name, [body, tip], coll)
    ob.location = loc
    ob.rotation_euler = rot
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


# ---------------------------------------------------------------- palette (ส่ง Roblox)
def bake_palette(objects, image_name, cell=8, cols=16):
    """
    รวมสีของทุกวัสดุเป็นภาพ palette เล็กๆ แล้วตั้ง UV ทุกหน้าไปที่ช่องสีของมัน
    -> Roblox ได้สีครบด้วย texture เดียว (ไฟล์เล็ก ไม่ต้องอบแสง)
    คืนค่า: (image, material)
    """
    colors = []
    index = {}
    for ob in objects:
        for m in ob.data.materials:
            if m and m.name not in index:
                c = m.get("as_color", [0.8, 0.8, 0.8])
                index[m.name] = len(colors)
                colors.append(tuple(c[:3]))
    n = max(1, len(colors))
    rows = (n + cols - 1) // cols
    w, h = cols * cell, max(1, rows) * cell
    img = bpy.data.images.new(image_name, w, h, alpha=False)
    px = [0.0] * (w * h * 4)
    for i, c in enumerate(colors):
        cx, cy = (i % cols) * cell, (i // cols) * cell
        for y in range(cy, cy + cell):
            for x in range(cx, cx + cell):
                k = (y * w + x) * 4
                px[k:k + 4] = [c[0], c[1], c[2], 1.0]  # ภาพ byte เก็บเป็น sRGB อยู่แล้ว
    img.pixels = px
    img.filepath_raw = os.path.join(EXPORTS, image_name + ".png")
    img.file_format = "PNG"
    img.save()
    pal = bpy.data.materials.new(image_name + "_Mat")
    pal.use_nodes = True
    tex = pal.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    pal.node_tree.links.new(tex.outputs["Color"], principled(pal).inputs["Base Color"])
    for ob in objects:
        me = ob.data
        if not me.uv_layers:
            me.uv_layers.new(name="UV")
        uv = me.uv_layers.active.data
        for p in me.polygons:
            m = me.materials[p.material_index] if me.materials else None
            i = index.get(m.name, 0) if m else 0
            u = ((i % cols) * cell + cell / 2) / w
            v = ((i // cols) * cell + cell / 2) / h
            for li in p.loop_indices:
                uv[li].uv = (u, v)
    return img, pal


def export_fbx(objects, path):
    """ส่งออก FBX สำหรับ Roblox 3D Importer (เลือกเฉพาะ objects ที่ให้)"""
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True, mesh_smooth_type="FACE", add_leaf_bones=False,
        bake_anim=False, path_mode="COPY", embed_textures=True,
    )
    for o in objects:
        o.select_set(False)
    return path


# ---------------------------------------------------------------- เรนเดอร์
def setup_render(width=1920, height=1080, samples=64, film_transparent=False, engine="EEVEE"):
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE" if engine == "EEVEE" else "CYCLES"
    except TypeError as e:
        print("engine fallback", e)
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = film_transparent
    sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    ee = sc.eevee
    for attr, val in (("taa_render_samples", samples), ("use_raytracing", True), ("use_shadows", True),
                      ("volumetric_tile_size", "4"), ("volumetric_samples", 96), ("use_volumetric_shadows", True),
                      ("shadow_ray_count", 2), ("shadow_step_count", 8), ("fast_gi_method", "GLOBAL_ILLUMINATION")):
        try:
            setattr(ee, attr, val)
        except Exception:
            pass
    if engine == "CYCLES":
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
        try:
            bpy.context.preferences.addons["cycles"].preferences.compute_device_type = "OPTIX"
            sc.cycles.device = "GPU"
        except Exception:
            pass
    return sc


def world_sky(color=(0.02, 0.025, 0.05), strength=1.0, fog_density=0.0, fog_color=(0.5, 0.55, 0.7), fog_anisotropy=0.3):
    sc = bpy.context.scene
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = (*color, 1)
    bg.inputs["Strength"].default_value = strength
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    if fog_density > 0:
        vol = nt.nodes.new("ShaderNodeVolumePrincipled")
        set_input(vol, "Density", fog_density)
        set_input(vol, "Color", (*fog_color, 1))
        set_input(vol, "Anisotropy", fog_anisotropy)
        nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    return w


def night_sky(zenith=(0.004, 0.006, 0.02), horizon=(0.05, 0.09, 0.22), stars=1.0, fog_density=0.0, fog_color=(0.45, 0.55, 0.9), fog_anisotropy=0.5):
    """ฟ้ากลางคืน: ไล่สีขอบฟ้า -> จุดสูงสุด + ดาว + หมอก volumetric"""
    sc = bpy.context.scene
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 0.45
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = (*horizon, 1)
    mix.inputs[7].default_value = (*zenith, 1)
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
    # ดาว: voronoi จุดเล็กๆ
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 420
    star_mr = nt.nodes.new("ShaderNodeMapRange")
    star_mr.inputs["From Min"].default_value = 0.0
    star_mr.inputs["From Max"].default_value = 0.035
    star_mr.inputs["To Min"].default_value = 3.0 * stars
    star_mr.inputs["To Max"].default_value = 0.0
    nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
    nt.links.new(vor.outputs["Distance"], star_mr.inputs["Value"])
    add = nt.nodes.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["Factor"].default_value = 1.0
    nt.links.new(mix.outputs[2], add.inputs[6])
    nt.links.new(star_mr.outputs["Result"], add.inputs[7])
    nt.links.new(add.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    if fog_density > 0:
        vol = nt.nodes.new("ShaderNodeVolumePrincipled")
        set_input(vol, "Density", fog_density)
        set_input(vol, "Color", (*fog_color, 1))
        set_input(vol, "Anisotropy", fog_anisotropy)
        nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    return w


def fog_box(size, loc, density=0.02, color=(0.6, 0.65, 0.75), coll=None, anisotropy=0.4):
    """กล่องหมอก volumetric (แสงทะลุเป็นลำ)"""
    ob = cube("FogVolume", size, loc, coll=coll)
    mat = bpy.data.materials.new("FogMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    set_input(vol, "Density", density)
    set_input(vol, "Color", (*color, 1))
    set_input(vol, "Anisotropy", anisotropy)
    # หมอกเป็นปื้นๆ
    noise = nt.nodes.new("ShaderNodeTexNoise")
    set_input(noise, "Scale", 0.04)
    set_input(noise, "Detail", 3)
    ramp = nt.nodes.new("ShaderNodeMath")
    ramp.operation = "MULTIPLY"
    ramp.inputs[1].default_value = density * 2
    nt.links.new(noise.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs["Value"], vol.inputs["Density"])
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    ob.data.materials.append(mat)
    ob.display_type = "BOUNDS"
    return ob


def light(kind, loc, energy, color=(1, 1, 1), rot=(0, 0, 0), size=1.0, name=None, coll=None, angle=None):
    ld = bpy.data.lights.new(name or kind, kind)
    ld.energy = energy
    ld.color = color
    if kind in ("POINT", "SPOT"):
        ld.shadow_soft_size = size
    if kind == "AREA":
        ld.size = size
    if kind == "SUN" and angle is not None:
        ld.angle = angle
    try:
        ld.use_shadow = True
    except Exception:
        pass
    ob = bpy.data.objects.new(name or kind, ld)
    ob.location = loc
    ob.rotation_euler = rot
    link(ob, coll)
    return ob


def camera(loc, target, lens=35, name="Camera", dof_target=None, fstop=2.8):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_end = 5000
    ob = bpy.data.objects.new(name, cd)
    ob.location = loc
    direction = V(target) - V(loc)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    link(ob)
    if dof_target is not None:
        cd.dof.use_dof = True
        cd.dof.focus_distance = (V(dof_target) - V(loc)).length
        cd.dof.aperture_fstop = fstop
    bpy.context.scene.camera = ob
    return ob


def bloom_compositor(strength=0.6, threshold=0.8, size=8):
    """Bloom ผ่าน compositor (Blender 4.2+/5.x)"""
    sc = bpy.context.scene
    try:
        tree = bpy.data.node_groups.new("AS_Comp", "CompositorNodeTree")
        sc.compositing_node_group = tree
        rl = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        for attr, val in (("glare_type", "BLOOM"), ("quality", "HIGH")):
            try:
                setattr(glare, attr, val)
            except Exception:
                pass
        for name, val in (("Type", "Bloom"), ("Quality", "High"), ("Threshold", threshold), ("Strength", strength), ("Size", size)):
            if name in glare.inputs:
                try:
                    glare.inputs[name].default_value = val
                except Exception as e:
                    print("glare input", name, e)
        tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], out.inputs[0])
        return True
    except Exception as e:
        print("compositor (5.x) failed:", e)
    try:
        sc.use_nodes = True
        tree = sc.node_tree
        tree.nodes.clear()
        rl = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        comp = tree.nodes.new("CompositorNodeComposite")
        glare.glare_type = "BLOOM"
        tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], comp.inputs["Image"])
        return True
    except Exception as e:
        print("compositor (legacy) failed:", e)
        return False


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    return path


def ground_plane(name, size, loc=(0, 0, 0), mat=None, subdiv=6, displace=0.0, noise_scale=0.08, coll=None, seed=0):
    """พื้นดินขรุขระ (displace ด้วย noise)"""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2 ** subdiv, y_segments=2 ** subdiv, size=size / 2)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    link(ob, coll)
    if displace > 0:
        from mathutils import noise
        for v in me.vertices:
            p = v.co * noise_scale + V((seed * 3.1, seed * 1.7, 0))
            v.co.z += noise.fractal(p, 1.0, 2.0, 4) * displace
    for p in me.polygons:
        p.use_smooth = True
    if mat:
        assign(ob, mat)
    return ob
