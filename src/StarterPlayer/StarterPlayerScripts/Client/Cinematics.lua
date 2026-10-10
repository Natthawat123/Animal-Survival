--[[
	Cinematics — ฉาก/ตัวอักษรใหญ่แบบภาพยนตร์
	  หน้าโหลด, NIGHT X, BLOOD MOON, เปิดตัวบอส (กล้องหมุน), BEAST VANQUISHED, YOU PERISHED, ฉากจบ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, opts.Y or 0.28, 0), BackgroundTransparency = 1 })
	local t = bigText(f)
	t.Text = title
	t.TextColor3 = color or C.Gold
	t.TextSize = opts.Size or 72
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 520, 0, 2), Position = UDim2.new(0.5, -260, 0, 92), BackgroundColor3 = color or C.Gold, BackgroundTransparency = 1 })
	line:SetAttribute("Line", true)
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
-- โครงหน้าโหลด: พื้นหลังไล่สี + ชื่อเกม + แถบความคืบหน้า + ขั้นตอน + เคล็ดลับ -> คืน { Root, Set(p, text), Close() }
local function loadingScreen(title, subtitle)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 7, 10), BackgroundTransparency = 0, ZIndex = 100 })
	UIKit.Gradient(f, Color3.fromRGB(46, 36, 96), Color3.fromRGB(10, 10, 28), 90)
	-- แสงไฟกองไฟวูบวาบด้านล่าง
	local glow = UIKit.Frame(f, { Size = UDim2.fromScale(1.2, 0.6), Position = UDim2.fromScale(-0.1, 0.62), BackgroundColor3 = Color3.fromRGB(255, 120, 40), BackgroundTransparency = 0.82, ZIndex = 100 })
	UIKit.Corner(glow, 400)
	local fx = Instance.new("UIGradient")
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fx.Rotation = 90
	fx.Parent = glow
	-- ประกายไฟลอยขึ้น
	for i = 1, 26 do
		local s = UIKit.Frame(f, { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromScale(math.random(), 1.02), BackgroundColor3 = Color3.fromRGB(255, 190, 90), BackgroundTransparency = 0.2, ZIndex = 101 })
		UIKit.Corner(s, 2)
		task.spawn(function()
			task.wait(i * 0.17)
			while s.Parent do
				s.Position = UDim2.fromScale(math.random(), 1.02)
				local t = 3 + math.random() * 3
				TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Linear), { Position = UDim2.fromScale(s.Position.X.Scale + (math.random() - 0.5) * 0.15, 0.35 + math.random() * 0.3), BackgroundTransparency = 1 }):Play()
				task.wait(t)
				s.BackgroundTransparency = 0.2
			end
		end)
	end
	local titleL = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 0.26, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 96, Text = title, TextColor3 = C.Gold, ZIndex = 102,
	})
	titleL:FindFirstChildOfClass("UIStroke").Thickness = 6
	UIKit.Gradient(titleL, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 160, 40), 90)
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.26, 108), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 30, Text = subtitle, TextColor3 = Color3.fromRGB(226, 208, 178), ZIndex = 102,
	})
	-- แถบความคืบหน้า (มีเงาเรืองแสง)
	local track = UIKit.Frame(f, { Size = UDim2.new(0, 600, 0, 26), Position = UDim2.new(0.5, -300, 0.76, 0), BackgroundColor3 = Color3.fromRGB(16, 16, 34), BackgroundTransparency = 0, ZIndex = 102 })
	UIKit.Corner(track, 11)
	UIKit.Stroke(track, C.Outline, 3, 0)
	local fill = UIKit.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, BackgroundTransparency = 0, ZIndex = 103 })
	UIKit.Corner(fill, 11)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.41, Color3.fromRGB(205, 205, 205)), ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
	})
	fg.Rotation = 90
	fg.Parent = fill
	local pct = UIKit.Text(f, { Size = UDim2.new(0, 600, 0, 26), Position = UDim2.new(0.5, -300, 0.76, -34), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 24, Font = UIKit.Fonts.Title, ZIndex = 102, TextColor3 = C.Gold, Text = "0%" })
	local status = UIKit.Text(f, { Size = UDim2.new(0, 600, 0, 26), Position = UDim2.new(0.5, -300, 0.76, -34), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18, Font = UIKit.Fonts.Black, ZIndex = 102, TextColor3 = Color3.fromRGB(220, 206, 184), Text = "" })
	local tip = UIKit.Text(f, { Size = UDim2.new(1, -80, 0, 24), Position = UDim2.new(0, 40, 0.88, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, ZIndex = 102, TextColor3 = Color3.fromRGB(196, 182, 156), Text = "💡 " .. TIPS[math.random(#TIPS)] })
	task.spawn(function()
		while f.Parent do
			task.wait(5)
			tip.Text = "💡 " .. TIPS[math.random(#TIPS)]
		end
	end)
	local shown = 0
	local api = { Root = f }
	function api.Set(p, text)
		p = math.clamp(p, 0, 1)
		if p > shown then
			shown = p
			UIKit.Tween(fill, 0.35, { Size = UDim2.fromScale(p, 1) })
		end
		pct.Text = math.floor(shown * 100) .. "%"
		if text then
			status.Text = text
		end
	end
	function api.Close()
		api.Set(1, "พร้อมแล้ว!")
		task.wait(0.4)
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
			elseif d:IsA("Frame") then
				UIKit.Tween(d, 0.8, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				UIKit.Tween(d, 0.8, { Transparency = 1 })
			end
		end
		UIKit.Tween(f, 0.9, { BackgroundTransparency = 1 })
		task.wait(0.95)
		f:Destroy()
	end
	local _ = titleL
	return api
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

-- เข้าเกม: โหลดโลก -> โหลดทรัพยากร (โมเดล/พื้นผิว/เอฟเฟกต์) -> ตัวละคร + พื้นใต้เท้า -> ค่อยปิด
function Cinematics.Loading(state)
	local ui = loadingScreen(Config.GameName, Config.Subtitle)
	Cinematics.IsLoading = true
	task.spawn(function()
		-- 1) โลก (เซิร์ฟเวอร์สร้างแมพ) 0-40%
		while (state:GetAttribute("LoadProgress") or 0) < 1 and not state:GetAttribute("Ready") do
			local p = state:GetAttribute("LoadProgress") or 0
			ui.Set(p * 0.4, string.format("กำลังสร้างโลกทั้ง 4 ธาตุ... %d%%", math.floor(p * 100)))
			task.wait(0.1)
		end
		ui.Set(0.4, "กำลังโหลดโมเดลและพื้นผิว...")
		-- 2) ทรัพยากรทั้งหมด 40-90%
		local list = {}
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if assets then
			table.insert(list, assets)
		end
		local lobby = Workspace:FindFirstChild("Lobby")
		if lobby then
			table.insert(list, lobby)
		end
		local items = {}
		for _, root in ipairs(list) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter")
					or d:IsA("Beam") or d:IsA("SpecialMesh") or d:IsA("Sound") then
					table.insert(items, d)
				end
			end
		end
		local total = math.max(#items, 1)
		local done = 0
		local CP = game:GetService("ContentProvider")
		local batch = 40
		for i = 1, #items, batch do
			local chunk = {}
			for k = i, math.min(i + batch - 1, #items) do
				table.insert(chunk, items[k])
			end
			pcall(function()
				CP:PreloadAsync(chunk)
			end)
			done += #chunk
			ui.Set(0.4 + 0.5 * done / total, string.format("กำลังโหลดทรัพยากร %d/%d", done, total))
		end
		-- 3) ตัวละคร + พื้นล็อบบี้ใต้เท้า 90-100%
		ui.Set(0.9, "กำลังจุดกองไฟในค่าย...")
		local t0 = os.clock()
		while not (player.Character and groundReady()) and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
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
function Cinematics.BossIntro(d)
	local model = d.Model
	local cam = Workspace.CurrentCamera
	if not (model and model.Parent) then
		model = nil
	end
	letterbox(true)
	local color = C.Element[d.Element] or C.Gold
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 160), Position = UDim2.new(0, 0, 0.62, 0), BackgroundTransparency = 1, ZIndex = 60 })
	local name = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 56,
		Text = d.Name, TextColor3 = Color3.fromRGB(245, 236, 220), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 700, 0, 2), Position = UDim2.new(0.5, -350, 0, 72), BackgroundColor3 = color, BackgroundTransparency = 1, ZIndex = 61 })
	line:SetAttribute("Line", true)
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24,
		Text = d.Thai, TextColor3 = color, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local _ = name
	fadeTexts(f, 0, 1)
	if model then
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not root then
			model = nil
		end
	end
	if model then
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		local size = model:GetExtentsSize()
		local prevType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > 3.6 or not root.Parent or not model.Parent then
				conn:Disconnect()
				cam.CameraType = prevType
				return
			end
			local ang = t * 0.35 + 0.6
			local dist = math.max(size.Magnitude * 1.1, 30) * (1.15 - t * 0.06)
			local center = root.Position + Vector3.new(0, size.Y * 0.35, 0)
			local pos = center + Vector3.new(math.cos(ang) * dist, size.Y * 0.25 + 4, math.sin(ang) * dist)
			cam.CFrame = CFrame.lookAt(pos, center)
		end)
	end
	task.delay(4.2, function()
		letterbox(false)
		fadeTexts(f, 1, 1)
		task.wait(1.1)
		f:Destroy()
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
	local t = UIKit.Text(band, {
		Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 96, Text = "YOU PERISHED", TextColor3 = Color3.fromRGB(150, 16, 20), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 72,
	})
	local alive = d and d.Alive or 0
	local s = UIKit.Text(band, {
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
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 90 })
	UIKit.Tween(f, 2, { BackgroundTransparency = 0.15 })
	local t = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 0.3, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 80, Text = title, TextColor3 = color, TextTransparency = 1, ZIndex = 91,
	})
	UIKit.Tween(t, 2.5, { TextTransparency = 0 })
	for i, line in ipairs(lines) do
		local l = UIKit.Text(f, {
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.3, 110 + i * 34), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22,
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

function Cinematics.Handle(kind, d, menus, combat)
	if kind == "NightStart" then
		local color = d.BloodMoon and Color3.fromRGB(220, 40, 40) or (C.Element[d.Element] or C.Gold)
		local title = d.BloodMoon and "BLOOD MOON" or ("NIGHT " .. d.Night)
		local sub = (d.BloodMoon and ("คืนที่ " .. d.Night .. " · ") or "") .. (d.Title or "") .. " — " .. (ELEMENT_NIGHT_TEXT[d.Element] or "")
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
		Cinematics.BossIntro(d)
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
				"ลูกสัตว์ทั้ง 4 ธาตุกลับมาพร้อมหน้า", "คุณพิชิต 99 คืน — จบแบบสมบูรณ์", "💎 +300 เพชร", tail,
			}, Color3.fromRGB(255, 226, 150), 12)
		else
			Cinematics.FullScreen("99 NIGHTS CONQUERED", {
				"คุณพิชิต 99 คืนแห่งผืนป่า!", string.format("ลูกสัตว์ธาตุกลับมา %d/4 ตัว — ช่วยครบเพื่อฉากจบที่แท้จริง", d.Spirits or 0),
				"💎 +100 เพชร", tail,
			}, C.Gold, 12)
		end
	elseif kind == "Purchased" then
		if d.Kind == "Pack" then
			Cinematics.Banner("💎 +" .. tostring(d.Diamonds or 0), "เติม " .. (d.Name or "เพชร") .. " สำเร็จ — ขอบคุณที่สนับสนุน!", Color3.fromRGB(120, 230, 255), 3, { Size = 72, Y = 0.3 })
		else
			Cinematics.Banner("🎫 " .. (d.Name or "GAME PASS"), "ปลดล็อกแล้ว! ขอบคุณที่สนับสนุน", C.Gold, 3, { Size = 64, Y = 0.3 })
		end
	elseif kind == "SpiritFreed" then
		Cinematics.Banner("SPIRIT UNSEALED", (d.Player or "") .. " ปลดปล่อย " .. (d.Name or "") .. " — พากลับกองไฟ!", C.Element[d.Element] or C.Gold, 3.5, { Size = 56 })
	elseif kind == "SpiritRescued" then
		Cinematics.Banner("SPIRIT RETURNED", string.format("%s กลับบ้านแล้ว (%d/4) · บัฟ: %s", d.Name or "", d.Count or 0, d.Buff or ""), C.Element[d.Element] or C.Gold, 4.5, { Size = 60 })
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
	end
end

function Cinematics.Init(state)
	gui = UIKit.Screen("Cinematics", 40)
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

return Cinematics
