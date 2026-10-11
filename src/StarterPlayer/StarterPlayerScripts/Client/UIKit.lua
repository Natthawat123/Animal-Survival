--[[
	UIKit — ตัวช่วยสร้าง UI ใช้ทั้งเกม
	ธีม: เกม Roblox ยุคใหม่ — ปุ่มนูน 3D สีสด + ขอบเข้มหนา, ตัวหนังสือขาวขอบดำ, ฟอนต์ Fredoka, การ์ดกรมท่าเข้ม
	มีแอนิเมชันเด้งตอนชี้/กด/เปิดหน้าต่าง (UIKit.Pop)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

---------------------------------------------------------------- สเกลอัตโนมัติตามขนาดจอ (มือถือจอเล็ก = ย่อ UI ลง)
-- UIKit.AutoScale(frame): ใส่ UIScale ที่ปรับเองเมื่อจอเปลี่ยนขนาด · UIKit.UserScale = ตัวคูณจากหน้าตั้งค่า
--   หน้าต่างกลางจอ (AnchorPoint 0.5,0.5 + ขนาดเป็นพิกเซล) จะถูกย่อเพิ่มจน "พอดีจอเสมอ" (ปุ่มปิด/หัวหน้าต่างไม่หลุดขอบ)
UIKit.UserScale = 1
UIKit.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local scaled = setmetatable({}, { __mode = "k" })
local function viewport()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 50 or vp.Y < 50 then
		vp = Vector2.new(1280, 720)
	end
	return vp
end
function UIKit.GetScale(frame)
	local vp = viewport()
	-- มือถือ: อ้างอิงจอเล็กกว่า (UI ใหญ่ขึ้นนิด ปุ่มกดง่าย) — หน้าต่างใหญ่ยังถูกบีบให้พอดีจอด้านล่าง
	local refX, refY = 1280, 720
	if UIKit.IsTouch then
		refX, refY = 1100, 620
	end
	local base = math.clamp(math.min(vp.X / refX, vp.Y / refY), 0.4, 1) * UIKit.UserScale
	if frame and frame:IsA("GuiObject") and frame.AnchorPoint == Vector2.new(0.5, 0.5) and frame.Size.X.Scale == 0 and frame.Size.Y.Scale == 0 then
		-- เผื่อขอบ: แถบหัวหน้าต่าง (ยื่นขึ้น ~24) + ปุ่มปิด (ยื่นออก ~30) + ระยะห่างจากขอบจอ
		local w, h = frame.Size.X.Offset + 70, frame.Size.Y.Offset + 70
		base = math.min(base, (vp.X - 16) / w, (vp.Y - 16) / h)
	end
	return math.max(base, 0.3)
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
	scaler(frame).Scale = UIKit.GetScale(frame)
	scaled[frame] = true
	return frame
end
function UIKit.RefreshScale()
	for f in pairs(scaled) do
		if f.Parent then
			scaler(f).Scale = UIKit.GetScale(f)
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

-- fullScreen = true: เต็มจอจริง (ฉากโหลด/ข้อความภาพยนตร์) · อื่นๆ หลบติ่งกล้อง/ขอบโค้งของมือถือ (DeviceSafeInsets)
function UIKit.Screen(name, order, fullScreen)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	if not fullScreen then
		pcall(function()
			gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		end)
	end
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

-- ข้อความบรรทัดเดียวยาวเกินกรอบ (ภาษาไทยยาวกว่าอังกฤษ) -> ย่อตัวอักษรลงเองให้พอดีกรอบ ไม่ล้นออกนอกปุ่ม/การ์ด
-- (ขนาดปกติไม่เปลี่ยน: ใช้ TextScaled + จำกัดไม่ให้ใหญ่กว่า TextSize เดิม)
function UIKit.FitText(obj)
	if obj.TextScaled or obj.TextWrapped or obj.AutomaticSize ~= Enum.AutomaticSize.None or obj:FindFirstChildOfClass("UITextSizeConstraint") then
		return
	end
	local size = obj.TextSize
	local h = obj.Size.Y
	if h.Scale == 0 and h.Offset < size * 0.85 then
		return -- กรอบเตี้ยกว่าตัวอักษร (ตั้งใจให้ล้นขึ้นลง) ไม่ยุ่ง
	end
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.MinTextSize = math.max(8, math.floor(size * 0.5))
	c.Parent = obj
	obj.TextScaled = true
	-- โค้ดที่ตั้ง/ทวีน TextSize ทีหลัง (เช่น ป้ายใหญ่กลางจอ) ยังได้ขนาดตามที่ตั้ง
	obj:GetPropertyChangedSignal("TextSize"):Connect(function()
		c.MaxTextSize = math.max(1, obj.TextSize)
		c.MinTextSize = math.min(c.MaxTextSize, math.max(8, math.floor(obj.TextSize * 0.5)))
	end)
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
	UIKit.FitText(t)
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
	if b.Text ~= "" then
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = b
		UIKit.FitText(b)
	end
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
	UIKit.EnsureTouchSize(b, 44, onClose)
	return b
end

---------------------------------------------------------------- ปุ่มนิ้วกดง่าย (มือถือ)
-- ปุ่มที่อยู่ในกรอบที่ถูกย่อ (AutoScale) อาจเล็กกว่า 44px บนจอจริง -> ใส่พื้นที่แตะล่องหนรอบปุ่มให้ได้อย่างน้อย minPx บนจอเสมอ
-- (เฉพาะเครื่องจอสัมผัส · onActivate = ฟังก์ชันเดียวกับที่ปุ่มทำ)
function UIKit.EnsureTouchSize(button, minPx, onActivate)
	if not (UIKit.IsTouch and button and onActivate) or button:FindFirstChild("TouchHit") then
		return
	end
	minPx = minPx or 44
	local hit = Instance.new("TextButton")
	hit.Name = "TouchHit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = button.ZIndex + 1
	hit.Parent = button
	local function fit()
		local abs, off = button.AbsoluteSize, button.Size
		if abs.X <= 0 or abs.Y <= 0 or off.X.Offset <= 0 or off.Y.Offset <= 0 then
			return
		end
		-- ตัวคูณสเกลจริงบนจอ (รวม UIScale ของกรอบแม่ทุกชั้น)
		local k = math.max(abs.X / off.X.Offset, 0.05)
		local need = minPx / k
		hit.Size = UDim2.fromOffset(math.max(off.X.Offset, need), math.max(off.Y.Offset, need))
	end
	button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	hit.Activated:Connect(function()
		if not button.Visible then
			return
		end
		if UIKit.OnAnyClick then
			UIKit.OnAnyClick()
		end
		onActivate()
	end)
	return hit
end

---------------------------------------------------------------- หน้าต่าง: ปิดด้วย Esc / แตะนอกหน้าต่าง
-- UIKit.RegisterWindow(frame, closeFn, opts)
--   frame   = กรอบหน้าต่างที่สลับ Visible เปิด/ปิด
--   closeFn = ฟังก์ชันปิด (ไม่ใส่ = frame.Visible = false)
--   opts.Backdrop = false : ไม่ต้องปิดเมื่อแตะนอกหน้าต่าง (หน้าต่างเต็มจอ / หน้าสอนเล่น)
--   opts.Dim = 0..1       : ความมืดของพื้นหลังด้านหลังหน้าต่าง (ค่าเริ่ม 1 = ใส)
-- Esc ปิดหน้าต่างที่เปิดล่าสุดทีละบาน
local windows = {}
local escBound = false
local lastEscClose = 0

local function shownOnScreen(obj)
	local o = obj
	while o do
		if o:IsA("GuiObject") then
			if not o.Visible then
				return false
			end
		elseif o:IsA("LayerCollector") then
			return o.Enabled
		end
		o = o.Parent
	end
	return false
end

function UIKit.TopWindow()
	local best
	for _, w in ipairs(windows) do
		if w.Frame.Parent and shownOnScreen(w.Frame) and (not best or w.Opened > best.Opened) then
			best = w
		end
	end
	return best
end

function UIKit.AnyWindowOpen()
	return UIKit.TopWindow() ~= nil
end

function UIKit.CloseTopWindow()
	local w = UIKit.TopWindow()
	if not w then
		return false
	end
	lastEscClose = os.clock()
	local ok, err = pcall(w.Close)
	if not ok then
		warn("[AS] close window", err)
		w.Frame.Visible = false
	end
	return true
end

local function bindEsc()
	if escBound then
		return
	end
	escBound = true
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if os.clock() - lastEscClose > 0.15 then
				UIKit.CloseTopWindow()
			end
		end
	end)
end

function UIKit.RegisterWindow(frame, closeFn, opts)
	if not frame then
		return
	end
	opts = opts or {}
	local w = {
		Frame = frame,
		Close = closeFn or function()
			frame.Visible = false
		end,
		Opened = frame.Visible and os.clock() or 0,
	}
	table.insert(windows, w)
	bindEsc()
	local backdrop
	if opts.Backdrop ~= false and frame.Parent then
		backdrop = Instance.new("TextButton")
		backdrop.Name = frame.Name .. "_Backdrop"
		backdrop.Text = ""
		backdrop.AutoButtonColor = false
		backdrop.BorderSizePixel = 0
		backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
		backdrop.BackgroundTransparency = opts.Dim or 1
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.AnchorPoint = Vector2.new(0, 0)
		backdrop.Position = UDim2.fromScale(0, 0)
		backdrop.ZIndex = frame.ZIndex - 1
		backdrop.Visible = frame.Visible
		backdrop.Parent = frame.Parent
		backdrop.Activated:Connect(function()
			if frame.Visible then
				w.Close()
			end
		end)
		w.Backdrop = backdrop
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			w.Opened = os.clock()
		end
		if backdrop then
			backdrop.Visible = frame.Visible
		end
	end)
	frame.Destroying:Connect(function()
		if backdrop then
			backdrop:Destroy()
		end
		local i = table.find(windows, w)
		if i then
			table.remove(windows, i)
		end
	end)
	return w
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
	local target = UIKit.GetScale(frame)
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

-- ไอคอนวาดจาก Frame (ไม่ต้องอัปโหลดรูป): "Ruby" ทับทิม (สกุลเงิน) · "Ruby" แร่ · "Shield" โล่ดาบ (คลาส) · "Trophy" ถ้วยรางวัล (ป้าย)
-- ทุกชิ้น = สี่เหลี่ยมหมุนได้ + มุมมน + ไล่สีแบบแบ่งหน้าเหลี่ยม + ขอบเข้มด้านหลัง (สไตล์การ์ตูน)
local SQ2 = math.sqrt(2)
local function facet(light, dark, darker)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, light),
		ColorSequenceKeypoint.new(0.499, light),
		ColorSequenceKeypoint.new(0.5, dark),
		ColorSequenceKeypoint.new(1, darker or dark),
	})
end
function UIKit.Icon(parent, kind, size, props)
	local root = Instance.new("Frame")
	root.Name = "Icon" .. kind
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(size, size)
	for k, v in pairs(props or {}) do
		root[k] = v
	end
	root.Parent = parent
	local s, z0 = size, root.ZIndex
	local function piece(z, cx, cy, w, h, rot, fill, opt)
		opt = opt or {}
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx, cy)
		f.Size = UDim2.fromOffset(w, h)
		f.Rotation = rot
		f.ZIndex = z0 + z
		f.BackgroundTransparency = opt.tr or 0
		if typeof(fill) == "Color3" then
			f.BackgroundColor3 = fill
		else
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			local g = Instance.new("UIGradient")
			g.Color = fill
			g.Rotation = opt.grot or 0
			g.Parent = f
		end
		if opt.corner then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, math.min(w, h) / 2 * opt.corner)
			c.Parent = f
		end
		if opt.ring then
			f.BackgroundTransparency = 1
			local st = Instance.new("UIStroke")
			st.Thickness = opt.ring
			st.Color = fill
			st.Parent = f
		end
		f.Parent = root
		return f
	end
	if kind == "Ore" then
		local o, dark = s * 0.045, Color3.fromRGB(58, 14, 22)
		local red = facet(Color3.fromRGB(255, 120, 120), Color3.fromRGB(196, 28, 46), Color3.fromRGB(150, 16, 34))
		local function shard(bx, by, W, H, rot, z)
			local bodyH = H - W / 2
			local th = math.rad(rot)
			local function tr(lx, ly)
				return bx + lx * math.cos(th) - ly * math.sin(th), by + lx * math.sin(th) + ly * math.cos(th)
			end
			local bcx, bcy = tr(0, -bodyH / 2)
			local tcx, tcy = tr(0, -bodyH)
			local side = W / SQ2
			piece(z, bcx, bcy, W + 2 * o, bodyH + 2 * o, rot, dark)
			piece(z, tcx, tcy, side + 2 * o, side + 2 * o, rot + 45, dark)
			piece(z + 1, tcx, tcy, side, side, rot + 45, red, { grot = -45 })
			piece(z + 2, bcx, bcy, W, bodyH, rot, red)
			local hx, hy = tr(-W * 0.22, -bodyH * 0.62)
			piece(z + 3, hx, hy, W * 0.11, bodyH * 0.5, rot, Color3.fromRGB(255, 220, 220), { tr = 0.25, corner = 1 })
		end
		shard(s * 0.32, s * 0.74, s * 0.2, s * 0.44, -24, 1)
		shard(s * 0.69, s * 0.75, s * 0.19, s * 0.4, 22, 5)
		shard(s * 0.5, s * 0.72, s * 0.27, s * 0.64, 0, 9)
		local rock = ColorSequence.new(Color3.fromRGB(150, 138, 150), Color3.fromRGB(84, 74, 88))
		local blobs = { { 0.34, 0.79, 0.4, 0.3 }, { 0.62, 0.8, 0.5, 0.26 }, { 0.5, 0.85, 0.74, 0.16 } }
		for _, b in ipairs(blobs) do
			piece(20, s * b[1], s * b[2], s * b[3] + 2 * o, s * b[4] + 2 * o, 0, Color3.fromRGB(30, 22, 30), { corner = 0.75 })
		end
		for _, b in ipairs(blobs) do
			piece(21, s * b[1], s * b[2], s * b[3], s * b[4], 0, rock, { grot = 90, corner = 0.75 })
		end
		piece(22, s * 0.38, s * 0.74, s * 0.14, s * 0.05, -8, Color3.fromRGB(200, 190, 205), { tr = 0.45, corner = 1 })
	elseif kind == "Ruby" then
		-- ทับทิมเจียระไน: ทรงข้าวหลามตัด ซีกซ้ายสว่าง/ขวาเข้ม + ครึ่งบนอ่อน + หน้าโต๊ะกลาง + ประกาย
		local cx, cy, side, o = s / 2, s * 0.52, s * 0.6, s * 0.05
		local hard = function(a, b)
			return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.499, a), ColorSequenceKeypoint.new(0.5, b), ColorSequenceKeypoint.new(1, b) })
		end
		piece(1, cx, cy, side + 2 * o, side + 2 * o, 45, Color3.fromRGB(74, 6, 24), { corner = 0.12 })
		piece(2, cx, cy, side, side, 45, facet(Color3.fromRGB(246, 52, 86), Color3.fromRGB(188, 16, 50), Color3.fromRGB(150, 8, 40)), { grot = -45, corner = 0.12 })
		piece(3, cx, cy, side * 0.999, side * 0.999, 45, hard(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), { grot = 45, tr = 0.86, corner = 0.12 })
		local t = side * 0.5
		piece(4, cx, cy - s * 0.04, t, t, 45, facet(Color3.fromRGB(255, 150, 168), Color3.fromRGB(236, 70, 100)), { grot = -45 })
		piece(5, cx, cy - s * 0.04, t * 0.55, t * 0.55, 45, facet(Color3.fromRGB(255, 205, 214), Color3.fromRGB(255, 140, 160)), { grot = -45 })
		for _, f in ipairs({ { 45, -1, -1 }, { -45, 1, -1 }, { -45, -1, 1 }, { 45, 1, 1 } }) do
			piece(6, cx + f[2] * s * 0.13, cy - s * 0.04 + f[3] * s * 0.13, s * 0.02, s * 0.21, f[1], Color3.fromRGB(255, 170, 185), { tr = 0.5 })
		end
		piece(7, cx - s * 0.16, cy - s * 0.16, s * 0.14, s * 0.028, -45, Color3.new(1, 1, 1), { tr = 0.05, corner = 1 })
		piece(7, cx - s * 0.08, cy - s * 0.22, s * 0.05, s * 0.05, 45, Color3.new(1, 1, 1), { tr = 0.05 })
		piece(7, cx + s * 0.2, cy + s * 0.12, s * 0.035, s * 0.035, 45, Color3.fromRGB(255, 225, 232), { tr = 0.2 })
	elseif kind == "Scroll" then
		-- ม้วนคัมภีร์ภารกิจ: กระดาษ + ม้วนไม้บนล่าง + เส้นตัวหนังสือ + ตราประทับแดง
		local o, dark = s * 0.045, Color3.fromRGB(70, 40, 14)
		local paper = ColorSequence.new(Color3.fromRGB(255, 244, 214), Color3.fromRGB(240, 214, 160))
		local roll = ColorSequence.new(Color3.fromRGB(236, 196, 130), Color3.fromRGB(196, 140, 74))
		piece(1, s * 0.5, s * 0.5, s * 0.56 + 2 * o, s * 0.62 + 2 * o, 0, dark, { corner = 0.08 })
		piece(2, s * 0.5, s * 0.5, s * 0.56, s * 0.62, 0, paper, { grot = 90, corner = 0.08 })
		for _, y in ipairs({ 0.2, 0.8 }) do
			piece(3, s * 0.5, s * y, s * 0.72 + 2 * o, s * 0.13 + 2 * o, 0, dark, { corner = 1 })
			piece(4, s * 0.5, s * y, s * 0.72, s * 0.13, 0, roll, { grot = 90, corner = 1 })
			for _, x in ipairs({ 0.14, 0.86 }) do
				piece(5, s * x, s * y, s * 0.07, s * 0.16, 0, Color3.fromRGB(150, 96, 46), { corner = 0.5 })
			end
		end
		for _, l in ipairs({ { 0.36, 0.36 }, { 0.45, 0.4 }, { 0.54, 0.3 }, { 0.63, 0.22 } }) do
			piece(5, s * (0.31 + l[2] / 2), s * l[1], s * l[2], s * 0.035, 0, Color3.fromRGB(150, 112, 70), { corner = 1 })
		end
		piece(6, s * 0.66, s * 0.64, s * 0.17 + 2 * o, s * 0.17 + 2 * o, 0, Color3.fromRGB(90, 10, 20), { corner = 1 })
		piece(7, s * 0.66, s * 0.64, s * 0.17, s * 0.17, 0, ColorSequence.new(Color3.fromRGB(255, 90, 100), Color3.fromRGB(196, 24, 44)), { grot = 90, corner = 1 })
		piece(8, s * 0.66, s * 0.64, s * 0.06, s * 0.06, 45, Color3.fromRGB(255, 210, 210), { tr = 0.2 })
	elseif kind == "Shield" then
		local o, dark = s * 0.05, Color3.fromRGB(26, 26, 44)
		local W, bodyH, top = s * 0.62, s * 0.34, s * 0.12
		local side = W / SQ2
		local blue = facet(Color3.fromRGB(110, 160, 255), Color3.fromRGB(62, 100, 210), Color3.fromRGB(44, 76, 176))
		piece(1, s / 2, top + bodyH / 2, W + 2 * o, bodyH + 2 * o, 0, dark, { corner = 0.22 })
		piece(1, s / 2, top + bodyH, side + 2 * o, side + 2 * o, 45, dark, { corner = 0.16 })
		piece(2, s / 2, top + bodyH, side, side, 45, blue, { grot = -45, corner = 0.16 })
		piece(3, s / 2, top + bodyH / 2, W, bodyH, 0, blue, { corner = 0.22 })
		local steel = facet(Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 204, 222))
		local gold = ColorSequence.new(Color3.fromRGB(255, 230, 130), Color3.fromRGB(222, 150, 40))
		local bw, bh, bcy, oo = s * 0.11, s * 0.4, s * 0.44, o * 0.7
		local ts = bw / SQ2
		piece(4, s / 2, bcy, bw + 2 * oo, bh + 2 * oo, 0, dark)
		piece(4, s / 2, bcy - bh / 2, ts + 2 * oo, ts + 2 * oo, 45, dark)
		piece(5, s / 2, bcy - bh / 2, ts, ts, 45, steel, { grot = -45 })
		piece(6, s / 2, bcy, bw, bh, 0, steel)
		local hilt = { { 0.66, 0.36, 0.08, 0.4 }, { 0.74, 0.08, 0.12, 0.2 }, { 0.82, 0.13, 0.08, 1 } }
		for _, h in ipairs(hilt) do
			piece(7, s / 2, s * h[1], s * h[2] + 2 * oo, s * h[3] + 2 * oo, 0, dark, { corner = h[4] })
		end
		for _, h in ipairs(hilt) do
			piece(8, s / 2, s * h[1], s * h[2], s * h[3], 0, gold, { grot = 90, corner = h[4] })
		end
	elseif kind == "Trophy" then
		local o, dark = s * 0.045, Color3.fromRGB(70, 40, 8)
		local gold = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 140)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(246, 184, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 138, 28)),
		})
		local ring, d = s * 0.06, s * 0.18
		for _, x in ipairs({ 0.25, 0.75 }) do
			piece(1, s * x, s * 0.36, d - 2 * o, d - 2 * o, 0, dark, { corner = 1, ring = ring + 2 * o })
			piece(2, s * x, s * 0.36, d, d, 0, Color3.fromRGB(240, 176, 46), { corner = 1, ring = ring })
		end
		local parts = { { 0.5, 0.42, 0.5, 0.5, 1 }, { 0.5, 0.27, 0.5, 0.2, 0.06 }, { 0.5, 0.71, 0.11, 0.14, 0 }, { 0.5, 0.8, 0.3, 0.07, 0.3 }, { 0.5, 0.87, 0.46, 0.1, 0.3 } }
		for _, q in ipairs(parts) do
			piece(3, s * q[1], s * q[2], s * q[3] + 2 * o, s * q[4] + 2 * o, 0, dark, { corner = q[5] })
		end
		for _, q in ipairs(parts) do
			piece(4, s * q[1], s * q[2], s * q[3], s * q[4], 0, gold, { grot = 90, corner = q[5] })
		end
		piece(5, s * 0.4, s * 0.36, s * 0.07, s * 0.2, 0, Color3.fromRGB(255, 250, 220), { tr = 0.3, corner = 1 })
		piece(5, s * 0.5, s * 0.17, s * 0.5, s * 0.04, 0, Color3.fromRGB(255, 246, 200), { tr = 0.2, corner = 1 })
	end
	return root
end

function UIKit.Tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

return UIKit
