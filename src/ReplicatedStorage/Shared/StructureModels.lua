--[[
	StructureModels — หน้าตาสิ่งก่อสร้าง (server สร้างของจริง / client ใช้ทำเงาตอนวาง)
	ทุกโมเดล: จุดหมุน (pivot) อยู่ที่พื้น ตรงกลาง, หันหน้า -Z
]]

local Items = require(script.Parent.Items)
local MeshProps = require(script.Parent.MeshProps)
local MESH_STRUCT = { LogWall = "LogWall", Bed = "Bed" }

local StructureModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

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

local function totem(m, color, glowColor)
	local base = cylY(m, 2, 5, CF(0, 1, 0), C(80, 76, 72), Enum.Material.Slate)
	local pole = P(m, V(2.6, 10, 2.6), CF(0, 7, 0), C(110, 90, 70), Enum.Material.Wood)
	for i = 0, 3 do
		P(m, V(2.8, 0.6, 2.8), CF(0, 4 + i * 2.4, 0) * ANG(0, i * 0.4, 0), color, Enum.Material.Neon)
	end
	local orb = P(m, V(3.2, 3.2, 3.2), CF(0, 13.4, 0), glowColor, Enum.Material.Neon, "Ball")
	orb.Name = "Orb"
	light(orb, glowColor, 30, 2)
	for i = 0, 3 do
		local a = i * math.pi / 2
		P(m, V(0.5, 3, 1.4), CF(math.cos(a) * 1.8, 12.6, math.sin(a) * 1.8) * ANG(0, -a, 0.3), color, Enum.Material.Neon, "Wedge")
	end
	return base, pole
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

Builders.TerraTotem = function(m)
	totem(m, C(110, 210, 80), C(150, 255, 110))
end
Builders.TideTotem = function(m)
	totem(m, C(60, 170, 240), C(110, 230, 255))
end
Builders.GaleTotem = function(m)
	totem(m, C(200, 214, 240), C(235, 245, 255))
end
Builders.EmberTotem = function(m)
	totem(m, C(240, 100, 30), C(255, 160, 60))
end

Builders.SunBeacon = function(m)
	cylY(m, 4, 10, CF(0, 2, 0), C(120, 116, 110), Enum.Material.Slate)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		P(m, V(2, 34, 2), CF(math.cos(a) * 3.4, 20, math.sin(a) * 3.4) * ANG(math.sin(a) * -0.08, 0, math.cos(a) * 0.08), C(214, 196, 150), Enum.Material.Marble)
	end
	local sun = P(m, V(7, 7, 7), CF(0, 38, 0), C(255, 236, 160), Enum.Material.Neon, "Ball")
	sun.Name = "Sun"
	light(sun, C(255, 230, 170), 60, 4, true)
	local l2 = Instance.new("SpotLight")
	l2.Face = Enum.NormalId.Bottom
	l2.Range = 60
	l2.Angle = 120
	l2.Brightness = 3
	l2.Color = C(255, 230, 170)
	l2.Parent = sun
end

function StructureModels.Build(kind)
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

StructureModels.Builders = Builders
return StructureModels
