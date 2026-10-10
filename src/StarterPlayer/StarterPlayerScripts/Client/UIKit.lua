--[[
	UIKit — ตัวช่วยสร้าง UI ใช้ทั้งเกม
	ธีม: เกม Roblox ยุคใหม่ — ปุ่มนูน 3D สีสด + ขอบเข้มหนา, ตัวหนังสือขาวขอบดำ, ฟอนต์ Fredoka, การ์ดกรมท่าเข้ม
	มีแอนิเมชันเด้งตอนชี้/กด/เปิดหน้าต่าง (UIKit.Pop)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

---------------------------------------------------------------- สเกลอัตโนมัติตามขนาดจอ (มือถือจอเล็ก = ย่อ UI ลง)
-- UIKit.AutoScale(frame): ใส่ UIScale ที่ปรับเองเมื่อจอเปลี่ยนขนาด · UIKit.UserScale = ตัวคูณจากหน้าตั้งค่า
UIKit.UserScale = 1
local scaled = setmetatable({}, { __mode = "k" })
function UIKit.GetScale()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local base = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1)
	return base * UIKit.UserScale
end
local function scaler(frame)
	local sc = frame:FindFirstChild("AutoScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "AutoScale"
		sc.Parent = frame
	end
	return sc
end
function UIKit.AutoScale(frame)
	scaler(frame).Scale = UIKit.GetScale()
	scaled[frame] = true
	return frame
end
function UIKit.RefreshScale()
	local k = UIKit.GetScale()
	for f in pairs(scaled) do
		if f.Parent then
			scaler(f).Scale = k
		end
	end
end
task.defer(function()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(UIKit.RefreshScale)
	end
end)

UIKit.Colors = {
	Panel = Color3.fromRGB(22, 24, 40),
	Panel2 = Color3.fromRGB(58, 66, 104),
	Outline = Color3.fromRGB(10, 10, 22),
	Gold = Color3.fromRGB(255, 208, 70),
	GoldDim = Color3.fromRGB(176, 150, 96),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(176, 184, 214),
	Red = Color3.fromRGB(236, 64, 72),
	Blood = Color3.fromRGB(170, 24, 36),
	Health = Color3.fromRGB(255, 72, 96),
	Hunger = Color3.fromRGB(255, 166, 48),
	Stamina = Color3.fromRGB(64, 224, 150),
	Fire = Color3.fromRGB(255, 138, 40),
	Good = Color3.fromRGB(96, 230, 120),
	Bad = Color3.fromRGB(255, 86, 80),
	-- สีปุ่ม (สดแบบเกมยุคใหม่)
	Green = Color3.fromRGB(72, 214, 96),
	Blue = Color3.fromRGB(56, 156, 255),
	Purple = Color3.fromRGB(150, 96, 255),
	Orange = Color3.fromRGB(255, 150, 40),
	Pink = Color3.fromRGB(255, 92, 168),
	Cyan = Color3.fromRGB(40, 210, 230),
	Element = {
		Earth = Color3.fromRGB(130, 230, 90),
		Water = Color3.fromRGB(80, 200, 255),
		Air = Color3.fromRGB(220, 232, 255),
		Fire = Color3.fromRGB(255, 110, 40),
		All = Color3.fromRGB(255, 70, 90),
	},
}
UIKit.ElementThai = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี", All = "ทุกธาตุ" }
UIKit.ElementIcon = { Earth = "🌿", Water = "🌊", Air = "🌪", Fire = "🔥", All = "🩸" }

UIKit.Fonts = {
	Title = Enum.Font.FredokaOne,
	Black = Enum.Font.FredokaOne,
	Bold = Enum.Font.BuilderSansBold,
	Body = Enum.Font.BuilderSansMedium,
}

local function darker(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end
UIKit.Darker = darker

function UIKit.Screen(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order or 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UIKit.Frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = UIKit.Colors.Panel
	f.BackgroundTransparency = 0.06
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

function UIKit.Corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, (r or 12) + 2)
	c.Parent = parent
	return c
end

-- ขอบ: ขอบขาวจางๆ (สไตล์กระจกเดิม) -> แปลงเป็นขอบเข้มหนาแบบการ์ตูน, ขอบสีอื่นใช้สีนั้นแต่หนาขึ้น
function UIKit.Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	color = color or Color3.new(1, 1, 1)
	transparency = transparency or 0.2
	local whiteish = color.R > 0.9 and color.G > 0.9 and color.B > 0.9
	if whiteish and transparency >= 0.6 then
		s.Color = UIKit.Colors.Outline
		s.Transparency = 0.1
		s.Thickness = 3
	else
		s.Color = color
		s.Transparency = math.min(transparency, 0.25)
		s.Thickness = math.clamp((thickness or 1) * 1.5, 2, 3.5)
	end
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIKit.Gradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

-- ขอบดำรอบตัวอักษร (ตัวหนังสือขาวขอบดำแบบเกมยุคใหม่)
function UIKit.TextStroke(obj, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = UIKit.Colors.Outline
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0.15
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	-- ขอบต้องจางตามตัวหนังสือ (ไม่งั้นข้อความที่ค่อยๆ โผล่/หาย เหลือเงาดำค้างกลางจอ)
	local base = s.Transparency
	local function sync()
		s.Transparency = base + (1 - base) * obj.TextTransparency
	end
	sync()
	obj:GetPropertyChangedSignal("TextTransparency"):Connect(sync)
	return s
end

function UIKit.Text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = UIKit.Colors.Text
	t.Font = UIKit.Fonts.Bold
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	local customStroke = props and props.TextStrokeTransparency ~= nil
	for k, v in pairs(props or {}) do
		if k ~= "TextStrokeTransparency" then
			t[k] = v
		end
	end
	t.Parent = parent
	-- ตัวหนังสือขนาดกลางขึ้นไปมีขอบดำเสมอ (อ่านง่ายบนฉากทุกแบบ)
	if t.TextSize >= 14 or t.TextScaled or customStroke then
		UIKit.TextStroke(t, t.TextScaled and 2 or math.clamp(t.TextSize / 11, 1.2, 3.5), 0.2)
	end
	return t
end

-- ปุ่มนูน 3D: ไล่สีสว่างด้านบน + ขอบล่างเข้ม (ปาก) + ขอบรอบเข้ม + ตัวหนังสือขาวขอบดำ + เด้งตอนชี้/กด
function UIKit.Button(parent, props, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = UIKit.Colors.Panel2
	b.TextColor3 = UIKit.Colors.Text
	b.Font = UIKit.Fonts.Black
	b.TextSize = 16
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	UIKit.Corner(b, 12)
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Thickness = 2.5
	border.LineJoinMode = Enum.LineJoinMode.Round
	border.Color = darker(b.BackgroundColor3, 0.4)
	border.Parent = b
	b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		border.Color = darker(b.BackgroundColor3, 0.4)
	end)
	UIKit.TextStroke(b, math.clamp(b.TextSize / 10, 1.5, 3), 0.1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(236, 236, 236)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(205, 205, 205)),
		ColorSequenceKeypoint.new(0.81, Color3.fromRGB(150, 150, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 140)),
	})
	g.Rotation = 90
	g.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
		TweenService:Create(border, TweenInfo.new(0.12), { Thickness = 3.2 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(border, TweenInfo.new(0.12), { Thickness = 2.5 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.07), { Scale = 0.93 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
	b.Activated:Connect(function()
		if UIKit.OnAnyClick then
			UIKit.OnAnyClick()
		end
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- ปุ่มสีสด (เขียว/น้ำเงิน/ม่วง...) — ทางลัดของ Button
function UIKit.ColorButton(parent, color, props, onClick)
	props = props or {}
	props.BackgroundColor3 = color
	return UIKit.Button(parent, props, onClick)
end

-- ปุ่มปิด X วงกลมแดงมุมขวาบน
function UIKit.CloseButton(panel, onClose)
	local b = UIKit.Button(panel, {
		Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -30, 0, -14), BackgroundColor3 = UIKit.Colors.Red, Text = "✕", TextSize = 24, ZIndex = 10,
	}, onClose)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	return b
end

-- แถบหัวหน้าต่างสีสด (ริบบิ้น) วางทับขอบบนของการ์ด
function UIKit.Header(panel, text, color)
	color = color or UIKit.Colors.Blue
	local h = UIKit.Frame(panel, {
		Size = UDim2.new(0.6, 0, 0, 46), Position = UDim2.new(0.2, 0, 0, -22), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 5,
	})
	UIKit.Corner(h, 14)
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = darker(color, 0.4)
	s.Parent = h
	UIKit.Gradient(h, Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180), 90)
	local t = UIKit.Text(h, {
		Size = UDim2.fromScale(1, 1), Text = text, Font = UIKit.Fonts.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
	})
	return h, t
end

-- การ์ดหน้าต่างหลัก (พื้นกรมท่าไล่สี + ขอบเข้มหนา + ขอบในสว่าง)
function UIKit.Card(parent, props)
	local f = UIKit.Frame(parent, props)
	f.BackgroundColor3 = props and props.BackgroundColor3 or Color3.fromRGB(34, 38, 64)
	f.BackgroundTransparency = props and props.BackgroundTransparency or 0
	UIKit.Corner(f, 18)
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = UIKit.Colors.Outline
	s.Parent = f
	UIKit.Gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 156, 180), 90)
	return f
end

-- เปิดหน้าต่างแบบเด้ง
function UIKit.Pop(frame)
	local target = UIKit.GetScale()
	local sc = scaler(frame)
	scaled[frame] = true
	sc.Scale = target * 0.82
	TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	if UIKit.OnPop then
		UIKit.OnPop()
	end
end

-- แถบค่า (เลือด/หิว/สตามิน่า): ร่องเข้ม + ขอบดำ + ไฮไลต์มันวาวด้านบน
function UIKit.Bar(parent, props)
	local holder = UIKit.Frame(parent, {
		Size = props.Size, Position = props.Position, BackgroundColor3 = Color3.fromRGB(14, 14, 26), BackgroundTransparency = 0.05, ClipsDescendants = true,
	})
	local h = props.Size and props.Size.Y.Offset or 12
	local function round(o)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, math.max(3, h / 2))
		c.Parent = o
	end
	round(holder)
	local st = Instance.new("UIStroke")
	st.Thickness = h >= 12 and 2.5 or 2
	st.Color = UIKit.Colors.Outline
	st.Parent = holder
	local lag = UIKit.Frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.35 })
	round(lag)
	local fill = UIKit.Frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = props.Color, BackgroundTransparency = 0 })
	round(fill)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.36, Color3.fromRGB(215, 215, 215)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 165, 165)),
	})
	g.Rotation = 90
	g.Parent = fill
	local label = UIKit.Text(holder, {
		Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = math.clamp(h - 6, 11, 16), Font = UIKit.Fonts.Black,
		Text = props.Label or "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 3, TextStrokeTransparency = 0,
	})
	local api = { Holder = holder, Fill = fill, Label = label, Value = 1 }
	function api.Set(frac, text)
		frac = math.clamp(frac, 0, 1)
		if math.abs(frac - api.Value) > 0.001 then
			TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(frac, 1) }):Play()
			if frac < api.Value then
				TweenService:Create(lag, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
			else
				lag.Size = UDim2.fromScale(frac, 1)
			end
			api.Value = frac
		end
		if text then
			label.Text = text
		end
	end
	return api
end

-- ไอคอนวงกลมสีสด (ใช้หน้าแถบค่า / ปุ่มเมนู)
function UIKit.IconBadge(parent, icon, color, size, props)
	local f = UIKit.Frame(parent, { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 4 })
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = UIKit.Colors.Outline
	s.Parent = f
	UIKit.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)
	UIKit.Text(f, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = math.floor(size * 0.55), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	return f
end

function UIKit.Tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

return UIKit
