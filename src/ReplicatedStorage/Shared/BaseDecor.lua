--[[
	BaseDecor — ของประดับฉากอลังการ ใช้ร่วมกันทั้งล็อบบี้และแคมป์ในแมพ
	ทุกฟังก์ชันรับ parent + CFrame (จุดวางบนพื้น) แล้วคืนโมเดล/ชิ้นที่สร้าง
]]

local MeshProps = require(script.Parent.MeshProps)

local BaseDecor = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB
local rad = math.rad

BaseDecor.Element = {
	Earth = C(130, 240, 100), Water = C(80, 210, 255), Air = C(225, 236, 255), Fire = C(255, 110, 30),
}

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
BaseDecor.Part = P

local function cylY(parent, h, d, cf, color, mat, extra)
	local props = { Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = cf * ANG(0, 0, math.pi / 2), Color = color, Material = mat or Enum.Material.Wood }
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return P(parent, props)
end
BaseDecor.CylY = cylY

local function light(part, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l.Parent = part
	return l
end

local function fire(part, size, color)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.4
	if color then
		f.Color = color
		f.SecondaryColor = color:Lerp(C(255, 255, 255), 0.3)
	end
	f.Parent = part
	return f
end

local function sparks(part, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate or 6
	e.Lifetime = NumberRange.new(1, 2.2)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(25, 25)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.3, 0)
	e.Color = ColorSequence.new(color or C(255, 200, 100), C(255, 80, 20))
	e.Acceleration = V(0, 3, 0)
	e.Parent = part
	return e
end

---------------------------------------------------------------- คบเพลิงบนเสา (ชามไฟเหล็ก)
function BaseDecor.Torch(parent, cf, height, color, shadows)
	height = height or 8
	local m = Instance.new("Model")
	m.Name = "TorchPost"
	cylY(m, height, 0.7, cf * CF(0, height / 2, 0), C(70, 50, 34), Enum.Material.Wood)
	P(m, { Size = V(1.4, 0.4, 1.4), CFrame = cf * CF(0, height - 0.2, 0), Color = C(46, 44, 46), Material = Enum.Material.Metal })
	for i = 0, 3 do
		local a = i * math.pi / 2
		P(m, { Size = V(0.2, 1.2, 0.2), CFrame = cf * CF(math.cos(a) * 0.65, height + 0.4, math.sin(a) * 0.65) * ANG(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), Color = C(46, 44, 46), Material = Enum.Material.Metal })
	end
	local core = P(m, { Name = "Flame", Shape = Enum.PartType.Ball, Size = V(0.9, 0.9, 0.9), CFrame = cf * CF(0, height + 0.5, 0), Color = color or C(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
	fire(core, 2.6, color)
	light(core, color or C(255, 160, 80), 22, 2.2, shadows)
	sparks(core, color, 3)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- ไฟสายโค้งระหว่างสองจุด (หลอดไฟเรืองแสง)
function BaseDecor.StringLights(parent, a, b, sag, count, color)
	count = count or 10
	sag = sag or 2
	local m = Instance.new("Model")
	m.Name = "StringLights"
	local prev = a
	for i = 1, count do
		local t = i / count
		local p = a:Lerp(b, t) - V(0, math.sin(t * math.pi) * sag, 0)
		local mid = (prev + p) / 2
		local len = (p - prev).Magnitude
		P(m, { Size = V(0.08, 0.08, len), CFrame = CFrame.lookAt(mid, p), Color = C(40, 34, 30), CanCollide = false, CanQuery = false })
		if i < count then
			local bulb = P(m, { Shape = Enum.PartType.Ball, Size = V(0.45, 0.45, 0.45), CFrame = CF(p - V(0, 0.3, 0)), Color = color or C(255, 214, 140), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			if i % 4 == 0 then
				light(bulb, color or C(255, 200, 120), 9, 1)
			end
		end
		prev = p
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------- ธงธาตุ
function BaseDecor.Banner(parent, cf, color, height)
	height = height or 14
	local m = Instance.new("Model")
	m.Name = "Banner"
	cylY(m, height, 0.6, cf * CF(0, height / 2, 0), C(66, 50, 36), Enum.Material.Wood)
	P(m, { Size = V(4, 0.4, 0.4), CFrame = cf * CF(1.6, height - 0.6, 0), Color = C(66, 50, 36), Material = Enum.Material.Wood })
	local cloth = P(m, { Size = V(3.4, height * 0.45, 0.15), CFrame = cf * CF(1.8, height - 0.9 - height * 0.225, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	P(m, { ClassName = "WedgePart", Size = V(0.15, 1.6, 1.7), CFrame = cloth.CFrame * CF(0.85, -height * 0.225 - 0.8, 0) * ANG(0, rad(90), math.pi), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	P(m, { ClassName = "WedgePart", Size = V(0.15, 1.6, 1.7), CFrame = cloth.CFrame * CF(-0.85, -height * 0.225 - 0.8, 0) * ANG(0, rad(-90), math.pi), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	local emblem = P(m, { Shape = Enum.PartType.Ball, Size = V(1.2, 1.2, 1.2), CFrame = cloth.CFrame * CF(0, 0.6, -0.15), Color = color:Lerp(C(255, 255, 255), 0.5), Material = Enum.Material.Neon, CanCollide = false })
	light(emblem, color, 8, 0.8)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- หอสังเกตการณ์
function BaseDecor.Watchtower(parent, cf, height)
	height = height or 16
	local m = Instance.new("Model")
	m.Name = "Watchtower"
	local wood, dark = C(120, 86, 56), C(78, 56, 38)
	for _, x in ipairs({ -3, 3 }) do
		for _, z in ipairs({ -3, 3 }) do
			cylY(m, height + 4, 1, cf * CF(x, (height + 4) / 2, z), dark, Enum.Material.Wood)
		end
	end
	-- ค้ำกากบาท
	for _, side in ipairs({ { 0, -3, 0 }, { 0, 3, 0 }, { -3, 0, 90 }, { 3, 0, 90 } }) do
		P(m, { Size = V(0.4, 0.4, 9), CFrame = cf * CF(side[1], height * 0.45, side[2]) * ANG(0, rad(side[3]), 0) * ANG(rad(45), 0, 0), Color = wood, Material = Enum.Material.Wood })
	end
	P(m, { Size = V(8.5, 0.8, 8.5), CFrame = cf * CF(0, height, 0), Color = wood, Material = Enum.Material.WoodPlanks })
	-- ราวกันตก
	for i = 0, 3 do
		local a = i * math.pi / 2
		P(m, { Size = V(8.5, 1.6, 0.4), CFrame = cf * CF(0, height + 1.2, 0) * ANG(0, a, 0) * CF(0, 0, 4), Color = wood, Material = Enum.Material.WoodPlanks })
	end
	-- หลังคาปิรามิด
	for i = 0, 3 do
		local a = i * math.pi / 2
		P(m, { ClassName = "WedgePart", Size = V(10, 3.6, 5), CFrame = cf * CF(0, height + 5.8, 0) * ANG(0, a, 0) * CF(0, 0, 2.5), Color = C(110, 50, 40), Material = Enum.Material.WoodPlanks })
	end
	-- บันได
	for k = 0, math.floor(height / 1.6) do
		P(m, { Size = V(2.4, 0.3, 0.3), CFrame = cf * CF(0, 1 + k * 1.6, 4.2), Color = wood, Material = Enum.Material.Wood })
	end
	P(m, { Size = V(0.3, height, 0.3), CFrame = cf * CF(-1.2, height / 2, 4.2), Color = dark })
	P(m, { Size = V(0.3, height, 0.3), CFrame = cf * CF(1.2, height / 2, 4.2), Color = dark })
	-- ไฟบนยอด
	local brazier = P(m, { Name = "Beacon", Shape = Enum.PartType.Ball, Size = V(1.6, 1.6, 1.6), CFrame = cf * CF(0, height + 1.6, 0), Color = C(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
	fire(brazier, 4)
	light(brazier, C(255, 160, 80), 40, 2.5, true)
	sparks(brazier, nil, 6)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- วงเวท (คืนชิ้นวงแหวนไว้เปลี่ยนสี)
function BaseDecor.RuneCircle(parent, cf, radius, color, transparency)
	local m = Instance.new("Model")
	m.Name = "RuneCircle"
	local rings = {}
	for _, r in ipairs({ radius, radius * 0.82 }) do
		local seg = 32
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			local len = 2 * math.pi * r / seg * 1.05
			table.insert(rings, P(m, { Size = V(len, 0.12, 0.35), CFrame = cf * CF(math.cos(a) * r, 0.12, math.sin(a) * r) * ANG(0, -a + math.pi / 2, 0), Color = color, Material = Enum.Material.Neon, Transparency = transparency or 0.2, CanCollide = false, CanQuery = false }))
		end
	end
	-- อักษรรูน: แท่งสั้นรอบวง
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local r = radius * 0.91
		table.insert(rings, P(m, { Size = V(0.3, 0.12, radius * 0.12), CFrame = cf * CF(math.cos(a) * r, 0.12, math.sin(a) * r) * ANG(0, -a + (i % 2) * 0.6, 0), Color = color, Material = Enum.Material.Neon, Transparency = transparency or 0.2, CanCollide = false, CanQuery = false }))
	end
	m.Parent = parent
	return m, rings
end

---------------------------------------------------------------- ลำแสงขึ้นฟ้า
function BaseDecor.LightPillar(parent, cf, color, height, width)
	local base = P(parent, { Name = "PillarBase", Size = V(1, 1, 1), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false })
	local top = P(parent, { Name = "PillarTop", Size = V(1, 1, 1), CFrame = cf * CF(0, height or 200, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = base
	a1.Parent = top
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width or 8
	beam.Width1 = (width or 8) * 1.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 0.6
	beam.TextureLength = 20
	beam.Parent = base
	return beam
end

---------------------------------------------------------------- ซุ้มประตูหิน + โคมแขวน
function BaseDecor.StoneArch(parent, cf, width, height, color)
	width = width or 16
	height = height or 16
	local m = Instance.new("Model")
	m.Name = "StoneArch"
	local stone = C(120, 116, 112)
	for _, x in ipairs({ -width / 2, width / 2 }) do
		for k = 0, math.floor(height / 3) - 1 do
			P(m, { Size = V(3.6 - (k % 2) * 0.4, 3, 3.6 - (k % 2) * 0.4), CFrame = cf * CF(x, 1.5 + k * 3, 0) * ANG(0, k * 0.2, 0), Color = stone:Lerp(C(90, 88, 86), (k % 3) / 3), Material = Enum.Material.Cobblestone })
		end
	end
	P(m, { Size = V(width + 5, 3, 4.2), CFrame = cf * CF(0, height + 1.5, 0), Color = C(104, 100, 96), Material = Enum.Material.Slate })
	P(m, { Size = V(width * 0.6, 1.2, 4.6), CFrame = cf * CF(0, height + 3.6, 0), Color = C(90, 86, 84), Material = Enum.Material.Slate })
	-- โคมแขวนกลางซุ้ม
	P(m, { Size = V(0.15, 2, 0.15), CFrame = cf * CF(0, height - 1, 0), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	local lantern = P(m, { Size = V(1.2, 1.6, 1.2), CFrame = cf * CF(0, height - 2.6, 0), Color = color or C(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
	light(lantern, color or C(255, 190, 110), 24, 2.2, true)
	-- รูนเรืองแสงบนเสา
	for _, x in ipairs({ -width / 2, width / 2 }) do
		P(m, { Size = V(3.8, 0.5, 3.8), CFrame = cf * CF(x, height * 0.6, 0), Color = color or C(255, 180, 90), Material = Enum.Material.Neon })
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------- เพิงหลังคา (คลุมโต๊ะช่าง)
function BaseDecor.Shelter(parent, cf, w, d, h)
	w, d, h = w or 14, d or 10, h or 8
	local m = Instance.new("Model")
	m.Name = "Shelter"
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			cylY(m, h + (z < 0 and 1.5 or 0), 0.9, cf * CF(x, (h + (z < 0 and 1.5 or 0)) / 2, z), C(86, 62, 42), Enum.Material.Wood)
		end
	end
	local roof = P(m, { Size = V(w + 3, 0.5, d + 3), CFrame = cf * CF(0, h + 0.9, 0) * ANG(rad(-9), 0, 0), Color = C(120, 70, 46), Material = Enum.Material.WoodPlanks })
	local _ = roof
	-- โคมใต้หลังคา
	local lamp = P(m, { Size = V(0.9, 1.2, 0.9), CFrame = cf * CF(0, h - 0.6, 0), Color = C(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
	light(lamp, C(255, 190, 110), 18, 1.8, true)
	m.Parent = parent
	return m
end

---------------------------------------------------------------- แท่นวิญญาณ (ลูกแก้วสีธาตุ)
function BaseDecor.SpiritPedestal(parent, cf, color, lit)
	local m = Instance.new("Model")
	m.Name = "SpiritPedestal"
	cylY(m, 1, 4.4, cf * CF(0, 0.5, 0), C(100, 96, 92), Enum.Material.Cobblestone)
	cylY(m, 3, 2.4, cf * CF(0, 2.5, 0), C(120, 116, 110), Enum.Material.Slate)
	cylY(m, 0.6, 3.4, cf * CF(0, 4.3, 0), C(100, 96, 92), Enum.Material.Slate)
	local orb = P(m, { Name = "Orb", Shape = Enum.PartType.Ball, Size = V(2.2, 2.2, 2.2), CFrame = cf * CF(0, 5.8, 0), Color = lit and color or C(60, 60, 66), Material = lit and Enum.Material.Neon or Enum.Material.Glass, CanCollide = false })
	if lit then
		light(orb, color, 16, 2)
	end
	m.Parent = parent
	return m, orb
end

---------------------------------------------------------------- ลังไม้ซ้อน
function BaseDecor.Crates(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Crates"
	local col = C(140, 100, 62)
	P(m, { Size = V(3, 3, 3), CFrame = cf * CF(0, 1.5, 0), Color = col, Material = Enum.Material.WoodPlanks })
	P(m, { Size = V(2.6, 2.6, 2.6), CFrame = cf * CF(2.9, 1.3, 0.4) * ANG(0, 0.3, 0), Color = col:Lerp(C(90, 64, 40), 0.3), Material = Enum.Material.WoodPlanks })
	P(m, { Size = V(2.4, 2.4, 2.4), CFrame = cf * CF(0.8, 4.2, 0.2) * ANG(0, 0.7, 0), Color = col, Material = Enum.Material.WoodPlanks })
	m.Parent = parent
	return m
end

---------------------------------------------------------------- ม้านั่งท่อนซุง
function BaseDecor.Bench(parent, cf, len)
	len = len or 7
	local b = cylY(parent, 2, 1.8, cf, C(110, 78, 52), Enum.Material.Wood)
	b.Size = V(len, 1.8, 1.8)
	b.CFrame = cf * CF(0, 1, 0)
	return b
end

---------------------------------------------------------------- หิ่งห้อยลอยทั่วบริเวณ
function BaseDecor.Fireflies(parent, cf, size, rate, color)
	local box = P(parent, { Name = "Fireflies", Size = size, CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate or 25
	e.Lifetime = NumberRange.new(4, 8)
	e.Speed = NumberRange.new(0.4, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(color or C(255, 230, 140))
	e.Parent = box
	return box
end

---------------------------------------------------------------- ภูเขาไกล (ฉากหลัง) + หินลอยฟ้า
function BaseDecor.Mountains(parent, center, radius, count, height)
	local m = Instance.new("Model")
	m.Name = "Mountains"
	local rng = Random.new(7)
	for i = 1, count or 22 do
		local a = i / (count or 22) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local h = (height or 260) * rng:NextNumber(0.55, 1.1)
		local w = h * rng:NextNumber(0.9, 1.4)
		local pos = center + V(math.cos(a) * radius, -h * 0.25, math.sin(a) * radius)
		local look = CFrame.lookAt(pos, V(center.X, pos.Y, center.Z))
		for k = 0, 3 do
			P(m, { ClassName = "WedgePart", Size = V(w * (1 - k * 0.12), h * (1 - k * 0.08), w * 0.55), CFrame = look * ANG(0, k * math.pi / 2, 0) * CF(0, h / 2, -w * 0.27), Color = C(70, 78, 96):Lerp(C(110, 120, 140), rng:NextNumber()), Material = Enum.Material.Slate, CanCollide = false, CanQuery = false, CastShadow = false })
		end
		if h > (height or 260) * 0.8 then
			P(m, { ClassName = "WedgePart", Size = V(w * 0.3, h * 0.22, w * 0.18), CFrame = look * CF(0, h * 0.86, -w * 0.06), Color = C(240, 244, 255), Material = Enum.Material.Snow, CanCollide = false, CanQuery = false, CastShadow = false })
		end
	end
	m.Parent = parent
	return m
end

function BaseDecor.FloatingRocks(parent, center, radius, count)
	local m = Instance.new("Model")
	m.Name = "FloatingRocks"
	local rng = Random.new(11)
	for i = 1, count or 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius * rng:NextNumber(0.9, 1.3)
		local s = rng:NextNumber(8, 22)
		local pos = center + V(math.cos(a) * r, rng:NextNumber(-30, 60), math.sin(a) * r)
		P(m, { Size = V(s, s * 0.5, s * 0.9), CFrame = CF(pos) * ANG(rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3)), Color = C(100, 96, 100), Material = Enum.Material.Slate, CanCollide = false })
		P(m, { ClassName = "WedgePart", Size = V(s * 0.8, s * 0.8, s * 0.6), CFrame = CF(pos - V(0, s * 0.6, 0)) * ANG(math.pi, a, 0), Color = C(84, 80, 84), Material = Enum.Material.Slate, CanCollide = false })
		P(m, { Size = V(s * 0.95, 0.6, s * 0.85), CFrame = CF(pos + V(0, s * 0.27, 0)) * ANG(0, a, 0), Color = C(84, 130, 64), Material = Enum.Material.Grass, CanCollide = false })
		if MeshProps.Has("GiantPine") and rng:NextNumber() < 0.7 then
			local t = MeshProps.Build("GiantPine")
			pcall(function()
				t:ScaleTo(s / 30)
			end)
			t:PivotTo(CF(pos + V(0, s * 0.3, 0)))
			t.Parent = m
		end
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------- เต็นท์ผ้าใบ A-frame (ประตูหัน -Z)
function BaseDecor.CanvasTent(parent, cf, color)
	local w, l, h = 9, 11, 6.5
	local slope = math.atan2(h, w / 2)
	local side = math.sqrt(h * h + (w / 2) ^ 2)
	for _, s in ipairs({ -1, 1 }) do
		P(parent, { Size = V(side, 0.2, l), CFrame = cf * CF(s * w / 4, h / 2, 0) * ANG(0, 0, s * -slope), Color = color, Material = Enum.Material.Fabric })
	end
	-- ปิดหัวท้ายเป็นจั่วสามเหลี่ยม (ท้าย = ผ้าใบ, หน้า = ช่องเปิดมืด)
	for _, e in ipairs({ { l / 2 - 0.1, color:Lerp(C(0, 0, 0), 0.2) }, { -l / 2 + 0.1, C(26, 22, 26) } }) do
		P(parent, { ClassName = "WedgePart", Size = V(0.15, h, w / 2), CFrame = cf * CF(w / 4, h / 2, e[1]) * ANG(0, math.rad(-90), 0), Color = e[2], Material = Enum.Material.Fabric })
		P(parent, { ClassName = "WedgePart", Size = V(0.15, h, w / 2), CFrame = cf * CF(-w / 4, h / 2, e[1]) * ANG(0, math.rad(90), 0), Color = e[2], Material = Enum.Material.Fabric })
	end
	P(parent, { Size = V(0.3, 0.3, l + 1.2), CFrame = cf * CF(0, h + 0.05, 0), Color = C(90, 70, 50), Material = Enum.Material.Wood })
	for _, z in ipairs({ -l / 2 - 0.4, l / 2 + 0.4 }) do
		P(parent, { Size = V(0.3, h + 0.4, 0.3), CFrame = cf * CF(0, h / 2, z), Color = C(90, 70, 50), Material = Enum.Material.Wood })
		-- เชือกยึด
		local a, b = (cf * CF(0, h, z)).Position, (cf * CF(0, 0.1, z + (z > 0 and 4 or -4))).Position
		P(parent, { Size = V(0.06, 0.06, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = C(220, 210, 180), CanCollide = false, CanQuery = false })
	end
end

---------------------------------------------------------------- ของใช้แคมป์ปิ้ง (สไตล์ 99 Nights)
-- ลานดินโล่งรอบกองไฟ (ขอบไม่เป็นวงกลมเป๊ะ)
function BaseDecor.DirtClearing(parent, cf, radius)
	local dirt = C(98, 80, 60)
	P(parent, { Shape = Enum.PartType.Cylinder, Size = V(3, radius * 2, radius * 2), CFrame = cf * CF(0, -1.1, 0) * ANG(0, 0, math.pi / 2), Color = dirt, Material = Enum.Material.Ground, CanCollide = false })
	local rng = Random.new(5)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local d = rng:NextNumber(10, 18)
		P(parent, { Shape = Enum.PartType.Cylinder, Size = V(2.9, d, d), CFrame = cf * CF(math.cos(a) * radius * 0.92, -1.12, math.sin(a) * radius * 0.92) * ANG(0, 0, math.pi / 2), Color = dirt:Lerp(C(80, 96, 56), rng:NextNumber(0, 0.4)), Material = Enum.Material.Ground, CanCollide = false })
	end
end

-- เสาไม้แขวนตะเกียง
function BaseDecor.LanternPost(parent, cf, h)
	h = h or 7
	local m = Instance.new("Model")
	m.Name = "LanternPost"
	cylY(m, h, 0.6, cf * CF(0, h / 2, 0), C(86, 62, 42), Enum.Material.Wood)
	P(m, { Size = V(0.3, 0.3, 2), CFrame = cf * CF(0, h - 0.3, -0.9), Color = C(86, 62, 42), Material = Enum.Material.Wood })
	P(m, { Size = V(0.08, 0.8, 0.08), CFrame = cf * CF(0, h - 0.8, -1.7), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	P(m, { Size = V(0.9, 0.15, 0.9), CFrame = cf * CF(0, h - 1.2, -1.7), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	local glass = P(m, { Size = V(0.7, 1, 0.7), CFrame = cf * CF(0, h - 1.8, -1.7), Color = C(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false })
	P(m, { Size = V(0.9, 0.15, 0.9), CFrame = cf * CF(0, h - 2.35, -1.7), Color = C(40, 36, 34), Material = Enum.Material.Metal })
	light(glass, C(255, 180, 100), 18, 1.6, false)
	m.Parent = parent
	return m
end

-- ตอไม้ผ่าฟืน + ขวานปัก
function BaseDecor.ChoppingStump(parent, cf)
	local m = Instance.new("Model")
	m.Name = "ChoppingStump"
	cylY(m, 2, 2.6, cf * CF(0, 1, 0), C(120, 88, 58), Enum.Material.Wood)
	P(m, { Shape = Enum.PartType.Cylinder, Size = V(0.1, 2.3, 2.3), CFrame = cf * CF(0, 2.02, 0) * ANG(0, 0, math.pi / 2), Color = C(196, 160, 112), Material = Enum.Material.Wood, CanCollide = false })
	P(m, { Size = V(0.25, 3, 0.25), CFrame = cf * CF(0.2, 3.2, 0) * ANG(0, 0, rad(-25)), Color = C(110, 76, 46), Material = Enum.Material.Wood, CanCollide = false })
	P(m, { Size = V(0.15, 0.7, 1.1), CFrame = cf * CF(-0.25, 2.25, 0) * ANG(0, 0, rad(-25)), Color = C(160, 160, 168), Material = Enum.Material.Metal, CanCollide = false })
	for i = 0, 2 do
		P(m, { Size = V(0.6, 0.6, 1.8), CFrame = cf * CF(1.8 + i * 0.3, 0.3, -0.8 + i * 0.9) * ANG(0, i * 0.7, rad(80)), Color = C(170, 130, 86), Material = Enum.Material.Wood })
	end
	m.Parent = parent
	return m
end

-- ถุงนอน
function BaseDecor.SleepingBag(parent, cf, color)
	P(parent, { Size = V(2.6, 0.5, 6), CFrame = cf * CF(0, 0.25, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	P(parent, { Size = V(2.2, 0.6, 1.2), CFrame = cf * CF(0, 0.45, -2.2), Color = C(230, 226, 214), Material = Enum.Material.Fabric, CanCollide = false })
end

-- เก้าอี้แคมป์พับ
function BaseDecor.CampChair(parent, cf, color)
	local m = Instance.new("Model")
	m.Name = "CampChair"
	local metal = C(60, 60, 66)
	for _, x in ipairs({ -1, 1 }) do
		P(m, { Size = V(0.15, 2.6, 0.15), CFrame = cf * CF(x * 1, 1.2, 0) * ANG(rad(30), 0, 0), Color = metal, Material = Enum.Material.Metal })
		P(m, { Size = V(0.15, 2.6, 0.15), CFrame = cf * CF(x * 1, 1.2, 0) * ANG(rad(-30), 0, 0), Color = metal, Material = Enum.Material.Metal })
	end
	P(m, { Size = V(2.2, 0.15, 1.8), CFrame = cf * CF(0, 2.2, 0), Color = color, Material = Enum.Material.Fabric })
	P(m, { Size = V(2.2, 2, 0.15), CFrame = cf * CF(0, 3.2, 0.95) * ANG(rad(-12), 0, 0), Color = color, Material = Enum.Material.Fabric })
	m.Parent = parent
	return m
end

-- กล่องเก็บความเย็น
function BaseDecor.Cooler(parent, cf)
	P(parent, { Size = V(3, 1.8, 2), CFrame = cf * CF(0, 0.9, 0), Color = C(200, 60, 50), Material = Enum.Material.SmoothPlastic })
	P(parent, { Size = V(3.1, 0.4, 2.1), CFrame = cf * CF(0, 1.95, 0), Color = C(236, 236, 236), Material = Enum.Material.SmoothPlastic })
end

-- กระเป๋าเป้
function BaseDecor.Backpack(parent, cf, color)
	P(parent, { Size = V(1.6, 2, 1), CFrame = cf * CF(0, 1, 0) * ANG(rad(-12), 0, 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	P(parent, { Size = V(1.3, 0.8, 0.5), CFrame = cf * CF(0, 0.8, -0.65) * ANG(rad(-12), 0, 0), Color = color:Lerp(C(0, 0, 0), 0.25), Material = Enum.Material.Fabric, CanCollide = false })
	P(parent, { Size = V(1.8, 0.6, 0.6), CFrame = cf * CF(0, 2.1, 0.1), Color = C(70, 110, 70), Material = Enum.Material.Fabric, CanCollide = false })
end

-- ราวตากผ้าระหว่างสองเสา
function BaseDecor.Clothesline(parent, a, b)
	local h = 6
	for _, p in ipairs({ a, b }) do
		cylY(parent, h, 0.4, CF(p + V(0, h / 2, 0)), C(86, 62, 42), Enum.Material.Wood)
	end
	local ta, tb = a + V(0, h - 0.3, 0), b + V(0, h - 0.3, 0)
	local len = (tb - ta).Magnitude
	P(parent, { Size = V(0.06, 0.06, len), CFrame = CFrame.lookAt((ta + tb) / 2 - V(0, 0.3, 0), tb - V(0, 0.3, 0)), Color = C(220, 214, 196), CanCollide = false, CanQuery = false })
	local cols = { C(196, 70, 60), C(70, 110, 170), C(220, 200, 120), C(90, 140, 90) }
	local look = CFrame.lookAt(ta, tb)
	for i = 1, 4 do
		local t = i / 5
		local p = ta:Lerp(tb, t) - V(0, 0.4 + math.sin(t * math.pi) * 0.3, 0)
		P(parent, { Size = V(0.08, 1.8, 1.6), CFrame = CF(p - V(0, 0.9, 0)) * (look - look.Position) * ANG(0, math.pi / 2, 0), Color = cols[i], Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false })
	end
end

return BaseDecor
