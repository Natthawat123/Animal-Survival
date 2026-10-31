--[[
	Cinematics — ฉาก/ตัวอักษรใหญ่แบบภาพยนตร์
	  หน้าโหลด, NIGHT X, BLOOD MOON, เปิดตัวบอส (กล้องหมุน), BEAST VANQUISHED, YOU PERISHED, ฉากจบ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)

local Cinematics = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local gui

local TIPS = {
	"กองไฟคือชีวิต — ไฟดับเมื่อไร กวางกลวงจะเข้ามาในแคมป์",
	"อัปเกรดกองไฟเพื่อเปิดหมอก และขยายเขตปลอดภัย",
	"ถือคบเพลิงไว้ กวางกลวงจะไม่กล้าเข้าใกล้",
	"น้ำชนะไฟ · ไฟชนะลม · ลมชนะดิน · ดินชนะน้ำ",
	"ลูกสัตว์ธาตุ 4 ตัวถูกขังอยู่ในศาลเจ้า ช่วยครบเพื่อฉากจบที่แท้จริง",
	"ทุก 10 คืนจะเกิดพระจันทร์เลือด ฝูงทุกธาตุบุกพร้อมกัน",
	"เพื่อนล้มลง? ใช้ผ้าพันแผลช่วยให้ทันใน 30 วินาที — ไม่เหลือใครยืนอยู่ = แพ้ทั้งทีม",
	"ตายแล้วไม่เกิดใหม่ในรอบนั้น — ช่วยกันระวังหลังให้กัน",
	"รอดครบ 99 คืน = พิชิต! แต่เล่นต่อได้ไม่จำกัดเพื่อทำสถิติขึ้นกระดานอันดับ",
	"หน้าไม้ยักษ์ยิงเองอัตโนมัติ วางไว้รอบกองไฟ",
	"ลมพัดขึ้นในเขตวายุจะส่งคุณขึ้นสู่เกาะลอยฟ้า",
	"รังบอสอยู่ใจกลางแต่ละธาตุ — เตรียมตัวให้พร้อมก่อนเข้าไป",
}

local function bigText(parent)
	return UIKit.Text(parent, {
		Size = UDim2.new(1, 0, 0, 90), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 72, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), TextTransparency = 1,
	})
end

local function fadeTexts(frame, to, time)
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(time), { TextTransparency = to, TextStrokeTransparency = math.max(to, 0.4) }):Play()
		elseif d:IsA("Frame") and d:GetAttribute("Line") then
			TweenService:Create(d, TweenInfo.new(time), { BackgroundTransparency = to }):Play()
		end
	end
end

-- ข้อความใหญ่กลางจอ (หายเอง)
function Cinematics.Banner(title, subtitle, color, hold, opts)
	opts = opts or {}
	title, subtitle = UIKit.StripIcons(title), UIKit.StripIcons(subtitle)
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 170), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, opts.Y or 0.28, 0), BackgroundTransparency = 1 })
	UIKit.AutoScale(f) -- มือถือ: ตัวหนังสือใหญ่กลางจอย่อตามจอ
	local t = bigText(f)
	t.Text = title
	t.TextColor3 = color or C.Gold
	t.TextSize = opts.Size or 72
	local s = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 100), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Bold,
		TextSize = 24, Text = subtitle or "", TextColor3 = C.Text, TextTransparency = 1, TextStrokeTransparency = 1,
	})
	local _ = s
	fadeTexts(f, 0, 0.8)
	task.delay(hold or 3, function()
		fadeTexts(f, 1, 1.2)
		task.wait(1.3)
		f:Destroy()
	end)
	return f
end

-- แถบดำบน-ล่าง
local bars
local function letterbox(on)
	if not bars then
		bars = {
			UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 }),
			UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 }),
		}
	end
	for _, b in ipairs(bars) do
		UIKit.Tween(b, 0.6, { Size = UDim2.new(1, 0, on and 0.12 or 0, 0) })
	end
end

---------------------------------------------------------------- หน้าโหลด (เข้าเกม + เดินทางลงแมพ)
-- ฉากหลัง 3 มิติ: แคมป์กลางป่ายามค่ำ (โมเดลจริงในเกม) กล้องค่อยๆ หมุนรอบกองไฟ + มังกรเฝ้าอยู่หลังแนวป่า
local function asset(folder, name)
	local a = ReplicatedStorage:FindFirstChild("Assets")
	local f = a and a:FindFirstChild(folder)
	local src = f and f:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	if m:IsA("BasePart") then
		local wrap = Instance.new("Model")
		m.Parent = wrap
		wrap.PrimaryPart = m
		m = wrap
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	return m
end

local function placeModel(world, m, height, cf)
	if not m then
		return nil
	end
	m.Parent = world
	local _, size = m:GetBoundingBox()
	if height and size.Y > 0.05 then
		pcall(function()
			m:ScaleTo(m:GetScale() * height / size.Y)
		end)
	end
	local bcf, bsize = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local foot = pivot.Position.Y - (bcf.Position.Y - bsize.Y / 2)
	local off = pivot.Position - bcf.Position
	m:PivotTo(cf * CFrame.new(off.X, foot, off.Z) * (pivot - pivot.Position))
	return m
end

local function campScene(parent)
	local vpf = Instance.new("ViewportFrame")
	-- ใหญ่กว่าจอนิดหน่อย: เลื่อนกรอบภาพช้าๆ แทนการขยับกล้อง (ฉาก 3 มิติวาดครั้งเดียว ไม่ต้องวาดใหม่ทุกเฟรม = ไม่แลค)
	vpf.AnchorPoint = Vector2.new(0.5, 0.5)
	vpf.Position = UDim2.fromScale(0.5, 0.5)
	vpf.Size = UDim2.fromScale(1.12, 1.12)
	vpf.BackgroundTransparency = 1
	vpf.ZIndex = 100
	vpf.Ambient = Color3.fromRGB(70, 74, 120)
	vpf.LightColor = Color3.fromRGB(255, 150, 80)
	vpf.LightDirection = Vector3.new(0.2, -0.35, -1)
	vpf.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	local rng = Random.new(7)
	-- พื้นดิน
	local ground = Instance.new("Part")
	ground.Anchored = true
	ground.Shape = Enum.PartType.Cylinder
	ground.Size = Vector3.new(1, 220, 220)
	ground.CFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ground.Color = Color3.fromRGB(46, 58, 40)
	ground.Material = Enum.Material.Grass
	ground.Parent = world
	-- กองไฟ + ม้านั่ง + เต็นท์
	placeModel(world, asset("Props", "CampfireLogs"), 3, CFrame.new())
	local ember = Instance.new("Part")
	ember.Anchored = true
	ember.Shape = Enum.PartType.Ball
	ember.Size = Vector3.new(2.6, 2.6, 2.6)
	ember.CFrame = CFrame.new(0, 1.6, 0)
	ember.Material = Enum.Material.Neon
	ember.Color = Color3.fromRGB(255, 150, 50)
	ember.Transparency = 0.15
	ember.Parent = world
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.4
		placeModel(world, asset("Props", "LogBench"), 1.6, CFrame.new(math.cos(a) * 7, 0, math.sin(a) * 7) * CFrame.Angles(0, -a + math.pi / 2, 0))
	end
	placeModel(world, asset("Props", "SleepingBagStore"), 2, CFrame.new(-11, 0, 6) * CFrame.Angles(0, 1.2, 0))
	placeModel(world, asset("Props", "LogPileStore"), 2.4, CFrame.new(9, 0, -8) * CFrame.Angles(0, 0.6, 0))
	-- ผู้รอดชีวิตรอบกองไฟ (หันหน้าเข้ากองไฟ)
	for i, cls in ipairs({ "Survivor", "Hunter", "Medic", "Lumberjack" }) do
		local a = i / 4 * math.pi * 2 + 1.1
		local okC, ClassAvatars = pcall(require, script.Parent.ClassAvatars)
		if okC then
			local okB, m = pcall(ClassAvatars.Build, cls)
			if okB and m then
				m.Parent = world
				local pos = Vector3.new(math.cos(a) * 4.6, 0, math.sin(a) * 4.6)
				m:PivotTo(CFrame.lookAt(pos, Vector3.new(0, 0, 0)))
			end
		end
	end
	-- แนวป่ารอบแคมป์ 2 ชั้น
	local trees = { "Fir1", "SnowPine", "OakPack", "Fir1", "DeadTree" }
	for ring = 1, 2 do
		local count = ring == 1 and 10 or 14
		for i = 1, count do
			local a = i / count * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local r = (ring == 1 and 24 or 40) + rng:NextNumber(-3, 3)
			placeModel(world, asset("Props", trees[rng:NextInteger(1, #trees)]), rng:NextNumber(14, 22) * (ring == 1 and 1 or 1.25),
				CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end
	for i = 1, 6 do
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(10, 20)
		placeModel(world, asset("Props", i % 2 == 0 and "RockLP" or "BushLP"), rng:NextNumber(1.2, 2.6), CFrame.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 52
	cam.Parent = vpf
	vpf.CurrentCamera = cam
	-- กล้องนิ่ง (วาดฉากครั้งเดียว) · ความเคลื่อนไหวมาจาก: กรอบภาพเลื่อนช้าๆ + ประกายไฟ 2 มิติ
	cam.CFrame = CFrame.lookAt(Vector3.new(math.cos(0.3) * 21, 6.5, math.sin(0.3) * 21), Vector3.new(0, 4.5, 0))
	vpf.LightColor = Color3.fromRGB(255, 150, 70)
	local pan = TweenService:Create(vpf, TweenInfo.new(14, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0.535, 0.48) })
	pan:Play()
	vpf.Destroying:Connect(function()
		pan:Cancel()
	end)
	return vpf
end

-- โครงหน้าโหลด: ฉากแคมป์ 3 มิติ + หมอก/แสงไฟ + โลโก้สี่ธาตุ + ชื่อเกมเงาวิ่ง + แถบความคืบหน้าสี่ธาตุ + ขั้นตอน + เคล็ดลับ
-- คืน { Root, Set(p, text), Close() }
local function sceneLoadingScreen(title, subtitle)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 14), BackgroundTransparency = 0, ZIndex = 100 })
	UIKit.Gradient(f, Color3.fromRGB(30, 26, 70), Color3.fromRGB(6, 6, 14), 90)
	pcall(campScene, f)
	-- หมอกบน/ล่าง + ขอบมืด
	local fogTop = UIKit.Frame(f, { Size = UDim2.fromScale(1, 0.55), BackgroundColor3 = Color3.fromRGB(10, 10, 30), BackgroundTransparency = 0, ZIndex = 101 })
	local ft = Instance.new("UIGradient")
	ft.Rotation = 90
	ft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(1, 1) })
	ft.Parent = fogTop
	local fogBottom = UIKit.Frame(f, { Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.55), BackgroundColor3 = Color3.fromRGB(8, 6, 10), BackgroundTransparency = 0, ZIndex = 101 })
	local fb = Instance.new("UIGradient")
	fb.Rotation = 90
	fb.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0) })
	fb.Parent = fogBottom
	-- แสงไฟกองไฟวูบวาบกลางจอ
	local glow = UIKit.Frame(f, { Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.05, 0.38), BackgroundColor3 = Color3.fromRGB(255, 120, 40), BackgroundTransparency = 0.78, ZIndex = 101 })
	UIKit.Corner(glow, 600)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	-- ประกายไฟลอยขึ้น
	for i = 1, 22 do
		local sz = math.random(2, 5)
		local s = UIKit.Frame(f, { Size = UDim2.fromOffset(sz, sz), Position = UDim2.fromScale(0.3 + math.random() * 0.4, 1.02), BackgroundColor3 = Color3.fromRGB(255, math.random(150, 210), 80), BackgroundTransparency = 0.1, ZIndex = 102 })
		UIKit.Corner(s, 3)
		task.spawn(function()
			task.wait(i * 0.12)
			while s.Parent do
				s.Position = UDim2.fromScale(0.3 + math.random() * 0.4, 0.75 + math.random() * 0.2)
				s.BackgroundTransparency = 0.1
				local t = 2.5 + math.random() * 3
				TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(s.Position.X.Scale + (math.random() - 0.5) * 0.25, 0.2 + math.random() * 0.35), BackgroundTransparency = 1 }):Play()
				task.wait(t)
			end
		end)
	end
	-- โลโก้: ลูกแก้วสี่ธาตุหมุนรอบเปลวไฟ
	local emblem = UIKit.Frame(f, { Size = UDim2.fromOffset(150, 150), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.17), BackgroundTransparency = 1, ZIndex = 103 })
	local core = UIKit.IconBadge(emblem, "🔥", Color3.fromRGB(255, 150, 40), 70, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 104 })
	core:FindFirstChildOfClass("TextLabel").ZIndex = 105
	local ring = UIKit.Frame(emblem, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 103 })
	local rs = Instance.new("UIStroke")
	rs.Thickness = 3
	rs.Color = Color3.fromRGB(255, 220, 150)
	rs.Transparency = 0.5
	rs.Parent = ring
	UIKit.Corner(ring, 200)
	local orbs = {}
	for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local o = UIKit.IconBadge(emblem, UIKit.ElementIcon[el], C.Element[el], 42, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 106 })
		o:FindFirstChildOfClass("TextLabel").ZIndex = 107
		orbs[i] = o
	end
	-- ชื่อเกม (ทองไล่สี + เงาวิ่ง) — อยู่ในกล่องเดียวกัน ย่อ/ขยายพร้อมกัน
	local titleBox = UIKit.Frame(f, { Size = UDim2.fromOffset(1100, 170), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.28), BackgroundTransparency = 1, ZIndex = 104 })
	local titleL = UIKit.Text(titleBox, {
		Size = UDim2.new(1, 0, 0, 120), Position = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 110, Text = title, TextColor3 = Color3.new(1, 1, 1), ZIndex = 104,
	})
	titleL:FindFirstChildOfClass("UIStroke").Thickness = 7
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 50)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 236, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 236, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 40)),
	})
	tg.Parent = titleL
	local sub = UIKit.Text(titleBox, {
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 118), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 32, Text = subtitle, TextColor3 = Color3.fromRGB(236, 220, 190), ZIndex = 104,
	})
	local line = UIKit.Frame(titleBox, { Size = UDim2.new(0, 420, 0, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 164), BackgroundColor3 = C.Gold, BackgroundTransparency = 0, ZIndex = 104 })
	local lg = Instance.new("UIGradient")
	lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	lg.Parent = line
	-- แถบความคืบหน้า (สี่ธาตุ + หัวเรืองแสง + แสงวิ่ง)
	local barW = 680
	local barBox = UIKit.Frame(f, { Size = UDim2.fromOffset(barW, 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), BackgroundTransparency = 1, ZIndex = 104 })
	local track = UIKit.Frame(barBox, { Size = UDim2.new(0, barW, 0, 26), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = Color3.fromRGB(14, 14, 30), BackgroundTransparency = 0.1, ZIndex = 104, ClipsDescendants = true })
	UIKit.Corner(track, 11)
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Thickness = 3
	trackStroke.Color = Color3.fromRGB(255, 214, 120)
	trackStroke.Transparency = 0.35
	trackStroke.Parent = track
	local fill = UIKit.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 105 })
	UIKit.Corner(fill, 11)
	local fc = Instance.new("UIGradient")
	fc.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Element.Earth), ColorSequenceKeypoint.new(0.33, C.Element.Water),
		ColorSequenceKeypoint.new(0.66, C.Element.Air), ColorSequenceKeypoint.new(1, C.Element.Fire),
	})
	fc.Parent = fill
	local sheen = UIKit.Frame(fill, { Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, ZIndex = 106 })
	UIKit.Corner(sheen, 8)
	local runner = UIKit.Frame(fill, { Size = UDim2.new(0, 90, 1, 0), Position = UDim2.fromScale(-0.2, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 107 })
	local rg = Instance.new("UIGradient")
	rg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) })
	rg.Parent = runner
	local head = UIKit.Frame(barBox, { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 13), BackgroundColor3 = Color3.fromRGB(255, 230, 160), BackgroundTransparency = 0.3, ZIndex = 108 })
	UIKit.Corner(head, 20)
	local pct = UIKit.Text(barBox, { Size = UDim2.new(0, barW, 0, 30), Position = UDim2.fromOffset(0, -36), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 28, Font = UIKit.Fonts.Title, ZIndex = 104, TextColor3 = C.Gold, Text = "0%" })
	local status = UIKit.Text(barBox, { Size = UDim2.new(0, barW - 100, 0, 30), Position = UDim2.fromOffset(0, -36), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 19, Font = UIKit.Fonts.Black, ZIndex = 104, TextColor3 = Color3.fromRGB(230, 216, 194), Text = "" })
	-- ขั้นตอน (ติ๊กถูกเมื่อผ่าน)
	local steps = { { 0.4, "🌍 สร้างโลกสี่ธาตุ" }, { 0.9, "🎨 โหลดโมเดลและพื้นผิว" }, { 1, "🔥 จุดไฟในค่าย" } }
	local stepRow = UIKit.Frame(barBox, { Size = UDim2.new(0, barW, 0, 26), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, ZIndex = 104 })
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sl.Padding = UDim.new(0, 26)
	sl.Parent = stepRow
	local stepLabels = {}
	for i, st in ipairs(steps) do
		stepLabels[i] = UIKit.Text(stepRow, { Size = UDim2.fromOffset(200, 26), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = UIKit.Fonts.Black, ZIndex = 104, TextColor3 = Color3.fromRGB(150, 146, 170), Text = "○ " .. st[2], LayoutOrder = i })
	end
	-- การ์ดเคล็ดลับ
	local tipCard = UIKit.Frame(f, { Size = UDim2.new(0, 760, 0, 46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.91, 0), BackgroundColor3 = Color3.fromRGB(16, 16, 32), BackgroundTransparency = 0.25, ZIndex = 104 })
	UIKit.Corner(tipCard, 14)
	local tcs = Instance.new("UIStroke")
	tcs.Thickness = 2
	tcs.Color = Color3.fromRGB(255, 214, 120)
	tcs.Transparency = 0.6
	tcs.Parent = tipCard
	local tip = UIKit.Text(tipCard, { Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(15, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, ZIndex = 105, TextColor3 = Color3.fromRGB(236, 224, 200), TextWrapped = true, Text = "💡 " .. TIPS[math.random(#TIPS)] })
	-- ย่อทั้งชุดบนจอเล็ก (มือถือ)
	for _, obj in ipairs({ emblem, titleBox, barBox, tipCard }) do
		UIKit.AutoScale(obj)
	end
	local t0 = os.clock()
	local animConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for i, o in ipairs(orbs) do
			local a = t * 0.9 + (i - 1) * math.pi / 2
			o.Position = UDim2.new(0.5, math.cos(a) * 75, 0.5, math.sin(a) * 75 * 0.45)
			o.ZIndex = math.sin(a) > 0 and 106 or 102
			o:FindFirstChildOfClass("TextLabel").ZIndex = o.ZIndex + 1
		end
		core.Rotation = math.sin(t * 2) * 6
		tg.Offset = Vector2.new(((t * 0.35) % 2) - 1, 0)
		runner.Position = UDim2.new(((t * 0.6) % 1.4) - 0.2, 0, 0, 0)
		glow.BackgroundTransparency = 0.76 + math.noise(t * 2.3, 1.7) * 0.08
		head.Size = UDim2.fromOffset(30 + math.sin(t * 6) * 4, 30 + math.sin(t * 6) * 4)
	end)
	task.spawn(function()
		while f.Parent do
			task.wait(5)
			if not f.Parent then
				break
			end
			UIKit.Tween(tip, 0.3, { TextTransparency = 1 })
			task.wait(0.32)
			tip.Text = "💡 " .. TIPS[math.random(#TIPS)]
			UIKit.Tween(tip, 0.3, { TextTransparency = 0 })
		end
	end)
	local shown, target = 0, 0
	-- แถบไหลไปหาเป้าหมายแบบนุ่มๆ ทุกเฟรม (ไม่กระตุกเป็นขั้นๆ)
	local smoothConn = RunService.RenderStepped:Connect(function(dt)
		if math.abs(target - shown) > 0.0005 then
			shown += (target - shown) * math.min(1, dt * 6)
			fill.Size = UDim2.fromScale(shown, 1)
			head.Position = UDim2.fromOffset(barW * shown, 13)
			pct.Text = math.floor(shown * 100 + 0.5) .. "%"
		end
	end)
	f.Destroying:Connect(function()
		smoothConn:Disconnect()
	end)
	local api = { Root = f }
	function api.Set(p, text)
		p = math.clamp(p, 0, 1)
		if p > target then
			target = p
		end
		for i, st in ipairs(steps) do
			local done = target >= st[1] - 0.001
			local active = not done and (i == 1 or target >= steps[i - 1][1] - 0.001)
			stepLabels[i].Text = (done and "✔ " or (active and "◉ " or "○ ")) .. st[2]
			stepLabels[i].TextColor3 = done and C.Good or (active and C.Gold or Color3.fromRGB(150, 146, 170))
		end
		if text then
			status.Text = text
		end
	end
	function api.Close()
		-- กันค้าง: ถ้าแอนิเมชันปิดพังกลางทาง ก็ต้องลบหน้าโหลดทิ้งเสมอ (ไม่งั้นบังจอจนกดอะไรไม่ได้)
		task.delay(4, function()
			if f.Parent then
				animConn:Disconnect()
				f:Destroy()
			end
		end)
		api.Set(1, "พร้อมแล้ว!")
		local tw = os.clock()
		while shown < 0.995 and os.clock() - tw < 1.2 do
			task.wait()
		end
		task.wait(0.25)
		local vpf = f:FindFirstChildOfClass("ViewportFrame")
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 0.9, { TextTransparency = 1, TextStrokeTransparency = 1 })
			elseif d:IsA("Frame") then
				UIKit.Tween(d, 0.9, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				UIKit.Tween(d, 0.9, { Transparency = 1 })
			end
		end
		if vpf then
			UIKit.Tween(vpf, 0.9, { ImageTransparency = 1 })
		end
		UIKit.Tween(f, 1, { BackgroundTransparency = 1 })
		task.wait(1.05)
		animConn:Disconnect()
		f:Destroy()
	end
	api.Set(0)
	-- เปิดหน้าโหลดแบบนุ่ม: ชื่อเกมเลื่อนลงมา + กล่องต่างๆ ค่อยๆ ขยาย
	titleBox.Position = UDim2.new(0.5, 0, 0.28, -40)
	UIKit.Tween(titleBox, 0.9, { Position = UDim2.fromScale(0.5, 0.28) }, Enum.EasingStyle.Back)
	for _, obj in ipairs({ emblem, barBox, tipCard }) do
		local sc = obj:FindFirstChild("AutoScale")
		if sc then
			local k = sc.Scale
			sc.Scale = k * 0.7
			UIKit.Tween(sc, 0.7, { Scale = k }, Enum.EasingStyle.Back)
		end
	end
	return api
end

-- หน้าโหลดแบบภาพวาด (Shared/LoadingArt: ค่ายริมกองไฟ + โลโก้) เต็มจอแบบครอป + หลอดโหลด/เคล็ดลับจริงวางทับตำแหน่งในรูป
local function artLoadingScreen(img)
	local LoadingArt = require(ReplicatedStorage.Shared.LoadingArt)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0, ZIndex = 100, ClipsDescendants = true })
	local canvas = Instance.new("ImageLabel")
	canvas.Name = "Art"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.BackgroundTransparency = 1
	canvas.ImageContent = Content.fromObject(img)
	canvas.ZIndex = 101
	canvas.Parent = f
	-- ฉากหลัง: รูปเดียวกันขยายเต็มจอแบบมืด (เติมขอบจอที่ไม่ใช่ 16:9)
	local backdrop = canvas:Clone()
	backdrop.Name = "Backdrop"
	backdrop.ZIndex = 100
	backdrop.ImageColor3 = Color3.fromRGB(90, 90, 110)
	backdrop.Parent = f
	-- รูปหลักเห็นครบทั้งภาพเสมอ (โลโก้บน + หลอดโหลด/เคล็ดลับล่าง ไม่โดนตัด)
	local function fit()
		local sw, sh = f.AbsoluteSize.X, f.AbsoluteSize.Y
		if sw < 2 or sh < 2 then
			return
		end
		local w, h = sw, sw / LoadingArt.Aspect
		if h > sh then
			h, w = sh, sh * LoadingArt.Aspect
		end
		canvas.Size = UDim2.fromOffset(w, h)
		local bw, bh = sw, sw / LoadingArt.Aspect
		if bh < sh then
			bh, bw = sh, sh * LoadingArt.Aspect
		end
		backdrop.Size = UDim2.fromOffset(bw * 1.08, bh * 1.08)
	end
	fit()
	f:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local zoom = Instance.new("UIScale")
	zoom.Parent = canvas
	local breathe = TweenService:Create(zoom, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.035 })
	breathe:Play()
	local function rect(r, props)
		local o = UIKit.Frame(canvas, { Position = UDim2.fromScale(r[1], r[2]), Size = UDim2.fromScale(r[3] - r[1], r[4] - r[2]), BackgroundTransparency = 1, ZIndex = 103 })
		for k, v in pairs(props or {}) do
			o[k] = v
		end
		return o
	end
	-- แสงกองไฟวูบวาบ
	local glow = UIKit.Frame(canvas, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.49, 0.64), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = Color3.fromRGB(255, 140, 50), BackgroundTransparency = 0.85, ZIndex = 102 })
	UIKit.Corner(glow, 600)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	-- ประกายไฟลอยขึ้นจากกองไฟ
	for i = 1, 16 do
		local sz = math.random(2, 4)
		local sp = UIKit.Frame(canvas, { Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.fromRGB(255, math.random(160, 220), 90), BackgroundTransparency = 1, ZIndex = 102 })
		UIKit.Corner(sp, 3)
		task.spawn(function()
			task.wait(i * 0.2)
			while sp.Parent do
				sp.Position = UDim2.fromScale(0.47 + math.random() * 0.05, 0.66)
				sp.BackgroundTransparency = 0.1
				local t = 2 + math.random() * 2.5
				TweenService:Create(sp, TweenInfo.new(t, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(0.44 + math.random() * 0.12, 0.32 + math.random() * 0.2), BackgroundTransparency = 1 }):Play()
				task.wait(t)
			end
		end)
	end
	-- หลอดโหลด (เขียวไล่สี + เงาวาว) ในรางของรูป
	local bar = rect(LoadingArt.Bar, { ClipsDescendants = true })
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local fill = UIKit.Frame(bar, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 104 })
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 200, 60)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 240, 110)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 215, 70)),
	})
	fg.Parent = fill
	local sheen = UIKit.Frame(fill, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.12), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, ZIndex = 105 })
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = sheen
	local pct = rect(LoadingArt.Pct)
	local pctL = UIKit.Text(pct, { Size = UDim2.fromScale(1, 1), TextScaled = true, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, Text = "0%", ZIndex = 104 })
	local tipBox = rect(LoadingArt.Tip)
	local tip = UIKit.Text(tipBox, { Size = UDim2.fromScale(1, 0.72), Position = UDim2.fromScale(0, 0.14), TextScaled = true, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(240, 226, 200), Text = "💡 " .. TIPS[math.random(#TIPS)], ZIndex = 104 })
	local status = UIKit.Text(canvas, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, LoadingArt.Tip[4] + 0.012), Size = UDim2.fromScale(0.4, 0.024), TextScaled = true, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(220, 206, 186), Text = "", ZIndex = 104 })
	local t0 = os.clock()
	local animConn = RunService.RenderStepped:Connect(function()
		glow.BackgroundTransparency = 0.82 + math.noise((os.clock() - t0) * 2.3, 1.7) * 0.1
	end)
	task.spawn(function()
		while f.Parent do
			task.wait(5)
			if not f.Parent then
				break
			end
			UIKit.Tween(tip, 0.3, { TextTransparency = 1 })
			task.wait(0.32)
			tip.Text = "💡 " .. TIPS[math.random(#TIPS)]
			UIKit.Tween(tip, 0.3, { TextTransparency = 0 })
		end
	end)
	local shown, target = 0, 0
	local smoothConn = RunService.RenderStepped:Connect(function(dt)
		if math.abs(target - shown) > 0.0005 then
			shown += (target - shown) * math.min(1, dt * 6)
			fill.Size = UDim2.fromScale(math.max(shown, 0.04), 1)
			pctL.Text = math.floor(shown * 100 + 0.5) .. "%"
		end
	end)
	f.Destroying:Connect(function()
		smoothConn:Disconnect()
		animConn:Disconnect()
		breathe:Cancel()
	end)
	local api = { Root = f }
	function api.Set(p, text)
		p = math.clamp(p, 0, 1)
		if p > target then
			target = p
		end
		if text then
			status.Text = text
		end
	end
	function api.Close()
		task.delay(4, function()
			if f.Parent then
				f:Destroy()
			end
		end)
		api.Set(1, "พร้อมแล้ว!")
		local tw = os.clock()
		while shown < 0.995 and os.clock() - tw < 1.2 do
			task.wait()
		end
		task.wait(0.25)
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 0.9, { TextTransparency = 1 })
			elseif d:IsA("ImageLabel") then
				UIKit.Tween(d, 0.9, { ImageTransparency = 1 })
			elseif d:IsA("Frame") then
				UIKit.Tween(d, 0.9, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				UIKit.Tween(d, 0.9, { Transparency = 1 })
			end
		end
		UIKit.Tween(f, 1, { BackgroundTransparency = 1 })
		task.wait(1.05)
		f:Destroy()
	end
	api.Set(0)
	canvas.ImageTransparency = 1
	UIKit.Tween(canvas, 0.5, { ImageTransparency = 0 })
	return api
end

-- ใช้ภาพวาดเป็นหลัก · วาดรูปไม่ได้ (EditableImage ใช้ไม่ได้ในเครื่องนั้น) -> หน้าโหลดฉาก 3 มิติแบบเดิม
local function loadingScreen(title, subtitle)
	local ok, img = pcall(function()
		return require(ReplicatedStorage.Shared.LoadingArt).Image()
	end)
	if ok and img then
		local ok2, api = pcall(artLoadingScreen, img)
		if ok2 and api then
			return api
		end
		warn("[AS] art loading screen failed", api)
	end
	return sceneLoadingScreen(title, subtitle)
end

-- พื้นใต้เท้าโหลดมาถึงเครื่องแล้วหรือยัง
local function groundReady()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char }
	return Workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rp) ~= nil
end

-- ระหว่างหน้าโหลด (เข้าเกม/เดินทาง) ล็อกการควบคุมตัวละคร: เดิมยังเดิน/กระโดด/ขึ้นแท่นวาร์ปอยู่หลังหน้าโหลดได้
--   ปิดปุ่มควบคุม (PlayerModule) + หยุดเดิน + ไม่ให้ตกพื้นที่ยังโหลดไม่มา · เปิดคืนเองเมื่อหน้าโหลดปิด
local frozen = false
local ctrl
local function controls()
	if not ctrl then
		local ps = player:FindFirstChild("PlayerScripts")
		local mod = ps and ps:FindFirstChild("PlayerModule")
		local ok, pm = pcall(function()
			return mod and require(mod)
		end)
		ctrl = ok and pm and pm:GetControls() or nil
	end
	return ctrl
end
RunService.Heartbeat:Connect(function()
	local hardFreeze = Cinematics.IsLoading == true or Cinematics.Traveling == true
	-- ฉากคัตซีน: ปิดปุ่มบังคับ แต่ยังให้สคริปต์ฉากสั่งเดิน (MoveTo) ได้
	local want = hardFreeze or Cinematics.Cutscene == true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hardFreeze then
		if hum then
			hum:Move(Vector3.zero)
			hum.Jump = false
		end
	end
	if want == frozen then
		return
	end
	local c = controls()
	if not c then
		return -- PlayerModule ยังไม่มา: ลองใหม่เฟรมหน้า (ระหว่างนี้ hum:Move(0) กันเดินไว้แล้ว)
	end
	frozen = want
	if c then
		if want then
			c:Disable()
		else
			c:Enable()
		end
	end
end)

-- เข้าเกม: โหลดให้ครบก่อนค่อยเปิดจอ (ไม่เข้าไปเจอของค้าง/พื้นยังไม่มา/แมพยังสร้างไม่เสร็จ)
--   ค่าย 0-25% -> พื้นผิว/โมเดลค่าย 25-50% -> เซิร์ฟเวอร์สร้างแมพ 50-85% -> โมเดลในแมพ/บอส/เอฟเฟกต์ 85-97% -> ตัวละคร+พื้นใต้เท้า 97-100%
--   ทุกช่วงมีเวลากันค้างยาวๆ (เน็ตช้ามากก็ยังเข้าได้ในที่สุด) · หลอดเดินหน้าอย่างเดียว ไม่ถอยหลัง
function Cinematics.Loading(state)
	local ui = loadingScreen(Config.GameName, Config.Subtitle)
	Cinematics.IsLoading = true
	task.spawn(function()
		local CP = game:GetService("ContentProvider")
		local function collect(root)
			local items = {}
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter")
					or d:IsA("Beam") or d:IsA("SpecialMesh") or d:IsA("Sound") or d:IsA("ImageLabel") or d:IsA("ImageButton") then
					table.insert(items, d)
				end
			end
			return items
		end
		-- โหลดทรัพยากรเป็นชุด (เดินหลอดจาก a ถึง b) · เกินเวลาที่กำหนด = ไปต่อ
		local function preload(items, a, b, label, limit)
			local total = math.max(#items, 1)
			local p0 = os.clock()
			for i = 1, #items, 40 do
				if os.clock() - p0 > limit then
					break
				end
				-- ชุดเดียวค้างนาน (เน็ตช้า) ก็ไม่รอเกินเวลาที่เหลือ — ของที่ยังไม่มาจะโหลดตามมาเองระหว่างเล่น
				local batchDone = false
				task.spawn(function()
					pcall(function()
						CP:PreloadAsync(table.move(items, i, math.min(i + 39, #items), 1, {}))
					end)
					batchDone = true
				end)
				while not batchDone and os.clock() - p0 <= limit do
					task.wait(0.05)
				end
				local done = math.min(i + 39, #items)
				ui.Set(a + (b - a) * done / total, string.format("%s %d/%d", label, done, total))
			end
			ui.Set(b)
		end
		-- เซิร์ฟเวอร์ทีม (มาจากแท่นวาร์ป): ไม่ต้องโหลดค่ายซ้ำ · โมเดลโหลดไว้แล้วตอนอยู่ล็อบบี้ (แคชในเครื่อง) -> ไม่รอนาน
		--   เคยโหลดค่ายใหม่ + รอโหลดโมเดลถึง 90 วิ เครื่องช้าค้างหน้าโหลดนานกว่าเพื่อน แล้วยังเจอหน้าโหลดเดินทางซ้อนอีกรอบ
		local team = state and state:GetAttribute("TeamServer") == true
		-- 1) ค่ายทั้งชุดมาถึงเครื่อง 0-25%
		local w0 = os.clock()
		local lobby
		while not team and os.clock() - w0 < 90 do
			lobby = Workspace:FindFirstChild("Lobby")
			local want = lobby and lobby:GetAttribute("Parts")
			local have = lobby and #lobby:GetDescendants() or 0
			if want and have >= want * 0.98 then
				break
			end
			local k = want and math.clamp(have / want, 0, 1) or 0
			ui.Set(0.25 * k, string.format("กำลังโหลดค่าย... %d%%", math.floor(k * 100)))
			task.wait(0.1)
		end
		-- 2) พื้นผิว/โมเดลของค่าย 25-50%
		if not team then
			preload(lobby and collect(lobby) or {}, 0.25, 0.5, "กำลังโหลดค่าย", 60)
		end
		-- 3) รอเซิร์ฟเวอร์สร้างแมพเสร็จ 50-85%
		local g0 = os.clock()
		while os.clock() - g0 < 240 do
			local lp = state and state:GetAttribute("LoadProgress") or 1
			if lp >= 1 then
				break
			end
			ui.Set(0.5 + 0.35 * lp, string.format("กำลังสร้างโลก... %d%%", math.floor(lp * 100)))
			task.wait(0.2)
		end
		ui.Set(0.85, "สร้างโลกเสร็จแล้ว")
		-- 4) โมเดลในแมพ/สัตว์/บอส/อาวุธ/เอฟเฟกต์ 85-97%
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		preload(assets and collect(assets) or {}, 0.85, 0.97, "กำลังโหลดโมเดล", team and 12 or 45)
		-- 5) ตัวละคร + พื้นใต้เท้า 97-100% · เซิร์ฟเวอร์ทีม: รอจนตัวละครไปเกิดในแมพแล้ว (ไม่เปิดจอที่ล็อบบี้แล้วโหลดเดินทางซ้ำ)
		--   เช็ก "ออกห่างล็อบบี้" (ล็อบบี้อยู่นอกแมพไกลมาก) ไม่ใช่ "ใกล้แคมป์" -> กลับเข้ารอบเดิมไปเกิดที่เตียงไกลแคมป์ก็ผ่าน
		ui.Set(0.97, team and "กำลังเข้าสู่แคมป์..." or "กำลังจุดกองไฟในค่าย...")
		local function atCamp()
			if not team then
				return true
			end
			local lb = Workspace:FindFirstChild("Lobby")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not (player:GetAttribute("InRun") and root) then
				return false
			end
			return not lb or (root.Position - lb:GetPivot().Position).Magnitude > 1500
		end
		local t0 = os.clock()
		while not (player.Character and atCamp() and groundReady()) and os.clock() - t0 < 60 do
			task.wait(0.1)
		end
		task.wait(0.4) -- ให้เฟรมแรกในค่ายวาดเสร็จก่อนค่อยเปิดจอ
		ui.Close()
		Cinematics.IsLoading = false
		if Cinematics.OnLoaded then
			Cinematics.OnLoaded()
		end
	end)
end

-- เดินทางลงแมพ (ออกจากล็อบบี้): รอพื้นแมพรอบตัวโหลดเสร็จก่อนค่อยเปิดจอ
function Cinematics.Travel()
	if Cinematics.Traveling then
		return
	end
	Cinematics.Traveling = true
	local ui = loadingScreen("ออกเดินทาง", "สู่ดินแดนสี่ธาตุ")
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 25 do
			local k = math.clamp((os.clock() - t0) / 2.5, 0, 1)
			if player:GetAttribute("InRun") and groundReady() and k >= 1 then
				break
			end
			ui.Set(math.min(0.95, k * 0.7 + (groundReady() and 0.25 or 0)), groundReady() and "กำลังเข้าสู่แคมป์..." or "กำลังโหลดพื้นที่รอบแคมป์...")
			task.wait(0.1)
		end
		ui.Close()
		Cinematics.Traveling = false
	end)
end

---------------------------------------------------------------- เปิดตัวบอส
-- ฉากเปิดตัวบอส (แต่ละธาตุไม่เหมือนกัน) — เซิร์ฟเวอร์ตรึงบอสไว้ ~7 วิ เครื่องเราขยับตัวบอสเอง แล้วคืนที่เดิมตอนจบ
--   ดิน: แผ่นดินสั่น แตก -> โผล่พุ่งขึ้นจากดิน -> กระแทกลงพื้น -> คำราม
--   น้ำ: น้ำวน -> พุ่งกระโดดขึ้นจากทะเล โค้งกลางอากาศ -> ตกน้ำสาดกระจาย -> คำราม
--   น้ำแข็ง: ถูกแช่ในก้อนน้ำแข็ง -> ร้าว สั่น -> น้ำแข็งแตกกระจาย -> คำราม
--   ไฟ: ดิ่งลงมาจากฟ้า -> บินวนกระพือปีกครู่หนึ่ง -> ลงพื้นไฟระเบิด -> คำราม
local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end
local function easeIn(x)
	x = math.clamp(x, 0, 1)
	return x * x
end

local function bossNameCard(d, color)
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 200), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 0), BackgroundTransparency = 1, ZIndex = 60 })
	UIKit.AutoScale(f)
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, Font = UIKit.Fonts.Bold,
		Text = "— บอสประจำธาตุ —", TextColor3 = color, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local name = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 78), Position = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 64,
		Text = d.Name, TextColor3 = Color3.fromRGB(250, 242, 226), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	UIKit.TextStroke(name, 3, 0.1)
	local ng = Instance.new("UIGradient")
	ng.Color = ColorSequence.new(Color3.fromRGB(255, 252, 240), color:Lerp(Color3.new(1, 1, 1), 0.35))
	ng.Rotation = 90
	ng.Parent = name
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 760, 0, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), BackgroundColor3 = color, BackgroundTransparency = 1, ZIndex = 61 })
	line.Visible = false -- ไม่มีขีดแนวนอนใต้ชื่อบอส
	line:SetAttribute("Line", true)
	local lg = Instance.new("UIGradient")
	lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	lg.Parent = line
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 116), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 26,
		Text = d.Thai, TextColor3 = color, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local sc = Instance.new("UIScale")
	sc.Scale = 1.35
	sc.Parent = f
	local api = {}
	function api.Show()
		fadeTexts(f, 0, 0.5)
		UIKit.Tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	function api.Hide()
		fadeTexts(f, 1, 1)
		task.delay(1.1, function()
			f:Destroy()
		end)
	end
	return api
end

-- ก้อนน้ำแข็งแช่บอส + แตกกระจาย
local function iceBlock(model)
	local BossFX = require(script.Parent:WaitForChild("BossFX"))
	local cf, size = model:GetBoundingBox()
	local block = BossFX.Part({ Name = "IntroIce", Size = size * Vector3.new(1.12, 1.06, 1.12), CFrame = cf, Material = Enum.Material.Glass, Color = Color3.fromRGB(170, 225, 255), Transparency = 0.35, Reflectance = 0.15 })
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.fromRGB(220, 245, 255)
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = block
	local api = { Part = block }
	-- รอยร้าว: เศษน้ำแข็งเล็กๆ ปลิว + ก้อนสั่น
	function api.Crack(k)
		BossFX.Emit(cf.Position + Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.3) * size.Y, (math.random() - 0.5) * size.Z), {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(230, 248, 255)), LightEmission = 1,
			Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(8, 20), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		}, math.floor(6 + 14 * k), 2)
		local j = 0.15 + 0.6 * k
		block.CFrame = cf * CFrame.new((math.random() - 0.5) * j, 0, (math.random() - 0.5) * j)
	end
	function api.Shatter()
		local rng = Random.new()
		for _ = 1, 26 do
			local s = Vector3.new(rng:NextNumber(0.12, 0.3) * size.X, rng:NextNumber(0.1, 0.28) * size.Y, rng:NextNumber(0.12, 0.3) * size.Z)
			local p = BossFX.Part({ Size = s, CFrame = cf * CFrame.new(rng:NextNumber(-0.45, 0.45) * size.X, rng:NextNumber(-0.45, 0.45) * size.Y, rng:NextNumber(-0.45, 0.45) * size.Z)
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Material = Enum.Material.Glass, Color = Color3.fromRGB(190, 232, 255), Transparency = 0.25 })
			p.Anchored = false
			local out = (p.Position - cf.Position)
			out = Vector3.new(out.X, math.abs(out.Y) * 0.4 + size.Y * 0.2, out.Z).Unit
			p.AssemblyLinearVelocity = out * rng:NextNumber(40, 90)
			p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
			task.delay(1.6, function()
				if p.Parent then
					BossFX.TweenObj(p, 0.8, { Transparency = 1, Size = p.Size * 0.3 })
				end
			end)
			game:GetService("Debris"):AddItem(p, 2.6)
		end
		block:Destroy()
	end
	return api
end

function Cinematics.BossIntro(d)
	local model = d.Model
	local cam = Workspace.CurrentCamera
	if not (model and model.Parent) then
		model = nil
	end
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	local color = C.Element[d.Element] or C.Gold
	letterbox(true)
	local card = bossNameCard(d, color)
	if not root then
		card.Show()
		task.delay(4, function()
			letterbox(false)
			card.Hide()
		end)
		return
	end
	local BossFX = require(script.Parent:WaitForChild("BossFX"))
	local okA, BossAnimator = pcall(require, script.Parent:FindFirstChild("BossAnimator"))
	local el = d.Element
	local rest = model:GetPivot() -- ตำแหน่งจริงที่เซิร์ฟเวอร์ตรึงไว้
	local size = model:GetExtentsSize()
	local H = math.max(size.Y, 8)
	local Rr = math.max(size.Magnitude * 0.55, 18)
	local fwd = rest.LookVector * Vector3.new(1, 0, 1)
	fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
	local feet = rest.Position - Vector3.new(0, H * 0.45, 0)
	local function shake(p, t)
		if BossFX.Shake then
			BossFX.Shake(p, t)
		end
	end
	local function pose(off)
		if model.Parent then
			model:PivotTo(rest * off)
		end
	end
	-- ตาราง: จบฉาก (วิ) / จังหวะคำราม (วิ) / ฟังก์ชันท่าทางตามเวลา / เหตุการณ์ (เอฟเฟกต์) ตามเวลา
	local DUR, ROAR = 5.6, 3.1
	local shapeFn, events
	local ice
	local savedFly, savedGround
	if el == "Earth" then
		-- ใต้ดิน -> แผ่นดินแตก -> พุ่งขึ้น -> ลงกระแทก
		DUR, ROAR = 5.8, 3.2
		shapeFn = function(t)
			if t < 1.6 then
				return CFrame.new(0, -H * 1.05 + math.sin(t * 30) * 0.15, 0)
			elseif t < 2.25 then
				local k = easeOut((t - 1.6) / 0.65)
				return CFrame.new(0, -H * 1.05 + (H * 1.6) * k, 0) * CFrame.Angles(-0.25 * (1 - k), 0, 0)
			elseif t < 2.75 then
				local k = easeIn((t - 2.25) / 0.5)
				return CFrame.new(0, H * 0.55 * (1 - k), 0)
			end
			return CFrame.new()
		end
		events = {
			{ 0.1, function()
				BossFX.Play("Crack", CFrame.new(feet), { Scale = math.clamp(H / 4, 2, 12), Duration = 1.4, Tint = Color3.fromRGB(255, 190, 110) })
			end },
			{ 0.3, function() shake(0.5, 1.4) BossFX.Dust(feet, H * 0.8, el, 20) end },
			{ 0.9, function() BossFX.Dust(feet, H, el, 26) BossFX.Debris(feet, H * 0.6, el, 6) end },
			{ 1.6, function() BossFX.IntroBurst(feet, math.clamp(H * 0.9, 16, 44), el) BossFX.Play("RockRing", CFrame.new(feet), { Scale = math.clamp(H / 5, 2, 10), Duration = 0.5 }) end },
			{ 2.75, function() BossFX.IntroBurst(feet, math.clamp(H, 18, 48), el) shake(1.6, 0.8) end },
		}
	elseif el == "Water" then
		-- ใต้น้ำ -> พุ่งกระโดดโค้งขึ้นจากทะเลเข้าหาผู้เล่น -> ตกน้ำสาด
		DUR, ROAR = 5.4, 3.0
		shapeFn = function(t)
			if t < 0.8 then
				return CFrame.new(0, -H * 1.6, Rr * 0.9)
			elseif t < 2.3 then
				local k = (t - 0.8) / 1.5
				local y = -H * 1.6 + H * 1.6 * k + H * 2.4 * math.sin(math.pi * k)
				local z = Rr * 0.9 * (1 - ease(k))
				local pitch = 0.9 * math.cos(math.pi * k)
				return CFrame.new(0, y, z) * CFrame.Angles(pitch, 0, math.sin(math.pi * k) * 0.2)
			end
			return CFrame.new()
		end
		local surf = rest.Position
		events = {
			{ 0.05, function() BossFX.Play("WaterSwirl", CFrame.new(surf + fwd * -Rr * 0.9), { Scale = math.clamp(H / 3, 3, 12), Duration = 1.2 }) end },
			{ 0.8, function() BossFX.IntroBurst(surf + rest.LookVector * -Rr * 0.9, math.clamp(H, 16, 44), el) shake(0.7, 0.6) end },
			{ 2.3, function() BossFX.IntroBurst(surf, math.clamp(H * 1.1, 18, 50), el) shake(1.4, 0.8) end },
		}
	elseif el == "Air" then
		-- แช่น้ำแข็ง -> ร้าวสั่น -> แตกกระจาย
		DUR, ROAR = 5.2, 2.6
		ice = iceBlock(model)
		shapeFn = function()
			return CFrame.new()
		end
		events = {
			{ 0.6, function() ice.Crack(0.2) shake(0.2, 0.3) end },
			{ 1.0, function() ice.Crack(0.4) shake(0.3, 0.3) end },
			{ 1.35, function() ice.Crack(0.6) shake(0.4, 0.3) end },
			{ 1.65, function() ice.Crack(0.8) shake(0.6, 0.3) end },
			{ 1.9, function() ice.Crack(1) shake(0.8, 0.3) end },
			{ 2.15, function()
				ice.Shatter()
				BossFX.IntroBurst(feet, math.clamp(H, 18, 48), el)
				BossFX.Play("Ice", CFrame.new(feet), { Scale = math.clamp(H / 4, 2, 10), Duration = 0.6 })
				shake(1.5, 0.8)
			end },
		}
	else
		-- ไฟ: ดิ่งจากฟ้า -> บินวนกระพือปีก -> ลงพื้น
		DUR, ROAR = 6.4, 4.2
		savedFly, savedGround = model:GetAttribute("Flying"), model:GetAttribute("Grounded")
		model:SetAttribute("Flying", true)
		model:SetAttribute("Grounded", false)
		local high = CFrame.new(0, H * 7, Rr * 3.2)
		local hover = CFrame.new(0, H * 1.4, 0)
		shapeFn = function(t)
			if t < 1.9 then
				local k = easeOut(t / 1.9)
				local p = high.Position:Lerp(hover.Position, k) + Vector3.new(math.sin(k * math.pi) * Rr * 0.8, 0, 0)
				return CFrame.new(p) * CFrame.Angles(-0.55 * (1 - k), 0, -0.35 * math.sin(k * math.pi))
			elseif t < 3.3 then
				local k = t - 1.9
				return hover * CFrame.new(math.sin(k * 2.2) * 2, math.sin(k * 3.6) * H * 0.06, 0) * CFrame.Angles(0, math.sin(k * 1.4) * 0.15, 0)
			elseif t < 3.9 then
				local k = ease((t - 3.3) / 0.6)
				return hover:Lerp(CFrame.new(), k)
			end
			return CFrame.new()
		end
		events = {
			{ 0.0, function() BossFX.Play("FireBall", CFrame.new(rest.Position + Vector3.new(0, H * 7, 0) + rest.LookVector * -Rr * 3.2), { Scale = math.clamp(H / 5, 2, 8), Duration = 0.8 }) end },
			{ 1.9, function() BossFX.Play("Fire2", CFrame.new(rest.Position + Vector3.new(0, H * 1.4, 0)), { Scale = math.clamp(H / 4, 2, 10), Duration = 1.0 }) shake(0.5, 0.5) end },
			{ 3.0, function() BossFX.Dust(feet, H * 1.2, el, 30) end },
			{ 3.85, function()
				model:SetAttribute("Grounded", true)
				BossFX.IntroBurst(feet, math.clamp(H * 1.1, 18, 50), el)
				shake(1.6, 0.8)
			end },
		}
	end
	pose(shapeFn(0))
	-- คำราม: ท่าคำราม/ทุบ + คลื่นลม + จอสั่น + ป้ายชื่อขึ้น
	local wind = 0.55
	table.insert(events, { ROAR, function()
		if okA and BossAnimator then
			pcall(BossAnimator.PlayIntro, model, wind)
		end
	end })
	table.insert(events, { ROAR + wind, function()
		BossFX.Play("BlastWind", CFrame.new(rest.Position), { Scale = math.clamp(H / 14, 1, 4), Duration = 0.5 })
		shake(1.2, 1.0)
		card.Show()
	end })
	table.sort(events, function(a, b)
		return a[1] < b[1]
	end)
	-- กล้อง: ตามตัวบอสตลอด จากด้านหน้ามุมต่ำ ค่อยๆ วนข้าง · ช่วงคำรามดันเข้าใกล้หน้า
	local prevType, prevFov = cam.CameraType, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local baseAng = math.atan2(fwd.Z, fwd.X)
	local camPos, camLook
	local t0 = os.clock()
	local nextEv = 1
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if t > DUR or not model.Parent then
			conn:Disconnect()
			if model.Parent then
				model:PivotTo(rest)
				if savedFly ~= nil or el == "Fire" then
					model:SetAttribute("Flying", savedFly)
					model:SetAttribute("Grounded", savedGround)
				end
			end
			if ice and ice.Part.Parent then
				ice.Part:Destroy()
			end
			cam.CameraType = prevType
			cam.FieldOfView = prevFov
			return
		end
		while events[nextEv] and t >= events[nextEv][1] do
			pcall(events[nextEv][2])
			nextEv += 1
		end
		pose(shapeFn(t))
		local body = model:GetPivot().Position
		local roarK = ease((t - ROAR) / 0.8)
		local orbit = baseAng + math.rad(25) * ease(t / DUR) - math.rad(12)
		local dist = Rr * (1.75 - 0.45 * roarK)
		local want = rest.Position + Vector3.new(math.cos(orbit) * dist, H * (0.12 + 0.18 * (1 - roarK)), math.sin(orbit) * dist)
		local look = body + Vector3.new(0, H * 0.25, 0)
		camPos = camPos and camPos:Lerp(want, 1 - math.exp(-dt * 5)) or want
		camLook = camLook and camLook:Lerp(look, 1 - math.exp(-dt * 7)) or look
		cam.FieldOfView = 58 - 10 * roarK
		cam.CFrame = CFrame.lookAt(camPos, camLook)
	end)
	task.delay(DUR + 0.2, function()
		letterbox(false)
		card.Hide()
	end)
end

---------------------------------------------------------------- ฉากศาลเจ้า (ช่วยลูกสัตว์ธาตุ)
-- โหมดภาพยนตร์: ซ่อน HUD/หลอดเลือด/ปุ่มกด/ข้อความแจ้งเตือนทั้งหมด + แต่งสีภาพ + ชัดลึก + ขอบจอมืด + หมอกจาง
local cineSaved
local function cinemaMode(on, tint)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if on and not cineSaved then
		cineSaved = { Guis = {}, Fx = {} }
		for _, g in ipairs(pg and pg:GetChildren() or {}) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(cineSaved.Guis, g)
			end
		end
		pcall(function()
			game:GetService("ProximityPromptService").Enabled = false
		end)
		player:SetAttribute("CineMode", true) -- AtmosphereController ลดหมอกให้ภาพใส
		local bars = pg and pg:FindFirstChild("MobBars")
		if bars then
			cineSaved.Bars = bars
			bars.Parent = nil -- หลอดเลือดเหนือหัวสัตว์ไม่ขึ้นในฉาก (ของใหม่ยังเข้าโฟลเดอร์นี้ตามปกติ)
		end
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ShrineCineGrade"
		cc.Contrast, cc.Saturation, cc.Brightness = 0, 0, 0
		cc.TintColor = Color3.new(1, 1, 1)
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(0.8), { Contrast = 0.16, Saturation = 0.2, Brightness = 0.02, TintColor = (tint or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.88) }):Play()
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "ShrineCineDof"
		dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0.28, 0.15, 30, 34
		dof.Parent = Lighting
		local shade = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 45 })
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.28, 1), NumberSequenceKeypoint.new(0.72, 1), NumberSequenceKeypoint.new(1, 0.35) })
		grad.Parent = shade
		TweenService:Create(shade, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
		cineSaved.Fx = { cc, dof, shade }
		cineSaved.Grade = cc
		cineSaved.Dof = dof
	elseif not on and cineSaved then
		for _, g in ipairs(cineSaved.Guis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		pcall(function()
			game:GetService("ProximityPromptService").Enabled = true
		end)
		player:SetAttribute("CineMode", nil)
		if cineSaved.Bars and pg then
			cineSaved.Bars.Parent = pg
		end
		for _, f in ipairs(cineSaved.Fx) do
			if f.Parent then
				f:Destroy()
			end
		end
		cineSaved = nil
	end
end

local function sfx(name, pitch)
	local ok, Sound = pcall(require, script.Parent:FindFirstChild("SoundController"))
	if ok and Sound then
		pcall(Sound.Play, name, pitch)
	end
end

-- จอมืด/สว่างวาบตอนเปลี่ยนช็อต
local function flash(color, time)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 70 })
	TweenService:Create(f, TweenInfo.new(time or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(f, (time or 0.5) + 0.1)
end

-- คำบรรยายล่างจอ: ตัวหนังสือขึ้นทีละนิดแบบหนัง (อยู่เหนือแถบดำ)
local function caption(text, color, hold)
	text = UIKit.StripIcons(text)
	local t = UIKit.Text(gui, {
		Size = UDim2.new(1, -40, 0, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.865, 8), TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Bold, TextSize = 32, Text = text, TextColor3 = color or C.Text, TextTransparency = 1, ZIndex = 60,
	})
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = 1
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 0.15 }):Play()
	end
	TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.865, 0) }):Play()
	task.delay(hold or 2.2, function()
		TweenService:Create(t, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		if st then
			TweenService:Create(st, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		t:Destroy()
	end)
end

-- ป้ายใหญ่กลางจอสไตล์หนัง: หัวข้อเด้งเข้า + เส้นคาด + คำรอง (ไม่ทับแถบดำ)
local function titleCard(title, sub, color, hold)
	title, sub = UIKit.StripIcons(title), UIKit.StripIcons(sub)
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 170), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.29), BackgroundTransparency = 1, ZIndex = 62 })
	UIKit.AutoScale(f)
	local t = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 92), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 76,
		Text = title, TextColor3 = Color3.fromRGB(255, 250, 235), TextTransparency = 1, ZIndex = 63,
	})
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 252, 240), color:Lerp(Color3.new(1, 1, 1), 0.2))
	tg.Rotation = 90
	tg.Parent = t
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 63 })
	line.Visible = false -- ไม่มีขีดแนวนอนใต้หัวข้อ
	local lg = Instance.new("UIGradient")
	lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	lg.Parent = line
	local s = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 108), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Bold, TextSize = 28,
		Text = sub or "", TextColor3 = C.Text, TextTransparency = 1, ZIndex = 63,
	})
	local sc = Instance.new("UIScale")
	sc.Scale = 1.3
	sc.Parent = f
	local strokes = {}
	for _, lbl in ipairs({ t, s }) do
		local st = lbl:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = 1
			table.insert(strokes, st)
			TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()
		end
		TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
	UIKit.Tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	TweenService:Create(line, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 760, 0, 3) }):Play()
	task.delay(hold or 2.4, function()
		for _, lbl in ipairs({ t, s }) do
			TweenService:Create(lbl, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		end
		for _, st in ipairs(strokes) do
			TweenService:Create(st, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		end
		TweenService:Create(line, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		f:Destroy()
	end)
end

local function animalsNear(pos, radius, pred)
	local out = {}
	for _, m in ipairs(CollectionService:GetTagged("Animal")) do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude < radius and pred(m) then
			table.insert(out, m)
		end
	end
	return out
end

local function sparkBurst(pos, color, count, speed)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.8)
	e.Speed = NumberRange.new(speed or 14, (speed or 14) * 2.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(count or 60)
	game:GetService("Debris"):AddItem(p, 3)
end

-- คลื่นแสงแผ่จากพื้น (เสาโผล่สุด / ลูกสัตว์ถึงบ้าน)
local function shockRing(pos, color, radius)
	local r = Instance.new("Part")
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Size = Vector3.new(0.4, 6, 6)
	r.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	r.Transparency = 0.15
	r.Parent = Workspace
	TweenService:Create(r, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(r, 1.3)
end

local function centroid(models, fallback)
	local sum, n = Vector3.zero, 0
	for _, m in ipairs(models) do
		if m.Parent then
			sum += m:GetPivot().Position
			n += 1
		end
	end
	return n > 0 and sum / n or fallback
end

local CLEAR_VIEW = { Guard = true, Run = true, Turn = true, Home = true }
-- กล้องตามบท: shotFn(t) -> ตำแหน่ง, จุดมอง, fov, รหัสช็อต · เปลี่ยนรหัส = ตัดภาพ · กล้องสั่นเบาๆ แบบถือมือ + ระยะชัดตามจุดมอง
local function runShots(dur, shotFn, onDone)
	local cam = Workspace.CurrentCamera
	local prevType, prevFov = cam.CameraType, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local camPos, camLook, lastShot, fovNow
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if t > dur then
			conn:Disconnect()
			cam.CameraType = prevType
			cam.FieldOfView = prevFov
			local ok, err = pcall(onDone)
			if not ok then
				warn("[AS] cine done", err)
			end
			return
		end
		local ok, want, look, fov, shot = pcall(shotFn, t)
		if not ok then
			warn("[AS] cine shot", want)
			return
		end
		if not want then
			return
		end
		-- ช็อตที่ถ่ายผู้เล่น/ผู้เฝ้า/สัตว์: มีของบังระหว่างกล้องกับตัวละคร -> ขยับกล้องเข้ามาหน้าของที่บัง
		if CLEAR_VIEW[shot] then
			local ignore = CollectionService:GetTagged("Animal")
			if player.Character then
				table.insert(ignore, player.Character)
			end
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = ignore
			rp.RespectCanCollide = true
			local span = want - look
			local hit = span.Magnitude > 1 and Workspace:Raycast(look, span, rp)
			if hit then
				want = hit.Position - span.Unit * 1.5
			end
		end
		if shot ~= lastShot then
			camPos, camLook, fovNow, lastShot = want, look, fov or 60, shot
		end
		camPos = camPos:Lerp(want, 1 - math.exp(-dt * 9))
		camLook = camLook:Lerp(look, 1 - math.exp(-dt * 9))
		fovNow += ((fov or 60) - fovNow) * math.min(1, dt * 7)
		cam.FieldOfView = fovNow
		local hx = math.noise(t * 0.9, 3.1) * 0.012
		local hy = math.noise(t * 0.7, 7.7) * 0.012
		cam.CFrame = CFrame.lookAt(camPos, camLook) * CFrame.Angles(hx, hy, hx * 0.5)
		if cineSaved and cineSaved.Dof then
			cineSaved.Dof.FocusDistance = (camPos - camLook).Magnitude
		end
	end)
end

-- เรียงเหตุการณ์ตามเวลา (คืนฟังก์ชันเรียกทุกเฟรม)
local function timeline(events)
	table.sort(events, function(a, b)
		return a[1] < b[1]
	end)
	local i = 1
	return function(t)
		while events[i] and t >= events[i][1] do
			local ok, err = pcall(events[i][2])
			if not ok then
				warn("[AS] cine event", err)
			end
			i += 1
		end
	end
end

-- ฉากเปิด: ศาลเจ้า -> ลูกสัตว์ในกรง -> ผู้เฝ้าเดินไปหา -> เราวิ่งเข้าไป -> ผู้เฝ้าเห็นเรา หันมาคำราม
function Cinematics.ShrineIntro(d)
	if Cinematics.ShrineCut then
		return
	end
	local col = C.Element[d.Element] or C.Gold
	local cage = d.Cage
	local toEntry = ((d.Entry or (cage + Vector3.new(0, 0, -80))) - cage) * Vector3.new(1, 0, 1)
	toEntry = toEntry.Magnitude > 0.1 and toEntry.Unit or Vector3.new(0, 0, -1)
	local side = toEntry:Cross(Vector3.new(0, 1, 0))
	local DUR, TURN = d.Dur or 12, d.Turn or 9
	local name = d.Name or "ลูกสัตว์ธาตุ"
	local elThai = UIKit.ElementThai and UIKit.ElementThai[d.Element] or ""
	Cinematics.ShrineCut = true
	Cinematics.Cutscene = true
	letterbox(true)
	cinemaMode(true, col)
	local function guards()
		return animalsNear(cage, 90, function(m)
			return m:GetAttribute("Guardian") == true
		end)
	end
	local function myRoot()
		local ch = player.Character
		return ch and ch:FindFirstChild("HumanoidRootPart")
	end
	local leadGuard
	local function lead()
		-- ผู้เฝ้าที่ถ่ายได้ไม่ติดกรง = ตัวข้างลาน (ตัวหลังกรงมีกรงบังอยู่) เลือกตัวเดิมตลอดฉาก
		if leadGuard and leadGuard.Parent then
			return leadGuard
		end
		local best, bd
		for _, g in ipairs(guards()) do
			local dd = math.abs((g:GetPivot().Position - cage):Dot(side))
			if not bd or dd > bd then
				best, bd = g, dd
			end
		end
		leadGuard = best
		return best
	end
	local cageSpark = false
	local run = timeline({
		{ 0.1, function() sfx("Dusk", 0.7) end },
		{ 0.35, function() titleCard("ศาลเจ้า" .. elThai, "มีเสียงร้องดังมาจากกลางลาน...", col, 1.7) end },
		{ 2.6, function() flash(Color3.new(0, 0, 0), 0.45) sfx("StalkerWarn", 1.5) end },
		{ 2.9, function() caption(name .. " ถูกขังอยู่ในกรงผนึก...", col, 1.9) end },
		{ 4.9, function() flash(Color3.new(0, 0, 0), 0.4) sfx("WaveIncoming", 0.8) end },
		{ 5.1, function() caption("ผู้พิทักษ์ศาลเจ้ากำลังเดินเข้าไปหามัน!", Color3.fromRGB(255, 130, 110), 2.1) end },
		{ 7.4, function()
			flash(Color3.new(1, 1, 1), 0.3)
			caption("ต้องรีบเข้าไปช่วย!", C.Gold, 1.5)
			player:SetAttribute("CineRun", 1.6)
			local ch = player.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:MoveTo(cage + toEntry * 26)
			end
		end },
		{ TURN, function()
			flash(Color3.new(0, 0, 0), 0.25)
			sfx("BossIntro", 1.15)
		end },
		{ TURN + 0.55, function()
			if Cinematics.Combat then
				Cinematics.Combat.Shake(0.7, 1)
			end
			flash(Color3.new(1, 0.5, 0.4), 0.3)
			titleCard("ผู้พิทักษ์เห็นคุณแล้ว!", "ปราบให้หมด เพื่อปลดผนึกกรงช่วย " .. name, Color3.fromRGB(255, 110, 90), 1.9)
		end },
	})
	runShots(DUR, function(t)
		run(t)
		local baseAng = math.atan2(toEntry.Z, toEntry.X)
		if t < 2.6 then
			-- 1: มุมกว้างจากฟ้าลงสู่ลาน กรงอยู่กลางภาพ ผู้เฝ้าเริ่มเดินจากขอบลาน
			local k = ease(t / 2.6)
			local ang = baseAng + math.rad(14 - 28 * k)
			local dist = 62 - 22 * k
			return cage + Vector3.new(math.cos(ang) * dist, 34 - 22 * k, math.sin(ang) * dist), cage + Vector3.new(0, 4 + 2 * k, 0), 58, "Wide"
		elseif t < 4.9 then
			-- 2: ใกล้กรง กล้องต่ำดันเข้าหาลูกสัตว์ที่ก้มหน้าตัวสั่น (มองผ่านซี่กรง)
			if not cageSpark then
				cageSpark = true
				sparkBurst(cage + Vector3.new(0, 3, 0), col, 14, 4)
			end
			local k = ease((t - 2.6) / 2.3)
			local ang = baseAng + math.rad(-24 + 22 * k)
			local dist = 15 - 6 * k
			return cage + Vector3.new(math.cos(ang) * dist, 3.4, math.sin(ang) * dist), cage + Vector3.new(0, 2.6, 0), 42 - 6 * k, "Pup"
		elseif t < 7.4 then
			-- 3: หลังไหล่ผู้เฝ้าที่กำลังเดินเข้าหากรง (กรงอยู่ข้างหน้า ตัวมันใหญ่กินภาพ)
			local g = lead()
			local gp = g and g:GetPivot().Position or (cage - toEntry * 20)
			local dir = (cage - gp) * Vector3.new(1, 0, 1)
			dir = dir.Magnitude > 0.5 and dir.Unit or toEntry
			local s2 = dir:Cross(Vector3.new(0, 1, 0))
			local sz = g and g:GetExtentsSize().Y or 6
			return gp - dir * (sz * 1.5 + 7) + s2 * (sz * 0.8 + 2) + Vector3.new(0, sz * 0.75 + 1.5, 0), cage + Vector3.new(0, 2.5, 0), 50, "Guard"
		end
		local r = myRoot()
		local me = r and r.Position or (cage + toEntry * 60)
		local dir = (cage - me) * Vector3.new(1, 0, 1)
		dir = dir.Magnitude > 0.1 and dir.Unit or -toEntry
		if t < TURN then
			-- 4: กล้องอยู่ข้างหน้า วิ่งถอยไปด้วย เห็นหน้าเราวิ่งเข้ามา + ฉากหลังประตูมิติ
			local k = (t - 7.4) / (TURN - 7.4)
			return me + dir * (11 + 2 * k) + side * (4 - 7 * k) + Vector3.new(0, 2.2, 0), me + Vector3.new(0, 1.5, 0), 66, "Run"
		end
		-- 5: ซูมเข้าหน้าผู้เฝ้าตอนหันขวับมาหาเรา + คำราม
		local k = ease((t - TURN) / 1.8)
		local g = lead()
		local gp = g and g:GetPivot().Position or cage
		local sz = g and g:GetExtentsSize().Y or 6
		local toMe = (me - gp) * Vector3.new(1, 0, 1)
		toMe = toMe.Magnitude > 0.5 and toMe.Unit or toEntry
		local s3 = toMe:Cross(Vector3.new(0, 1, 0))
		return gp + toMe * (sz * 2.8 + 12 - 8 * k) + s3 * (sz * 0.7) + Vector3.new(0, sz * 0.25, 0), gp + Vector3.new(0, sz * 0.55, 0), 44 - 12 * k, "Turn"
	end, function()
		letterbox(false)
		cinemaMode(false)
		player:SetAttribute("CineRun", nil)
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local r = myRoot()
		if hum and r then
			hum:MoveTo(r.Position)
		end
		Cinematics.Cutscene = false
		Cinematics.ShrineCut = false
	end)
end

-- ฉากจบ: กรงแตก ลูกสัตว์ดีใจ -> เสาผลึกธาตุพุ่งจากดิน ลำแสงทะลุฟ้า "เคลียร์แล้ว" -> ลูกสัตว์ไปโผล่ที่บ้าน ดีใจ + 1 วัน
function Cinematics.ShrineCleared(d)
	local col = C.Element[d.Element] or C.Gold
	local cage, pillar, home = d.Cage, d.Pillar, d.Home
	local PA, HA = d.PillarAt or 3.6, d.HomeAt or 8.6
	local DUR = HA + 4.2
	Cinematics.ShrineCut = true
	Cinematics.Cutscene = true
	letterbox(true)
	cinemaMode(true, col)
	local pup = animalsNear(cage, 16, function(m)
		return m:GetAttribute("Kind") == "Spirit"
	end)[1]
	local rest = pup and pup:GetPivot()
	if pup then
		pup:SetAttribute("Cheer", true)
	end
	local name = d.Name or "ลูกสัตว์ธาตุ"
	local elThai = UIKit.ElementThai and UIKit.ElementThai[d.Element] or ""
	local away = (pillar - home) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 1 and away.Unit or Vector3.new(1, 0, 0)
	local pSide = away:Cross(Vector3.new(0, 1, 0))
	local pet, homeYaw
	local function findPet()
		if not (pet and pet.Parent) then
			-- หาตัวของศาลเจ้านี้ตามชนิด (ที่บ้านอาจมีตัวที่ช่วยมาก่อนอยู่แล้ว)
			pet = animalsNear(home, 80, function(m)
				return m:GetAttribute("Pet") == true and m:GetAttribute("AnimalId") == d.PetId
			end)[1]
			if pet then
				pet:SetAttribute("Cheer", true)
			end
		end
		return pet
	end
	local run = timeline({
		{ 0, function()
			flash(col:Lerp(Color3.new(1, 1, 1), 0.5), 0.45)
			sfx("Spirit")
			sfx("Reward")
			sparkBurst(cage + Vector3.new(0, 4, 0), col, 90, 18)
			shockRing(cage, col, 30)
			if Cinematics.Combat then
				Cinematics.Combat.Shake(0.45, 0.5)
			end
		end },
		{ 0.5, function() titleCard("ปลดผนึกสำเร็จ!", name .. " เป็นอิสระแล้ว", col, 2.2) end },
		{ PA - 0.25, function() flash(Color3.new(1, 1, 1), 0.55) end },
		{ PA, function()
			sfx("NightStart", 0.65)
			if Cinematics.Combat then
				Cinematics.Combat.Shake(0.5, 3)
			end
			caption("แผ่นดินสั่นสะเทือน...", C.Text, 1.8)
		end },
		{ PA + 3.1, function()
			-- เสาโผล่สุด: คลื่นแสง + ประกาศเคลียร์
			flash(col:Lerp(Color3.new(1, 1, 1), 0.7), 0.5)
			shockRing(pillar, col, 90)
			sparkBurst(pillar + Vector3.new(0, 40, 0), col, 120, 30)
			sfx("CampUpgrade")
			titleCard("เคลียร์ศาลเจ้า" .. elThai .. "แล้ว!", "เสาผลึก" .. elThai .. "ส่องแสงเหนือไบโอม", col, 1.6)
		end },
		{ HA - 0.25, function() flash(col:Lerp(Color3.new(1, 1, 1), 0.6), 0.55) end },
		{ HA + 0.15, function()
			sparkBurst(home + Vector3.new(0, 3, 0), col, 80, 16)
			shockRing(home, col, 22)
			sfx("Reward", 1.1)
		end },
		{ HA + 0.8, function()
			-- กลางวัน/พลบค่ำ +1 ทันที · กลางคืนเก็บไว้นับตอนเช้า (DirectorService:SkipDay)
			local st = Cinematics.State
			local phase = st and st:GetAttribute("Phase")
			local now = phase == "Day" or phase == "Dusk"
			local dayText = now and st:GetAttribute("Night") and ("ตอนนี้วันที่ " .. st:GetAttribute("Night")) or "นับให้ตอนเช้า"
			titleCard("+1 วัน", dayText .. " · " .. name .. " มาอยู่ที่บ้านแล้ว", C.Gold, 1.7)
		end },
		{ HA + 2.6, function() caption("บัฟ: " .. (d.Buff or "") .. " · กด E ที่ตัวมันเพื่อขี่ได้", C.Text, 1.5) end },
	})
	runShots(DUR, function(t)
		run(t)
		if t < PA then
			-- 1: ลูกสัตว์กระโดดดีใจหมุนตัว กล้องวนต่ำรอบมัน (ภาพเฉพาะเครื่องนี้)
			if pup and pup.Parent and rest then
				local hop = math.abs(math.sin(t * 5.2)) * 2.6
				pup:PivotTo(rest * CFrame.new(0, hop, 0) * CFrame.Angles(0, t * 2.2, 0))
			end
			local ang = math.rad(25) + t * 0.45
			local at = pup and pup.Parent and pup:GetPivot().Position or (cage + Vector3.new(0, 3, 0))
			return cage + Vector3.new(math.cos(ang) * 13, 4.5, math.sin(ang) * 13), at + Vector3.new(0, 0.5, 0), 48, "Free"
		elseif t < PA + 3.1 then
			-- 2: ติดพื้นใกล้เสา มองขึ้น เสาพุ่งผ่านจอ (ประตูศาลเจ้าอยู่ฝั่งแคมป์ ไม่บัง)
			local k = ease((t - PA) / 3.1)
			return pillar + pSide * (46 + 4 * k) + away * 10 + Vector3.new(0, 5 + 6 * k, 0), pillar + Vector3.new(0, 6 + 42 * k, 0), 62, "Rise"
		elseif t < HA then
			-- 3: ถอยออกมุมกว้าง เห็นเสาทั้งแท่งกับลำแสงทะลุฟ้าเหนือป่า
			local k = ease((t - PA - 3.1) / (HA - PA - 3.1))
			return pillar + pSide * (58 + 70 * k) + away * (14 + 20 * k) + Vector3.new(0, 14 + 34 * k, 0), pillar + Vector3.new(0, 44 + 20 * k, 0), 60, "Beam"
		end
		-- 4: ที่บ้าน: ตามตัวลูกสัตว์ที่โตแล้วกำลังดีใจ
		local m = findPet()
		local at = m and m:GetPivot().Position or home
		local k = (t - HA) / (DUR - HA)
		-- กล้องอยู่ด้านหน้าตัวมัน (เห็นหน้า) ค่อยๆ เคลื่อนเข้าใกล้
		local fwd = m and (m:GetPivot().LookVector * Vector3.new(1, 0, 1)) or Vector3.new(0, 0, -1)
		fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
		-- สัตว์ตัวอื่นที่ช่วยมาก่อนเดินอยู่แถวนี้: เลือกมุมหน้าที่ไม่มีตัวไหนบัง (เลือกครั้งเดียว ไม่ให้กล้องกระตุก)
		if m and not homeYaw then
			homeYaw = 0
			for _, a in ipairs({ 0, 40, -40, 80, -80 }) do
				local dir = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(fwd)
				local blocked = false
				for _, o2 in ipairs(animalsNear(at, 45, function(x)
					return x ~= m and x:GetAttribute("Pet") == true
				end)) do
					local rel = (o2:GetPivot().Position - at) * Vector3.new(1, 0, 1)
					local along = rel:Dot(dir)
					if along > 0 and along < 24 and (rel - dir * along).Magnitude < 9 then
						blocked = true
					end
				end
				if not blocked then
					homeYaw = a
					break
				end
			end
		end
		fwd = CFrame.Angles(0, math.rad(homeYaw or 0), 0):VectorToWorldSpace(fwd)
		local sd = fwd:Cross(Vector3.new(0, 1, 0))
		return at + fwd * (20 - 7 * k) + sd * (6 - 8 * k) + Vector3.new(0, 5 - 1.5 * k, 0), at + Vector3.new(0, 3, 0), 48, "Home"
	end, function()
		letterbox(false)
		cinemaMode(false)
		if pup and pup.Parent and rest then
			pup:SetAttribute("Cheer", nil)
			pup:PivotTo(rest)
		end
		if pet and pet.Parent then
			pet:SetAttribute("Cheer", nil)
		end
		Cinematics.Cutscene = false
		Cinematics.ShrineCut = false
	end)
end

---------------------------------------------------------------- จอดำตาย
local deathFrame
local function clearDeath(time)
	if not deathFrame then
		return
	end
	local df = deathFrame
	deathFrame = nil
	for _, d in ipairs(df:GetDescendants()) do
		if d:IsA("TextLabel") then
			UIKit.Tween(d, time, { TextTransparency = 1 })
		elseif d:IsA("Frame") then
			UIKit.Tween(d, time, { BackgroundTransparency = 1 })
		end
	end
	task.delay(time + 0.1, function()
		df:Destroy()
	end)
end

-- ตายในรอบ: ไม่เกิดใหม่ -> จอ YOU PERISHED สั้นๆ แล้วไปโหมดดูเพื่อน (DeathClient)
function Cinematics.Died(d)
	if deathFrame then
		deathFrame:Destroy()
	end
	deathFrame = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 70 })
	local band = UIKit.Frame(deathFrame, { Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0.5, -85), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 71 })
	UIKit.Gradient(band, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	local inner = UIKit.Frame(band, { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 71 })
	UIKit.AutoScale(inner)
	local t = UIKit.Text(inner, {
		Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 96, Text = "YOU PERISHED", TextColor3 = Color3.fromRGB(150, 16, 20), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 72,
	})
	local alive = d and d.Alive or 0
	local s = UIKit.Text(inner, {
		Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 124), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20,
		Text = alive > 0 and string.format("สิ้นชีพ... ไม่มีการเกิดใหม่ในรอบนี้ · เพื่อนยังรอดอยู่ %d คน", alive) or "สิ้นชีพ... ไม่มีการเกิดใหม่ในรอบนี้",
		TextColor3 = Color3.fromRGB(200, 170, 160), TextTransparency = 1, ZIndex = 72,
	})
	UIKit.Tween(band, 1.5, { BackgroundTransparency = 0 })
	UIKit.Tween(t, 2.2, { TextTransparency = 0, TextSize = 104 })
	task.delay(1.4, function()
		UIKit.Tween(s, 1, { TextTransparency = 0 })
	end)
	task.delay(3.4, function()
		if alive > 0 then
			clearDeath(0.8)
		end
		if Cinematics.Death then
			Cinematics.Death.StartSpectate(d)
		end
	end)
	player.CharacterAdded:Once(function()
		clearDeath(0.8)
	end)
end

---------------------------------------------------------------- จบเกม
function Cinematics.FullScreen(title, lines, color, time)
	title = UIKit.StripIcons(title)
	for i, l in ipairs(lines) do
		lines[i] = UIKit.StripIcons(l)
	end
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 90 })
	UIKit.Tween(f, 2, { BackgroundTransparency = 0.15 })
	-- เนื้อหาอยู่ในกล่องกลางจอ (ย่อทั้งกล่องบนมือถือ)
	local box = UIKit.Frame(f, { Size = UDim2.new(1, 0, 0, 120 + #lines * 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), BackgroundTransparency = 1, ZIndex = 90 })
	UIKit.AutoScale(box)
	local t = UIKit.Text(box, {
		Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 80, Text = title, TextColor3 = color, TextTransparency = 1, ZIndex = 91,
	})
	UIKit.Tween(t, 2.5, { TextTransparency = 0 })
	for i, line in ipairs(lines) do
		local l = UIKit.Text(box, {
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 76 + i * 34), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22,
			Text = line, TextColor3 = C.Text, TextTransparency = 1, ZIndex = 91,
		})
		task.delay(1.5 + i * 0.8, function()
			UIKit.Tween(l, 1, { TextTransparency = 0 })
		end)
	end
	task.delay(time or 12, function()
		UIKit.Tween(f, 1.5, { BackgroundTransparency = 1 })
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 1.2, { TextTransparency = 1 })
			end
		end
		task.wait(1.6)
		f:Destroy()
	end)
end

---------------------------------------------------------------- ตัวจัดการ
local ELEMENT_NIGHT_TEXT = {
	Earth = "ป่าทั้งผืนตื่นขึ้น... ฝูงสัตว์แห่งปฐพีกำลังมา",
	Water = "เสียงคลื่นคำราม... สัตว์แห่งวารีขึ้นจากน้ำ",
	Air = "ลมหวีดหวิว... ผู้ล่าแห่งท้องฟ้าโฉบลงมา",
	Fire = "ภูเขาไฟปะทุ... อสูรเพลิงลุกลาม",
	All = "ทุกธาตุโกรธเกรี้ยว...",
}

-- กวางกลวงกำลังจะออกล่า (เตือนก่อน ~5 วินาที): ขอบจอมืดเต้นแบบหลอน + ป้ายเตือน (เสียงเล่นจาก SoundController)
--   ห้ามใช้สีแดง: แดง = เจ็บ/เลือดต่ำเท่านั้น (เคยแดงกะพริบทุกคืน ผู้เล่นนึกว่าเลือดจะหมด)
function Cinematics.StalkerWarning(d, combat)
	local holder = UIKit.Frame(gui, { Name = "StalkerVignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local red = Color3.fromRGB(8, 4, 18)
	local specs = {
		{ UDim2.new(1, 0, 0.24, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0.24, 0), UDim2.fromScale(0, 0.76), -90 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 },
	}
	local edges = {}
	for _, sp in ipairs(specs) do
		local e = UIKit.Frame(holder, { Size = sp[1], Position = sp[2], BackgroundColor3 = red, BackgroundTransparency = 1 })
		local g = Instance.new("UIGradient")
		g.Rotation = sp[3]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = e
		table.insert(edges, e)
	end
	Cinematics.Banner("มีบางอย่างกำลังเข้ามา...", "อยู่ใกล้แสงไฟ! 🔥", Color3.fromRGB(255, 70, 60), 3.5, { Size = 50, Y = 0.2 })
	if combat and combat.Shake then
		combat.Shake(0.12, 0.5)
	end
	task.spawn(function()
		local pulses = math.clamp(math.floor((tonumber(d.In) or 5) / 1.05 + 0.5), 2, 6)
		for _ = 1, pulses do
			for _, e in ipairs(edges) do
				UIKit.Tween(e, 0.35, { BackgroundTransparency = 0.25 })
			end
			task.wait(0.4)
			for _, e in ipairs(edges) do
				UIKit.Tween(e, 0.6, { BackgroundTransparency = 0.7 })
			end
			task.wait(0.65)
		end
		for _, e in ipairs(edges) do
			UIKit.Tween(e, 0.8, { BackgroundTransparency = 1 })
		end
		task.wait(0.9)
		holder:Destroy()
	end)
end

-- ระหว่างฉากศาลเจ้า: งดป้ายใหญ่ของระบบ (ไม่ทับตัวหนังสือในฉาก / แถบดำไม่หดกลางฉาก)
local QUIET_IN_CUT = { NightStart = true, DayStart = true, Dusk = true, Dawn = true, WaveIncoming = true, CampUpgrade = true, FireOut = true }
function Cinematics.Handle(kind, d, menus, combat)
	Cinematics.Combat = combat
	if Cinematics.ShrineCut and QUIET_IN_CUT[kind] then
		return
	end
	if kind == "NightStart" then
		local color = d.BloodMoon and Color3.fromRGB(220, 40, 40) or (C.Element[d.Element] or C.Gold)
		local title = d.BloodMoon and "BLOOD MOON" or ("NIGHT " .. d.Night)
		local sub = (d.BloodMoon and ("คืนที่ " .. d.Night .. " · ") or "") .. (d.Title or "") .. " — " .. (ELEMENT_NIGHT_TEXT[d.Element] or "")
		if type(d.Elements) == "table" and #d.Elements > 0 then
			-- พระจันทร์เลือดครั้งแรก: บอกว่าธาตุไหนบุกบ้าง
			local names = {}
			for _, e in ipairs(d.Elements) do
				table.insert(names, (UIKit.ElementIcon[e] or "") .. (UIKit.ElementThai[e] or tostring(e)))
			end
			sub = "คืนที่ " .. d.Night .. " · " .. (d.Title or "") .. " — " .. table.concat(names, " + ") .. " บุกพร้อมกัน!"
		end
		if d.Boss then
			sub = "คืนที่ " .. d.Night .. " · " .. (d.Title or "") .. " — บอสธาตุกำลังมาถึง!"
		end
		letterbox(true)
		Cinematics.Banner(title, sub, color, 4)
		task.delay(4.5, function()
			letterbox(false)
		end)
		combat.Shake(0.3, 1)
	elseif kind == "DayStart" then
		if d.Day > 1 then
			Cinematics.Banner("DAY " .. d.Day, "สำรวจ เก็บของ และเตรียมรับมือก่อนค่ำ", C.Gold, 2.5, { Size = 54, Y = 0.22 })
		else
			Cinematics.Banner("DAY 1", "จุดไฟไว้ให้ลุกโชน... ป่านี้ไม่เคยหลับใหล", C.Gold, 4, { Size = 60, Y = 0.22 })
		end
	elseif kind == "Dusk" then
		Cinematics.Banner("DUSK", "พระอาทิตย์กำลังตก — กลับไปที่กองไฟ!", C.Fire, 2.5, { Size = 50, Y = 0.22 })
	elseif kind == "Dawn" then
		Cinematics.Banner("DAWN", string.format("รอดชีวิตผ่านคืนที่ %d แล้ว", d.Night), Color3.fromRGB(255, 220, 160), 3, { Size = 60 })
	elseif kind == "WaveIncoming" then
		combat.Shake(0.15, 0.6)
	elseif kind == "BossIntro" then
		task.spawn(function()
			local t0 = os.clock()
			while not (d.Model and d.Model.Parent and (d.Model:FindFirstChild("HumanoidRootPart") or d.Model.PrimaryPart)) and os.clock() - t0 < 3 do
				local animals = Workspace:FindFirstChild("Animals")
				for _, m in ipairs(animals and animals:GetChildren() or {}) do
					if m:GetAttribute("AnimalId") == d.Id and m:GetAttribute("IsBoss") then
						d.Model = m
					end
				end
				task.wait(0.1)
			end
			Cinematics.BossIntro(d)
		end)
	elseif kind == "BossFelled" then
		Cinematics.Banner("BEAST VANQUISHED", "ปราบ " .. (d.Thai or "") .. " สำเร็จ! · ได้หัวใจอสูร", Color3.fromRGB(255, 214, 120), 4.5, { Size = 76 })
	elseif kind == "Died" then
		Cinematics.Died(d)
	elseif kind == "Downed" then
		combat.Shake(0.5, 0.4)
		Cinematics.Banner("DOWNED", "คุณล้มลง! รอเพื่อนใช้ผ้าพันแผลช่วย — ถ้าไม่เหลือใครยืนอยู่ = แพ้ทั้งทีม", Color3.fromRGB(255, 90, 80), 3, { Size = 64, Y = 0.2 })
	elseif kind == "Revived" then
		Cinematics.Banner("", "✨ ได้รับการช่วยชีวิต!", C.Good, 1.5, { Size = 10, Y = 0.5 })
	elseif kind == "GameOver" then
		clearDeath(0.3)
		if Cinematics.Death then
			Cinematics.Death.StopSpectate()
		end
		local lines = {
			string.format("ทีมล้มลงทั้งหมดในคืนที่ %d", d.Night or 1),
			string.format("รอดได้ %d คืน · สถิติสูงสุดของคุณ %d คืน", d.Survived or 0, d.Best or 0),
			"กองไฟมอดดับลง... ป่ากลืนกินทุกสิ่ง",
			"กำลังพากลับสู่ล็อบบี้...",
		}
		Cinematics.FullScreen("ALL HAVE PERISHED", lines, Color3.fromRGB(170, 20, 24), 11)
	elseif kind == "Ending" then
		local tail = d.Continue and "♾ เกมยังไม่จบ! เล่นต่อได้ไม่จำกัด — รอดให้นานที่สุดเพื่อขึ้นกระดานอันดับ" or ""
		if d.Kind == "True" then
			Cinematics.FullScreen("THE FOUR SPIRITS REUNITE", {
				"ลูกสัตว์ทั้ง 4 ธาตุกลับมาพร้อมหน้า", "คุณพิชิต 99 คืน — จบแบบสมบูรณ์", "♦️ +300 Ruby", tail,
			}, Color3.fromRGB(255, 226, 150), 12)
		else
			Cinematics.FullScreen("99 NIGHTS CONQUERED", {
				"คุณพิชิต 99 คืนแห่งผืนป่า!", string.format("ลูกสัตว์ธาตุกลับมา %d/4 ตัว — ช่วยครบเพื่อฉากจบที่แท้จริง", d.Spirits or 0),
				"♦️ +100 Ruby", tail,
			}, C.Gold, 12)
		end
	elseif kind == "Purchased" then
		if d.Kind == "Pack" then
			Cinematics.Banner("♦️ +" .. tostring(d.Diamonds or 0), "เติม " .. (d.Name or "Ruby") .. " สำเร็จ — ขอบคุณที่สนับสนุน!", Color3.fromRGB(120, 230, 255), 3, { Size = 72, Y = 0.3 })
		else
			Cinematics.Banner("🎫 " .. (d.Name or "GAME PASS"), "ปลดล็อกแล้ว! ขอบคุณที่สนับสนุน", C.Gold, 3, { Size = 64, Y = 0.3 })
		end
	elseif kind == "SpiritFreed" then
		Cinematics.Banner("SPIRIT UNSEALED", (d.Player or "") .. " ปลดปล่อย " .. (d.Name or "") .. " — พากลับกองไฟ!", C.Element[d.Element] or C.Gold, 3.5, { Size = 56 })
	elseif kind == "SpiritRescued" then
		if not Cinematics.ShrineCut then -- คนที่ดูฉากจบศาลเจ้าอยู่เห็นข้อความในฉากแล้ว
			Cinematics.Banner("SPIRIT RETURNED", string.format("%s ไปอยู่ที่แคมป์แล้ว (%d/4)%s · บัฟ: %s", d.Name or "", d.Count or 0, d.Day and " · +1 วัน" or "", d.Buff or ""), C.Element[d.Element] or C.Gold, 4.5, { Size = 60 })
		end
	elseif kind == "ShrineIntro" then
		Cinematics.ShrineIntro(d)
	elseif kind == "ShrineCleared" then
		Cinematics.ShrineCleared(d)
	elseif kind == "CampUpgrade" then
		Cinematics.Banner("BONFIRE LV." .. d.Level, "เขตปลอดภัยขยาย · หมอกจางลง · ทางใหม่เปิดออก", C.Fire, 3, { Size = 54, Y = 0.22 })
	elseif kind == "FireOut" then
		Cinematics.Banner("THE FIRE IS OUT", "กองไฟดับ! เติมไม้ด่วน", Color3.fromRGB(255, 80, 60), 3, { Size = 56 })
		combat.Shake(0.3, 0.5)
	elseif kind == "OpenCraft" then
		menus.OpenCraft()
	elseif kind == "OpenShop" then
		menus.OpenShop("Diamonds")
	elseif kind == "OpenClasses" then
		menus.OpenShop("Classes")
	elseif kind == "OpenTrader" then
		menus.OpenTrader()
	elseif kind == "Teleporting" then
		if d.Back then
			Cinematics.Banner("RETURNING", "กำลังพากลับสู่ค่าย WILDHEART...", C.Gold, 8, { Size = 60, Y = 0.62 })
		else
			Cinematics.Banner("DEPARTING", "กำลังพาทีมไปยังผืนป่าของพวกคุณ...", C.Gold, 6, { Size = 60 })
		end
	elseif kind == "Depart" then
		letterbox(true)
		Cinematics.Banner("INTO THE WILDS", "ลงสู่ผืนป่า... จุดไฟให้ลุกโชน แล้วเอาชีวิตรอดให้ได้ 99 คืน", C.Gold, 3.5, { Size = 64 })
		task.delay(4, function()
			letterbox(false)
		end)
	elseif kind == "Shake" then
		combat.Shake(d.Power or 0.5, d.Time or 0.5)
	elseif kind == "Flash" then
		-- วาร์ปผ่านประตูมิติ: จอขาวแวบแล้วจางออก
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			local g = Instance.new("ScreenGui")
			g.IgnoreGuiInset = true
			g.DisplayOrder = 90
			g.ResetOnSpawn = false
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = d.Color or Color3.new(1, 1, 1)
			f.BackgroundTransparency = 0
			f.Parent = g
			g.Parent = pg
			TweenService:Create(f, TweenInfo.new(d.Time or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
			game:GetService("Debris"):AddItem(g, (d.Time or 0.6) + 0.2)
		end
	elseif kind == "Warp" then
		Cinematics.Warp(d)
	elseif kind == "StalkerWarning" then
		Cinematics.StalkerWarning(d, combat)
	end
end

---------------------------------------------------------------- วาร์ปผ่านประตูมิติ
-- In : ถูกดูดเข้าม่าน — มุมกล้องยืด, เส้นแสงพุ่งเข้ากลางจอ, จอค่อยๆ เป็นสีธาตุ, วงวน VFX ที่ตัว, เสียงลมหวีด
-- Out: โผล่ปลายทาง — สีจางออก, มุมกล้องเด้งกลับ, วงแสงระเบิดรอบตัว
local warpGui
function Cinematics.Warp(d)
	local col = d.Color or Color3.fromRGB(200, 230, 255)
	local cam = Workspace.CurrentCamera
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local okV, VFXLib = pcall(require, script.Parent:WaitForChild("VFXLib"))
	local function burst()
		if okV and root then
			pcall(VFXLib.Play, "VFXPack/Anime/Portal-Enter-01", CFrame.new(root.Position) * CFrame.Angles(0, 0, 0), { Scale = 1.4, Duration = 0.8, Tint = col })
		end
	end
	if d.Phase == "In" then
		if warpGui then
			warpGui:Destroy()
		end
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://9113077334"
		s.Volume = 0.7
		s.Parent = SoundService
		s:Play()
		game:GetService("Debris"):AddItem(s, 4)
		burst()
		Cinematics.WarpFov = Cinematics.WarpFov or cam.FieldOfView
		TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FieldOfView = 115 }):Play()
		if not pg then
			return
		end
		local g = Instance.new("ScreenGui")
		g.Name = "ASWarp"
		g.IgnoreGuiInset = true
		g.DisplayOrder = 90
		g.ResetOnSpawn = false
		g.Parent = pg
		warpGui = g
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.35)
		fill.BackgroundTransparency = 1
		fill.ZIndex = 2
		fill.Parent = g
		TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
		-- เส้นแสงพุ่งเข้าหากลางจอ (เหมือนถูกดูดเข้าอุโมงค์)
		for i = 1, 28 do
			local a = (i / 28) * 360 + math.random(-6, 6)
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromScale(0.5, 0.5)
			line.Size = UDim2.fromOffset(math.random(80, 200), math.random(2, 5))
			line.Rotation = a
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(col, 0.3)
			line.BackgroundTransparency = 0.2
			line.Parent = g
			local r = math.rad(a)
			local far = UDim2.new(0.5, math.cos(r) * 900, 0.5, math.sin(r) * 900)
			local near = UDim2.new(0.5, math.cos(r) * 60, 0.5, math.sin(r) * 60)
			line.Position = far
			TweenService:Create(line, TweenInfo.new(0.45 + math.random() * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = near, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(line.Size.X.Offset * 0.3, line.Size.Y.Offset) }):Play()
		end
		game:GetService("Debris"):AddItem(g, 3)
	else
		task.delay(0.08, burst)
		TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = Cinematics.WarpFov or 70 }):Play()
		Cinematics.WarpFov = nil
		local g = warpGui
		warpGui = nil
		if g and g.Parent then
			for _, c in ipairs(g:GetChildren()) do
				if c:IsA("Frame") and c.Name ~= "Fill" then
					c:Destroy()
				end
			end
			local fill = g:FindFirstChild("Fill")
			if fill then
				fill.BackgroundTransparency = 0
				TweenService:Create(fill, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			end
			game:GetService("Debris"):AddItem(g, 0.9)
		end
	end
end

function Cinematics.Init(state)
	Cinematics.State = state
	gui = UIKit.Screen("Cinematics", 40, true)
	Cinematics.Gui = gui
	-- หน้าโหลดเสมอตอนเข้าเกม (ปิดเองเมื่อโหลดทุกอย่างครบ) · ลงแมพ = หน้าโหลดเดินทาง
	local testing = ReplicatedStorage:FindFirstChild("ASAutoTest") ~= nil -- เทสต์อัตโนมัติ: ไม่บังจอ
	if not testing then
		Cinematics.Loading(state)
	else
		task.defer(function()
			if Cinematics.OnLoaded then
				Cinematics.OnLoaded()
			end
		end)
	end
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") and not Cinematics.IsLoading and not testing then
			Cinematics.Travel()
		end
	end)
end

-- ใช้ทดสอบหน้าตาหน้าโหลด (tests/ASLobbyProbe)
Cinematics.PreviewLoading = function(title, subtitle)
	return loadingScreen(title, subtitle)
end

return Cinematics
