--[[
	WoodKit — ธีมหน้าต่าง "แคมป์ไม้กลางป่า" (กรอบไม้เข้ม + ป้ายชื่อกระดาษ + ธงแดง + โคมไฟ + หัวหมาป่า/อินทรีบนกรอบ)
	ใช้กับ ภารกิจ & รางวัล / ป้ายความสำเร็จ / ร้านค้า / ตั้งค่า
	ภาพวาดประดับมาจาก Shared/PanelArt (EditableImage) — โหลดไม่ได้ = ไม่มีภาพ หน้าต่างยังใช้ได้ปกติ

	WoodKit.Window(parent, { Size = Vector2, Title, OnClose }) -> { Frame, Body }
	  Frame = กรอบนอกล่องหน (ใช้สลับ Visible / UIKit.Pop) · Body = แผ่นไม้ที่ใส่เนื้อหา
	  ธงแดงอยู่ "หลัง" แผ่นไม้ (โผล่แค่ส่วนที่ยื่นออกนอกกรอบ) ส่วนป้ายชื่อ/หัวสัตว์/โคม/ปุ่มปิดอยู่ "หน้า"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)
local PanelArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PanelArt"))

local WoodKit = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

WoodKit.Colors = {
	WoodDark = rgb(34, 22, 14),
	Wood = rgb(92, 58, 34),
	Inner = rgb(56, 36, 24),
	Parch = rgb(238, 218, 176),
	ParchEdge = rgb(110, 70, 36),
	Ink = rgb(58, 34, 18),
	InkDim = rgb(116, 84, 56),
	Red = rgb(170, 36, 34),
	RedDark = rgb(96, 18, 20),
	Gold = rgb(236, 192, 104),
	GoldDark = rgb(150, 104, 46),
	Night = rgb(44, 38, 76),
	Good = rgb(36, 118, 44),
	Bad = rgb(176, 34, 30),
}
local W = WoodKit.Colors
local WHITE = Color3.new(1, 1, 1)

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r == "round" and UDim.new(1, 0) or UDim.new(0, r)
	c.Parent = o
	return c
end
WoodKit.Corner = corner

-- UIStroke ตรงๆ (ไม่ผ่านการแปลงของ UIKit.Stroke)
local function stroke(o, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = o
	return s
end
WoodKit.Stroke = stroke

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end
WoodKit.Frame = frame

local function shade(o, bottom)
	return UIKit.Gradient(o, WHITE, bottom or rgb(170, 160, 150), 90)
end

---------------------------------------------------------------- ภาพวาด (PanelArt)
function WoodKit.Art(parent, name, width, props)
	local ok, img = pcall(PanelArt.Image, name)
	local size = PanelArt.Size[name]
	if not ok or not img or not size then
		return nil
	end
	local l = Instance.new("ImageLabel")
	l.Name = "Art_" .. name
	l.BackgroundTransparency = 1
	l.ImageContent = Content.fromObject(img)
	l.Size = UDim2.fromOffset(width, math.floor(width * size.Y / size.X))
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

---------------------------------------------------------------- ตัวหนังสือหมึกบนกระดาษ (ไม่มีขอบดำ)
function WoodKit.Ink(parent, props)
	props.TextColor3 = props.TextColor3 or W.Ink
	props.Font = props.Font or UIKit.Fonts.Title
	local t = UIKit.Text(parent, props)
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then
		s:Destroy()
	end
	return t
end

---------------------------------------------------------------- ปุ่ม
-- สไตล์: { พื้น, ขอบ, ตัวหนังสือ }
local STYLES = {
	Red = { rgb(176, 38, 36), W.Gold, WHITE },
	Wood = { rgb(104, 68, 42), rgb(168, 124, 66), rgb(255, 240, 214) },
	Dark = { rgb(58, 42, 30), rgb(118, 88, 58), rgb(226, 210, 188) },
	Off = { rgb(96, 88, 80), rgb(66, 58, 52), rgb(206, 198, 188) },
	Green = { rgb(66, 128, 56), W.Gold, WHITE },
	Night = { rgb(64, 54, 110), rgb(160, 140, 220), WHITE },
	Parch = { W.Parch, rgb(150, 104, 46), W.Ink }, -- ปุ่มกระดาษ ตัวหนังสือหมึก (ไม่มีขอบดำ)
}

function WoodKit.Style(b, style)
	local s = STYLES[style] or STYLES.Wood
	b.BackgroundColor3 = s[1]
	b.TextColor3 = s[3]
	local rim = b:FindFirstChild("Rim")
	if rim then
		rim.Color = s[2]
	end
	for _, st in ipairs(b:GetChildren()) do
		if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			st.Enabled = style ~= "Parch"
		end
	end
	b:SetAttribute("Style", style)
end

function WoodKit.Button(parent, style, props, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = UIKit.Fonts.Title
	b.TextSize = 18
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	corner(b, 8)
	local rim = stroke(b, W.Gold, 2.5, 0)
	rim.Name = "Rim"
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.5, rgb(225, 220, 215)),
		ColorSequenceKeypoint.new(1, rgb(165, 155, 150)),
	})
	g.Rotation = 90
	g.Parent = b
	UIKit.TextStroke(b, math.clamp(b.TextSize / 10, 1.3, 2.6), 0.25)
	if b.Text ~= "" then
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = b
		UIKit.FitText(b)
	end
	WoodKit.Style(b, style)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.07), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		if UIKit.OnAnyClick then
			UIKit.OnAnyClick()
		end
		if onClick then
			onClick()
		end
	end)
	return b
end

-- แท็บด้านบน: เลือกอยู่ = แดงขอบทอง · ไม่ได้เลือก = ไม้เข้ม
function WoodKit.Tab(parent, text, order, width, onClick)
	return WoodKit.Button(parent, "Dark", { Size = UDim2.fromOffset(width or 170, 44), Text = text, TextSize = 18, LayoutOrder = order }, onClick)
end

function WoodKit.SetTab(b, on)
	WoodKit.Style(b, on and "Red" or "Dark")
end

-- ปุ่มปิด X วงกลมแดงขอบทอง
function WoodKit.CloseButton(parent, onClose, props)
	local b = WoodKit.Button(parent, "Red", { Size = UDim2.fromOffset(50, 50), Text = "", ZIndex = 20 }, onClose)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	b.Rim.Thickness = 3.5
	-- กากบาทวาดจาก Frame (ฟอนต์ Fredoka ไม่มีตัว ✕)
	for _, rot in ipairs({ 45, -45 }) do
		local bar = frame(b, { Size = UDim2.fromOffset(26, 6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = rot, BackgroundColor3 = WHITE, ZIndex = 21 })
		corner(bar, 3)
		stroke(bar, W.RedDark, 1.5, 0.2)
	end
	UIKit.EnsureTouchSize(b, 44, onClose)
	return b
end

---------------------------------------------------------------- การ์ดกระดาษ / ป้าย / เหรียญไอคอน
function WoodKit.Parchment(parent, props, tint)
	local f = frame(parent, props)
	f.BackgroundColor3 = tint or W.Parch
	corner(f, 6)
	stroke(f, W.ParchEdge, 2.5, 0)
	shade(f, rgb(228, 214, 196))
	-- เส้นขอบในจางๆ (ขอบกระดาษ)
	local edge = frame(f, { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Active = false })
	corner(edge, 4)
	stroke(edge, W.ParchEdge, 1, 0.65)
	return f
end

-- กล่องไม้เข้ม (แถบหัวข้อ/ช่องรางวัล)
function WoodKit.Board(parent, props, color, rimColor)
	local f = frame(parent, props)
	f.BackgroundColor3 = color or W.Inner
	corner(f, 6)
	stroke(f, rimColor or W.GoldDark, 2, 0)
	shade(f)
	return f
end

-- ริบบิ้นหัวข้อ (ภารกิจรายวัน/รายสัปดาห์ ฯลฯ) — แถบสี + หางธงซ้าย
function WoodKit.Ribbon(parent, props, color, text, textSize)
	local f = WoodKit.Board(parent, props, color or W.Red, W.Gold)
	local label = UIKit.Text(f, {
		Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(14, 0), Text = text or "", Font = UIKit.Fonts.Title, TextSize = textSize or 22, ZIndex = f.ZIndex + 1,
	})
	return f, label
end

-- เหรียญไม้กลมขอบทอง + ไอคอน (อีโมจิ หรือ "Ruby"/"Trophy"/"Scroll"/"Shield" ของ UIKit.Icon)
function WoodKit.Medallion(parent, icon, size, props, color)
	local f = frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color or rgb(74, 44, 26) })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	corner(f, "round")
	stroke(f, W.GoldDark, 3, 0)
	shade(f, rgb(150, 140, 135))
	local ring = frame(f, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8) })
	corner(ring, "round")
	stroke(ring, W.Gold, 1.5, 0.45)
	if icon == "Ruby" or icon == "Trophy" or icon == "Scroll" or icon == "Shield" then
		UIKit.Icon(f, icon, math.floor(size * 0.72), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = f.ZIndex + 1 })
	else
		UIKit.Text(f, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = math.floor(size * 0.5), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = f.ZIndex + 1 })
	end
	return f
end

-- แคปซูล Ruby ของเรา (มุมขวาบนของหน้าต่าง) -> คืน TextLabel ตัวเลข
function WoodKit.RubyPill(parent, props)
	local f = frame(parent, { Size = UDim2.fromOffset(170, 46), BackgroundColor3 = rgb(30, 20, 14) })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	corner(f, 10)
	stroke(f, W.GoldDark, 2.5, 0)
	UIKit.Icon(f, "Ruby", 50, { Position = UDim2.fromOffset(8, -3), ZIndex = f.ZIndex + 1 })
	return UIKit.Text(f, { Size = UDim2.new(1, -72, 1, 0), Position = UDim2.fromOffset(64, 0), Text = "0", Font = UIKit.Fonts.Title, TextSize = 28, ZIndex = f.ZIndex + 1 })
end

-- แสงวิ้งวิ่งผ่าน (ของที่กดรับได้)
function WoodKit.Shine(f, delayT)
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	-- อยู่ใต้ปุ่ม (ZIndex 4) ไม่บังการกด
	local sheen = frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 250, 220), ZIndex = f.ZIndex + 2, Active = false })
	corner(sheen, 6)
	g.Parent = sheen
	task.spawn(function()
		task.wait(delayT or 0)
		while sheen.Parent do
			g.Offset = Vector2.new(-1, 0)
			TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(3)
		end
	end)
	return sheen
end

---------------------------------------------------------------- ชิ้นประดับกรอบ
-- ธงแดงห้อย (ปลายแหลม) + ตราอุ้งเท้าสีทอง · x = UDim2 (ใช้แค่แกน X)
local function banner(parent, x, y, w, h, z)
	local b = frame(parent, { Size = UDim2.fromOffset(w, h), Position = x, BackgroundColor3 = W.Red, ZIndex = z })
	b.Position = UDim2.new(x.X.Scale, x.X.Offset, 0, y)
	stroke(b, W.GoldDark, 2, 0)
	UIKit.Gradient(b, rgb(255, 255, 255), rgb(150, 120, 120), 0)
	local side = w / math.sqrt(2)
	local tip = frame(b, { Size = UDim2.fromOffset(side, side), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0), Rotation = 45, BackgroundColor3 = W.Red, ZIndex = z })
	UIKit.Gradient(tip, rgb(255, 255, 255), rgb(150, 120, 120), 45)
	local paw = UIKit.Text(b, { Size = UDim2.new(1, 0, 0, w), Position = UDim2.fromOffset(0, h * 0.35), Text = "🐾", TextSize = math.floor(w * 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = W.Gold, ZIndex = z + 1 })
	paw.TextTransparency = 0.15
	-- ไม้คานบนธง
	frame(b, { Size = UDim2.new(1, 12, 0, 8), Position = UDim2.fromOffset(-6, -4), BackgroundColor3 = rgb(70, 44, 24), ZIndex = z + 1 })
	return b
end

-- โคมไฟข้างกรอบ (ตัวโคม + แสงเรืองวูบวาบ)
local function lantern(parent, pos, z)
	local holder = frame(parent, { BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 52), AnchorPoint = Vector2.new(0.5, 0), Position = pos, ZIndex = z })
	local glow = frame(holder, { Size = UDim2.fromOffset(120, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), BackgroundColor3 = rgb(255, 170, 70), ZIndex = z })
	corner(glow, "round")
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	-- UIGradient ใช้ไล่เป็นวงไม่ได้: ซ้อนวงเล็กอีกชั้นให้ตรงกลางสว่าง
	local core = frame(holder, { Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30), BackgroundColor3 = rgb(255, 200, 110), BackgroundTransparency = 0.7, ZIndex = z })
	corner(core, "round")
	frame(holder, { Size = UDim2.fromOffset(4, 12), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = rgb(40, 30, 22), ZIndex = z + 1 })
	local cap = frame(holder, { Size = UDim2.fromOffset(30, 8), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), BackgroundColor3 = rgb(54, 40, 28), ZIndex = z + 1 })
	corner(cap, 3)
	local body = frame(holder, { Size = UDim2.fromOffset(24, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 17), BackgroundColor3 = rgb(255, 196, 96), ZIndex = z + 1 })
	corner(body, 5)
	stroke(body, rgb(54, 40, 28), 3, 0)
	UIKit.Gradient(body, rgb(255, 250, 220), rgb(255, 150, 60), 90)
	local base = frame(holder, { Size = UDim2.fromOffset(28, 6), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 47), BackgroundColor3 = rgb(54, 40, 28), ZIndex = z + 1 })
	corner(base, 3)
	task.spawn(function()
		while holder.Parent do
			local k = 0.55 + math.random() * 0.12
			TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { BackgroundTransparency = k - 0.55 }):Play()
			task.wait(0.35 + math.random() * 0.3)
		end
	end)
	return holder
end

---------------------------------------------------------------- หน้าต่างหลัก
function WoodKit.Window(parent, opts)
	local w, h = opts.Size.X, opts.Size.Y
	local root = frame(parent, {
		Name = opts.Name or "WoodWindow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(w, h), Visible = opts.Visible == true,
	})
	-- แผ่นไม้ (กรอบนอก)
	local body = frame(root, { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = W.Wood, ZIndex = 2 })
	corner(body, 12)
	stroke(body, W.WoodDark, 4, 0)
	shade(body, rgb(150, 136, 124))
	-- ลายไม้บนขอบ
	for _, y in ipairs({ 5, 10, -11, -6 }) do
		frame(body, { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, y < 0 and 1 or 0, y), BackgroundColor3 = W.WoodDark, BackgroundTransparency = 0.6 })
	end
	-- แผ่นในเข้ม + ลายแผ่นไม้แนวตั้ง
	local inner = frame(body, { Name = "Inner", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), BackgroundColor3 = W.Inner, ClipsDescendants = true })
	corner(inner, 8)
	stroke(inner, W.GoldDark, 2, 0.35)
	shade(inner, rgb(140, 130, 124))
	for x = 90, w - 40, 96 do
		frame(inner, { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromOffset(x, 0), BackgroundColor3 = rgb(20, 12, 8), BackgroundTransparency = 0.7 })
	end
	-- หมุดทองที่มุม
	for _, p in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local stud = frame(body, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(p[1], p[1] == 0 and 7 or -7, p[2], p[2] == 0 and 7 or -7), BackgroundColor3 = W.Gold, ZIndex = 3 })
		corner(stud, "round")
		stroke(stud, W.WoodDark, 1.5, 0)
	end
	-- ธงแดงห้อยคร่อมขอบซ้าย/ขวา + โคมไฟใต้ธง
	local bh = opts.BannerHeight or math.floor(h * 0.3)
	if opts.Banners ~= false then
		banner(root, UDim2.fromOffset(-38, 0), 40, 44, bh, 4)
		banner(root, UDim2.new(1, -6, 0, 0), 40, 44, bh, 4)
	end
	if opts.Lanterns ~= false then
		lantern(root, UDim2.new(0, -16, 0, bh + 80), 6)
		lantern(root, UDim2.new(1, 16, 0, bh + 80), 6)
	end
	-- ป้ายชื่อ: กรอบไม้ + กระดาษ + ตัวหนังสือหมึก (Plaque = false: ไม่มีป้าย แต่ TitleWidth ยังใช้กำหนดระยะหัวสัตว์)
	local pw = opts.TitleWidth or math.clamp(#(opts.Title or "") * 6 + 120, 300, 420)
	local title
	if opts.Plaque ~= false then
		local plaque = frame(root, { Size = UDim2.fromOffset(pw, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -34), BackgroundColor3 = rgb(80, 50, 28), ZIndex = 10 })
		corner(plaque, 8)
		stroke(plaque, W.WoodDark, 3, 0)
		shade(plaque)
		local paper = WoodKit.Parchment(plaque, { Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), ZIndex = 11 })
		title = WoodKit.Ink(paper, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = opts.Title or "", TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12 })
	end
	-- หัวหมาป่า (ซ้าย หันเข้ากลาง) / อินทรี (ขวา) — อยู่นอกป้ายชื่อ ซ้อนแค่ขอบนิดเดียว และวาดทับป้าย ไม่ให้ป้ายบังหัว
	if opts.Beasts ~= false then
		WoodKit.Art(root, "Wolf", 150, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -pw / 2 + 8, 0, 34), ZIndex = 13 })
		WoodKit.Art(root, "Eagle", 136, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, pw / 2 - 6, 0, 36), ZIndex = 13 })
	end
	if opts.OnClose then
		WoodKit.CloseButton(root, opts.OnClose, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -16, 0, 14) })
	end
	return { Frame = root, Body = body, Inner = inner, Title = title }
end

return WoodKit
