--[[
	LobbyService — ล็อบบี้แบบ 99 Nights in the Forest
	  ค่ายฟาร์มกลางป่ายามค่ำคืน: พื้นดิน + ทางเดินไม้กระดาน, รั้วไม้สูงรอบค่าย, โรงนา/กังหันลม/ต้นไม้ใบเหลี่ยมเป็นฉากหลัง
	  ทางเข้า (ใต้): ลานไม้จุดเกิด + ซุ้มประตูไม้ซุง "WILDHEART CAMP"
	  กลาง: เต็นท์ "Classes" (ร้านคลาส + เวทีโชว์หุ่นที่กล้องร้านคลาสเล็ง) + กระดานข่าว
	  ซ้าย: หม้อรางวัลประจำวัน (เพชรฟรี) + กระดานคนรอดนานสุด + แคมป์ไฟ
	  ขวา: แท่น "เริ่มเกม" เรืองแสง 4 แท่น — ขึ้นไปยืน เลือกขนาดทีม 1-5 คน -> คนครบ/หมดเวลา = ออกเดินทาง

	ออกเดินทาง:
	  - เกม publish แล้ว: ทั้งทีมถูกส่งไปเซิร์ฟเวอร์ส่วนตัวของทีม (TeleportService reserved server) เหมือนต้นฉบับ
	  - ใน Studio / เซิร์ฟเวอร์ของทีมเอง: ลงแมพในเซิร์ฟเวอร์นี้เลย
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shop = require(ReplicatedStorage.Shared.Shop)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)
local BaseDecor = require(ReplicatedStorage.Shared.BaseDecor)

local LobbyService = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

LobbyService.Position = V(12000, 1800, 12000) -- ไกลนอกแมพ: มองจากแคมป์ไม่เห็นภูเขา/เกาะลอยของล็อบบี้
local COUNTDOWN = 20
local COUNTDOWN_FULL = 5
local COUNTDOWN_JOIN = 4

function LobbyService:Init(ctx)
	self.ctx = ctx
	self.boxes = {}
	-- เซิร์ฟเวอร์ที่ถูกจองให้ทีม (มาจากล็อบบี้) = เริ่มเล่นเลย ไม่ต้องมีล็อบบี้
	self.IsTeamServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function P(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function cyl(parent, h, d, cf, color, mat)
	return P(parent, { Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = cf * ANG(0, 0, math.pi / 2), Color = color, Material = mat })
end

local function label(parent, face, text, color, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.PixelsPerStud = 30
	sg.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBlack
	t.TextColor3 = color or C(255, 224, 150)
	t.Parent = sg
	return t
end

local function sign(parent, text, cf, size, color)
	local board = P(parent, { Size = size or V(14, 4, 0.6), CFrame = cf, Color = C(60, 44, 32), Material = Enum.Material.Wood })
	local a = label(board, Enum.NormalId.Front, text, color)
	label(board, Enum.NormalId.Back, text, color)
	return board, a
end

local function prompt(parent, action, object, key, dist)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.MaxActivationDistance = dist or 14
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function mesh(kind, cf, parent, scale)
	if not MeshProps.Has(kind) then
		return nil
	end
	local m = MeshProps.Build(kind)
	if scale and scale ~= 1 then
		pcall(function()
			m:ScaleTo(scale)
		end)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- คนในเต็นท์คลาส (ที่ปรึกษาค่าย)
local function shopkeeper(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Counselor"
	local coat = C(70, 90, 60)
	local body = P(m, { Name = "Body", Size = V(2.4, 3.2, 1.6), CFrame = cf * CF(0, 3.6, 0), Color = coat, Material = Enum.Material.Fabric })
	P(m, { Shape = Enum.PartType.Ball, Size = V(1.8, 1.8, 1.8), CFrame = cf * CF(0, 6, 0), Color = C(224, 184, 150) })
	P(m, { Size = V(2.6, 0.4, 2.6), CFrame = cf * CF(0, 6.9, 0), Color = C(90, 60, 40), Material = Enum.Material.Fabric })
	P(m, { Size = V(1.6, 1.2, 1.6), CFrame = cf * CF(0, 7.4, 0), Color = C(90, 60, 40), Material = Enum.Material.Fabric })
	P(m, { Size = V(2.2, 0.5, 0.4), CFrame = cf * CF(0, 5.3, -0.9), Color = C(150, 120, 90), Material = Enum.Material.Fabric })
	for _, x in ipairs({ -0.6, 0.6 }) do
		P(m, { Size = V(0.8, 2, 0.8), CFrame = cf * CF(x, 1, 0), Color = C(60, 46, 36) })
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m, body
end

---------------------------------------------------------------- ชิ้นส่วนค่ายแบบ 99 Nights (ฟาร์ม/แคมป์ยามค่ำคืน)
local WOOD = { C(112, 80, 54), C(98, 70, 48), C(124, 90, 60), C(88, 62, 42) }
local LEAF = { C(44, 92, 52), C(52, 104, 56), C(38, 80, 48), C(60, 112, 60) }

local function light(part, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, shadows == true
	l.Parent = part
	return l
end

local function fireOn(part, size)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.3
	f.Parent = part
	return f
end

-- ทางเดินไม้กระดาน (แผ่นไม้วางขวางทาง เอียงนิดๆ สีไม่เท่ากัน)
local function boardwalk(parent, a, b, width, rng)
	local dir = (b - a)
	local len = dir.Magnitude
	local cf = CFrame.lookAt(a, b)
	local t = 0
	while t < len do
		local w = width + rng:NextNumber(-0.8, 0.8)
		P(parent, {
			Size = V(w, 0.4, rng:NextNumber(1.6, 2.2)),
			CFrame = cf * CF(rng:NextNumber(-0.4, 0.4), 0.2, -t) * ANG(0, math.rad(rng:NextNumber(-4, 4)), 0),
			Color = WOOD[rng:NextInteger(1, #WOOD)]:Lerp(C(60, 44, 32), rng:NextNumber(0, 0.3)), Material = Enum.Material.WoodPlanks,
		})
		t += rng:NextNumber(2.3, 2.7)
	end
end

-- ลานไม้ (ดาดฟ้า) สี่เหลี่ยม
local function deck(parent, cf, w, d, rng)
	for x = -w / 2 + 1, w / 2 - 1, 2.1 do
		P(parent, { Size = V(1.95, 0.5, d), CFrame = cf * CF(x, 0.25, rng:NextNumber(-0.3, 0.3)), Color = WOOD[rng:NextInteger(1, #WOOD)], Material = Enum.Material.WoodPlanks })
	end
	for _, z in ipairs({ -d / 2 + 0.6, d / 2 - 0.6 }) do
		P(parent, { Size = V(w + 0.6, 0.7, 1), CFrame = cf * CF(0, 0.35, z), Color = C(78, 56, 40), Material = Enum.Material.Wood })
	end
end

-- รั้วไม้กระดานสูง (แผ่นตั้ง + เสา + คาน)
local function plankFence(parent, a, b, h, rng)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b)
	local t = 0.6
	while t < len do
		local ph = h + rng:NextNumber(-0.8, 0.6)
		P(parent, { Size = V(0.4, ph, 1.35), CFrame = cf * CF(0, ph / 2, -t), Color = WOOD[rng:NextInteger(1, #WOOD)]:Lerp(C(50, 38, 30), rng:NextNumber(0, 0.25)), Material = Enum.Material.WoodPlanks })
		t += 1.45
	end
	for t2 = 0, len, 10 do
		P(parent, { Size = V(1.2, h + 1.2, 1.2), CFrame = cf * CF(0.7, (h + 1.2) / 2, -t2), Color = C(74, 52, 38), Material = Enum.Material.Wood })
	end
	for _, y in ipairs({ 2.5, h - 2 }) do
		P(parent, { Size = V(0.5, 0.7, len), CFrame = cf * CF(0.45, y, -len / 2), Color = C(80, 58, 40), Material = Enum.Material.Wood })
	end
	P(parent, { Name = "FenceBlock", Size = V(1, 40, len), CFrame = cf * CF(0, 20, -len / 2), Transparency = 1, CanQuery = false })
end

-- ต้นไม้ใบเหลี่ยม (สไตล์ 99 Nights)
local function blockyTree(parent, cf, s, rng)
	local m = Instance.new("Model")
	m.Name = "BlockTree"
	local th = rng:NextNumber(14, 22) * s
	P(m, { Size = V(2.6 * s, th, 2.6 * s), CFrame = cf * CF(0, th / 2, 0) * ANG(0, rng:NextNumber(0, 1.5), 0), Color = C(84, 60, 44), Material = Enum.Material.Wood })
	for i = 1, rng:NextInteger(3, 5) do
		local size = rng:NextNumber(9, 15) * s
		local off = V(rng:NextNumber(-4, 4) * s, th + rng:NextNumber(-2, 6) * s + (i == 1 and 2 * s or 0), rng:NextNumber(-4, 4) * s)
		P(m, {
			Size = V(size, size * rng:NextNumber(0.75, 1), size), CFrame = cf * CF(off) * ANG(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 1.5), rng:NextNumber(-0.15, 0.15)),
			Color = LEAF[rng:NextInteger(1, #LEAF)], Material = Enum.Material.Grass, CanCollide = false,
		})
	end
	m.Parent = parent
	return m
end

-- เสาตะเกียง
local function lanternPost(parent, cf, h)
	h = h or 8
	P(parent, { Size = V(0.8, h, 0.8), CFrame = cf * CF(0, h / 2, 0), Color = C(70, 50, 36), Material = Enum.Material.Wood })
	P(parent, { Size = V(0.4, 0.4, 2.2), CFrame = cf * CF(0, h - 0.4, -0.9), Color = C(70, 50, 36), Material = Enum.Material.Wood })
	local lamp = P(parent, { Size = V(1, 1.3, 1), CFrame = cf * CF(0, h - 1.5, -1.8), Color = C(255, 206, 130), Material = Enum.Material.Neon, CanCollide = false })
	P(parent, { Size = V(1.3, 0.2, 1.3), CFrame = cf * CF(0, h - 0.75, -1.8), Color = C(40, 36, 34), Material = Enum.Material.Metal, CanCollide = false })
	light(lamp, C(255, 186, 110), 22, 1.8)
	return lamp
end

-- ตอไม้มีไฟลุก (แบบหน้าเต็นท์ Classes)
local function fireStump(parent, cf, brightness, range)
	cyl(parent, 3, 3.4, cf * CF(0, 1.5, 0), C(120, 86, 58), Enum.Material.Wood)
	P(parent, { Shape = Enum.PartType.Cylinder, Size = V(0.1, 3, 3), CFrame = cf * CF(0, 3.02, 0) * ANG(0, 0, math.pi / 2), Color = C(70, 50, 36), Material = Enum.Material.Wood })
	local core = P(parent, { Size = V(1, 1, 1), CFrame = cf * CF(0, 3.6, 0), Transparency = 1, CanCollide = false })
	fireOn(core, 4)
	light(core, C(255, 150, 70), range or 26, brightness or 2.4, true)
end

-- กองฟาง
local function hayBale(parent, cf)
	P(parent, { Size = V(5, 3, 3), CFrame = cf * CF(0, 1.5, 0), Color = C(214, 180, 90), Material = Enum.Material.Fabric })
	for _, x in ipairs({ -1.2, 1.2 }) do
		P(parent, { Size = V(0.2, 3.05, 3.05), CFrame = cf * CF(x, 1.5, 0), Color = C(140, 104, 50), Material = Enum.Material.Fabric })
	end
end

local function crate(parent, cf, s)
	s = s or 3
	P(parent, { Size = V(s, s, s), CFrame = cf * CF(0, s / 2, 0), Color = C(150, 110, 70), Material = Enum.Material.WoodPlanks })
	P(parent, { Size = V(s * 1.42, 0.3, 0.32), CFrame = cf * CF(0, s / 2, -s / 2 - 0.05) * ANG(0, 0, math.rad(45)), Color = C(110, 78, 50), Material = Enum.Material.Wood })
end

-- โรงนา + กังหันลม (ฉากหลังหลังรั้ว)
local function barn(parent, cf)
	local red, trim = C(140, 52, 44), C(226, 220, 206)
	local w, d, h = 34, 28, 14
	P(parent, { Size = V(w, h, d), CFrame = cf * CF(0, h / 2, 0), Color = red, Material = Enum.Material.WoodPlanks })
	-- หลังคาจั่ว gambrel (สองช่วง)
	for _, s in ipairs({ -1, 1 }) do
		P(parent, { Size = V(10.5, 0.8, d + 2), CFrame = cf * CF(s * 13.2, h + 3.6, 0) * ANG(0, 0, s * -math.rad(58)), Color = C(70, 64, 62), Material = Enum.Material.Slate })
		P(parent, { Size = V(10.5, 0.8, d + 2), CFrame = cf * CF(s * 4.6, h + 9.3, 0) * ANG(0, 0, s * -math.rad(20)), Color = C(70, 64, 62), Material = Enum.Material.Slate })
	end
	for _, z in ipairs({ -d / 2, d / 2 }) do
		P(parent, { Size = V(w - 8, 9, 0.6), CFrame = cf * CF(0, h + 4.5, z), Color = red, Material = Enum.Material.WoodPlanks })
	end
	-- ประตูกากบาทขาว
	local door = cf * CF(0, 5.5, -d / 2 - 0.35)
	P(parent, { Size = V(12, 11, 0.4), CFrame = door, Color = C(120, 44, 38), Material = Enum.Material.WoodPlanks })
	for _, r in ipairs({ math.rad(42), -math.rad(42) }) do
		P(parent, { Size = V(16, 0.8, 0.3), CFrame = door * CF(0, 0, -0.3) * ANG(0, 0, r), Color = trim, Material = Enum.Material.Wood })
	end
	P(parent, { Size = V(12.6, 0.8, 0.3), CFrame = door * CF(0, 5.6, -0.3), Color = trim, Material = Enum.Material.Wood })
	P(parent, { Size = V(12.6, 0.8, 0.3), CFrame = door * CF(0, -5.4, -0.3), Color = trim, Material = Enum.Material.Wood })
	local loft = P(parent, { Size = V(5, 4, 0.3), CFrame = cf * CF(0, h + 3.2, -d / 2 - 0.4), Color = C(255, 200, 120), Material = Enum.Material.Neon })
	light(loft, C(255, 190, 110), 26, 1.6)
end

local function windmill(parent, cf)
	local h = 38
	local iron = C(96, 96, 104)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local bottom = (cf * CF(x * 5, 0, z * 5)).Position
			local top = (cf * CF(x * 1.2, h, z * 1.2)).Position
			P(parent, { Size = V(0.6, 0.6, (top - bottom).Magnitude), CFrame = CFrame.lookAt((top + bottom) / 2, top), Color = iron, Material = Enum.Material.Metal })
		end
	end
	for k = 1, 4 do
		local y = k * h / 5
		local r = 5 - (5 - 1.2) * (y / h)
		for i = 0, 3 do
			P(parent, { Size = V(r * 2, 0.35, 0.35), CFrame = cf * CF(0, y, 0) * ANG(0, i * math.pi / 2, 0) * CF(0, 0, r), Color = iron, Material = Enum.Material.Metal })
		end
	end
	P(parent, { Size = V(3, 2.4, 4), CFrame = cf * CF(0, h + 1, 0), Color = C(70, 70, 76), Material = Enum.Material.Metal })
	P(parent, { ClassName = "WedgePart", Size = V(0.3, 4, 6), CFrame = cf * CF(0, h + 2.5, 4.5), Color = C(150, 60, 50), Material = Enum.Material.Metal })
	-- ใบพัด (หมุนด้วย Heartbeat)
	local hub = P(parent, { Name = "WindmillHub", Shape = Enum.PartType.Cylinder, Size = V(1.2, 2.4, 2.4), CFrame = cf * CF(0, h + 1, -2.6) * ANG(0, math.pi / 2, 0), Color = C(60, 60, 66), Material = Enum.Material.Metal })
	local blades = {}
	for i = 0, 11 do
		table.insert(blades, P(parent, { Size = V(1.6, 9, 0.2), Color = C(196, 196, 204), Material = Enum.Material.Metal, CanCollide = false }))
	end
	local center = (cf * CF(0, h + 1, -3.4))
	task.spawn(function()
		local a = 0
		while hub.Parent do
			a += RunService.Heartbeat:Wait() * 0.8
			for i, bl in ipairs(blades) do
				local ang = a + (i - 1) / #blades * math.pi * 2
				bl.CFrame = center * ANG(0, 0, ang) * CF(0, 5.3, 0) * ANG(0, 0.35, 0)
			end
		end
	end)
end

-- เต็นท์ Classes (ผ้าใบสีเขียวขี้ม้า หน้าเปิด) + เวทีโชว์หุ่น
local function classesTent(self, parent, cf)
	local W, D, H, E = 40, 32, 22, 9
	local canvas, canvasDark = C(134, 130, 70), C(108, 104, 56)
	local rng = Random.new(77)
	-- พื้นไม้ในเต็นท์
	deck(parent, cf * CF(0, 1, 0), W - 2, D - 2, rng)
	-- หลังคาสองฝั่ง
	local slope = math.atan2(H - E, W / 2)
	local slen = math.sqrt((H - E) ^ 2 + (W / 2) ^ 2)
	for _, s in ipairs({ -1, 1 }) do
		P(parent, { Size = V(slen + 1.5, 0.4, D + 3), CFrame = cf * CF(s * W / 4, (H + E) / 2 + 1, 0) * ANG(0, 0, -s * slope), Color = canvas, Material = Enum.Material.Fabric })
		-- ชายผ้าห้อยด้านหน้า
		P(parent, { Size = V(slen + 1.5, 1.6, 0.2), CFrame = cf * CF(s * W / 4, (H + E) / 2 + 0.2, -D / 2 - 1.5) * ANG(0, 0, -s * slope), Color = canvasDark, Material = Enum.Material.Fabric })
		-- ผนังข้าง
		P(parent, { Size = V(0.4, E, D), CFrame = cf * CF(s * W / 2, E / 2 + 1, 0), Color = canvasDark, Material = Enum.Material.Fabric })
	end
	-- ผนังหลัง + จั่ว
	P(parent, { Size = V(W, E, 0.4), CFrame = cf * CF(0, E / 2 + 1, D / 2), Color = canvasDark, Material = Enum.Material.Fabric })
	for _, s in ipairs({ -1, 1 }) do
		P(parent, { ClassName = "WedgePart", Size = V(0.4, H - E, W / 2), CFrame = cf * CF(s * W / 4, E + 1 + (H - E) / 2, D / 2) * ANG(0, s * -math.pi / 2, 0), Color = canvasDark, Material = Enum.Material.Fabric })
	end
	-- เสา + คานสัน
	for _, x in ipairs({ -W / 2, 0, W / 2 }) do
		local ph = (x == 0) and H + 1 or E + 1
		P(parent, { Size = V(0.9, ph, 0.9), CFrame = cf * CF(x, ph / 2, -D / 2 - 0.5), Color = C(84, 62, 44), Material = Enum.Material.Wood })
	end
	P(parent, { Size = V(0.8, 0.8, D + 4), CFrame = cf * CF(0, H + 1.4, 0), Color = C(84, 62, 44), Material = Enum.Material.Wood })
	-- เชือกยึด + หมุด
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -D / 2, 0, D / 2 }) do
			local a = (cf * CF(s * W / 2, E + 1, z)).Position
			local b = (cf * CF(s * (W / 2 + 7), 1, z)).Position
			P(parent, { Size = V(0.12, 0.12, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = C(214, 204, 170), CanCollide = false, CanQuery = false })
			P(parent, { Size = V(0.5, 1.2, 0.5), CFrame = CF(b + V(0, 0.4, 0)), Color = C(84, 62, 44), Material = Enum.Material.Wood })
		end
	end
	-- ป้าย "Classes" ไฟนีออนเขียว
	local signCf = cf * CF(0, 15.5, -D / 2 - 1.8)
	for _, x in ipairs({ -6, 6 }) do
		P(parent, { Size = V(0.15, 4.5, 0.15), CFrame = signCf * CF(x, 4.2, 0), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	end
	local board = P(parent, { Size = V(17, 5.6, 0.6), CFrame = signCf, Color = C(80, 52, 34), Material = Enum.Material.WoodPlanks })
	P(parent, { Size = V(17.8, 6.4, 0.4), CFrame = signCf * CF(0, 0, 0.2), Color = C(56, 38, 26), Material = Enum.Material.Wood })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		sg.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 0.72)
		t.BackgroundTransparency = 1
		t.Text = "Classes"
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = C(110, 255, 110)
		t.Parent = sg
		local st = Instance.new("UIStroke")
		st.Color, st.Thickness, st.Parent = C(20, 60, 20), 4, t
		local t2 = Instance.new("TextLabel")
		t2.Size = UDim2.fromScale(1, 0.26)
		t2.Position = UDim2.fromScale(0, 0.72)
		t2.BackgroundTransparency = 1
		t2.Text = "ร้านคลาส · เดินเข้าไปคุยได้เลย"
		t2.TextScaled = true
		t2.Font = Enum.Font.GothamBold
		t2.TextColor3 = C(255, 236, 190)
		t2.Parent = sg
	end
	light(board, C(120, 255, 120), 16, 1.2)
	-- ไฟหน้าเต็นท์ (ตอไม้มีไฟ)
	fireStump(parent, cf * CF(-W / 2 + 3, 1, -D / 2 - 5))
	fireStump(parent, cf * CF(W / 2 - 3, 1, -D / 2 - 5))
	-- ภายใน: เคาน์เตอร์ + คนดูแลคลาส + ไวท์บอร์ด + ลังไม้ + โคมแขวน
	local counterCf = cf * CF(-11, 1.5, -6)
	P(parent, { Size = V(10, 3.2, 3), CFrame = counterCf * CF(0, 1.6, 0), Color = C(110, 78, 50), Material = Enum.Material.WoodPlanks })
	P(parent, { Size = V(10.6, 0.4, 3.6), CFrame = counterCf * CF(0, 3.3, 0), Color = C(140, 100, 64), Material = Enum.Material.WoodPlanks })
	local keeper, kbody = shopkeeper(parent, counterCf * CF(0, 0, 3.2) * ANG(0, math.pi, 0))
	-- ใช้ตัวละคร Roblox จริง (เจ้าหน้าที่อุทยาน) แทนหุ่นบล็อก
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local chars = assets and assets:FindFirstChild("Characters")
	local src = chars and chars:FindFirstChild("Scout")
	if src then
		local npc = src:Clone()
		npc.Name = "CounselorModel"
		local mn, mx
		for _, d in ipairs(npc:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				if d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
					mn = mn and mn:Min(d.Position - d.Size / 2) or d.Position - d.Size / 2
					mx = mx and mx:Max(d.Position + d.Size / 2) or d.Position + d.Size / 2
				end
			end
		end
		local face = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
		local look = face.CFrame.LookVector * Vector3.new(1, 0, 1)
		local foot = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
		npc.PrimaryPart = face
		face.PivotOffset = face.CFrame:ToObjectSpace(CFrame.lookAt(foot, foot + look.Unit))
		npc:PivotTo(counterCf * CF(0, 0, 3.2) * ANG(0, math.pi, 0))
		npc.Parent = parent
		for _, d in ipairs(keeper:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
			end
		end
	end
	prompt(kbody, "ดูคลาส", "ที่ปรึกษาค่าย", Enum.KeyCode.E, 18).Triggered:Connect(function(p)
		self.ctx.Remotes.Get("Cinematic"):FireClient(p, "OpenClasses", {})
	end)
	prompt(board, "ร้านคลาส", "Classes", Enum.KeyCode.E, 30).Triggered:Connect(function(p)
		self.ctx.Remotes.Get("Cinematic"):FireClient(p, "OpenClasses", {})
	end)
	-- ไวท์บอร์ดบนขาตั้ง (หลังเวที ซ้าย)
	local wbCf = cf * CF(-9, 1.5, D / 2 - 4) * ANG(0, math.rad(15), 0)
	local wb = P(parent, { Size = V(9, 5.5, 0.3), CFrame = wbCf * CF(0, 6, 0), Color = C(196, 192, 200), Material = Enum.Material.SmoothPlastic })
	for _, x in ipairs({ -3.5, 3.5 }) do
		P(parent, { Size = V(0.3, 8, 0.3), CFrame = wbCf * CF(x, 4, 0.4) * ANG(math.rad(8), 0, 0), Color = C(200, 200, 206), Material = Enum.Material.Metal })
	end
	label(wb, Enum.NormalId.Front, "แผนวันนี้:\n1. เลือกคลาส\n2. ขึ้นแท่นเริ่มเกม\n3. รอด 99 คืน!", C(40, 60, 160), Enum.Font.GothamBold)
	-- ตอไม้มีไฟ (หลังเวที ขวา) + ลังไม้
	fireStump(parent, cf * CF(10, 1.5, D / 2 - 4), 0.7, 14) -- ไฟอ่อนๆ ไม่ให้หน้าตัวละครบนเวทีสว่างจ้า
	crate(parent, cf * CF(16, 1.5, D / 2 - 3))
	crate(parent, cf * CF(16.5, 4.5, D / 2 - 3) * ANG(0, 0.5, 0), 2.4)
	crate(parent, cf * CF(-16, 1.5, -10) * ANG(0, 0.3, 0))
	for _, z in ipairs({ -8, 6 }) do
		local lamp = P(parent, { Size = V(1.2, 1.6, 1.2), CFrame = cf * CF(0, H - 4, z), Color = C(255, 214, 150), Material = Enum.Material.Neon, CanCollide = false })
		P(parent, { Size = V(0.1, 4, 0.1), CFrame = cf * CF(0, H - 1.6, z), Color = C(40, 36, 34), CanCollide = false })
		light(lamp, C(255, 196, 130), 24, 0.8, true)
	end
	-- เวทีโชว์หุ่นคลาส (กล้องร้านคลาสเล็งมาที่นี่) หันหน้าเข้าหาทางเข้าเต็นท์
	local stageCf = cf * CF(0, 1.5, D / 2 - 7)
	cyl(parent, 1.2, 8, stageCf * CF(0, 0.6, 0), C(120, 84, 56), Enum.Material.WoodPlanks)
	cyl(parent, 0.5, 9, stageCf * CF(0, 0.25, 0), C(84, 60, 42), Enum.Material.Wood)
	P(parent, { Name = "ClassStage", Size = V(6, 0.2, 6), CFrame = stageCf * CF(0, 1.1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local spot = P(parent, { Size = V(0.6, 0.6, 0.6), CFrame = stageCf * CF(0, 13, -6), Transparency = 1, CanCollide = false })
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Angle = 50
	sl.Range = 24
	sl.Brightness = 0.25
	sl.Color = C(255, 236, 210)
	sl.Parent = spot
end

-- หม้อรางวัลประจำวัน (หม้อดำ น้ำเขียวเรืองแสง)
local function dailyCauldron(self, parent, cf)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		P(parent, { Size = V(0.6, 3, 0.6), CFrame = cf * CF(math.cos(a) * 3, 1.4, math.sin(a) * 3) * ANG(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), Color = C(30, 30, 34), Material = Enum.Material.Metal })
	end
	local pot = cyl(parent, 4, 7.5, cf * CF(0, 4, 0), C(32, 32, 36), Enum.Material.Metal)
	P(parent, { Shape = Enum.PartType.Ball, Size = V(7.8, 4, 7.8), CFrame = cf * CF(0, 2.6, 0), Color = C(32, 32, 36), Material = Enum.Material.Metal })
	cyl(parent, 0.6, 8.2, cf * CF(0, 6, 0), C(46, 46, 52), Enum.Material.Metal)
	local liquid = P(parent, { Shape = Enum.PartType.Cylinder, Size = V(0.3, 7, 7), CFrame = cf * CF(0, 5.9, 0) * ANG(0, 0, math.pi / 2), Color = C(90, 255, 110), Material = Enum.Material.Neon, CanCollide = false })
	light(liquid, C(90, 255, 120), 22, 2.6)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Rate = 14
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.SpreadAngle = Vector2.new(20, 20)
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new(0.6, 0)
	bubbles.Color = ColorSequence.new(C(150, 255, 150))
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = liquid
	-- ไฟใต้หม้อ
	local under = P(parent, { Size = V(1, 1, 1), CFrame = cf * CF(0, 0.6, 0), Transparency = 1, CanCollide = false })
	fireOn(under, 3)
	for i = 0, 3 do
		cyl(parent, 4, 0.8, cf * CF(0, 0.5, 0) * ANG(0, i * math.pi / 4, 0) * ANG(0, 0, -math.pi / 2), C(90, 64, 44), Enum.Material.Wood)
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(15, 4.4)
	bb.StudsOffset = V(0, 9, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Parent = pot
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.6)
	t.BackgroundTransparency = 1
	t.Text = "รางวัลประจำวัน 💎"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(130, 255, 120)
	t.Parent = bb
	local s1 = Instance.new("UIStroke")
	s1.Thickness, s1.Parent = 2.5, t
	local t2 = Instance.new("TextLabel")
	t2.Size = UDim2.fromScale(1, 0.38)
	t2.Position = UDim2.fromScale(0, 0.62)
	t2.BackgroundTransparency = 1
	t2.Text = "- รับเพชรฟรีทุกวัน -"
	t2.TextScaled = true
	t2.Font = Enum.Font.GothamBold
	t2.TextColor3 = C(255, 255, 255)
	t2.Parent = bb
	local s2 = Instance.new("UIStroke")
	s2.Thickness, s2.Parent = 2, t2
	prompt(pot, "รับรางวัลประจำวัน", "หม้อวิเศษ", Enum.KeyCode.E, 14).Triggered:Connect(function(p)
		self.ctx.Services.DataService:ClaimDaily(p)
	end)
end

-- แท่น "เริ่มเกม" (พื้นเรืองแสงขาว) + ป้ายลอย 0/5
local function startPad(self, parent, cf, i)
	local rng = Random.new(100 + i)
	-- กรอบไม้
	for _, e in ipairs({ { V(0, 0, -9), V(19.5, 0.8, 1.4) }, { V(0, 0, 9), V(19.5, 0.8, 1.4) }, { V(-9, 0, 0), V(1.4, 0.8, 19.5) }, { V(9, 0, 0), V(1.4, 0.8, 19.5) } }) do
		P(parent, { Size = e[2], CFrame = cf * CF(e[1] + V(0, 0.4, 0)), Color = WOOD[rng:NextInteger(1, #WOOD)], Material = Enum.Material.WoodPlanks })
	end
	local pad = P(parent, { Name = "StartPad" .. i, Size = V(16.4, 0.3, 16.4), CFrame = cf * CF(0, 0.25, 0), Color = C(200, 214, 245), Material = Enum.Material.Neon, Transparency = 0.5 })
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Top
	glow.Range = 14
	glow.Brightness = 0.7
	glow.Angle = 120
	glow.Color = C(200, 220, 255)
	glow.Parent = pad
	local edges = {}
	for _, e in ipairs({ { V(0, 0, -8.1), V(16.4, 0.12, 0.35) }, { V(0, 0, 8.1), V(16.4, 0.12, 0.35) }, { V(-8.1, 0, 0), V(0.35, 0.12, 16.4) }, { V(8.1, 0, 0), V(0.35, 0.12, 16.4) } }) do
		table.insert(edges, P(parent, { Size = e[2], CFrame = cf * CF(e[1] + V(0, 0.45, 0)), Color = C(230, 236, 255), Material = Enum.Material.Neon, CanCollide = false }))
	end
	-- ป้ายลอย
	local anchor = P(parent, { Size = V(1, 1, 1), CFrame = cf * CF(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(13, 7.5) -- ขนาดเป็น stud: ไกลแล้วเล็กลง ไม่ทับกัน
	bb.StudsOffset = V(0, 10, 0)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Parent = anchor
	local function line(y, h, txt, color, font)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, h)
		t.BackgroundTransparency = 1
		t.Text = txt
		t.TextScaled = true
		t.Font = font or Enum.Font.GothamBlack
		t.TextColor3 = color
		t.Parent = bb
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Parent = t
		return t
	end
	line(0, 0.3, "เริ่มเกม", C(130, 255, 120))
	local count = line(0.3, 0.42, "0/5", C(255, 255, 255))
	local sub = line(0.74, 0.24, "", C(230, 230, 240), Enum.Font.GothamBold)
	-- เสาป้ายเปลี่ยนขนาดทีม (หลังแท่น)
	local post = cf * CF(0, 0, 10.5)
	P(parent, { Size = V(0.8, 6, 0.8), CFrame = post * CF(0, 3, 0), Color = C(74, 52, 38), Material = Enum.Material.Wood })
	local plate = P(parent, { Size = V(6, 2.4, 0.4), CFrame = post * CF(0, 5.6, 0), Color = C(96, 68, 46), Material = Enum.Material.WoodPlanks })
	label(plate, Enum.NormalId.Front, "ขนาดทีม [F]", C(255, 230, 170), Enum.Font.GothamBold)
	label(plate, Enum.NormalId.Back, "ขนาดทีม [F]", C(255, 230, 170), Enum.Font.GothamBold)
	local go = light(pad, C(120, 255, 140), 24, 2.5)
	go.Enabled = false
	local zone = P(parent, { Name = "MatchBox" .. i, Size = V(16, 12, 16), CFrame = cf * CF(0, 6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local box = { Index = i, Zone = zone, Size = 5, Text = count, Sub = sub, Countdown = nil, Pad = pad, Runes = edges, Pillar = go }
	prompt(plate, "เปลี่ยนขนาดทีม", "แท่นเริ่มเกม " .. i, Enum.KeyCode.F, 22).Triggered:Connect(function(p)
		if box.Members and box.Members[p] then
			box.Size = box.Size % 5 + 1
			box.Countdown = nil
		else
			self.ctx.Notify(p, "ขึ้นไปยืนบนแท่นก่อน แล้วค่อยเปลี่ยนขนาดทีม", "Info")
		end
	end)
	return box
end

---------------------------------------------------------------- สร้างล็อบบี้: ค่ายฟาร์มกลางป่ายามค่ำคืน (แบบ 99 Nights)
function LobbyService:Build()
	local old = Workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Lobby"
	local base = CF(self.Position)
	m.WorldPivot = base
	local rng = Random.new(2024)
	-- พื้นดิน + หินใต้เกาะ
	cyl(m, 8, 560, base * CF(0, -4, 0), C(78, 62, 48), Enum.Material.Ground)
	cyl(m, 1, 556, base * CF(0, 0.5, 0), C(96, 76, 56), Enum.Material.Ground)
	for i = 1, 5 do
		cyl(m, 16, 560 - i * 90, base * CF(0, -8 - i * 14, 0), C(60 - i * 5, 56 - i * 5, 56 - i * 5), Enum.Material.Rock)
	end
	-- หย่อมหญ้าเขียวรอบลาน
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, 120)
		local d = rng:NextNumber(14, 30)
		P(m, { Shape = Enum.PartType.Cylinder, Size = V(0.3, d, d), CFrame = base * CF(math.cos(a) * r, 1.05, math.sin(a) * r) * ANG(0, 0, math.pi / 2), Color = C(62, 104, 56):Lerp(C(80, 120, 60), rng:NextNumber()), Material = Enum.Material.Grass, CanCollide = false })
	end

	local FX, FZ0, FZ1 = 120, -112, 104 -- ขอบรั้ว
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = m

	------------------------------------------------ ทางเข้า: ลานไม้จุดเกิด + ซุ้มประตูไม้ซุง
	deck(deco, base * CF(0, 1, 86), 50, 26, rng)
	local archCf = base * CF(0, 1, FZ1)
	for _, x in ipairs({ -12, 12 }) do
		cyl(deco, 20, 2.6, archCf * CF(x, 10, 0), C(104, 74, 50), Enum.Material.Wood)
		cyl(deco, 2.5, 3.8, archCf * CF(x, 1.2, 0), C(100, 96, 92), Enum.Material.Cobblestone)
	end
	P(deco, { Shape = Enum.PartType.Cylinder, Size = V(30, 2.4, 2.4), CFrame = archCf * CF(0, 19.5, 0), Color = C(104, 74, 50), Material = Enum.Material.Wood })
	P(deco, { Shape = Enum.PartType.Cylinder, Size = V(27, 1.6, 1.6), CFrame = archCf * CF(0, 16.8, 0), Color = C(92, 66, 44), Material = Enum.Material.Wood })
	local campSign = P(deco, { Size = V(20, 4.2, 0.6), CFrame = archCf * CF(0, 13.4, 0), Color = C(76, 52, 34), Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -8, 8 }) do
		P(deco, { Size = V(0.15, 2.4, 0.15), CFrame = archCf * CF(x, 15.6, 0), Color = C(40, 36, 34) })
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local t = label(campSign, face, "WILDHEART CAMP", C(255, 214, 120), Enum.Font.FredokaOne)
		local st = Instance.new("UIStroke")
		st.Color, st.Thickness, st.Parent = C(40, 24, 10), 3, t
	end
	for _, x in ipairs({ -6, 6 }) do
		local l = P(deco, { Size = V(1.1, 1.5, 1.1), CFrame = archCf * CF(x, 10.8, 0), Color = C(255, 206, 130), Material = Enum.Material.Neon, CanCollide = false })
		P(deco, { Size = V(0.1, 5, 0.1), CFrame = archCf * CF(x, 14, 0), Color = C(40, 36, 34), CanCollide = false })
		light(l, C(255, 186, 110), 26, 2, true)
	end
	for _, x in ipairs({ -20, 20 }) do
		fireStump(deco, base * CF(x, 1, FZ1 - 4))
	end
	-- ทางนอกซุ้มหายเข้าป่ามืด (ปิดด้วยกำแพงล่องหน)
	boardwalk(deco, (base * CF(0, 1, FZ1 + 2)).Position, (base * CF(0, 1, FZ1 + 34)).Position, 9, rng)
	P(m, { Name = "GateBlock", Size = V(30, 40, 1), CFrame = base * CF(0, 20, FZ1 + 6), Transparency = 1, CanQuery = false })

	------------------------------------------------ ทางเดินไม้
	boardwalk(deco, (base * CF(0, 1, 72)).Position, (base * CF(0, 1, -30)).Position, 10, rng)
	boardwalk(deco, (base * CF(-86, 1, 44)).Position, (base * CF(92, 1, 44)).Position, 8, rng)
	boardwalk(deco, (base * CF(71, 1, 44)).Position, (base * CF(71, 1, -24)).Position, 8, rng)
	boardwalk(deco, (base * CF(-42, 1, 44)).Position, (base * CF(-42, 1, -8)).Position, 8, rng)
	for z = 60, -16, -19 do
		lanternPost(deco, base * CF(-8, 1, z) * ANG(0, math.rad(-90), 0), 8)
		lanternPost(deco, base * CF(8, 1, z) * ANG(0, math.rad(90), 0), 8)
	end
	for _, x in ipairs({ -70, -24, 30, 92 }) do
		lanternPost(deco, base * CF(x, 1, 51) * ANG(0, 0, 0), 8)
	end

	------------------------------------------------ กลาง: เต็นท์ Classes
	classesTent(self, deco, base * CF(0, 0, -54) * ANG(0, math.pi, 0)) -- หน้าเต็นท์หันมาทางจุดเกิด

	-- กระดานข่าว (ขวาของเต็นท์)
	local nbCf = base * CF(30, 1, -30) * ANG(0, math.rad(-18), 0)
	for _, x in ipairs({ -4, 4 }) do
		P(deco, { Size = V(0.9, 12, 0.9), CFrame = nbCf * CF(x, 6, 0), Color = C(74, 52, 38), Material = Enum.Material.Wood })
	end
	local nb = P(deco, { Size = V(9.5, 8, 0.5), CFrame = nbCf * CF(0, 7.6, 0), Color = C(150, 96, 56), Material = Enum.Material.WoodPlanks })
	P(deco, { ClassName = "WedgePart", Size = V(11, 1.5, 2), CFrame = nbCf * CF(0, 12.4, 0), Color = C(90, 60, 40), Material = Enum.Material.Wood })
	local nbg = Instance.new("SurfaceGui")
	nbg.Face = Enum.NormalId.Front
	nbg.PixelsPerStud = 36
	nbg.Parent = nb
	local nt = Instance.new("TextLabel")
	nt.Size = UDim2.fromScale(0.9, 0.9)
	nt.Position = UDim2.fromScale(0.05, 0.05)
	nt.BackgroundTransparency = 1
	nt.RichText = true
	nt.TextScaled = true
	nt.TextWrapped = true
	nt.Font = Enum.Font.GothamBold
	nt.TextColor3 = C(255, 240, 200)
	nt.Text = '<font color="#FFE066">กระดานข่าวค่าย</font>\n\nรอดคืนที่ 5·10·25·50·99\n= รับเพชร 💎\n\nช่วยลูกสัตว์ธาตุ = 💎15\n<font color="#8CFF8C">รับเพชรฟรีที่หม้อเขียวทุกวัน!</font>'
	nt.Parent = nbg
	local nlamp = P(deco, { Size = V(0.9, 0.9, 0.9), CFrame = nbCf * CF(0, 12, -1.6), Color = C(255, 214, 150), Material = Enum.Material.Neon, CanCollide = false })
	light(nlamp, C(255, 196, 130), 14, 1.6)

	------------------------------------------------ ซ้าย: หม้อรางวัลประจำวัน + กระดานผู้รอดนานสุด + แคมป์ไฟ
	dailyCauldron(self, deco, base * CF(-42, 1, -16))
	local boardCf = base * CF(-88, 1, 6) * ANG(0, math.rad(90), 0)
	local board = P(deco, { Size = V(16, 10, 0.8), CFrame = boardCf * CF(0, 7.5, 0), Color = C(44, 34, 30), Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -7.5, 7.5 }) do
		P(deco, { Size = V(1, 13, 1), CFrame = boardCf * CF(x, 6.5, 0.7), Color = C(80, 56, 38), Material = Enum.Material.Wood })
	end
	P(deco, { ClassName = "WedgePart", Size = V(18, 1.8, 2.4), CFrame = boardCf * CF(0, 13.4, 0), Color = C(90, 60, 40), Material = Enum.Material.Wood })
	self.boardLabel = label(board, Enum.NormalId.Back, "🏆 ผู้รอดนานสุด", C(255, 230, 170), Enum.Font.GothamBold)
	label(board, Enum.NormalId.Front, "🏆 ผู้รอดนานสุด", C(255, 230, 170), Enum.Font.GothamBold)
	lanternPost(deco, boardCf * CF(-10, 0, -2), 9)
	-- แคมป์ไฟเล็ก + ม้านั่งท่อนซุง + เต็นท์นอน
	local fcf = base * CF(-62, 1, 74)
	local ring = mesh("Campfire", fcf, deco)
	if ring then
		ring.Name = "LobbyFireRing"
	end
	local core = P(deco, { Name = "LobbyFire", Size = V(2, 2, 2), CFrame = fcf * CF(0, 2, 0), Transparency = 1, CanCollide = false })
	fireOn(core, 7)
	light(core, C(255, 150, 70), 40, 2.8, true)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.5
		cyl(deco, 7, 1.8, fcf * CF(math.cos(a) * 8, 0.9, math.sin(a) * 8) * ANG(0, -a + math.pi / 2, 0) * ANG(0, 0, -math.pi / 2), C(104, 74, 50), Enum.Material.Wood)
	end
	BaseDecor.CanvasTent(deco, base * CF(-90, 1, 78) * ANG(0, math.rad(-70), 0), C(70, 104, 150))
	BaseDecor.CanvasTent(deco, base * CF(-80, 1, 96) * ANG(0, math.rad(-130), 0), C(196, 110, 52))

	------------------------------------------------ ขวา: แท่นเริ่มเกม 4 แท่น
	self.boxes = {}
	for i, pos in ipairs({ V(56, 1, -8), V(86, 1, -8), V(56, 1, 20), V(86, 1, 20) }) do
		table.insert(self.boxes, startPad(self, deco, base * CF(pos), i))
	end
	local startSign = P(deco, { Size = V(14, 3.4, 0.5), CFrame = base * CF(71, 7.5, 50) * ANG(0, math.pi, 0), Color = C(76, 52, 34), Material = Enum.Material.WoodPlanks })
	label(startSign, Enum.NormalId.Front, "⚔ เริ่มเกม →", C(130, 255, 120), Enum.Font.GothamBlack)
	label(startSign, Enum.NormalId.Back, "⚔ เริ่มเกม", C(130, 255, 120), Enum.Font.GothamBlack)
	for _, x in ipairs({ -6, 6 }) do
		P(deco, { Size = V(0.8, 7, 0.8), CFrame = base * CF(71 + x, 4.5, 50.4), Color = C(74, 52, 38), Material = Enum.Material.Wood })
	end

	------------------------------------------------ ของตกแต่ง: ฟาง ลังไม้ โต๊ะปิกนิก
	for _, info in ipairs({ { 96, -92, 0.2 }, { 102, -84, 1.4 }, { 98, -88, 0.9, true }, { -100, -90, 0.6 }, { -94, -96, 2 } }) do
		hayBale(deco, base * CF(info[1], info[3] and 4 or 1, info[2]) * ANG(0, info[3] or 0, 0))
	end
	for _, info in ipairs({ { 24, -40 }, { 27, -44 }, { -26, -40 }, { 40, 60 }, { -102, 30 } }) do
		crate(deco, base * CF(info[1], 1, info[2]) * ANG(0, rng:NextNumber(0, 1), 0))
	end
	for _, pcf in ipairs({ base * CF(30, 1, 72), base * CF(44, 1, 84) * ANG(0, 0.5, 0) }) do
		P(deco, { Size = V(9, 0.5, 3.6), CFrame = pcf * CF(0, 3.2, 0), Color = C(130, 92, 60), Material = Enum.Material.WoodPlanks })
		for _, z in ipairs({ -3, 3 }) do
			P(deco, { Size = V(9, 0.4, 1.4), CFrame = pcf * CF(0, 1.8, z), Color = C(116, 82, 54), Material = Enum.Material.WoodPlanks })
		end
		for _, x in ipairs({ -3.5, 3.5 }) do
			P(deco, { Size = V(0.5, 3, 7), CFrame = pcf * CF(x, 1.5, 0), Color = C(96, 68, 46), Material = Enum.Material.Wood })
		end
	end
	-- กอหญ้า
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-FX + 4, FX - 4), rng:NextNumber(FZ0 + 4, FZ1 - 4)
		if math.abs(x) > 12 and not (math.abs(x) < 26 and z < -30) and not (x > 46 and x < 96 and z > -20 and z < 34) then
			for k = 0, 2 do
				P(deco, { ClassName = "WedgePart", Size = V(0.2, rng:NextNumber(1, 2.2), 1), CFrame = base * CF(x + k * 0.4, 1.6, z) * ANG(0, rng:NextNumber(0, 6), 0), Color = LEAF[rng:NextInteger(1, #LEAF)]:Lerp(C(120, 160, 80), 0.3), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false })
			end
		end
	end

	------------------------------------------------ รั้วไม้สูงรอบค่าย (เว้นประตูทิศใต้)
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = m
	local function fp(x, z)
		return (base * CF(x, 1, z)).Position
	end
	plankFence(fence, fp(-FX, FZ0), fp(FX, FZ0), 12, rng)
	plankFence(fence, fp(FX, FZ0), fp(FX, FZ1), 12, rng)
	plankFence(fence, fp(-FX, FZ1), fp(-FX, FZ0), 12, rng)
	plankFence(fence, fp(FX, FZ1), fp(14, FZ1), 12, rng)
	plankFence(fence, fp(-14, FZ1), fp(-FX, FZ1), 12, rng)

	------------------------------------------------ ฉากหลัง: โรงนา กังหันลม ป่าใบเหลี่ยม
	barn(deco, base * CF(70, 1, FZ0 - 34) * ANG(0, math.rad(8), 0))
	windmill(deco, base * CF(-62, 1, FZ0 - 30))
	for _, info in ipairs({ { -104, -70 }, { 104, -60 }, { -106, 50 }, { 106, 70 }, { -30, -98 }, { 30, -100 }, { 100, -20 } }) do
		blockyTree(deco, base * CF(info[1], 1, info[2]) * ANG(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.9, 1.2), rng)
	end
	local trees = Instance.new("Folder")
	trees.Name = "Forest"
	trees.Parent = m
	for _ = 1, 150 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(150, 265)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not (math.abs(x) < 16 and z > FZ1) and not (x > 40 and x < 100 and z < FZ0 - 10 and z > FZ0 - 60) and not (x > -80 and x < -44 and z < FZ0 - 14 and z > FZ0 - 46) then
			blockyTree(trees, base * CF(x, 1, z) * ANG(0, rng:NextNumber(0, 6), 0), rng:NextNumber(1, 1.6), rng)
		end
	end
	-- แนวต้นไม้ชิดรั้วด้านนอก
	for _ = 1, 60 do
		local side = rng:NextInteger(1, 4)
		local x, z
		if side == 1 then
			x, z = rng:NextNumber(-FX, FX), FZ0 - rng:NextNumber(8, 30)
		elseif side == 2 then
			x, z = FX + rng:NextNumber(8, 30), rng:NextNumber(FZ0, FZ1)
		elseif side == 3 then
			x, z = -FX - rng:NextNumber(8, 30), rng:NextNumber(FZ0, FZ1)
		else
			x, z = rng:NextNumber(-FX, FX), FZ1 + rng:NextNumber(10, 30)
		end
		local blocked = (x > 40 and x < 100 and z < FZ0) or (x > -80 and x < -44 and z < FZ0) or (math.abs(x) < 16 and z > FZ1)
		if not blocked then
			blockyTree(trees, base * CF(x, 1, z) * ANG(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.9, 1.4), rng)
		end
	end

	self.spawnCf = base * CF(0, 4, 88)
	m.Parent = Workspace
	self.model = m
	return m
end

function LobbyService:SpawnPoint()
	local a = math.random() * math.pi * 2
	return (self.spawnCf * CF(math.cos(a) * 8, 0, math.sin(a) * 5)).Position
end

function LobbyService:InLobby(player)
	return not player:GetAttribute("InRun")
end

-- ลงแมพในเซิร์ฟเวอร์นี้
function LobbyService:Depart(player)
	local ctx = self.ctx
	if player:GetAttribute("InRun") then
		return
	end
	player:SetAttribute("InRun", true)
	local surv = ctx.Services.SurvivalService
	surv:GiveStartItems(player)
	local data = ctx.Services.DataService:Get(player)
	if data and data.PendingKits then
		for kitId in pairs(data.PendingKits) do
			local kit = Shop.KitById[kitId]
			if kit then
				for id, n in pairs(kit.Items) do
					ctx.Services.InventoryService:Add(player, id, n, true)
				end
				ctx.Notify(player, "🎒 ได้รับ " .. kit.Name, "Reward")
			end
		end
		data.PendingKits = {}
	end
	ctx.Remotes.Get("Cinematic"):FireClient(player, "Depart", {})
	surv:Spawn(player)
	if not ctx.Services.DirectorService:IsRunning() then
		ctx.Services.DirectorService:StartRun()
	end
end

-- ส่งทั้งทีม: publish แล้ว -> เซิร์ฟเวอร์ส่วนตัวของทีม / Studio -> ลงแมพที่นี่
function LobbyService:DepartTeam(list)
	local canTeleport = not RunService:IsStudio() and game.PlaceId ~= 0 and not self.IsTeamServer
	if canTeleport then
		for _, p in ipairs(list) do
			self.ctx.Services.DataService:Save(p)
			self.ctx.Remotes.Get("Cinematic"):FireClient(p, "Teleporting", {})
		end
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			opts:SetTeleportData({ Team = true })
			TeleportService:TeleportAsync(game.PlaceId, list, opts)
		end)
		if ok then
			return
		end
		warn("[AS] teleport failed, play here instead:", err)
	end
	for _, p in ipairs(list) do
		task.spawn(self.Depart, self, p)
	end
end

function LobbyService:ReturnAll()
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("InRun", false)
	end
end

local function inside(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) < zone.Size.X / 2 and math.abs(rel.Y) < zone.Size.Y / 2 and math.abs(rel.Z) < zone.Size.Z / 2
end

function LobbyService:Tick(dt)
	local s = self.ctx.State
	local worldReady = s:GetAttribute("Ready")
	local running = self.ctx.Services.DirectorService:IsRunning()
	local anyCountdown = -1
	local anyCount = 0
	for _, box in ipairs(self.boxes) do
		local members, list = {}, {}
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and self:InLobby(p) then
				if inside(box.Zone, r.Position) and #list < box.Size then
					members[p] = true
					table.insert(list, p)
				end
				if r.Position.Y < self.Position.Y - 150 then
					r.CFrame = CFrame.new(self:SpawnPoint())
				end
			end
		end
		box.Members = members
		local n = #list
		box.Text.Text = string.format("%d/%d", n, box.Size)
		if not worldReady then
			box.Sub.Text = string.format("⏳ กำลังสร้างโลก %d%%", math.floor((s:GetAttribute("LoadProgress") or 0) * 100))
			box.Countdown = nil
		elseif s:GetAttribute("Phase") == "Ended" then
			box.Sub.Text = "รอรอบก่อนจบ..."
			box.Countdown = nil
		elseif n == 0 then
			box.Countdown = nil
			box.Sub.Text = running and "⚔ ร่วมทีมที่เล่นอยู่" or "[F] เปลี่ยนขนาดทีม"
			box.Pad.Color = C(200, 214, 245)
			box.Pillar.Enabled = false
			for _, r in ipairs(box.Runes) do
				r.Color = C(230, 236, 255)
			end
		else
			local target = running and COUNTDOWN_JOIN or ((n >= box.Size) and COUNTDOWN_FULL or COUNTDOWN)
			box.Countdown = math.min(box.Countdown or target, target) - dt
			box.Sub.Text = string.format("ออกเดินทางใน %d", math.max(0, math.ceil(box.Countdown)))
			box.Pad.Color = C(120, 230, 130)
			box.Pillar.Enabled = true
			local blink = math.floor(os.clock() * 2) % 2 == 0
			for _, r in ipairs(box.Runes) do
				r.Color = blink and C(120, 255, 140) or C(255, 255, 255)
			end
			anyCountdown = math.max(anyCountdown, math.ceil(box.Countdown))
			anyCount += n
			if box.Countdown <= 0 then
				box.Countdown = nil
				self:DepartTeam(list)
			end
		end
	end
	s:SetAttribute("PortalCount", anyCount)
	s:SetAttribute("PortalCountdown", anyCountdown)
end

function LobbyService:RefreshBoard()
	if not self.boardLabel then
		return
	end
	local rows = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = self.ctx.Services.DataService:Get(p)
		if d then
			table.insert(rows, { p.DisplayName, d.BestNight or 0 })
		end
	end
	table.sort(rows, function(a, b)
		return a[2] > b[2]
	end)
	local lines = { "🏆 ผู้รอดนานสุด" }
	for i = 1, math.min(6, #rows) do
		table.insert(lines, string.format("%d. %s — %d คืน", i, rows[i][1], rows[i][2]))
	end
	self.boardLabel.Text = table.concat(lines, "\n")
end

function LobbyService:Start(ctx)
	ctx.Remotes.Get("BuyKit").OnServerEvent:Connect(function(player, kitId)
		local kit = Shop.KitById[kitId]
		local data = ctx.Services.DataService:Get(player)
		if not (kit and data) then
			return
		end
		if player:GetAttribute("InRun") then
			ctx.Notify(player, "ซื้อชุดเริ่มต้นได้เฉพาะในล็อบบี้", "Error")
			return
		end
		data.PendingKits = data.PendingKits or {}
		if data.PendingKits[kitId] then
			ctx.Notify(player, "ซื้อชุดนี้ไว้แล้ว (ได้ตอนออกเดินทาง)", "Info")
			return
		end
		if data.Diamonds < kit.Price then
			ctx.Notify(player, "💎 เพชรไม่พอ", "Error")
			return
		end
		data.Diamonds -= kit.Price
		data.PendingKits[kitId] = true
		player:SetAttribute("Diamonds", data.Diamonds)
		ctx.Notify(player, "🛒 ซื้อ " .. kit.Name .. " แล้ว — ได้ของตอนออกเดินทาง", "Reward")
		ctx.Remotes.Get("Profile"):FireClient(player, data)
	end)
	-- เซิร์ฟเวอร์ของทีม: ไม่มีล็อบบี้ ลงแมพทันทีที่โลกพร้อม
	if self.IsTeamServer then
		local function arrive(p)
			task.spawn(function()
				while not ctx.State:GetAttribute("Ready") do
					task.wait(0.5)
				end
				self:Depart(p)
			end)
		end
		Players.PlayerAdded:Connect(arrive)
		for _, p in ipairs(Players:GetPlayers()) do
			arrive(p)
		end
	end
	task.spawn(function()
		local t = 0
		while true do
			local dt = task.wait(0.25)
			t += dt
			local ok, err = pcall(self.Tick, self, dt)
			if not ok then
				warn("[AS] lobby", err)
			end
			if t > 5 then
				t = 0
				pcall(self.RefreshBoard, self)
			end
		end
	end)
end

return LobbyService
