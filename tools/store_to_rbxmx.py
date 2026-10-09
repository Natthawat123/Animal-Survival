"""
store_to_rbxmx.py — แปลงโครงสร้างโมเดลที่ดึงจาก Creator Store (assets/store/<id>.json) เป็นไฟล์โมเดล XML (.rbxmx)
ให้ build_rbxlx.py ใส่เข้าเกมใน ReplicatedStorage.Assets.<Folder>/<Name> (MeshPart อ้าง MeshId/TextureID เดิมของโมเดล)

  python tools/store_to_rbxmx.py <assetId> <ชื่อ> [<Folder>=Creatures]

ไม่รองรับ UnionOperation (ต้องใช้ข้อมูล CSG) -> ข้าม; สคริปต์ถูกลบตั้งแต่ตอนดึง
"""
import json
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")
OUT = os.path.join(ROOT, "assets", "rbxm")

MATERIAL = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Marble": 784, "Basalt": 788,
    "Slate": 800, "CrackedLava": 804, "Concrete": 816, "Limestone": 820, "Granite": 832, "Pavement": 836, "Brick": 848,
    "Pebble": 864, "Cobblestone": 880, "Rock": 896, "Sandstone": 912, "CorrodedMetal": 1040, "DiamondPlate": 1056,
    "Foil": 1072, "Metal": 1088, "Grass": 1280, "LeafyGrass": 1284, "Sand": 1296, "Fabric": 1312, "Snow": 1328,
    "Mud": 1344, "Ground": 1360, "Asphalt": 1376, "Salt": 1392, "Ice": 1536, "Glacier": 1552, "Glass": 1568,
    "ForceField": 1584, "SmoothPlastic ": 272,
}
SHAPE = {"Ball": 0, "Block": 1, "Cylinder": 2, "Wedge": 3, "CornerWedge": 4}
MESHTYPE = {"Head": 0, "Torso": 1, "Wedge": 2, "Sphere": 3, "Cylinder": 4, "FileMesh": 5, "Brick": 6, "Prism": 7, "Pyramid": 8, "ParallelRamp": 9,
            "RightAngleRamp": 10, "CornerWedge": 11}
FACE = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
ALPHA = {"Overlay": 0, "Transparency": 1, "TintMask": 2}
KEEP = {"Model", "Folder", "MeshPart", "Part", "WedgePart", "CornerWedgePart", "TrussPart", "SpecialMesh", "BlockMesh", "CylinderMesh",
        "SurfaceAppearance", "Decal", "Texture", "Bone", "Attachment", "Motor6D", "Weld", "ManualWeld", "Snap", "WeldConstraint",
        "Humanoid", "AnimationController", "Animator", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh", "Accessory", "Hat", "Tool",
        "ParticleEmitter", "Beam"}

EMIT_DIR = {"Right": 0, "Top": 1, "Back": 2, "Left": 3, "Bottom": 4, "Front": 5}
P_SHAPE = {"Box": 0, "Sphere": 1, "Cylinder": 2, "Disc": 3}
P_STYLE = {"Volume": 0, "Surface": 1}
P_INOUT = {"Outward": 0, "Inward": 1, "InAndOut": 2}
P_ORIENT = {"FacingCamera": 0, "FacingCameraWorldUp": 1, "VelocityParallel": 2, "VelocityPerpendicular": 3}
FB_LAYOUT = {"None": 0, "Grid2x2": 1, "Grid4x4": 2, "Grid8x8": 3}
FB_MODE = {"Loop": 0, "OneShot": 1, "PingPong": 2, "Random": 3}
TEX_MODE = {"Stretch": 0, "Wrap": 1, "Static": 2}


def nseq(name, ks):
    ks = ks or [[0, 0, 0], [1, 0, 0]]
    return '<NumberSequence name="%s">' % name + " ".join("%s %s %s" % (k[0], k[1], k[2]) for k in ks) + " </NumberSequence>"


def cseq(name, ks):
    ks = ks or [[0, 1, 1, 1], [1, 1, 1, 1]]
    return '<ColorSequence name="%s">' % name + " ".join("%s %s %s %s 0" % (k[0], k[1], k[2], k[3]) for k in ks) + " </ColorSequence>"


def nrange(name, r):
    r = r or [0, 0]
    return '<NumberRange name="%s">%s %s </NumberRange>' % (name, r[0], r[1])


def fl(name, x, d=0):
    return '<float name="%s">%s</float>' % (name, x if x is not None else d)


def bl(name, x):
    return '<bool name="%s">%s</bool>' % (name, "true" if x else "false")

BODYPART = {"Head": 0, "Torso": 1, "LeftArm": 2, "RightArm": 3, "LeftLeg": 4, "RightLeg": 5}


def v3(name, v):
    return f'<Vector3 name="{name}"><X>{v[0]}</X><Y>{v[1]}</Y><Z>{v[2]}</Z></Vector3>'


def cf(name, c):
    keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return f'<CoordinateFrame name="{name}">' + "".join(f"<{k}>{x}</{k}>" for k, x in zip(keys, c)) + "</CoordinateFrame>"


def content(name, url):
    if url:
        return f'<Content name="{name}"><url>{escape(url)}</url></Content>'
    return f'<Content name="{name}"><null></null></Content>'


def color(c):
    r, g, b = (max(0, min(255, int(round(x * 255)))) for x in c)
    return f'<Color3uint8 name="Color3uint8">{0xFF000000 | (r << 16) | (g << 8) | b}</Color3uint8>'


def mul(a, b):
    """CFrame components (x,y,z,R00..R22) a*b"""
    ax, ay, az, *ar = a
    bx, by, bz, *br = b
    R = lambda m, i, j: m[i * 3 + j]
    rr = [sum(R(ar, i, k) * R(br, k, j) for k in range(3)) for i in range(3) for j in range(3)]
    px = ax + R(ar, 0, 0) * bx + R(ar, 0, 1) * by + R(ar, 0, 2) * bz
    py = ay + R(ar, 1, 0) * bx + R(ar, 1, 1) * by + R(ar, 1, 2) * bz
    pz = az + R(ar, 2, 0) * bx + R(ar, 2, 1) * by + R(ar, 2, 2) * bz
    return [px, py, pz] + rr


def inv(a):
    x, y, z, *r = a
    rt = [r[0], r[3], r[6], r[1], r[4], r[7], r[2], r[5], r[8]]
    px = -(rt[0] * x + rt[1] * y + rt[2] * z)
    py = -(rt[3] * x + rt[4] * y + rt[5] * z)
    pz = -(rt[6] * x + rt[7] * y + rt[8] * z)
    return [px, py, pz] + rt


def convert(aid, name, folder="Props"):
    data = json.load(open(os.path.join(STORE, f"{aid}.json"), encoding="utf-8"))
    items = data["Items"]
    n = len(items)
    children = {i: [] for i in range(n + 1)}
    for i, it in enumerate(items, 1):
        children[it.get("P", 0)].append(i)
    skipped = {}
    r15 = any(it["C"] in ("MeshPart", "Part") and it["N"] == "UpperTorso" for it in items)
    # SurfaceAppearance โหลดจากไฟล์ไม่ได้ (ล็อกเจ้าของ) -> ใช้ ColorMap เป็น TextureID ของ MeshPart แทน
    for i, it in enumerate(items, 1):
        if it["C"] == "SurfaceAppearance" and it.get("ColorMap"):
            par = items[it["P"] - 1] if it.get("P") else None
            if par and par["C"] == "MeshPart" and not par.get("TextureID"):
                par["TextureID"] = it["ColorMap"]
            it["C"] = "_drop"

    def ref(i):
        return f"S{aid}_{i}"

    def props(i, it):
        c = it["C"]
        out = [f'<string name="Name">{escape(name if i == 1 else it["N"])}</string>']
        if c in ("MeshPart", "Part", "WedgePart", "CornerWedgePart", "TrussPart"):
            out.append(cf("CFrame", it["CF"]))
            out.append(v3("size", it["Size"]))
            out.append(color(it.get("Color", [0.6, 0.6, 0.6])))
            out.append(f'<token name="Material">{MATERIAL.get(it.get("Mat"), 256)}</token>')
            out.append(f'<float name="Transparency">{it.get("Tr", 0)}</float>')
            out.append(f'<float name="Reflectance">{it.get("Refl", 0)}</float>')
            out.append('<bool name="Anchored">false</bool><bool name="CanCollide">false</bool><bool name="CanTouch">false</bool><bool name="CanQuery">false</bool>')
            out.append('<bool name="Massless">true</bool><bool name="CastShadow">true</bool>')
            if c == "Part":
                out.append(f'<token name="shape">{SHAPE.get(it.get("Shape"), 1)}</token>')
            if c == "MeshPart":
                out.append(content("MeshId", it.get("MeshId")))
                out.append(content("TextureID", it.get("TextureID")))
                out.append(v3("InitialSize", it.get("MeshSize") or it["Size"]))
                out.append('<token name="CollisionFidelity">2</token><token name="RenderFidelity">1</token>')
                out.append(f'<bool name="DoubleSided">{"true" if it.get("DoubleSided") else "false"}</bool>')
        elif c == "SpecialMesh":
            out.append(content("MeshId", it.get("MeshId")))
            out.append(content("TextureId", it.get("TextureId")))
            out.append(v3("Scale", it.get("Scale", [1, 1, 1])))
            out.append(v3("Offset", it.get("Offset", [0, 0, 0])))
            out.append(v3("VertexColor", it.get("VertexColor", [1, 1, 1])))
            out.append(f'<token name="MeshType">{MESHTYPE.get(it.get("MeshType"), 5)}</token>')
        elif c == "SurfaceAppearance":
            out.append(content("ColorMap", it.get("ColorMap")))
            out.append(content("NormalMap", it.get("NormalMap")))
            out.append(f'<token name="AlphaMode">{ALPHA.get(it.get("Alpha"), 0)}</token>')
        elif c in ("Decal", "Texture"):
            out.append(content("Texture", it.get("Texture")))
            out.append(f'<token name="Face">{FACE.get(it.get("Face"), 5)}</token>')
        elif c == "Humanoid":
            out.append(f'<token name="RigType">{1 if r15 else 0}</token>')
            out.append('<token name="DisplayDistanceType">2</token><token name="HealthDisplayType">2</token>')
        elif c == "Shirt":
            out.append(content("ShirtTemplate", it.get("Template")))
        elif c == "Pants":
            out.append(content("PantsTemplate", it.get("Template")))
        elif c == "ShirtGraphic":
            out.append(content("Graphic", it.get("Template")))
        elif c == "BodyColors" and it.get("Colors"):
            for nm, col in zip(["HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3"], it["Colors"]):
                out.append(f'<Color3 name="{nm}"><R>{col[0]}</R><G>{col[1]}</G><B>{col[2]}</B></Color3>')
        elif c == "CharacterMesh":
            out.append(f'<int64 name="MeshId">{str(it.get("MeshId") or 0)}</int64>')
            out.append(f'<int64 name="BaseTextureId">{str(it.get("BaseTextureId") or 0)}</int64>')
            out.append(f'<int64 name="OverlayTextureId">{str(it.get("OverlayTextureId") or 0)}</int64>')
            out.append(f'<token name="BodyPart">{BODYPART.get(it.get("BodyPart"), 1)}</token>')
        elif c in ("Bone", "Attachment"):
            out.append(cf("CFrame", it["CF"]))
        elif c == "ParticleEmitter":
            out.append(content("Texture", it.get("Texture")))
            out.append(cseq("Color", it.get("ColorSeq")))
            out.append(nseq("Size", it.get("SizeSeq")))
            out.append(nseq("Transparency", it.get("TransparencySeq")))
            out.append(nseq("Squash", it.get("SquashSeq")))
            out.append(nrange("Lifetime", it.get("Lifetime")))
            out.append(nrange("Speed", it.get("Speed")))
            out.append(nrange("Rotation", it.get("Rotation")))
            out.append(nrange("RotSpeed", it.get("RotSpeed")))
            out.append(nrange("FlipbookFramerate", it.get("FlipbookFramerate")))
            sp = it.get("Spread") or [0, 0]
            out.append('<Vector2 name="SpreadAngle"><X>%s</X><Y>%s</Y></Vector2>' % (sp[0], sp[1]))
            out.append(v3("Acceleration", it.get("Accel") or [0, 0, 0]))
            for k, d in (("Rate", 0), ("Drag", 0), ("LightEmission", 0), ("LightInfluence", 0), ("Brightness", 1), ("ZOffset", 0),
                         ("ShapePartial", 1), ("TimeScale", 1), ("VelocityInheritance", 0)):
                out.append(fl(k, it.get(k), d))
            out.append(bl("Enabled", it.get("Enabled", True)))
            out.append(bl("LockedToPart", it.get("LockedToPart")))
            out.append(bl("FlipbookStartRandom", it.get("FlipbookStartRandom")))
            out.append('<token name="EmissionDirection">%d</token>' % EMIT_DIR.get(it.get("EmissionDirection"), 1))
            out.append('<token name="Shape">%d</token>' % P_SHAPE.get(it.get("Shape"), 0))
            out.append('<token name="ShapeStyle">%d</token>' % P_STYLE.get(it.get("ShapeStyle"), 0))
            out.append('<token name="ShapeInOut">%d</token>' % P_INOUT.get(it.get("ShapeInOut"), 0))
            out.append('<token name="Orientation">%d</token>' % P_ORIENT.get(it.get("Orientation"), 0))
            out.append('<token name="FlipbookLayout">%d</token>' % FB_LAYOUT.get(it.get("FlipbookLayout"), 0))
            out.append('<token name="FlipbookMode">%d</token>' % FB_MODE.get(it.get("FlipbookMode"), 0))
        elif c == "Beam":
            out.append(content("Texture", it.get("Texture")))
            out.append(cseq("Color", it.get("ColorSeq")))
            out.append(nseq("Transparency", it.get("TransparencySeq")))
            out.append('<Ref name="Attachment0">%s</Ref>' % (ref(it["A0"]) if it.get("A0") else "null"))
            out.append('<Ref name="Attachment1">%s</Ref>' % (ref(it["A1"]) if it.get("A1") else "null"))
            for k, d in (("LightEmission", 0), ("LightInfluence", 0), ("Brightness", 1), ("ZOffset", 0), ("TextureLength", 1), ("TextureSpeed", 1),
                         ("Width0", 1), ("Width1", 1)):
                out.append(fl(k, it.get(k), d))
            out.append(fl("CurveSize0", it.get("Curve0"), 0))
            out.append(fl("CurveSize1", it.get("Curve1"), 0))
            out.append('<int name="Segments">%d</int>' % int(it.get("Segments") or 10))
            out.append(bl("Enabled", it.get("Enabled", True)))
            out.append(bl("FaceCamera", it.get("FaceCamera")))
            out.append('<token name="TextureMode">%d</token>' % TEX_MODE.get(it.get("TextureMode"), 0))
        elif c in ("Motor6D", "Weld", "ManualWeld", "Snap"):
            out.append(f'<Ref name="Part0">{ref(it["P0"]) if it.get("P0") else "null"}</Ref>')
            out.append(f'<Ref name="Part1">{ref(it["P1"]) if it.get("P1") else "null"}</Ref>')
            out.append(cf("C0", it["C0"]))
            out.append(cf("C1", it["C1"]))
        return "".join(out)

    def emit(i):
        it = items[i - 1]
        c = it["C"]
        if c == "WeldConstraint":
            # แปลงเป็น Weld (ใช้ CFrame ของสองชิ้น)
            p0, p1 = it.get("P0"), it.get("P1")
            if not (p0 and p1) or "CF" not in items[p0 - 1] or "CF" not in items[p1 - 1]:
                return ""
            c0 = mul(inv(items[p0 - 1]["CF"]), items[p1 - 1]["CF"])
            it = dict(it, C="Weld", C0=c0, C1=[0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])
            c = "Weld"
        if c not in KEEP:
            skipped[c] = skipped.get(c, 0) + 1
            return ""
        cls = "Model" if i == 1 else ({"Hat": "Accessory", "Tool": "Model"}.get(c, c))
        body = "".join(emit(k) for k in children[i])
        return f'<Item class="{cls}" referent="{ref(i)}"><Properties>{props(i, dict(it, C=c))}</Properties>{body}</Item>\n'

    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n' + emit(1) + "</roblox>\n")
    od = os.path.join(OUT, folder)
    os.makedirs(od, exist_ok=True)
    path = os.path.join(od, name + ".rbxmx")
    with open(path, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"{aid} -> {os.path.relpath(path, ROOT)} ({len(xml)//1024} KB) skipped={skipped}")
    return path


if __name__ == "__main__":
    a = sys.argv[1:]
    convert(a[0], a[1], a[2] if len(a) > 2 else "Props")
