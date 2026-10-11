--[[
	LobbyService — ล็อบบี้แบบ 99 Nights in the Forest
	  ค่ายฟาร์มกลางป่ายามค่ำคืน: พื้นดิน + ทางเดินไม้กระดาน, รั้วไม้สูงรอบค่าย, โรงนา/กังหันลม/ต้นไม้ใบเหลี่ยมเป็นฉากหลัง
	  ทางเข้า (ใต้): ลานไม้จุดเกิด + ซุ้มประตูไม้ซุง "WILDHEART CAMP"
	  กลาง: เต็นท์ "Classes" (ร้านคลาส + เวทีโชว์หุ่นที่กล้องร้านคลาสเล็ง) + กระดานข่าว
	  ซ้าย: หม้อรางวัลประจำวัน (แร่แดงฟรี) + กระดานคนรอดนานสุด + แคมป์ไฟ
	  ขวา: แท่น "เริ่มเกม" เรืองแสง 4 แท่น — ขึ้นไปยืน เลือกขนาดทีม 1-5 คน -> คนครบ/หมดเวลา = ออกเดินทาง

	ออกเดินทาง:
	  - เกม publish แล้ว: ทั้งทีมถูกส่งไปเซิร์ฟเวอร์ส่วนตัวของทีม (TeleportService reserved server) เหมือนต้นฉบับ
	  - ใน Studio / เซิร์ฟเวอร์ของทีมเอง: ลงแมพในเซิร์ฟเวอร์นี้เลย
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Shop = require(ReplicatedStorage.Shared.Shop)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)
local BaseDecor = require(ReplicatedStorage.Shared.BaseDecor)
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
local Config = require(ReplicatedStorage.Shared.Config)

local LobbyService = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

LobbyService.Position = V(12000, 1799, 12000) -- ไกลนอกแมพ · Y 1799 = ผิวพื้น (y+1) ตรงเส้นตาราง voxel 4 studs ของ Terrain พอดี (หญ้าไม่ล้นขึ้นมาท่วมของ)
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
	if PropBuilder.RealFire(part, size / 4) then
		return part
	end
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.3
	f.Parent = part
	return f
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

local function crate(parent, cf, s)
	s = s or 3
	P(parent, { Size = V(s, s, s), CFrame = cf * CF(0, s / 2, 0), Color = C(150, 110, 70), Material = Enum.Material.WoodPlanks })
	P(parent, { Size = V(s * 1.42, 0.3, 0.32), CFrame = cf * CF(0, s / 2, -s / 2 - 0.05) * ANG(0, 0, math.rad(45)), Color = C(110, 78, 50), Material = Enum.Material.Wood })
end

-- เต็นท์ Classes (ผ้าใบสีเขียวขี้ม้า หน้าเปิด) + เวทีโชว์หุ่น
local function classesTent(self, parent, cf)
	local W, D, H, E = 40, 32, 22, 9
	local canvas, canvasDark = C(134, 130, 70), C(108, 104, 56)
	local rng = Random.new(77)
	-- กระท่อม Classes (โมเดล Import) แทนเต็นท์ผ้าใบ: ของตกแต่งที่ทำเองข้างล่างจะซ่อนไว้ ใช้แค่ภายใน (เคาน์เตอร์ เวที)
	-- Import 3D ของ Roblox หมุนโมเดลให้หน้า (ป้าย Classes) อยู่ทาง -Z แล้ว = ทางเดียวกับหน้าเต็นท์ · ยกให้พ้นพื้นไม้ของลาน
	local hut = PropBuilder.Imported("ClassHut", cf * CF(0, 1.3, 0), W + 6, parent)
	local tentFolder = parent
	local hutDeck, hutSize, hutUnit
	if hut then
		hut.Name = "ClassHut"
		for _, d in ipairs(hut:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false -- เดินเข้าได้ (พื้น/ผนังชนด้วยกล่องล่องหนด้านล่าง)
			end
		end
		-- เมชนี้ถูกดึงลงตามกระดูกราก (Y -0.83 ของความสูง 1.7) -> ยกกลับให้ฐานจริงแตะพื้น
		local mesh = hut:FindFirstChildWhichIsA("MeshPart", true)
		local unit = mesh and mesh.Size.Y / 1.7 or 14
		hut:PivotTo(hut:GetPivot() + V(0, 0.832 * unit, 0))
		local _, hs = hut:GetBoundingBox()
		-- พื้นไม้ในกระท่อม (วัดจากโมเดล: สูง 0.13 จากฐาน)
		hutDeck = 1.3 + 0.13 * unit
		hutSize = hs
		hutUnit = unit
		P(parent, { Name = "HutFloor", Size = V(hs.X * 0.9, 1, hs.Z * 0.85), CFrame = cf * CF(0, hutDeck - 0.5, 0), Transparency = 1 })
		tentFolder = Instance.new("Folder")
		tentFolder.Name = "TentHidden"
	end
	-- พื้นไม้ในเต็นท์
	deck(tentFolder, cf * CF(0, 1, 0), W - 2, D - 2, rng)
	-- หลังคาสองฝั่ง
	local slope = math.atan2(H - E, W / 2)
	local slen = math.sqrt((H - E) ^ 2 + (W / 2) ^ 2)
	for _, s in ipairs({ -1, 1 }) do
		P(tentFolder, { Size = V(slen + 1.5, 0.4, D + 3), CFrame = cf * CF(s * W / 4, (H + E) / 2 + 1, 0) * ANG(0, 0, -s * slope), Color = canvas, Material = Enum.Material.Fabric })
		-- ชายผ้าห้อยด้านหน้า
		P(tentFolder, { Size = V(slen + 1.5, 1.6, 0.2), CFrame = cf * CF(s * W / 4, (H + E) / 2 + 0.2, -D / 2 - 1.5) * ANG(0, 0, -s * slope), Color = canvasDark, Material = Enum.Material.Fabric })
		-- ผนังข้าง
		P(tentFolder, { Size = V(0.4, E, D), CFrame = cf * CF(s * W / 2, E / 2 + 1, 0), Color = canvasDark, Material = Enum.Material.Fabric })
	end
	-- ผนังหลัง + จั่ว
	P(tentFolder, { Size = V(W, E, 0.4), CFrame = cf * CF(0, E / 2 + 1, D / 2), Color = canvasDark, Material = Enum.Material.Fabric })
	for _, s in ipairs({ -1, 1 }) do
		P(tentFolder, { ClassName = "WedgePart", Size = V(0.4, H - E, W / 2), CFrame = cf * CF(s * W / 4, E + 1 + (H - E) / 2, D / 2) * ANG(0, s * -math.pi / 2, 0), Color = canvasDark, Material = Enum.Material.Fabric })
	end
	-- เสา + คานสัน
	for _, x in ipairs({ -W / 2, 0, W / 2 }) do
		local ph = (x == 0) and H + 1 or E + 1
		P(tentFolder, { Size = V(0.9, ph, 0.9), CFrame = cf * CF(x, ph / 2, -D / 2 - 0.5), Color = C(84, 62, 44), Material = Enum.Material.Wood })
	end
	P(tentFolder, { Size = V(0.8, 0.8, D + 4), CFrame = cf * CF(0, H + 1.4, 0), Color = C(84, 62, 44), Material = Enum.Material.Wood })
	-- เชือกยึด + หมุด
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -D / 2, 0, D / 2 }) do
			local a = (cf * CF(s * W / 2, E + 1, z)).Position
			local b = (cf * CF(s * (W / 2 + 7), 1, z)).Position
			P(tentFolder, { Size = V(0.12, 0.12, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = C(214, 204, 170), CanCollide = false, CanQuery = false })
			P(tentFolder, { Size = V(0.5, 1.2, 0.5), CFrame = CF(b + V(0, 0.4, 0)), Color = C(84, 62, 44), Material = Enum.Material.Wood })
		end
	end
	-- ป้าย "Classes" ไฟนีออนเขียว
	local signCf = cf * CF(0, 15.5, -D / 2 - 1.8)
	for _, x in ipairs({ -6, 6 }) do
		P(tentFolder, { Size = V(0.15, 4.5, 0.15), CFrame = signCf * CF(x, 4.2, 0), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	end
	local board = P(tentFolder, { Size = V(17, 5.6, 0.6), CFrame = signCf, Color = C(80, 52, 34), Material = Enum.Material.WoodPlanks })
	P(tentFolder, { Size = V(17.8, 6.4, 0.4), CFrame = signCf * CF(0, 0, 0.2), Color = C(56, 38, 26), Material = Enum.Material.Wood })
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
	fireStump(parent, cf * CF(-W / 2 - 1, 1, -D / 2 - 8))
	fireStump(parent, cf * CF(W / 2 + 1, 1, -D / 2 - 8))
	-- ภายใน: เคาน์เตอร์ + คนดูแลคลาส + ไวท์บอร์ด + ลังไม้ + โคมแขวน
	local counterCf = cf * CF(-11, 1.5, -6)
	P(tentFolder, { Size = V(10, 3.2, 3), CFrame = counterCf * CF(0, 1.6, 0), Color = C(110, 78, 50), Material = Enum.Material.WoodPlanks })
	P(tentFolder, { Size = V(10.6, 0.4, 3.6), CFrame = counterCf * CF(0, 3.3, 0), Color = C(140, 100, 64), Material = Enum.Material.WoodPlanks })
	-- ในกระท่อม: ที่ปรึกษายืนหลังโต๊ะยาวด้านหน้า หันออกทางเข้า
	local keeperCf = counterCf * CF(0, 0, 3.2) * ANG(0, math.pi, 0)
	if hutDeck then
		-- โต๊ะยาวในโมเดลอยู่ที่ x -0.75..0.25, y -0.85..-0.55 (หน่วยโมเดล, ด้านหน้า = -y) -> ยืนหลังโต๊ะ หันออกทางเข้า
		keeperCf = cf * CF(0.25 * hutUnit, hutDeck, -0.36 * hutUnit)
	end
	local keeper, kbody = shopkeeper(parent, keeperCf)
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
		npc:PivotTo(keeperCf)
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
	if hut then
		-- ป้ายเดิมซ่อน แต่เก็บปุ่มเปิดร้านไว้ที่จุดเดิม
		board.Parent = parent
		board.Transparency = 1
		board.CanCollide = false
		board:ClearAllChildren()
	end
	prompt(board, "ร้านคลาส", "Classes", Enum.KeyCode.E, 30).Triggered:Connect(function(p)
		self.ctx.Remotes.Get("Cinematic"):FireClient(p, "OpenClasses", {})
	end)
	-- ไวท์บอร์ดบนขาตั้ง (หลังเวที ซ้าย)
	local wbCf = cf * CF(-9, 1.5, D / 2 - 4) * ANG(0, math.rad(15), 0)
	local wb = P(tentFolder, { Size = V(9, 5.5, 0.3), CFrame = wbCf * CF(0, 6, 0), Color = C(196, 192, 200), Material = Enum.Material.SmoothPlastic })
	for _, x in ipairs({ -3.5, 3.5 }) do
		P(tentFolder, { Size = V(0.3, 8, 0.3), CFrame = wbCf * CF(x, 4, 0.4) * ANG(math.rad(8), 0, 0), Color = C(200, 200, 206), Material = Enum.Material.Metal })
	end
	label(wb, Enum.NormalId.Front, "แผนวันนี้:\n1. เลือกคลาส\n2. ขึ้นแท่นเริ่มเกม\n3. พิชิตคืนสุดท้าย!", C(40, 60, 160), Enum.Font.GothamBold)
	-- ตอไม้มีไฟ (หลังเวที ขวา) + ลังไม้
	fireStump(tentFolder, cf * CF(10, 1.5, D / 2 - 4), 0.7, 14) -- ไฟอ่อนๆ ไม่ให้หน้าตัวละครบนเวทีสว่างจ้า
	crate(tentFolder, cf * CF(16, 1.5, D / 2 - 3))
	crate(tentFolder, cf * CF(16.5, 4.5, D / 2 - 3) * ANG(0, 0.5, 0), 2.4)
	crate(tentFolder, cf * CF(-16, 1.5, -10) * ANG(0, 0.3, 0))
	for _, z in ipairs({ -8, 6 }) do
		local lamp = P(tentFolder, { Size = V(1.2, 1.6, 1.2), CFrame = cf * CF(0, H - 4, z), Color = C(255, 214, 150), Material = Enum.Material.Neon, CanCollide = false })
		P(tentFolder, { Size = V(0.1, 4, 0.1), CFrame = cf * CF(0, H - 1.6, z), Color = C(40, 36, 34), CanCollide = false })
		light(lamp, C(255, 196, 130), 24, 0.8, true)
	end
	-- เวทีโชว์หุ่นคลาส (กล้องร้านคลาสเล็งมาที่นี่) หันหน้าเข้าหาทางเข้าเต็นท์
	local stageCf = cf * CF(0, 1.5, D / 2 - 7)
	if hutDeck then
		-- บนพื้นกระท่อม ด้านขวา-หลัง (กล้องร้านคลาสอยู่หน้าเวที 16 studs ไม่ติดที่ปรึกษา/โต๊ะ)
		stageCf = cf * CF(0.97 * hutUnit, hutDeck - 1.1, 0.35 * hutUnit)
	end
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
	t.Text = "รางวัลประจำวัน 🔺"
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
	t2.Text = "- รับแร่แดงฟรีทุกวัน -"
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

-- ประตูมิติ (โมเดลหินจาก tools/lobby_art.py) -> ใส่ไฟ อนุภาค ป้าย 0/4 กลางม่าน เลขบนพื้น และโซนยืน
local PORTAL_IDLE, PORTAL_VEIL, PORTAL_GO, PORTAL_GO_VEIL = C(70, 230, 255), C(30, 190, 255), C(110, 245, 140), C(80, 230, 130)
local function portalHook(art, parent, i)
	local center = art:FindFirstChild("PortalCenter" .. i, true)
	local ring = art:FindFirstChild("PortalRing" .. i, true)
	local veil = art:FindFirstChild("PortalVeil" .. i, true)
	if not (center and ring and veil) then
		return nil
	end
	-- เลขประตูกลางลาน
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = center
	local num = Instance.new("TextLabel")
	num.Size = UDim2.fromScale(0.8, 0.8)
	num.Position = UDim2.fromScale(0.1, 0.1)
	num.BackgroundTransparency = 1
	num.Font = Enum.Font.FredokaOne
	num.TextScaled = true
	num.Text = tostring(i)
	num.TextColor3 = C(235, 252, 255)
	num.Parent = sg
	local ns = Instance.new("UIStroke")
	ns.Thickness = 5
	ns.Color = C(10, 60, 90)
	ns.Parent = num
	-- แสงม่าน + ประกายลอยออกจากม่าน
	local glow = light(veil, PORTAL_VEIL, 26, 2.2)
	local att = Instance.new("Attachment")
	att.Parent = veil
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Shape = Enum.ParticleEmitterShape.Disc
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Rate = 8
	motes.Lifetime = NumberRange.new(1.5, 3)
	motes.Speed = NumberRange.new(1, 3)
	motes.SpreadAngle = Vector2.new(40, 40)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
	motes.LightEmission = 1
	motes.Color = ColorSequence.new(C(190, 245, 255))
	motes.Parent = att
	for _, tag in ipairs({ "L", "R" }) do
		local lamp = art:FindFirstChild("PortalBrazier" .. i .. tag, true)
		if lamp then
			light(lamp, PORTAL_IDLE, 12, 1.4)
		end
	end
	-- ป้ายกลางม่าน (ตัวหนังสือขาวขอบเข้ม แบบภาพต้นแบบ)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(9, 4)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Adornee = veil
	bb.Parent = veil
	local function line(y, h, txt, font)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, h)
		t.BackgroundTransparency = 1
		t.Text = txt
		t.TextScaled = true
		t.Font = font
		t.TextColor3 = C(255, 255, 255)
		t.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = C(8, 40, 70)
		st.Parent = t
		return t
	end
	local count = line(0.0, 0.5, "👤 0/4", Enum.Font.FredokaOne)
	local sub = line(0.52, 0.24, "เดินขึ้นแท่นเพื่อเริ่ม", Enum.Font.GothamBold)
	local names = line(0.78, 0.2, "", Enum.Font.GothamBold)
	names.TextColor3 = C(170, 245, 255)
	-- วงฟ้าเรืองแสงบนลานหน้าประตู (เขตยืนรอ เห็นชัดว่าใครอยู่ในวง แบบเกมเอาชีวิตรอดซอมบี้) + ประกายลอยขึ้นจากวง
	local cp = center.Position
	local disc = P(parent, { Name = "PortalZone" .. i, Shape = Enum.PartType.Cylinder, Size = V(0.06, 19.6, 19.6), CFrame = CF(cp.X, cp.Y + 0.02, cp.Z) * ANG(0, 0, math.pi / 2),
		Color = PORTAL_IDLE, Material = Enum.Material.Neon, Transparency = 0.62, CanCollide = false, CanQuery = false, CastShadow = false })
	local edge = ring -- ขอบวงเรืองแสงรอบลาน (จากโมเดล)
	TweenService:Create(disc, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8 }):Play()
	local rise = Instance.new("ParticleEmitter")
	rise.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rise.Shape = Enum.ParticleEmitterShape.Disc
	rise.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rise.EmissionDirection = Enum.NormalId.Right -- แกนกระบอก = ขึ้นด้านบน
	rise.Rate = 10
	rise.Lifetime = NumberRange.new(1.6, 2.6)
	rise.Speed = NumberRange.new(2.5, 4.5)
	rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) })
	rise.LightEmission = 1
	rise.Color = ColorSequence.new(C(170, 245, 255))
	rise.Parent = disc
	local zone = P(parent, { Name = "MatchBox" .. i, Size = V(21, 12, 21), CFrame = CF(cp.X, cp.Y + 5, cp.Z), Transparency = 1, CanCollide = false, CanQuery = false })
	zone:SetAttribute("PadIndex", i)
	zone:SetAttribute("Size", 4)
	zone:SetAttribute("Count", 0)
	zone:SetAttribute("Countdown", -1)
	return { Index = i, Zone = zone, Size = 4, Text = count, Sub = sub, Names = names, Countdown = nil, Pad = veil, Ring = ring, Disc = disc, Edge = edge, Rise = rise, Runes = {}, Pillar = glow, Motes = motes }
end

---------------------------------------------------------------- สร้างล็อบบี้: ป่าโบราณศักดิ์สิทธิ์ (ประตูมิติหินโบราณ 4 ประตู + ซากรูน + ป่าดิบ + น้ำตก)
-- ฉากหิน/ต้นไม้/พืชทั้งหมดมาจาก ServerStorage.LobbyArt.LobbyRuins (สร้างด้วย tools/lobby_art.py) · ที่นี่ใส่ของที่ใช้งานได้ + ไฟ/อนุภาค
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
	-- หินใต้เกาะ (พื้นหญ้าด้านบน = Terrain ด้านล่าง)
	cyl(m, 8, 560, base * CF(0, -4, 0), C(96, 80, 60), Enum.Material.Ground)
	for i = 1, 5 do
		cyl(m, 16, 560 - i * 90, base * CF(0, -8 - i * 14, 0), C(60 - i * 5, 64 - i * 5, 60 - i * 5), Enum.Material.Rock)
	end

	local FX, FZ0, FZ1 = 120, -112, 104 -- ขอบค่าย (กำแพงหินพังในฉาก + กำแพงล่องหนกันตก)
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = m

	------------------------------------------------ ฉากหลักจากโมเดล
	local art
	local src = ServerStorage:FindFirstChild("LobbyArt")
	src = src and src:FindFirstChild("LobbyRuins")
	if src then
		art = src:Clone()
		local origin = art:FindFirstChild("Origin")
		if origin then
			art.PrimaryPart = origin -- จุด 0,0,0 ของฉาก = จุดกลางล็อบบี้ (กันโมเดลเลื่อน/จมจากจุดหมุนกลางกล่อง)
		end
		art:PivotTo(base)
		art.Parent = m
		for _, d in ipairs(art:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "CrystalLamp" then
					light(d, C(110, 230, 255), 16, 1.3)
				elseif d.Name == "WaterfallFoam" then
					local mist = Instance.new("ParticleEmitter")
					mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
					mist.Rate = 14
					mist.Lifetime = NumberRange.new(2, 3.5)
					mist.Speed = NumberRange.new(2, 5)
					mist.SpreadAngle = Vector2.new(60, 60)
					mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
					mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
					mist.Color = ColorSequence.new(C(235, 248, 255))
					mist.Parent = d
				end
			end
		end
		local campSign = art:FindFirstChild("CampSign", true)
		if campSign then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local t = label(campSign, face, "WILDHEART CAMP", C(150, 240, 255), Enum.Font.FredokaOne)
				local st = Instance.new("UIStroke")
				st.Color, st.Thickness, st.Parent = C(8, 40, 60), 3, t
			end
		end
		local groveSign = art:FindFirstChild("GroveSign", true)
		if groveSign then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local t = label(groveSign, face, "⚔ เดินเข้าประตูมิติเพื่อเริ่มเกม", C(150, 240, 255), Enum.Font.GothamBlack)
				local st = Instance.new("UIStroke")
				st.Color, st.Thickness, st.Parent = C(8, 40, 60), 2, t
			end
		end
	else
		warn("[AS] ไม่พบ ServerStorage.LobbyArt.LobbyRuins (รัน python tools/lobby_art.py แล้ว build ใหม่)")
	end
	-- กำแพงล่องหนรอบค่าย (เว้นประตูทิศใต้ที่ปิดด้วย GateBlock)
	for _, w in ipairs({
		{ V(FX * 2 + 4, 40, 2), V(0, 20, FZ0) }, { V(2, 40, FZ1 - FZ0), V(FX, 20, (FZ0 + FZ1) / 2) }, { V(2, 40, FZ1 - FZ0), V(-FX, 20, (FZ0 + FZ1) / 2) },
		{ V(FX - 14, 40, 2), V((FX + 14) / 2, 20, FZ1) }, { V(FX - 14, 40, 2), V(-(FX + 14) / 2, 20, FZ1) },
	}) do
		P(m, { Name = "Boundary", Size = w[1], CFrame = base * CF(w[2]), Transparency = 1, CanQuery = false })
	end
	P(m, { Name = "GateBlock", Size = V(30, 40, 1), CFrame = base * CF(0, 20, FZ1 + 6), Transparency = 1, CanQuery = false })

	------------------------------------------------ พื้น Terrain: หญ้าจริง (มีใบหญ้าขึ้น) + ทางหินปูถนน/ลานหิน
	local terrain = Workspace.Terrain
	local GX, GZ, GR = 52, 8, 50 -- ลานประตูมิติ (ตรงกับ tools/lobby_art.py)
	terrain:FillCylinder(base * CF(0, -1, 0), 4, 278, Enum.Material.Grass)
	-- พื้นกันตกล่องหน (ใต้ผิวหญ้านิดเดียว) เผื่อ Terrain ยังสตรีมมาไม่ถึงเครื่องผู้เล่น
	P(m, { Name = "SafetyFloor", Shape = Enum.PartType.Cylinder, Size = V(1, 556, 556), CFrame = base * CF(0, 0.4, 0) * ANG(0, 0, math.pi / 2), Transparency = 1, CanQuery = false })
	local function road(x0, z0, x1, z1, w, mat)
		local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
		local mid = (a + b) / 2
		terrain:FillBlock(base * CFrame.lookAt(mid + Vector3.new(0, -1, 0), b + Vector3.new(0, -1, 0)), V(w, 4, (b - a).Magnitude + w * 0.5), mat or Enum.Material.Cobblestone)
	end
	local function plaza(x, z, r, mat)
		terrain:FillCylinder(base * CF(x, -1, z), 4, r, mat or Enum.Material.Cobblestone)
	end
	plaza(0, 88, 15)
	road(0, 76, 0, -30, 10)
	plaza(0, -34, 12)
	road(-86, 44, GX - 18, 44, 9)
	road(-42, 44, -42, -8, 8)
	plaza(-42, -16, 10)
	road(-42, 6, -76, 6, 7)
	plaza(-78, 6, 9)
	road(-62, 44, -62, 64, 6)
	plaza(-62, 74, 11)
	plaza(GX, GZ, 19, Enum.Material.Slate)
	for _, ad in ipairs({ -60, -20, 20, 60 }) do
		local a = math.rad(ad)
		road(GX + math.cos(a) * 16, GZ + math.sin(a) * 16, GX + math.cos(a) * (GR - 10), GZ + math.sin(a) * (GR - 10), 7, Enum.Material.Slate)
	end

	------------------------------------------------ ต้นไม้/พุ่มไม้/เฟิร์น/หิน/เห็ด = โมเดลเมชชุดเดียวกับในแมพ (ไม่ใช่ลูกบอล)
	local veg = Instance.new("Folder")
	veg.Name = "Vegetation"
	veg.Parent = m
	local function plant(kind, x, z, scale)
		local inst = PropBuilder.Place(kind, (base * CF(x, 0.6, z)).Position, rng:NextNumber(0, math.pi * 2), scale or 1, nil, rng)
		if inst then
			CollectionService:RemoveTag(inst, "ResourceNode") -- ล็อบบี้: ตัด/เก็บไม่ได้
			CollectionService:RemoveTag(inst, "Hazard")
			inst:SetAttribute("Node", nil)
			inst.Parent = veg
		end
		return inst
	end
	local function blocked(x, z)
		return (math.abs(x) < 10 and z > -40 and z < 104) or (math.abs(z - 44) < 7.5 and x < GX - 14) or (math.abs(x + 42) < 7 and z > -10 and z < 44)
			or math.sqrt(x * x + (z - 88) ^ 2) < 19 or (math.abs(x) < 34 and z > -90 and z < -18) or math.sqrt((x + 42) ^ 2 + (z + 16) ^ 2) < 13
			or (x < -64 and x > -100 and math.abs(z - 6) < 22) or math.sqrt((x + 62) ^ 2 + (z - 74) ^ 2) < 16 or math.sqrt((x + 86) ^ 2 + (z - 86) ^ 2) < 16
			or math.sqrt((x + 96) ^ 2 + (z + 70) ^ 2) < 13 or math.abs(z - 6) < 5 and x < -40 and x > -78 or math.abs(x + 62) < 5 and z > 44 and z < 66
			or math.sqrt((x - GX) ^ 2 + (z - GZ) ^ 2) < GR + 18
	end
	-- ป่ารอบนอกกำแพง (ทึบ บังขอบเกาะ)
	for _ = 1, 90 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(128, 232)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if z > FZ0 - 30 and not (math.abs(x) < 26 and z > FZ1) then
			local k = rng:NextNumber()
			plant(k < 0.45 and "AncientOak" or (k < 0.85 and "Oak" or "Palm"), x, z, rng:NextNumber(0.9, 1.35))
		end
	end
	for _ = 1, 40 do -- พุ่มไม้ใต้ต้นไม้นอกกำแพง
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(124, 160)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if z > FZ0 - 20 and not (math.abs(x) < 26 and z > FZ1) then
			plant("Bush", x, z, rng:NextNumber(1.2, 1.8))
		end
	end
	-- ต้นไม้ใหญ่ในค่าย
	for _, t in ipairs({ { -104, -40 }, { 106, -66 }, { -102, 94 }, { 40, 94 }, { -64, 22 }, { -106, -88 }, { 66, -96 }, { -30, -100 }, { 108, 96 }, { -40, 96 }, { 26, 64 }, { -26, 66 } }) do
		plant(rng:NextNumber() < 0.6 and "AncientOak" or "Oak", t[1], t[2], rng:NextNumber(0.75, 0.95))
	end
	-- พุ่มไม้แน่นแนวกำแพงด้านใน
	for _ = 1, 70 do
		local side = rng:NextInteger(1, 4)
		local x, z
		if side == 1 then
			x, z = rng:NextNumber(-FX + 6, FX - 6), FZ0 + rng:NextNumber(4, 10)
		elseif side == 2 then
			x, z = FX - rng:NextNumber(4, 10), rng:NextNumber(FZ0, FZ1)
		elseif side == 3 then
			x, z = -FX + rng:NextNumber(4, 10), rng:NextNumber(FZ0, FZ1)
		else
			x, z = rng:NextNumber(-FX, FX), FZ1 - rng:NextNumber(4, 10)
		end
		if not blocked(x, z) then
			plant("Bush", x, z, rng:NextNumber(1.1, 1.7))
		end
	end
	-- พืชพื้นล่างทั่วค่าย
	local placed, tries = 0, 0
	while placed < 230 and tries < 3000 do
		tries += 1
		local x, z = rng:NextNumber(-FX + 6, FX - 6), rng:NextNumber(FZ0 + 6, FZ1 - 6)
		if not blocked(x, z) then
			placed += 1
			local k = rng:NextNumber()
			if k < 0.3 then
				plant("Bush", x, z, rng:NextNumber(0.9, 1.5))
			elseif k < 0.78 then
				plant("Fern", x, z, rng:NextNumber(1.0, 1.6))
			elseif k < 0.88 then
				plant("MossRock", x, z, rng:NextNumber(0.5, 1.0))
			elseif k < 0.96 then
				plant("Mushrooms", x, z, rng:NextNumber(0.9, 1.4))
			else
				plant("GlowShroom", x, z, rng:NextNumber(0.5, 0.9))
			end
		end
	end
	-- ลานประตู: พุ่มไม้/ต้นไม้ล้อมระหว่างประตู + เฟิร์นริมทาง
	for _, ad in ipairs({ -84, -40, 0, 40, 84 }) do
		local a = math.rad(ad)
		plant("Bush", GX + math.cos(a) * (GR + 2), GZ + math.sin(a) * (GR + 2), 1.6)
		if ad ~= -84 and ad ~= 84 then
			plant("AncientOak", GX + math.cos(a) * (GR + 14), GZ + math.sin(a) * (GR + 14), 0.85)
		end
	end
	for _, ad in ipairs({ -60, -20, 20, 60 }) do
		local a = math.rad(ad)
		for _, off in ipairs({ -0.22, 0.22 }) do
			plant("Bush", GX + math.cos(a + off) * (GR + 15), GZ + math.sin(a + off) * (GR + 15), 1.7)
		end
	end

	-- ของตกแต่งโทนเดียวกับกระท่อม Classes (โมเดลจริง): ม้านั่งท่อนซุง ลังไม้ กองฟืน โรงเก็บของ
	PropBuilder.StoreModel("CampShack", base * CF(-96, 1, -70) * ANG(0, math.rad(60), 0), deco)
	for _, info in ipairs({ { -24, -36, 0.2 }, { 28, -40, 1.1 }, { -60, 30, 2.2 }, { 46, 70, 0.6 }, { -100, -40, 1.6 } }) do
		PropBuilder.StoreModel("LogPileStore", base * CF(info[1], 1, info[2]) * ANG(0, info[3], 0), deco)
	end
	for _, info in ipairs({ { 22, -36, 0.4 }, { 25, -38, 1.2 }, { -30, 62, 0.3 }, { 110, 46, 0.9 }, { -104, 8, 0.2 } }) do
		PropBuilder.StoreModel("Crate", base * CF(info[1], 1, info[2]) * ANG(0, info[3], 0), deco)
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
	nt.Text = '<font color="#FFE066">กระดานข่าวค่าย</font>\n\nรอดคืนสำคัญ (ทุก 5-25 คืน)\n= รับแร่แดง 🔺\n\nช่วยลูกสัตว์ธาตุ = 🔺15\n<font color="#8CFF8C">รับแร่แดงฟรีที่หม้อเขียวทุกวัน!</font>'
	nt.Parent = nbg
	local nlamp = P(deco, { Size = V(0.9, 0.9, 0.9), CFrame = nbCf * CF(0, 12, -1.6), Color = C(255, 214, 150), Material = Enum.Material.Neon, CanCollide = false })
	light(nlamp, C(255, 196, 130), 14, 1.6)

	------------------------------------------------ ซ้าย: หม้อรางวัลประจำวัน + กระดานผู้รอดนานสุด + แคมป์ไฟ
	dailyCauldron(self, deco, base * CF(-42, 1, -16))
	local boardCf = base * CF(-88, 1, 6) * ANG(0, math.rad(90), 0)
	-- กระดานใหญ่ (กว้าง 26 x สูง 17) กรอบไม้หนา + ขอบทอง + หลังคา + โคมสองข้าง
	local board = P(deco, { Size = V(26, 17, 0.8), CFrame = boardCf * CF(0, 11, 0), Color = C(28, 26, 44), Material = Enum.Material.SmoothPlastic })
	for _, x in ipairs({ -13.6, 13.6 }) do
		P(deco, { Size = V(1.4, 21.5, 1.4), CFrame = boardCf * CF(x, 10.75, 0), Color = C(96, 64, 40), Material = Enum.Material.Wood })
		P(deco, { Size = V(2, 1, 2), CFrame = boardCf * CF(x, 0.5, 0), Color = C(96, 92, 88), Material = Enum.Material.Slate })
	end
	for _, y in ipairs({ 2.15, 19.85 }) do
		P(deco, { Size = V(27.6, 1.1, 1.3), CFrame = boardCf * CF(0, y, 0), Color = C(96, 64, 40), Material = Enum.Material.Wood })
	end
	for _, y in ipairs({ 2.75, 19.25 }) do
		P(deco, { Size = V(26.2, 0.18, 1.0), CFrame = boardCf * CF(0, y, 0), Color = C(255, 196, 70), Material = Enum.Material.Neon })
	end
	P(deco, { ClassName = "WedgePart", Size = V(30, 2.4, 3.2), CFrame = boardCf * CF(0, 21.6, 0), Color = C(120, 64, 40), Material = Enum.Material.WoodPlanks })
	self.boardGuis = { self:BuildBoardGui(board, Enum.NormalId.Back), self:BuildBoardGui(board, Enum.NormalId.Front) }
	lanternPost(deco, boardCf * CF(-16, 0, -2), 11)
	lanternPost(deco, boardCf * CF(16, 0, -2), 11)
	-- แคมป์ไฟเล็ก + ม้านั่งท่อนซุง + เต็นท์นอน
	local fcf = base * CF(-62, 1, 74)
	local ring = mesh("Campfire", fcf, deco)
	if ring then
		ring.Name = "LobbyFireRing"
	end
	local core = P(deco, { Name = "LobbyFire", Size = V(2, 2, 2), CFrame = fcf * CF(0, 2, 0), Transparency = 1, CanCollide = false })
	fireOn(core, 7)
	light(core, C(255, 150, 70), 40, 2.8, true)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.5
		local bcf = fcf * CF(math.cos(a) * 8, 0, math.sin(a) * 8) * ANG(0, -a, 0)
		if not PropBuilder.StoreModel("LogBench", bcf, deco) then
			cyl(deco, 7, 1.8, bcf * CF(0, 0.9, 0) * ANG(0, math.pi / 2, 0) * ANG(0, 0, -math.pi / 2), C(104, 74, 50), Enum.Material.Wood)
		end
	end
	BaseDecor.CanvasTent(deco, base * CF(-90, 1, 78) * ANG(0, math.rad(-70), 0), C(70, 104, 150))
	BaseDecor.CanvasTent(deco, base * CF(-80, 1, 96) * ANG(0, math.rad(-130), 0), C(196, 110, 52))

	------------------------------------------------ ประตูมิติ 4 ประตู (ลานฝั่งตะวันออก)
	self.boxes = {}
	if art then
		for i = 1, 4 do
			local box = portalHook(art, deco, i)
			if box then
				table.insert(self.boxes, box)
			end
		end
	end

	------------------------------------------------ ลังไม้ประปราย
	for _, info in ipairs({ { 24, -40 }, { 27, -44 }, { -26, -40 }, { 40, 60 }, { -102, 30 } }) do
		crate(deco, base * CF(info[1], 1, info[2]) * ANG(0, rng:NextNumber(0, 1), 0))
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
	ctx.Services.MonetizationService:GiveRunPerks(player)
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
		self:RefreshTag(p)
	end
end

-- เซิร์ฟเวอร์ของทีม -> ส่งกลับล็อบบี้หลัก (เซิร์ฟเวอร์สาธารณะของเกมเดียวกัน) · คืน true ถ้าเริ่มส่งได้
function LobbyService:ReturnToMainLobby(list, info)
	if RunService:IsStudio() or game.PlaceId == 0 or #list == 0 then
		return false
	end
	for _, p in ipairs(list) do
		self.ctx.Services.DataService:Save(p)
		self.ctx.Remotes.Get("Cinematic"):FireClient(p, "Teleporting", { Back = true })
	end
	local ok, err = pcall(function()
		local opts = Instance.new("TeleportOptions")
		opts:SetTeleportData({ Back = true, Result = info and info.Result, Night = info and info.Night })
		TeleportService:TeleportAsync(game.PlaceId, list, opts)
	end)
	if not ok then
		warn("[AS] return to lobby failed:", err)
	end
	return ok
end

-- คนที่ตายแล้ว (กำลังดูเพื่อน) กดกลับล็อบบี้เอง
function LobbyService:LeaveRun(player)
	local surv = self.ctx.Services.SurvivalService
	if not player:GetAttribute("InRun") or not player:GetAttribute("Dead") then
		return
	end
	if self.IsTeamServer and self:ReturnToMainLobby({ player }, { Result = "Left" }) then
		return
	end
	surv:ResetPlayer(player)
	self:RefreshTag(player)
	surv:CheckWipe()
end

---------------------------------------------------------------- ป้ายบนหัว (ล็อบบี้): คืนที่รอดนานสุด + VIP
local function tierColor(best)
	if best >= 99 then
		return C(255, 214, 90), "👑"
	elseif best >= 50 then
		return C(255, 120, 90), "🔥"
	elseif best >= 25 then
		return C(190, 140, 255), "🌕"
	elseif best >= 10 then
		return C(120, 210, 255), "🌙"
	end
	return C(225, 225, 235), "🌙"
end

function LobbyService:RefreshTag(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = head:FindFirstChild("ASTag")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "ASTag"
		bb.Size = UDim2.fromOffset(200, 50)
		bb.StudsOffset = Vector3.new(0, 2.4, 0)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = bb
		-- ตัวหนังสือล้วน + ขอบดำบาง (ไม่มีกรอบพื้นหลัง)
		local function line(name, order, size)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.LayoutOrder = order
			t.Size = UDim2.new(1, 0, 0, size)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextSize = size
			t.TextColor3 = C(255, 255, 255)
			t.Parent = bb
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = C(10, 10, 22)
			st.Parent = t
			return t
		end
		line("VIP", 1, 16)
		line("Best", 2, 22)
		bb.Parent = head
	end
	local best = player:GetAttribute("BestNight") or 0
	local color, icon = tierColor(best)
	local bestL = bb:FindFirstChild("Best")
	bestL.Text = string.format("%s %d วัน", icon, best)
	bestL.TextColor3 = color
	local vip = bb:FindFirstChild("VIP")
	vip.Visible = player:GetAttribute("Pass_VIP") == true
	vip.Text = "👑 VIP"
	vip.TextColor3 = C(255, 214, 90)
	-- โชว์เฉพาะในล็อบบี้ (ในแมพไม่รกจอ)
	bb.Enabled = not player:GetAttribute("InRun")
end

---------------------------------------------------------------- กระดานอันดับทั้งเกม (ทุกเซิร์ฟเวอร์)
function LobbyService:BuildBoardGui(board, face)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.PixelsPerStud = 36
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = C(255, 255, 255)
	bg.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(C(54, 60, 104), C(22, 24, 44))
	g.Rotation = 90
	g.Parent = bg
	-- หัวป้าย: ริบบิ้นทอง
	local head = Instance.new("Frame")
	head.Size = UDim2.fromScale(0.86, 0.15)
	head.Position = UDim2.fromScale(0.07, 0.035)
	head.BackgroundColor3 = C(255, 255, 255)
	head.Parent = bg
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0.35, 0)
	hc.Parent = head
	local hg = Instance.new("UIGradient")
	hg.Color = ColorSequence.new(C(255, 214, 90), C(230, 140, 30))
	hg.Rotation = 90
	hg.Parent = head
	local hs = Instance.new("UIStroke")
	hs.Thickness = 5
	hs.Color = C(70, 34, 8)
	hs.Parent = head
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.94, 0.86)
	title.Position = UDim2.fromScale(0.03, 0.07)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "🏆 ผู้รอดนานสุดทั้งเกม"
	title.TextColor3 = C(255, 255, 255)
	title.Parent = head
	local ts = Instance.new("UIStroke")
	ts.Thickness = 4
	ts.Color = C(70, 34, 8)
	ts.Parent = title
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Size = UDim2.fromScale(1, 0.045)
	sub.Position = UDim2.fromScale(0, 0.195)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.Text = "กำลังโหลดอันดับ..."
	sub.TextColor3 = C(200, 205, 235)
	sub.Parent = bg
	local rows = {}
	local n = Config.LeaderboardSize
	local top, h = 0.255, 0.725 / n
	local medal = { C(255, 205, 60), C(214, 222, 236), C(222, 146, 84) }
	for i = 1, n do
		local r = Instance.new("Frame")
		r.Size = UDim2.new(0.92, 0, h * 0.84, 0)
		r.Position = UDim2.new(0.04, 0, top + (i - 1) * h, 0)
		r.BackgroundColor3 = i <= 3 and C(70, 64, 120) or C(40, 44, 78)
		r.Parent = bg
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.3, 0)
		rc.Parent = r
		if i <= 3 then
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = medal[i]
			st.Parent = r
		end
		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.fromScale(0.08, 0.9)
		rank.Position = UDim2.fromScale(0.01, 0.05)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.FredokaOne
		rank.TextScaled = true
		rank.Text = tostring(i)
		rank.TextColor3 = medal[i] or C(210, 214, 236)
		rank.Parent = r
		local face2 = Instance.new("ImageLabel")
		face2.Size = UDim2.fromScale(0.07, 0.9)
		face2.Position = UDim2.fromScale(0.095, 0.05)
		face2.BackgroundColor3 = C(24, 26, 44)
		face2.Image = ""
		face2.Parent = r
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = face2
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = face2
		local name = Instance.new("TextLabel")
		name.Size = UDim2.fromScale(0.5, 0.78)
		name.Position = UDim2.fromScale(0.19, 0.11)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = "—"
		name.TextColor3 = C(244, 244, 252)
		name.Parent = r
		local val = Instance.new("TextLabel")
		val.Size = UDim2.fromScale(0.28, 0.82)
		val.Position = UDim2.fromScale(0.7, 0.09)
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.FredokaOne
		val.TextScaled = true
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Text = ""
		val.TextColor3 = C(255, 214, 90)
		val.Parent = r
		rows[i] = { Row = r, Face = face2, Name = name, Value = val }
	end
	return { Sub = sub, Rows = rows }
end

local nameCache, thumbCache = {}, {}
local function displayName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { userId })
	if ok and infos and infos[1] then
		nameCache[userId] = infos[1].DisplayName
	else
		local ok2, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		nameCache[userId] = ok2 and n or ("ผู้เล่น " .. userId)
	end
	return nameCache[userId]
end
local function thumb(userId)
	if thumbCache[userId] == nil then
		local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		thumbCache[userId] = ok and url or ""
	end
	return thumbCache[userId]
end
local function rowsFromServer(self)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = self.ctx.Services.DataService:Get(p)
		if d and p.UserId > 0 then
			table.insert(list, { UserId = p.UserId, Value = d.BestNight or 0 })
		end
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	return list
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
		box.List = list
		local n = #list
		box.Text.Text = string.format("👤 %d/%d", n, box.Size)
		if box.Names then
			local nm = {}
			for _, p in ipairs(list) do
				table.insert(nm, p.DisplayName)
			end
			box.Names.Text = table.concat(nm, " · ")
		end
		box.Zone:SetAttribute("Size", box.Size)
		box.Zone:SetAttribute("Count", n)
		box.Zone:SetAttribute("Countdown", box.Countdown and math.max(0, math.ceil(box.Countdown)) or -1)
		box.Zone:SetAttribute("Host", list[1] and list[1].UserId or 0)
		if not worldReady then
			box.Sub.Text = string.format("⏳ กำลังสร้างโลก %d%%", math.floor((s:GetAttribute("LoadProgress") or 0) * 100))
			box.Countdown = nil
		elseif s:GetAttribute("Phase") == "Ended" then
			box.Sub.Text = "รอรอบก่อนจบ..."
			box.Countdown = nil
		elseif n == 0 then
			box.Countdown = nil
			box.Sub.Text = running and "⚔ ร่วมทีมที่เล่นอยู่" or "เดินขึ้นแท่นเพื่อเริ่ม"
			box.Pad.Color = PORTAL_VEIL
			box.Ring.Color = PORTAL_IDLE
			if box.Disc then
				box.Disc.Color, box.Edge.Color, box.Rise.Rate = PORTAL_IDLE, PORTAL_IDLE, 10
			end
			box.Pillar.Color = PORTAL_VEIL
			box.Motes.Color = ColorSequence.new(C(190, 245, 255))
			box.Motes.Rate = 8
		else
			local target = running and COUNTDOWN_JOIN or ((n >= box.Size) and COUNTDOWN_FULL or COUNTDOWN)
			box.Countdown = math.min(box.Countdown or target, target) - dt
			box.Sub.Text = string.format("ออกเดินทางใน %d", math.max(0, math.ceil(box.Countdown)))
			box.Pad.Color = PORTAL_GO_VEIL
			box.Ring.Color = PORTAL_GO
			if box.Disc then
				box.Disc.Color, box.Edge.Color, box.Rise.Rate = PORTAL_GO, PORTAL_GO, 30
			end
			box.Pillar.Color = PORTAL_GO_VEIL
			box.Motes.Color = ColorSequence.new(C(170, 255, 180))
			box.Motes.Rate = 24
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
	if not self.boardGuis then
		return
	end
	local list = self.ctx.Services.DataService:GetTop(Config.LeaderboardSize)
	local global = list ~= nil
	list = list or rowsFromServer(self)
	local vipNames = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Pass_VIP") then
			vipNames[p.UserId] = true
		end
	end
	for _, gui in ipairs(self.boardGuis) do
		gui.Sub.Text = global and "อันดับจากทุกเซิร์ฟเวอร์ · อัปเดตทุก 1 นาที" or "(ยังเชื่อมระบบเซฟไม่ได้ — โชว์เฉพาะคนในเซิร์ฟเวอร์นี้)"
		for i, r in ipairs(gui.Rows) do
			local e = list[i]
			if e and (e.Value or 0) > 0 then
				r.Name.Text = displayName(e.UserId)
				r.Name.TextColor3 = vipNames[e.UserId] and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(240, 240, 250)
				r.Value.Text = string.format("%d วัน", e.Value)
				r.Face.Image = thumb(e.UserId)
				r.Row.Visible = true
			else
				r.Name.Text = "—"
				r.Value.Text = ""
				r.Face.Image = ""
				r.Row.Visible = i <= 3
			end
		end
	end
end

function LobbyService:Start(ctx)
	ctx.Remotes.Get("LeaveRun").OnServerEvent:Connect(function(player)
		self:LeaveRun(player)
	end)
	-- ป้ายบนหัว: สร้างทุกครั้งที่เกิด + อัปเดตเมื่อสถิติ/สถานะเปลี่ยน
	local function hookTag(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			self:RefreshTag(player)
		end)
		player:GetAttributeChangedSignal("BestNight"):Connect(function()
			self:RefreshTag(player)
		end)
		player:GetAttributeChangedSignal("InRun"):Connect(function()
			self:RefreshTag(player)
		end)
		if player.Character then
			self:RefreshTag(player)
		end
		-- กลับมาจากเซิร์ฟเวอร์ของทีม: สรุปผลรอบที่แล้ว
		local okJoin, join = pcall(function()
			return player:GetJoinData()
		end)
		local td = okJoin and join and join.TeleportData
		if type(td) == "table" and td.Back and not self.IsTeamServer then
			task.delay(6, function()
				if player.Parent and td.Result == "Defeat" then
					ctx.Notify(player, string.format("🔥 รอบที่แล้ว: ทีมไปถึงคืนที่ %d — ลองใหม่อีกครั้ง!", tonumber(td.Night) or 0), "Info")
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(hookTag)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(hookTag, p)
	end
	ctx.Remotes.Get("PadSize").OnServerEvent:Connect(function(player, index, n)
		local box = self.boxes and self.boxes[tonumber(index) or 0]
		n = math.floor(tonumber(n) or 0)
		if not box or n < 1 or n > 8 or not (box.Members and box.Members[player]) then
			return
		end
		if box.List and box.List[1] ~= player then
			ctx.Notify(player, "เฉพาะหัวหน้าแท่น (คนแรกที่ขึ้น) เลือกจำนวนคนได้", "Info")
			return
		end
		box.Size = math.max(n, #(box.List or {}))
		box.Countdown = nil
	end)
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
			ctx.Notify(player, "🔺 แร่แดงไม่พอ", "Error")
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
			if t > 60 or not self.boardOnce then
				t = 0
				self.boardOnce = true
				task.spawn(function()
					local ok, err = pcall(self.RefreshBoard, self)
					if not ok then
						warn("[AS] board", err)
					end
				end)
			end
		end
	end)
end

return LobbyService
