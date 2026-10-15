"""
loading_art.py — รูปหน้าโหลด -> ReplicatedStorage/Shared/LoadingArt.lua (เกมวาดเองด้วย EditableImage ไม่ต้องอัปโหลด)

    python tools/loading_art.py "<รูปหน้าโหลด.png>"

ลบส่วนที่วาดติดมากับรูป (หลอดโหลด 68%, ตัวเลข %, ข้อความเคล็ดลับ) แล้วเก็บตำแหน่งไว้ให้ Cinematics วางของจริงทับ
ตำแหน่ง (BAR/PCT/TIP) เป็นพิกัดของรูปต้นฉบับ 1672x941 — เปลี่ยนรูปใหม่ต้องวัดใหม่
รูปแบบข้อมูล: base64 ของ [w u16][h u16][n u8][พาเลต n*3 RGB][ดัชนีสี 1 byte ต่อพิกเซล]
"""
import base64
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "LoadingArt.lua")
W, H = 1024, 576
BAR = (529, 772, 1141, 803)  # ช่องในหลอดโหลด (x0, y0, x1, y1)
PCT = (790, 734, 890, 766)  # ตัวเลข 68%
TIP = (586, 826, 1102, 864)  # ข้อความเคล็ดลับ + หลอดไฟ

im = Image.open(sys.argv[1]).convert("RGB")
SW, SH = im.size
a = np.array(im)
# 1) หลอดโหลด: ทาสีรางเข้มทั้งช่อง (หลอดเขียวจริงวางทับตอนเล่น)
track = tuple(int(v) for v in a[(BAR[1] + BAR[3]) // 2, BAR[2] - 30])
d = ImageDraw.Draw(im)
d.rounded_rectangle(BAR, radius=(BAR[3] - BAR[1]) // 2, fill=track)
# 2) ตัวเลข %: ลบตัวหนังสือแล้วเติมพื้นหลังรอบๆ ให้กลืน (inpaint)
import cv2

a = np.array(im)
gray = a[PCT[1]:PCT[3], PCT[0]:PCT[2]].astype(int)
mask = np.zeros(a.shape[:2], np.uint8)
txt = (gray.sum(axis=2) > 560) | (gray.sum(axis=2) < 70)  # ตัวขาว + ขอบดำ
mask[PCT[1]:PCT[3], PCT[0]:PCT[2]] = txt.astype(np.uint8) * 255
mask = cv2.dilate(mask, np.ones((5, 5), np.uint8))
a = cv2.inpaint(a, mask, 9, cv2.INPAINT_TELEA)
im = Image.fromarray(a)
# 3) ข้อความเคล็ดลับ: ทาสีพื้นกล่อง
box = tuple(int(v) for v in np.array(im)[(TIP[1] + TIP[3]) // 2, TIP[0] - 12])
ImageDraw.Draw(im).rectangle(TIP, fill=box)
im.save(os.path.join(ROOT, "assets", "ui", "loading_clean.png"))

small = im.resize((W, H), Image.LANCZOS)
q = small.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
pal = q.getpalette()[: 255 * 3]
idx = np.array(q, dtype=np.uint8).tobytes()
blob = struct.pack("<HHB", W, H, 255) + bytes(pal) + idx
data = base64.b64encode(blob).decode()


def norm(r):
    return "{ %.4f, %.4f, %.4f, %.4f }" % (r[0] / SW, r[1] / SH, r[2] / SW, r[3] / SH)


lua = f'''--[[
	LoadingArt — รูปหน้าโหลด (สร้างโดย tools/loading_art.py — อย่าแก้มือ)
	LoadingArt.Image() -> EditableImage | nil · Aspect = กว้าง/สูง
	Bar/Pct/Tip = ตำแหน่งหลอดโหลด ตัวเลข % และข้อความเคล็ดลับในรูป (สัดส่วน 0..1: x0, y0, x1, y1)
]]

local AssetService = game:GetService("AssetService")

local LoadingArt = {{
	Aspect = {SW / SH:.5f},
	Bar = {norm(BAR)},
	Pct = {norm(PCT)},
	Tip = {norm(TIP)},
	TrackColor = Color3.fromRGB({track[0]}, {track[1]}, {track[2]}),
	TipColor = Color3.fromRGB({box[0]}, {box[1]}, {box[2]}),
}}
local DATA = "{data}"

local B64 = {{}}
for i, c in ipairs(string.split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", "")) do
	B64[string.byte(c)] = i - 1
end

local cached
function LoadingArt.Image()
	if cached ~= nil then
		return cached or nil
	end
	cached = false
	local n = #DATA
	local pad = (DATA:sub(-2) == "==") and 2 or ((DATA:sub(-1) == "=") and 1 or 0)
	local len = n // 4 * 3 - pad
	local src = buffer.create(len)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = DATA:byte(i, i + 3)
		local t = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		if o < len then buffer.writeu8(src, o, t // 65536) end
		if o + 1 < len then buffer.writeu8(src, o + 1, (t // 256) % 256) end
		if o + 2 < len then buffer.writeu8(src, o + 2, t % 256) end
		o += 3
	end
	local w, h, np = buffer.readu16(src, 0), buffer.readu16(src, 2), buffer.readu8(src, 4)
	local pal = {{}}
	for k = 0, np - 1 do
		local p = 5 + k * 3
		pal[k] = buffer.readu8(src, p) + buffer.readu8(src, p + 1) * 256 + buffer.readu8(src, p + 2) * 65536 + 0xFF000000
	end
	local base = 5 + np * 3
	local out = buffer.create(w * h * 4)
	for k = 0, w * h - 1 do
		buffer.writeu32(out, k * 4, pal[buffer.readu8(src, base + k)])
	end
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({{ Size = Vector2.new(w, h) }})
	end)
	if not ok or not img then
		return nil
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), out)
	cached = img
	return img
end

return LoadingArt
'''
open(OUT, "w", encoding="utf-8", newline="\n").write(lua)
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB", "track", track, "box", box)
