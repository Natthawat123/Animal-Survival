"""
menu_art.py — รูปปุ่มเมนูซ้ายในล็อบบี้ (ภาพวาด) -> ข้อมูลในโค้ด ReplicatedStorage/Shared/MenuArt.lua
เกมวาดรูปเองตอนรันด้วย EditableImage (ไม่ต้องอัปโหลดรูปขึ้น Roblox)

    python tools/menu_art.py <ภาพเมนูทั้งแผง.png>   ตัดพื้นหลัง (rembg) + แยก 5 ปุ่ม -> assets/ui/menu/*.png + MenuArt.lua
    python tools/menu_art.py                        สร้าง MenuArt.lua ใหม่จาก assets/ui/menu/*.png ที่มีอยู่

รูปแบบข้อมูล: base64 ของ [w u16][h u16][n สี u8][พาเลต n*4 (RGBA)] แล้วตามด้วยช่วงซ้ำ [จำนวน u8][ดัชนีสี u8]
"""
import base64
import os
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "ui", "menu")
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "MenuArt.lua")
NAMES = ["Classes", "Quests", "Badges", "Shop", "Settings"]  # เรียงจากบนลงล่างตามภาพ
WIDTH = 300  # ความกว้างที่เก็บ (จอแสดง ~220 px)


def cut_sheet(path):
    from rembg import new_session, remove

    im = Image.open(path).convert("RGB")
    cut = remove(im, session=new_session("isnet-general-use"))
    a = np.array(cut)[:, :, 3]
    rows = (a > 40).sum(axis=1).astype(float)
    # ปุ่มติดกัน -> แบ่งที่แถวที่มีพิกเซลน้อยสุดใกล้ๆ จุดแบ่งเท่าๆ กัน
    top, bottom = np.nonzero(rows > 6)[0][[0, -1]]
    step = (bottom - top) / 5
    cuts = [top]
    for k in range(1, 5):
        guess = int(top + step * k)
        lo, hi = guess - int(step * 0.25), guess + int(step * 0.25)
        cuts.append(lo + int(np.argmin(rows[lo:hi])))
    cuts.append(bottom + 1)
    os.makedirs(ART, exist_ok=True)
    for i, name in enumerate(NAMES):
        piece = cut.crop((0, cuts[i], im.width, cuts[i + 1]))
        piece = piece.crop(piece.getbbox())
        piece.save(os.path.join(ART, name + ".png"))
        print(name, piece.size)


def encode(path, width=WIDTH):
    im = Image.open(path).convert("RGBA")
    h = round(im.height * width / im.width)
    im = im.resize((width, h), Image.LANCZOS)
    arr = np.array(im)
    arr[arr[:, :, 3] < 16] = 0  # ขอบโปร่งเกือบหมด = โปร่งใส
    q = Image.fromarray(arr, "RGBA").quantize(colors=255, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    pal = q.getpalette(rawmode="RGBA")[: 255 * 4]
    idx = np.array(q).flatten()
    out = bytearray(struct.pack("<HHB", width, h, 255)) + bytes(pal)
    i, n = 0, len(idx)
    while i < n:
        j = i
        while j < n and j - i < 255 and idx[j] == idx[i]:
            j += 1
        out += bytes((j - i, int(idx[i])))
        i = j
    return base64.b64encode(bytes(out)).decode(), (width, h)


def write_lua(out_path, mod, doc, items):
    """items = [(ชื่อ, path png, ความกว้างที่เก็บ)] -> โมดูล Lua ที่ถอดรหัสเป็น EditableImage (ใช้ร่วมกับ panel_art.py)"""
    lines = [
        "--[[",
        f"\t{mod} — {doc}",
        f"\t{mod}.Image(name) -> EditableImage (แคชไว้) · {mod}.Size[name] = Vector2 ขนาดรูป",
        "]]",
        "",
        'local AssetService = game:GetService("AssetService")',
        "",
        f"local {mod} = {{ Size = {{}} }}",
        "local DATA = {",
    ]
    for name, path, width in items:
        data, (w, h) = encode(path, width)
        lines.append(f'\t{name} = "{data}",')
        lines.append(f"\t-- {name}: {w}x{h}")
        print(name, w, h, len(data))
    lines += [
        "}",
        "",
        "local B64 = {}",
        'for i, c in ipairs(string.split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", "")) do',
        "\tB64[string.byte(c)] = i - 1",
        "end",
        "",
        "local function b64decode(s)",
        "\tlocal n = #s",
        '\tlocal pad = (s:sub(-2) == "==") and 2 or ((s:sub(-1) == "=") and 1 or 0)',
        "\tlocal buf = buffer.create(n // 4 * 3 - pad)",
        "\tlocal o = 0",
        "\tfor i = 1, n, 4 do",
        "\t\tlocal a, b, c, d = s:byte(i, i + 3)",
        "\t\tlocal t = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)",
        "\t\tif o < buffer.len(buf) then buffer.writeu8(buf, o, t // 65536) end",
        "\t\tif o + 1 < buffer.len(buf) then buffer.writeu8(buf, o + 1, (t // 256) % 256) end",
        "\t\tif o + 2 < buffer.len(buf) then buffer.writeu8(buf, o + 2, t % 256) end",
        "\t\to += 3",
        "\tend",
        "\treturn buf",
        "end",
        "",
        "local cache = {}",
        f"function {mod}.Image(name)",
        "\tif cache[name] ~= nil then",
        "\t\treturn cache[name] or nil",
        "\tend",
        "\tcache[name] = false",
        "\tlocal str = DATA[name]",
        "\tif not str then",
        "\t\treturn nil",
        "\tend",
        "\tlocal src = b64decode(str)",
        "\tlocal w, h, np = buffer.readu16(src, 0), buffer.readu16(src, 2), buffer.readu8(src, 4)",
        "\tlocal out = buffer.create(w * h * 4)",
        "\tlocal off, o = 5 + np * 4, 0",
        "\tlocal len = buffer.len(src)",
        "\twhile off < len do",
        "\t\tlocal count, idx = buffer.readu8(src, off), buffer.readu8(src, off + 1)",
        "\t\tlocal p = 5 + idx * 4",
        "\t\tlocal px = buffer.readu32(src, p)",
        "\t\tfor _ = 1, count do",
        "\t\t\tbuffer.writeu32(out, o, px)",
        "\t\t\to += 4",
        "\t\tend",
        "\t\toff += 2",
        "\tend",
        "\tlocal ok, img = pcall(function()",
        "\t\treturn AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })",
        "\tend)",
        "\tif not ok or not img then",
        "\t\treturn nil",
        "\tend",
        "\timg:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), out)",
        "\tcache[name] = img",
        f"\t{mod}.Size[name] = Vector2.new(w, h)",
        "\treturn img",
        "end",
        "",
        f"return {mod}",
        "",
    ]
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote", out_path, os.path.getsize(out_path))


def main():
    if len(sys.argv) > 1:
        cut_sheet(sys.argv[1])
    items = [(n, os.path.join(ART, n + ".png"), WIDTH) for n in NAMES]
    write_lua(OUT, "MenuArt", "รูปปุ่มเมนูซ้ายในล็อบบี้ (สร้างโดย tools/menu_art.py — อย่าแก้มือ)", items)


if __name__ == "__main__":
    main()
