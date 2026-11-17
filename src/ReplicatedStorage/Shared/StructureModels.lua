--[[
	StructureModels — หน้าตาสิ่งก่อสร้าง (server สร้างของจริง / client ใช้ทำเงาตอนวาง)
	ทุกโมเดล: จุดหมุน (pivot) อยู่ที่พื้น ตรงกลาง, หันหน้า -Z
]]

local Items = require(script.Parent.Items)
local MeshProps = require(script.Parent.MeshProps)
local ItemModels = require(script.Parent.ItemModels)
local MESH_STRUCT = { LogWall = "LogWall", Bed = "Bed" }

local StructureModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB
local TOTEM_GLOW = { TerraTotem = C(150, 255, 110), TideTotem = C(110, 230, 255), GaleTotem = C(225, 240, 255), EmberTotem = C(255, 130, 50) }

local function P(model, size, cf, color, material, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function cylY(model, h, d, cf, color, material)
	return P(model, V(h, d, d), cf * ANG(0, 0, math.pi / 2), color, material, "Cylinder")
end

local function light(part, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l.Parent = part
	return l
end

local Builders = {}

Builders.LogWall = function(m)
	for i = 0, 4 do
		cylY(m, 10 + (i % 2) * 1.2, 2.5, CF(-4.8 + i * 2.4, 5 + (i % 2) * 0.6, 0), C(120, 84, 54), Enum.Material.Wood)
		P(m, V(1.2, 1.4, 1.2), CF(-4.8 + i * 2.4, 10.6 + (i % 2) * 1.2, 0) * ANG(0, 0.78, 0), C(140, 100, 64), Enum.Material.Wood, "Wedge")
	end
	P(m, V(12, 0.8, 0.6), CF(0, 3, -1.3), C(90, 64, 42), Enum.Material.Wood)
	P(m, V(12, 0.8, 0.6), CF(0, 7.5, -1.3), C(90, 64, 42), Enum.Material.Wood)
end

Builders.StoneWall = function(m)
	for row = 0, 3 do
		for i = 0, 3 do
			local off = (row % 2) * 1.5
			P(m, V(3, 3, 3.5), CF(-4.5 + i * 3 + off, 1.5 + row * 3, 0), (i + row) % 2 == 0 and C(130, 128, 124) or C(112, 110, 108), Enum.Material.Cobblestone)
		end
	end
	for i = 0, 3 do
		P(m, V(1.6, 1.6, 1.6), CF(-4.5 + i * 3, 12.8, 0) * ANG(0.3, 0.6, 0), C(150, 146, 140), Enum.Material.Slate)
	end
end

-- ประตูไม้: ผนังไม้ยาวเท่ากำแพง (ต่อกับกำแพงได้) + ช่องประตูกลาง + บาน "Leaf" (หมุนรอบ "Hinge" · StorageService เปิด/ปิด)
Builders.WoodDoor = function(m)
	local wood, dark, plank = C(120, 84, 54), C(84, 58, 38), C(146, 100, 60)
	for _, sx in ipairs({ -1, 1 }) do
		P(m, V(3.4, 10, 2), CF(sx * 4.3, 5, 0), wood, Enum.Material.WoodPlanks)
		P(m, V(0.5, 10, 2.4), CF(sx * 2.6, 5, 0), dark, Enum.Material.Wood)
		P(m, V(0.6, 10.4, 2.4), CF(sx * 5.8, 5.2, 0), dark, Enum.Material.Wood)
	end
	P(m, V(5.2, 2, 2), CF(0, 9, 0), wood, Enum.Material.WoodPlanks)
	P(m, V(12.2, 0.6, 2.5), CF(0, 10.1, 0), dark, Enum.Material.Wood)
	local leaf = Instance.new("Model")
	leaf.Name = "Leaf"
	leaf.Parent = m
	P(leaf, V(4.6, 7.9, 0.5), CF(0, 3.98, 0), plank, Enum.Material.WoodPlanks).Name = "Panel"
	for _, y in ipairs({ 1.6, 6.3 }) do
		P(leaf, V(4.4, 0.45, 0.2), CF(0, y, -0.35), dark, Enum.Material.Wood)
	end
	P(leaf, V(0.35, 5, 0.2), CF(0, 3.95, -0.35) * ANG(0, 0, 0.9), dark, Enum.Material.Wood)
	P(leaf, V(0.35, 0.35, 0.5), CF(1.8, 4, -0.5), C(60, 60, 64), Enum.Material.Metal)
	local hinge = P(leaf, V(0.3, 7.9, 0.3), CF(-2.3, 3.98, 0), C(0, 0, 0))
	hinge.Name, hinge.Transparency, hinge.CanCollide, hinge.CanQuery = "Hinge", 1, false, false
	local anchor = P(m, V(1, 1, 1), CF(0, 4, 0), C(0, 0, 0))
	anchor.Name, anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = "PromptAnchor", 1, false, false, false
end

-- กล่องเก็บของไม้ (กล่อง + ฝา + ขอบไม้มุม + แถบเหล็ก + กลอน) · กล่องใหญ่ = กล่องคู่ (กลอน 2 อัน)
local function storageBox(m, w, double)
	local d, h, lh = 3.2, 2.6, 1
	local body = P(m, V(w, h, d), CF(0, h / 2, 0), C(156, 108, 62), Enum.Material.WoodPlanks)
	body.Name = "Body"
	P(m, V(w + 0.2, lh, d + 0.2), CF(0, h + lh / 2, 0), C(138, 94, 54), Enum.Material.WoodPlanks).Name = "Lid"
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(m, V(0.4, h + lh + 0.05, 0.4), CF(sx * w / 2, (h + lh) / 2, sz * d / 2), C(92, 64, 40), Enum.Material.Wood)
		end
	end
	if double then
		P(m, V(0.35, h + lh, d + 0.3), CF(0, (h + lh) / 2, 0), C(92, 64, 40), Enum.Material.Wood)
	end
	P(m, V(w + 0.26, 0.22, d + 0.26), CF(0, h, 0), C(78, 78, 84), Enum.Material.Metal)
	P(m, V(w + 0.22, 0.18, d + 0.22), CF(0, 0.5, 0), C(78, 78, 84), Enum.Material.Metal)
	for _, x in ipairs(double and { -w / 4, w / 4 } or { 0 }) do
		P(m, V(0.7, 0.9, 0.2), CF(x, h - 0.05, -d / 2 - 0.2), C(196, 196, 204), Enum.Material.Metal)
	end
end
Builders.StorageBox = function(m)
	storageBox(m, 4.4, false)
end
Builders.BigStorageBox = function(m)
	storageBox(m, 8.6, true)
end

Builders.SpikeTrap = function(m)
	P(m, V(8, 0.6, 8), CF(0, 0.3, 0), C(90, 64, 42), Enum.Material.WoodPlanks)
	for x = -1, 1 do
		for z = -1, 1 do
			local s = P(m, V(0.6, 2.4, 0.9), CF(x * 2.6, 1.5, z * 2.6) * ANG(0.15 * z, 0, -0.15 * x), C(200, 190, 170), Enum.Material.SmoothPlastic, "Wedge")
			s.Name = "Spike"
		end
	end
end

Builders.Lantern = function(m)
	cylY(m, 8, 0.6, CF(0, 4, 0), C(60, 56, 54), Enum.Material.Metal)
	P(m, V(2, 0.4, 2), CF(0, 0.2, 0), C(70, 66, 62), Enum.Material.Metal)
	local glass = P(m, V(1.6, 2, 1.6), CF(0, 8.6, 0), C(255, 214, 140), Enum.Material.Neon)
	glass.Name = "Glow"
	P(m, V(2, 0.4, 2), CF(0, 9.8, 0), C(50, 46, 44), Enum.Material.Metal)
	light(glass, C(255, 200, 120), Items.Structures.Lantern.Light, 2.2, true)
end

Builders.Ballista = function(m)
	cylY(m, 2.4, 6, CF(0, 1.2, 0), C(100, 74, 50), Enum.Material.WoodPlanks)
	local turret = Instance.new("Model")
	turret.Name = "Turret"
	local body = P(turret, V(1.6, 1.4, 6), CF(0, 4.2, 0), C(130, 94, 62), Enum.Material.Wood)
	body.Name = "Pivot"
	P(turret, V(7, 0.6, 0.8), CF(0, 4.6, -2.2), C(110, 80, 52), Enum.Material.Wood)
	P(turret, V(0.4, 0.4, 5), CF(0, 5.1, -0.5), C(200, 196, 186), Enum.Material.Metal)
	P(turret, V(0.8, 0.8, 0.8), CF(0, 5.1, -3.2) * ANG(0.78, 0.78, 0), C(220, 220, 230), Enum.Material.Metal)
	turret.PrimaryPart = body
	turret.Parent = m
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		P(m, V(0.6, 3.4, 0.6), CF(math.cos(a) * 1.6, 2.6, math.sin(a) * 1.6) * ANG(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), C(90, 64, 42), Enum.Material.Wood)
	end
end

Builders.Bed = function(m)
	P(m, V(5, 1, 8), CF(0, 0.8, 0), C(110, 78, 50), Enum.Material.WoodPlanks)
	P(m, V(4.6, 0.8, 7), CF(0, 1.6, 0.3), C(180, 140, 100), Enum.Material.Fabric)
	P(m, V(4, 0.8, 1.6), CF(0, 2.1, 2.9), C(236, 226, 206), Enum.Material.Fabric)
	P(m, V(4.6, 0.3, 4.4), CF(0, 2.1, -1.2), C(160, 60, 50), Enum.Material.Fabric)
end

Builders.Bed2 = Builders.Bed

Builders.FarmPlot = function(m)
	P(m, V(10, 1, 10), CF(0, 0.5, 0), C(90, 64, 44), Enum.Material.Ground)
	for i = 0, 3 do
		local a = i * math.pi / 2
		P(m, V(10.6, 1.4, 0.6), CF(0, 0.7, 0) * ANG(0, a, 0) * CF(0, 0, 5.1), C(120, 84, 54), Enum.Material.Wood)
	end
	local crops = Instance.new("Model")
	crops.Name = "Crops"
	for x = -1, 1 do
		for z = -1, 1 do
			local p = P(crops, V(1.6, 1.6, 1.6), CF(x * 3, 1.6, z * 3), C(70, 140, 60), Enum.Material.LeafyGrass, "Ball")
			p.Name = "Crop"
		end
	end
	crops.Parent = m
end

Builders.CookPot = function(m)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		P(m, V(0.5, 5, 0.5), CF(math.cos(a) * 2, 2.4, math.sin(a) * 2) * ANG(math.sin(a) * 0.2, 0, -math.cos(a) * 0.2), C(70, 64, 60), Enum.Material.Metal)
	end
	local pot = P(m, V(3.6, 3.6, 3.6), CF(0, 2.4, 0), C(50, 48, 50), Enum.Material.Metal, "Ball")
	pot.Name = "Pot"
	local soup = cylY(m, 0.2, 3, CF(0, 3.8, 0), C(214, 130, 60), Enum.Material.Neon)
	soup.Name = "Soup"
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = P(m, V(1, 1, 1), CF(0, 0.5, 0), C(255, 140, 40), Enum.Material.Neon)
end

Builders.SunBeacon = function(m)
	cylY(m, 4, 10, CF(0, 2, 0), C(120, 116, 110), Enum.Material.Slate)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		P(m, V(2, 34, 2), CF(math.cos(a) * 3.4, 20, math.sin(a) * 3.4) * ANG(math.sin(a) * -0.08, 0, math.cos(a) * 0.08), C(214, 196, 150), Enum.Material.Marble)
	end
	local sun = P(m, V(7, 7, 7), CF(0, 38, 0), C(255, 236, 160), Enum.Material.Neon, "Ball")
	sun.Name = "Sun"
	sun.Transparency = 0.6 -- ลดความจ้า 60%
	light(sun, C(255, 230, 170), 60, 1.6, true)
	local l2 = Instance.new("SpotLight")
	l2.Face = Enum.NormalId.Bottom
	l2.Range = 60
	l2.Angle = 120
	l2.Brightness = 1.2
	l2.Color = C(255, 230, 170)
	l2.Parent = sun
end

-- หินวาร์ป (Teleporter): ลานหินแกะลาย (Store: PlazaCircleLP) + หินรูน 3 ก้อนล้อม (Store: RuneStoneLP) + วงแสงฟ้า + ประกายลอยขึ้น
--   "Pad" = จุดกด E (TeleporterService ใส่ปุ่ม) · ไม่มีโมเดล Store = จานหิน + แท่งหินปั้นแทน
local TP_COLOR = C(110, 220, 255)
Builders.Teleporter = function(m)
	local PropBuilder = require(script.Parent.PropBuilder) -- โหลดตอนใช้ (PropBuilder ไม่ได้ require โมดูลนี้ -> ไม่วน)
	local floor = PropBuilder.Imported("PlazaCircleLP", CF(0, 0.05, 0), 9.5, m, true)
	local top = 0.6
	if floor then
		-- โมเดลลานถูกหมุนให้ตั้งขึ้นตอนนำเข้า -> Imported วัดก้นผิดแกน (ลานลอยเหนือพื้น ~4.7 stud · ผู้เล่นยืนลอยตาม)
		--   วัดกล่องแนวโลกใหม่ แล้วเลื่อนลงให้ก้นลานแตะพื้นพอดี
		local bcf, bs = floor:GetBoundingBox()
		local bottom = bcf.Position.Y - bs.Y / 2
		floor:PivotTo(floor:GetPivot() - V(0, bottom - 0.02, 0))
		bcf, bs = floor:GetBoundingBox()
		top = bcf.Position.Y + bs.Y / 2
	else
		cylY(m, 0.6, 9.5, CF(0, 0.3, 0), C(140, 136, 130), Enum.Material.Slate)
	end
	-- ฐานหินใต้ลาน (จมดิน): วางบนพื้นเอียง/ขอบเนิน ลานไม่ลอยเห็นช่องใต้ (ส่วนที่พื้นต่ำลงไปเห็นเป็นแท่นหินแทน)
	local base = cylY(m, 8, 9.3, CF(0, top - 4.15, 0), C(118, 114, 108), Enum.Material.Slate)
	base.Name = "Foundation"
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + math.pi / 2
		-- หินรูนตั้งบนขอบลาน (ฐานจมลงผิวลานนิดหน่อย ไม่ลอย)
		local p = V(math.cos(a) * 3.9, top - 0.25, math.sin(a) * 3.9)
		local st = PropBuilder.Imported("RuneStoneLP", CFrame.lookAt(p, V(0, p.Y, 0)), 2.3, m, true)
		local stTop = p.Y + 4.2
		if st then
			local scf, ss = st:GetBoundingBox()
			stTop = scf.Position.Y + ss.Y / 2
		else
			P(m, V(1.4, 4.2, 0.9), CFrame.lookAt(p + V(0, 2.1, 0), V(0, p.Y + 2.1, 0)), C(120, 118, 114), Enum.Material.Slate)
		end
		-- รูนเรืองแสงฝังบนยอดหิน (เดิมลอยเหนือหิน 0.6 = ดูเหมือนชิ้นส่วนหลุดลอย)
		local rune = P(m, V(0.6, 0.6, 0.6), CF(p.X, stTop - 0.12, p.Z), TP_COLOR, Enum.Material.Neon, "Ball")
		rune.Name = "Rune"
		rune.CanCollide = false
	end
	local ring = cylY(m, 0.12, 7.2, CF(0, top + 0.06, 0), TP_COLOR, Enum.Material.Neon)
	ring.Name = "Ring"
	ring.Transparency = 0.35
	ring.CanCollide = false
	local inner = cylY(m, 0.13, 6.4, CF(0, top + 0.065, 0), C(30, 60, 80), Enum.Material.SmoothPlastic)
	inner.Name = "RingInner"
	inner.Transparency = 0.2
	inner.CanCollide = false
	-- จุดกด + แสง + ประกาย (ล่องหน ไม่ชน)
	local pad = P(m, V(6, 0.4, 6), CF(0, top + 0.4, 0), C(0, 0, 0))
	pad.Name, pad.Transparency, pad.CanCollide = "Pad", 1, false
	light(pad, TP_COLOR, 16, 1.6, false)
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Motes"
	fx.Rate = 14
	fx.Lifetime = NumberRange.new(1.4, 2.4)
	fx.Speed = NumberRange.new(2, 4)
	fx.SpreadAngle = Vector2.new(8, 8)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fx.Color = ColorSequence.new(TP_COLOR)
	fx.LightEmission = 1
	fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fx.Parent = pad
end

-- สิ่งก่อสร้างที่ใช้โมเดลจาก Creator Store (ด้านยาวสุด, stud)
-- เสา 4 ธาตุ = โมเดลใหม่ 3D Model/เสา (Import 3D -> assets/rbxm/Items/<ชื่อ>.rbxmx) สูง 10 · โมเดลเก่าลบทิ้งแล้ว
local STORE_STRUCT = { TerraTotem = 10, TideTotem = 10, GaleTotem = 10, EmberTotem = 10, CookPot = 7, SpikeTrap = 8, FarmPlot = 10, Lantern = 9, Bed = 8, Bed2 = 8, Ballista = 8, SunBeacon = 40, LogWall = 11, StoneWall = 12 }
local STORE_YAW = { LogWall = 90 } -- เตียง (Meshy): หัวเตียงอยู่ +Z ตรงกับเกมอยู่แล้ว

function StructureModels.Build(kind)
	if STORE_STRUCT[kind] and ItemModels.Has(kind) then
		if kind == "Ballista" then
			return StructureModels.StoreBallista()
		end
		local m, box = ItemModels.Clone(kind, STORE_STRUCT[kind], { Ground = true, Yaw = STORE_YAW[kind] })
		m.Name = kind
		local walkThrough = kind == "SpikeTrap" or kind == "FarmPlot"
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				-- โมเดล Store แปลงมาแบบทะลุได้ -> สิ่งก่อสร้างต้องชนจริง
				p.CanCollide = not walkThrough and p.Transparency < 0.95
				p.CanQuery = true
			end
		end
		if kind == "SunBeacon" then
			-- แสงสุริยะบนยอดหอ (ส่องไกล)
			local glow = P(m, V(2, 2, 2), CF(0, box.Y * 0.82, 0), C(0, 0, 0))
			glow.Name, glow.Transparency, glow.CanCollide = "Glow", 1, false
			light(glow, C(255, 230, 160), Items.Structures.SunBeacon.Light, 1.2, false) -- เดิม 3 (แสบตา) -> ลด 60%
			-- ลูกแก้วเรืองแสง (Neon) บนยอด: โปร่งขึ้น = เรืองน้อยลง ไม่จ้าแสบตา
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
					p.Transparency = math.max(p.Transparency, 0.6)
				end
			end
		elseif kind == "Lantern" then
			-- ไฟในโคม (ส่วนบนของเสา)
			local glow = P(m, V(1, 1, 1), CF(0, box.Y * 0.62, 0), C(0, 0, 0))
			glow.Name, glow.Transparency, glow.CanCollide = "Glow", 1, false
			light(glow, C(255, 200, 120), Items.Structures.Lantern.Light, 2.2, true)
		elseif kind == "CookPot" then
			-- จุดกดทำอาหาร (ตรงหม้อที่แขวนบนขาตั้ง) + ไฟใต้หม้อ
			local pot = P(m, V(3, 3, 3), CF(0, box.Y * 0.5, 0), C(0, 0, 0))
			pot.Name, pot.Transparency, pot.CanCollide = "Pot", 1, false
			local fire = Instance.new("Fire")
			fire.Size, fire.Heat = 3, 4
			fire.Parent = P(m, V(1, 0.4, 1), CF(0, 0.4, 0), C(0, 0, 0))
			fire.Parent.Transparency, fire.Parent.CanCollide = 1, false
		elseif kind == "FarmPlot" then
			StructureModels.AddCrops(m, box)
		elseif TOTEM_GLOW[kind] then
			-- เสาธาตุ: แสงสีธาตุส่องพื้นรอบเสา (ช่องเรืองแสงบนตัวเสามาจากเท็กซ์เจอร์)
			local orb = P(m, V(1, 1, 1), CF(0, box.Y * 0.75, 0), C(0, 0, 0))
			orb.Name, orb.Transparency, orb.CanCollide, orb.CanQuery = "Orb", 1, false, false
			light(orb, TOTEM_GLOW[kind], 24, 1.6)
		end
		return m
	end
	if MESH_STRUCT[kind] and MeshProps.Has(MESH_STRUCT[kind]) then
		local m = MeshProps.Build(MESH_STRUCT[kind], { Collide = "box" })
		m.Name = kind
		return m
	end
	local b = Builders[kind]
	if not b then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = kind
	b(m)
	m.WorldPivot = CF(0, 0, 0)
	return m
end

-- แปลงเบอร์รี่: พุ่มเบอร์รี่ (โมเดล Store เดียวกับในป่า) 1 พุ่มต่อแปลงย่อย 6 แปลง
--   ลูก = ชิ้นเล็กชื่อ "Berry" (BuildingService ซ่อนตอนยังไม่โต / โชว์ตอนเก็บได้)
local CROP_X = { -0.323, 0.005, 0.326 } -- ศูนย์กลางแปลงย่อย (สัดส่วนของกล่องโมเดล)
local CROP_Z = { -0.273, 0.274 }
function StructureModels.AddCrops(m, box)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Props") and assets.Props:FindFirstChild("BerryBushLP")
	if not src then
		return
	end
	local crops = Instance.new("Model")
	crops.Name = "Crops"
	local soil = box.Y * (1 / 5.5) -- ผิวดินในแปลง (ต้นฉบับสูง 5.5 ดินหนา 1)
	for _, x in ipairs(CROP_X) do
		for _, z in ipairs(CROP_Z) do
			local b = src:Clone()
			b.Name = "Bush"
			local biggest = 0
			for _, p in ipairs(b:GetDescendants()) do
				if p:IsA("BasePart") then
					biggest = math.max(biggest, p.Size.Magnitude)
				end
			end
			for _, p in ipairs(b:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
					if p.Size.Magnitude < biggest * 0.3 then
						p.Name = "Berry"
					end
				end
			end
			local _, size = b:GetBoundingBox()
			pcall(function()
				b:ScaleTo(math.min(box.X * 0.24, box.Z * 0.36) / math.max(size.X, size.Z))
			end)
			local cf, sz = b:GetBoundingBox()
			local off = CF(x * box.X, soil + sz.Y / 2, z * box.Z) * CF(-cf.Position)
			for _, p in ipairs(b:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = off * p.CFrame
				end
			end
			b.Parent = crops
		end
	end
	crops.Parent = m
end

-- หน้าไม้ยักษ์: ฐานไม้ + หน้าไม้จาก Creator Store (Turret หมุนเล็งสัตว์ได้)
function StructureModels.StoreBallista()
	local m = Instance.new("Model")
	m.Name = "Ballista"
	cylY(m, 2.4, 6, CF(0, 1.2, 0), C(100, 74, 50), Enum.Material.WoodPlanks)
	P(m, V(1.2, 1.4, 1.2), CF(0, 3.1, 0), C(80, 60, 42), Enum.Material.Wood)
	local turret = ItemModels.Clone("Ballista", STORE_STRUCT.Ballista)
	turret.Name = "Turret"
	-- หันลูกศรไปทาง -Z แนวนอน (ทิศหน้าที่ BuildingService ใช้เล็ง)
	--   โมเดลต้นฉบับเป็น Tool ถือมือ = ตั้งแนวดิ่ง -> ต้องหมุนทั้งก้ม/เงย ไม่ใช่แค่ซ้ายขวา
	--   ปลายลูกศร = ฝั่งที่ลูกศรยื่นเลยกลางโมเดล (ด้านคันธนู)
	local arrow = turret:FindFirstChild("Arrow", true)
	if arrow then
		local s = arrow.Size
		local axis = (s.X >= s.Y and s.X >= s.Z) and arrow.CFrame.RightVector or (s.Y >= s.Z and arrow.CFrame.UpVector or arrow.CFrame.LookVector)
		local center = turret:GetBoundingBox().Position
		if axis:Dot(arrow.Position - center) < 0 then
			axis = -axis
		end
		local r = CFrame.fromRotationBetweenVectors(axis, Vector3.new(0, 0, -1))
		for _, p in ipairs(turret:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CFrame = r * p.CFrame
			end
		end
	end
	-- วางหน้าไม้บนหัวเสา (ไม่จมเข้าไปในฐาน)
	local top = 3.8
	local tcf, tsize = turret:GetBoundingBox()
	local lift = CF(-tcf.X, top + tsize.Y / 2 - tcf.Y, -tcf.Z)
	for _, p in ipairs(turret:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = lift * p.CFrame
			p.Anchored = true
		end
	end
	local pivot = P(turret, V(0.5, 0.5, 0.5), CF(0, top + tsize.Y / 2, 0), C(0, 0, 0))
	pivot.Name, pivot.Transparency, pivot.CanCollide = "Pivot", 1, false
	turret.PrimaryPart = pivot
	turret.Parent = m
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	m.WorldPivot = CF(0, 0, 0)
	return m
end

StructureModels.Builders = Builders
return StructureModels
