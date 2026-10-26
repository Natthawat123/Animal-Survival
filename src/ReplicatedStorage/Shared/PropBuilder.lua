--[[
	PropBuilder — ปั้นและวางของทั้งโลก (ต้นไม้ หิน คริสตัล ปะการัง ภูเขาไฟเล็ก ฯลฯ) + สถานที่พิเศษ
	ใช้ทั้ง Server (ตอนเล่น) และปลั๊กอิน (ตอน Edit)

	เทคนิค: ปั้น "แม่แบบ" ของแต่ละชนิดครั้งเดียวด้วย CSG (Union/Intersect) แล้วโคลน -> ต้นไม้ 1 ต้น = 2-3 ชิ้น
	ถ้ามีโมเดลจาก Blender ใน ReplicatedStorage.Assets.Props.<Kind> จะใช้โมเดลนั้นแทน

	ของที่เก็บได้ติดแท็ก "ResourceNode" + attributes:
		Node = "Tree" | "Rock" | "Crystal" | "Bush"
		Yield = item id, HP = ค่าความทน, YieldPerHP = ได้ของกี่ชิ้นต่อดาเมจ 1 หน่วย
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(script.Parent.Biomes)
local MeshProps = require(script.Parent.MeshProps)
local BaseDecor = require(script.Parent.BaseDecor)
local SiteSpec = require(script.Parent.SiteSpec)

local PropBuilder = {}

local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local tempFolder: Folder? = nil
local templates = {}
local storeTemplates -- ประกาศก่อน (ใช้ใน LavaVent ที่อยู่ก่อนนิยาม)

---------------------------------------------------------------- helpers
local function P(className, props, parent)
	local p = Instance.new(className)
	p.Anchored = true
	if p:IsA("BasePart") then
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	for k, v in pairs(props) do
		p[k] = v
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function getTemp()
	if not tempFolder or not tempFolder.Parent then
		tempFolder = Instance.new("Folder")
		tempFolder.Name = "_ASPropTemp"
		tempFolder.Parent = workspace
	end
	return tempFolder
end

-- รวมชิ้น (Union) ถ้าทำไม่ได้ คืนค่าเป็น Model ของชิ้นเดิม
local function union(parts, props)
	if #parts == 1 then
		for k, v in pairs(props or {}) do
			parts[1][k] = v
		end
		return parts[1]
	end
	-- CSG ไม่รู้จัก SpecialMesh -> เปลี่ยนทรงรีเป็นทรงกลมจริงก่อนรวม
	for _, p in ipairs(parts) do
		local mesh = p:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then
			local s = p.Size
			mesh:Destroy()
			p.Shape = Enum.PartType.Ball
			local d = (s.X + s.Y + s.Z) / 3
			p.Size = V(d, d, d)
		end
	end
	local ok, res = pcall(function()
		local base = parts[1]
		local rest = {}
		for i = 2, #parts do
			rest[i - 1] = parts[i]
		end
		return base:UnionAsync(rest, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
	end)
	if ok and res then
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		res.UsePartColor = true
		for k, v in pairs(props or {}) do
			res[k] = v
		end
		return res
	end
	local m = Instance.new("Model")
	for _, p in ipairs(parts) do
		for k, v in pairs(props or {}) do
			if k ~= "Name" then
				p[k] = v
			end
		end
		p.Parent = m
	end
	return m
end

-- พีระมิดฐานสี่เหลี่ยม (Intersect wedge 4 ชิ้น) ฐาน b สูง h วางบน cf
local function pyramid(b, h, cf, props)
	local temp = getTemp()
	local wedges = {}
	for i = 0, 3 do
		table.insert(wedges, P("WedgePart", {
			Size = V(b, 2 * h, b),
			CFrame = cf * ANG(0, i * math.pi / 2, 0) * CF(0, h, 0),
		}, temp))
	end
	local ok, res = pcall(function()
		return wedges[1]:IntersectAsync({ wedges[2], wedges[3], wedges[4] }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
	end)
	for _, w in ipairs(wedges) do
		w:Destroy()
	end
	if ok and res then
		res.UsePartColor = true
		for k, v in pairs(props or {}) do
			res[k] = v
		end
		res.Parent = temp
		return res
	end
	-- สำรอง: ทรงรีแหลม
	local p = P("Part", { Size = V(b * 0.8, h, b * 0.8), CFrame = cf * CF(0, h / 2, 0) }, temp)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

local function ellipsoid(size, cf, props, parent)
	local p = P("Part", { Size = size, CFrame = cf, Shape = Enum.PartType.Ball }, parent or getTemp())
	if size.X ~= size.Y or size.Y ~= size.Z then
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

local function cylinderY(height, diameter, cf, props, parent)
	-- Cylinder ของ Roblox ตั้งตามแกน X -> หมุนให้ตั้งขึ้น
	local p = P("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = V(height, diameter, diameter),
		CFrame = cf * ANG(0, 0, math.pi / 2),
	}, parent or getTemp())
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- ชิ้นหินเหลี่ยม (block หมุนเอียง 3 ชิ้น รวมกัน)
local function rockShape(size, seed, props)
	local rng = Random.new(seed)
	local parts = {}
	for i = 1, 3 do
		local s = size * V(rng:NextNumber(0.6, 1), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.6, 1)) * (i == 1 and 1 or 0.75)
		local off = V(rng:NextNumber(-0.25, 0.25) * size.X, s.Y * 0.35, rng:NextNumber(-0.25, 0.25) * size.Z)
		table.insert(parts, P("Part", {
			Size = s,
			CFrame = CF(off) * ANG(rad(rng:NextNumber(-25, 25)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-25, 25))),
		}, getTemp()))
	end
	return union(parts, props)
end

-- คริสตัลแท่ง (block + ปลายแหลม)
local function crystalShard(width, height, cf, props)
	local body = P("Part", { Size = V(width, height * 0.7, width), CFrame = cf * CF(0, height * 0.35, 0) * ANG(0, rad(45), 0) }, getTemp())
	local tip = pyramid(width * 1.0, height * 0.3, cf * CF(0, height * 0.7, 0) * ANG(0, rad(45), 0), {})
	return union({ body, tip }, props)
end

local function finishTemplate(kind, model)
	model.Name = kind
	if model:IsA("Model") then
		model.WorldPivot = CF(0, 0, 0)
	elseif model:IsA("BasePart") then
		model.PivotOffset = model.CFrame:Inverse()
	end
	model.Parent = getTemp()
	return model
end

local function wrap(kind, children)
	local m = Instance.new("Model")
	m.Name = kind
	for _, c in ipairs(children) do
		c.Parent = m
	end
	m.WorldPivot = CF(0, 0, 0)
	return m
end

---------------------------------------------------------------- แม่แบบแต่ละชนิด
local Kinds = {}
PropBuilder.Kinds = Kinds

local function pine(kind, foliageColor, foliageMat, trunkColor, snow)
	local tiers = {}
	local y = 7
	local base, h = 17, 13
	for i = 1, 4 do
		table.insert(tiers, pyramid(base, h, CF(0, y, 0) * ANG(0, rad(i * 22), 0), {}))
		y += h * 0.55
		base *= 0.74
		h *= 0.84
	end
	local foliage = union(tiers, { Name = "Foliage", Color = foliageColor, Material = foliageMat, CanCollide = false })
	local trunk = cylinderY(16, 2.6, CF(0, 8, 0), { Name = "Trunk", Color = trunkColor, Material = Enum.Material.Wood })
	local children = { trunk, foliage }
	if snow then
		local cap = pyramid(7.5, 6.5, CF(0, y - 2, 0), { Name = "Snow", Color = C(240, 246, 255), Material = Enum.Material.Snow, CanCollide = false })
		table.insert(children, cap)
	end
	return wrap(kind, children)
end

local function broadTree(kind, leafColor, trunkColor, height, canopy)
	local trunk = cylinderY(height, 3.2, CF(0, height / 2, 0), { Name = "Trunk", Color = trunkColor, Material = Enum.Material.Wood })
	local branchA = cylinderY(height * 0.45, 1.6, CF(2.2, height * 0.75, 0) * ANG(0, 0, rad(-35)), { Color = trunkColor, Material = Enum.Material.Wood })
	local branchB = cylinderY(height * 0.4, 1.4, CF(-2, height * 0.7, 1) * ANG(rad(20), 0, rad(38)), { Color = trunkColor, Material = Enum.Material.Wood })
	local wood = union({ trunk, branchA, branchB }, { Name = "Trunk", Color = trunkColor, Material = Enum.Material.Wood })
	local blobs = {}
	local rng = Random.new(#kind * 31 + height)
	for i = 1, 6 do
		local s = canopy * rng:NextNumber(0.55, 0.85)
		local ang = i / 6 * math.pi * 2
		table.insert(blobs, ellipsoid(V(s, s * 0.8, s), CF(math.cos(ang) * canopy * 0.35, height + rng:NextNumber(-2, 4), math.sin(ang) * canopy * 0.35)))
	end
	table.insert(blobs, ellipsoid(V(canopy, canopy * 0.75, canopy), CF(0, height + canopy * 0.25, 0)))
	local leaves = union(blobs, { Name = "Foliage", Color = leafColor, Material = Enum.Material.LeafyGrass, CanCollide = false })
	return wrap(kind, { wood, leaves })
end

Kinds.GiantPine = {
	Node = { Node = "Tree", Yield = "Wood", HP = 10 },
	Scale = { 0.9, 1.7 },
	Build = function()
		return pine("GiantPine", C(46, 92, 52), Enum.Material.LeafyGrass, C(88, 62, 46))
	end,
}
Kinds.FrostPine = {
	Node = { Node = "Tree", Yield = "Wood", HP = 9 },
	Scale = { 0.8, 1.4 },
	Build = function()
		return pine("FrostPine", C(96, 140, 140), Enum.Material.Grass, C(96, 84, 80), true)
	end,
}
Kinds.Oak = {
	Node = { Node = "Tree", Yield = "Wood", HP = 8 },
	Scale = { 0.8, 1.2 },
	Build = function()
		return broadTree("Oak", C(96, 150, 58), C(104, 74, 50), 14, 15)
	end,
}
Kinds.AncientOak = {
	Node = { Node = "Tree", Yield = "Wood", HP = 16 },
	Scale = { 1.3, 2.0 },
	Build = function()
		local m = broadTree("AncientOak", C(52, 108, 46), C(80, 64, 50), 20, 22)
		-- มอสห้อย + รากใหญ่
		for i = 1, 4 do
			local ang = i / 4 * math.pi * 2 + 0.4
			local root = P("WedgePart", {
				Size = V(2.4, 5, 6),
				CFrame = CF(math.cos(ang) * 3.6, 2.2, math.sin(ang) * 3.6) * ANG(0, -ang + math.pi / 2, 0),
				Color = C(80, 64, 50), Material = Enum.Material.Wood,
			})
			root.Parent = m
		end
		return m
	end,
}
Kinds.Palm = {
	Node = { Node = "Tree", Yield = "Wood", HP = 7 },
	Scale = { 0.9, 1.3 },
	Build = function()
		local segs = {}
		local pos = V(0, 0, 0)
		for i = 1, 6 do
			local tilt = rad(4 + i * 3)
			local seg = cylinderY(4.2, 2 - i * 0.12, CF(pos + V(math.sin(tilt) * 2.1, 2.1, 0)) * ANG(0, 0, -tilt), { Color = C(150, 116, 78), Material = Enum.Material.Wood })
			table.insert(segs, seg)
			pos += V(math.sin(tilt) * 4, 4 * math.cos(tilt), 0)
		end
		local trunk = union(segs, { Name = "Trunk", Color = C(150, 116, 78), Material = Enum.Material.Wood })
		local leaves = {}
		for i = 0, 7 do
			local ang = i / 8 * math.pi * 2
			local leaf = P("WedgePart", {
				Size = V(2.6, 0.5, 9),
				CFrame = CF(pos) * ANG(0, ang, 0) * CF(0, 0, -4) * ANG(rad(-22), 0, 0),
			}, getTemp())
			table.insert(leaves, leaf)
		end
		table.insert(leaves, ellipsoid(V(2.4, 2, 2.4), CF(pos)))
		local crown = union(leaves, { Name = "Foliage", Color = C(70, 150, 70), Material = Enum.Material.LeafyGrass, CanCollide = false })
		local coconuts = ellipsoid(V(1.3, 1.3, 1.3), CF(pos - V(0.8, 1.2, 0.6)), { Name = "Coconut", Color = C(110, 80, 50), Material = Enum.Material.Wood })
		return wrap("Palm", { trunk, crown, coconuts })
	end,
}
Kinds.CharredTree = {
	Node = { Node = "Tree", Yield = "Coal", HP = 8, YieldPerHP = 0.5, Bonus = "Wood" },
	Scale = { 0.9, 1.5 },
	Build = function()
		local parts = { cylinderY(18, 2.4, CF(0, 9, 0), {}) }
		local rng = Random.new(7)
		for i = 1, 5 do
			local h = rng:NextNumber(7, 15)
			local ang = i / 5 * math.pi * 2
			table.insert(parts, cylinderY(rng:NextNumber(5, 8), 1, CF(math.cos(ang) * 2, h, math.sin(ang) * 2) * ANG(math.sin(ang) * 0.7, 0, -math.cos(ang) * 0.7), {}))
		end
		local wood = union(parts, { Name = "Trunk", Color = C(28, 24, 24), Material = Enum.Material.Basalt })
		local embers = {}
		for i = 1, 4 do
			table.insert(embers, ellipsoid(V(0.7, 1.4, 0.7), CF(rng:NextNumber(-1, 1), rng:NextNumber(3, 15), rng:NextNumber(-1, 1) + 1.1)))
		end
		local glow = union(embers, { Name = "Embers", Color = C(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false })
		return wrap("CharredTree", { wood, glow })
	end,
}

local function bush(kind, color, berries)
	local blobs = {}
	for i = 1, 4 do
		local ang = i / 4 * math.pi * 2
		table.insert(blobs, ellipsoid(V(4.2, 3.4, 4.2), CF(math.cos(ang) * 1.5, 1.6, math.sin(ang) * 1.5)))
	end
	local leaves = union(blobs, { Name = "Foliage", Color = color, Material = Enum.Material.LeafyGrass, CanCollide = false })
	local children = { leaves }
	if berries then
		local bs = {}
		local rng = Random.new(3)
		for _ = 1, 9 do
			local ang = rng:NextNumber(0, math.pi * 2)
			table.insert(bs, ellipsoid(V(0.8, 0.8, 0.8), CF(math.cos(ang) * 3.2, rng:NextNumber(1.2, 3.4), math.sin(ang) * 3.2)))
		end
		table.insert(children, union(bs, { Name = "Berries", Color = C(214, 40, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false }))
	end
	return wrap(kind, children)
end

Kinds.Bush = { Scale = { 0.7, 1.3 }, NoCollide = true, Build = function()
	return bush("Bush", C(78, 140, 60), false)
end }
Kinds.BerryBush = {
	Node = { Node = "Bush", Yield = "Berries", HP = 1, Amount = 3, Bonus = "Fiber", Regrow = 150 },
	Scale = { 0.9, 1.2 }, NoCollide = true,
	Build = function()
		return bush("BerryBush", C(64, 124, 56), true)
	end,
}
Kinds.Flowers = {
	Scale = { 0.8, 1.4 }, NoCollide = true,
	Build = function()
		local rng = Random.new(11)
		local stems, heads = {}, {}
		local palette = { C(255, 120, 160), C(255, 220, 90), C(180, 140, 255), C(255, 255, 255) }
		for _ = 1, 7 do
			local x, z = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
			local h = rng:NextNumber(1.2, 2.4)
			table.insert(stems, P("Part", { Size = V(0.2, h, 0.2), CFrame = CF(x, h / 2, z) }, getTemp()))
			table.insert(heads, ellipsoid(V(0.9, 0.5, 0.9), CF(x, h, z), { Color = palette[rng:NextInteger(1, #palette)] }))
		end
		local stem = union(stems, { Name = "Stems", Color = C(80, 140, 60), CanCollide = false })
		local m = wrap("Flowers", { stem })
		for _, hd in ipairs(heads) do
			hd.CanCollide = false
			hd.Material = Enum.Material.SmoothPlastic
			hd.Parent = m
		end
		return m
	end,
}
Kinds.Mushrooms = { Scale = { 0.7, 1.4 }, NoCollide = true, Build = function()
	return ellipsoid(V(2, 1.4, 2), CF(0, 1.2, 0), { Name = "Cap", Color = C(190, 50, 40), CanCollide = false })
end }
Kinds.GlowShroom = {
	Scale = { 0.8, 2.2 }, NoCollide = true, Light = { Color = C(110, 255, 200), Range = 14, Brightness = 1.4, Chance = 0.35 },
	Build = function()
		local stem = cylinderY(5, 1.2, CF(0, 2.5, 0), { Name = "Stem", Color = C(226, 220, 200), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		local cap = ellipsoid(V(5, 2.4, 5), CF(0, 5.2, 0), { Name = "Cap", Color = C(80, 230, 190), Material = Enum.Material.Neon, CanCollide = false })
		local spots = ellipsoid(V(3.2, 1.2, 3.2), CF(0, 6.2, 0), { Name = "Top", Color = C(40, 120, 110), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		local small = cylinderY(2.6, 0.7, CF(1.8, 1.3, 1), { Color = C(226, 220, 200), CanCollide = false })
		local smallCap = ellipsoid(V(2.2, 1.1, 2.2), CF(1.8, 2.7, 1), { Color = C(80, 230, 190), Material = Enum.Material.Neon, CanCollide = false })
		return wrap("GlowShroom", { stem, cap, spots, small, smallCap })
	end,
}

local function rockKind(kind, size, color, material, extra)
	return function()
		local rock = rockShape(size, #kind * 17, { Name = "Rock", Color = color, Material = material })
		local children = { rock }
		if extra then
			for _, c in ipairs(extra()) do
				table.insert(children, c)
			end
		end
		return wrap(kind, children)
	end
end

-- เฟิร์นคลุมดิน (โมเดลจริงจาก Store; ไม่มีก็ใช้พุ่มเล็ก)
Kinds.Fern = { Scale = { 0.8, 1.5 }, NoCollide = true, Build = function()
	return ellipsoid(V(4, 2, 4), CF(0, 0.8, 0), { Name = "Fern", Color = C(84, 130, 60), Material = Enum.Material.Grass, CanCollide = false })
end }
Kinds.Boulder = { Node = { Node = "Rock", Yield = "Stone", HP = 8 }, Scale = { 0.6, 1.4 }, Build = rockKind("Boulder", V(9, 6, 8), C(132, 130, 126), Enum.Material.Slate) }
Kinds.MossRock = {
	Node = { Node = "Rock", Yield = "Stone", HP = 10 }, Scale = { 0.8, 1.8 },
	Build = rockKind("MossRock", V(11, 7, 10), C(98, 102, 96), Enum.Material.Slate, function()
		return { ellipsoid(V(9, 2.4, 8), CF(0, 5.2, 0), { Name = "Moss", Color = C(70, 130, 50), Material = Enum.Material.Grass, CanCollide = false }) }
	end),
}
Kinds.SeaRock = { Node = { Node = "Rock", Yield = "Stone", HP = 8 }, Scale = { 0.8, 2.0 }, Build = rockKind("SeaRock", V(10, 9, 9), C(186, 204, 196), Enum.Material.Limestone) }
Kinds.SkyStone = {
	Node = { Node = "Rock", Yield = "Stone", HP = 8 }, Scale = { 0.7, 1.6 },
	Build = rockKind("SkyStone", V(9, 7, 8), C(120, 132, 168), Enum.Material.Slate, function()
		-- หินลอยเล็กๆ ข้างบน (พลังลม)
		local out = {}
		for i = 1, 3 do
			local s = rockShape(V(2.4, 2, 2.4), i * 5, { Name = "FloatStone", Color = C(150, 164, 200), Material = Enum.Material.Slate, CanCollide = false })
			s:PivotTo(CF(math.cos(i * 2.1) * 4, 9 + i * 1.5, math.sin(i * 2.1) * 4))
			table.insert(out, s)
		end
		return out
	end),
}
Kinds.IronRock = {
	Node = { Node = "Rock", Yield = "Iron", HP = 10, YieldPerHP = 0.6, Bonus = "Stone" }, Scale = { 0.8, 1.3 },
	Build = rockKind("IronRock", V(9, 6, 8), C(92, 90, 92), Enum.Material.Slate, function()
		local ores = {}
		local rng = Random.new(5)
		for _ = 1, 6 do
			table.insert(ores, P("Part", {
				Size = V(1.6, 1.6, 1.6),
				CFrame = CF(rng:NextNumber(-3, 3), rng:NextNumber(2, 5), rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			}, getTemp()))
		end
		return { union(ores, { Name = "Ore", Color = C(214, 140, 96), Material = Enum.Material.CorrodedMetal, CanCollide = false }) }
	end),
}
Kinds.CoalRock = {
	Node = { Node = "Rock", Yield = "Coal", HP = 10, YieldPerHP = 0.7, Bonus = "Stone" }, Scale = { 0.8, 1.3 },
	Build = rockKind("CoalRock", V(9, 6, 8), C(48, 44, 46), Enum.Material.Basalt, function()
		local ores = {}
		local rng = Random.new(9)
		for _ = 1, 5 do
			table.insert(ores, P("Part", {
				Size = V(1.4, 1.4, 1.4),
				CFrame = CF(rng:NextNumber(-3, 3), rng:NextNumber(2, 5), rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			}, getTemp()))
		end
		return { union(ores, { Name = "Ore", Color = C(255, 96, 24), Material = Enum.Material.Neon, CanCollide = false }) }
	end),
}

local function spire(kind, color, material, glow)
	return function()
		local rng = Random.new(#kind)
		local spikes = {}
		for i = 1, 3 do
			local h = (i == 1) and 34 or rng:NextNumber(14, 22)
			local b = (i == 1) and 8 or rng:NextNumber(4, 6)
			local off = (i == 1) and V(0, 0, 0) or V(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
			table.insert(spikes, pyramid(b, h, CF(off) * ANG(rad(rng:NextNumber(-8, 8)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-8, 8))), {}))
		end
		local main = union(spikes, { Name = "Spire", Color = color, Material = material })
		local children = { main }
		if glow then
			table.insert(children, ellipsoid(V(10, 1.2, 10), CF(0, 0.3, 0), { Name = "Glow", Color = glow, Material = Enum.Material.Neon, CanCollide = false }))
		end
		return wrap(kind, children)
	end
end

Kinds.IceSpire = { Scale = { 0.8, 1.8 }, Build = spire("IceSpire", C(170, 220, 245), Enum.Material.Glacier) }
Kinds.ObsidianSpire = { Scale = { 0.8, 2.0 }, Build = spire("ObsidianSpire", C(30, 24, 34), Enum.Material.Glass, C(255, 90, 20)) }

-- ไฟจริงจากคลัง VFX (Assets.VFX.RealFire) ใส่ใน part
local function seq(t, mul)
	local ks = {}
	for _, k in ipairs(t) do
		table.insert(ks, NumberSequenceKeypoint.new(k[1], k[2] * (mul or 1)))
	end
	return NumberSequence.new(ks)
end
-- ไฟกะทัดรัด 3 ชั้น: แกนเหลืองสว่าง / เปลวส้มพลิ้ว / ประกายลอย (scale 1 = สูง ~3 stud พอดีกองฟืน)
-- ขนาดตั้งต้นเก็บใน attribute BaseSize -> CampService ปรับโตตามเชื้อเพลิง
local function realFire(host, scale)
	scale = scale or 1
	local function emitter(name, props)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.LightEmission = 0.8
		e.LightInfluence = 0
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Top
		for k, v in pairs(props) do
			e[k] = v
		end
		e:SetAttribute("BaseSize", e.Size)
		e:SetAttribute("RealFire", true)
		e.Parent = host
		return e
	end
	emitter("FlameCore", {
		Rate = 34, Lifetime = NumberRange.new(0.45, 0.75), Speed = NumberRange.new(3 * scale, 4.5 * scale), SpreadAngle = Vector2.new(6, 6), ZOffset = 1.2,
		Rotation = NumberRange.new(-15, 15), RotSpeed = NumberRange.new(-30, 30), Acceleration = V(0, 3 * scale, 0),
		Size = seq({ { 0, 1.7 }, { 0.5, 1.3 }, { 1, 0.2 } }, scale),
		Transparency = seq({ { 0, 0.35 }, { 0.15, 0 }, { 0.8, 0.4 }, { 1, 1 } }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 250, 210)), ColorSequenceKeypoint.new(0.5, C(255, 200, 90)), ColorSequenceKeypoint.new(1, C(255, 120, 40)) }),
	})
	emitter("Flames", {
		Rate = 30, Lifetime = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(3.5 * scale, 5.5 * scale), SpreadAngle = Vector2.new(14, 14), ZOffset = 1,
		Rotation = NumberRange.new(-30, 30), RotSpeed = NumberRange.new(-60, 60), Acceleration = V(0, 2 * scale, 0),
		Size = seq({ { 0, 2.3 }, { 0.4, 1.9 }, { 1, 0.3 } }, scale),
		Transparency = seq({ { 0, 0.6 }, { 0.2, 0.08 }, { 0.75, 0.45 }, { 1, 1 } }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 190, 80)), ColorSequenceKeypoint.new(0.45, C(255, 110, 30)), ColorSequenceKeypoint.new(1, C(150, 40, 20)) }),
	})
	local sparks = emitter("Sparks", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 8, Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(4 * scale, 9 * scale), SpreadAngle = Vector2.new(25, 25), Drag = 1.5, Acceleration = V(0, 3, 0),
		Size = NumberSequence.new(0.18 * scale, 0), Transparency = NumberSequence.new(0),
		Color = ColorSequence.new(C(255, 220, 120), C(255, 90, 20)),
	})
	sparks.Shape = Enum.ParticleEmitterShape.Box
	return true
end
PropBuilder.RealFire = realFire

Kinds.LavaVent = {
	Hazard = "Lava", NoCollide = false, Scale = { 0.8, 1.4 },
	Build = function()
		-- หินภูเขาไฟก้อนเตี้ยๆ ล้อมรอยแยก + ไฟลุกจริง + ควันลอย
		local m = Instance.new("Model")
		m.Name = "LavaVent"
		local rocks = storeTemplates("CoalRock")
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			if rocks then
				local r = rocks[(i % #rocks) + 1]:Clone()
				pcall(function()
					r:ScaleTo(r:GetScale() * 0.7)
				end)
				r:PivotTo(CF(math.cos(a) * 3.2, -0.4, math.sin(a) * 3.2) * ANG(0, a, 0))
				r.Parent = m
			end
		end
		local core = P("Part", { Name = "Vent", Size = V(4, 0.4, 4), CFrame = CF(0, 0.2, 0), Color = C(60, 30, 20), Material = Enum.Material.CrackedLava, CanCollide = false }, m)
		if not realFire(core, 2.2) then
			local f = Instance.new("Fire")
			f.Size = 6
			f.Heat = 12
			f.Parent = core
		end
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Rate = 4
		smoke.Lifetime = NumberRange.new(3, 5)
		smoke.Speed = NumberRange.new(4, 7)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		smoke.Color = ColorSequence.new(C(70, 62, 60))
		smoke.Parent = core
		local l = Instance.new("PointLight")
		l.Color = C(255, 120, 40)
		l.Range = 16
		l.Brightness = 1.4
		l.Parent = core
		m.WorldPivot = CF()
		return m
	end,
}
local function crystalCluster(kind, color, element)
	return {
		Node = { Node = "Crystal", Yield = element, HP = 8, YieldPerHP = 0.4, Regrow = 300 },
		Scale = { 0.8, 1.5 },
		Build = function()
			local rng = Random.new(#kind * 13)
			local shards = {}
			for i = 1, 6 do
				local h = (i == 1) and 11 or rng:NextNumber(4, 8)
				local w = (i == 1) and 2.6 or rng:NextNumber(1.2, 2)
				local ang = i / 6 * math.pi * 2
				local off = (i == 1) and V(0, 0, 0) or V(math.cos(ang) * 2.2, 0, math.sin(ang) * 2.2)
				local tilt = (i == 1) and CFrame.identity or ANG(math.sin(ang) * 0.5, 0, -math.cos(ang) * 0.5)
				table.insert(shards, crystalShard(w, h, CF(off) * tilt, {}))
			end
			local crystals = union(shards, { Name = "Crystal", Color = color, Material = Enum.Material.Neon })
			local base = rockShape(V(7, 3, 7), 21, { Name = "Base", Color = C(70, 70, 76), Material = Enum.Material.Slate })
			return wrap(kind, { base, crystals })
		end,
	}
end


Kinds.TerraCrystal = crystalCluster("TerraCrystal", C(130, 240, 100), "TerraCore")
Kinds.TideCrystal = crystalCluster("TideCrystal", C(90, 210, 255), "TidePearl")
Kinds.GaleCrystal = crystalCluster("GaleCrystal", C(220, 236, 255), "GaleFeather")
Kinds.EmberCrystal = crystalCluster("EmberCrystal", C(255, 120, 40), "EmberShard")

Kinds.Coral = {
	Underwater = true, NoCollide = true, Scale = { 0.8, 1.8 },
	Build = function()
		local rng = Random.new(77)
		local palette = { C(255, 110, 150), C(255, 160, 80), C(120, 230, 255), C(190, 120, 255) }
		local m = Instance.new("Model")
		for i = 1, 3 do
			local col = palette[(i % #palette) + 1]
			local branches = {}
			local ox, oz = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
			for _ = 1, 5 do
				local h = rng:NextNumber(3, 7)
				table.insert(branches, cylinderY(h, rng:NextNumber(0.6, 1.1), CF(ox, h / 2, oz) * ANG(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)), {}))
			end
			local u = union(branches, { Name = "Coral" .. i, Color = col, Material = Enum.Material.SmoothPlastic, CanCollide = false })
			u.Parent = m
		end
		m.Name = "Coral"
		m.WorldPivot = CF(0, 0, 0)
		return m
	end,
}
Kinds.Kelp = {
	Underwater = true, NoCollide = true, Scale = { 0.8, 1.6 },
	Build = function()
		local strands = {}
		for i = 1, 4 do
			local x, z = math.cos(i * 1.6) * 1.5, math.sin(i * 1.6) * 1.5
			local y = 0
			for s = 1, 5 do
				table.insert(strands, P("Part", { Size = V(1.2, 4, 0.3), CFrame = CF(x + math.sin(s + i) * 0.6, y + 2, z) * ANG(0, i, math.sin(s * 1.3) * 0.2) }, getTemp()))
				y += 3.8
			end
		end
		return wrap("Kelp", { union(strands, { Name = "Kelp", Color = C(70, 120, 60), Material = Enum.Material.Grass, CanCollide = false }) })
	end,
}

---------------------------------------------------------------- ระบบแม่แบบ
---------------------------------------------------------------- โมเดลจาก Creator Store (assets/rbxm/Props)
-- Models = ชื่อโมเดลใน Assets.Props (แพ็กที่มีโมเดลย่อยหลายต้น -> สุ่มทีละต้น)
-- Height = ความสูงหลังปรับ · Trunk = เส้นผ่านศูนย์กลางลำต้น (ทำกล่องชนล่องหน) · Solid = ชนทั้งก้อน (หิน)
local STORE = {
	GiantPine = { Models = { "Fir1", "SnowPine" }, Height = 50, Trunk = 3, Foliage = C(44, 82, 52), Bark = C(84, 60, 44), DropWhite = true },
	Oak = { Models = { "OakPack" }, Split = "Models", Height = 30, Trunk = 3, Foliage = C(82, 122, 54), Bark = C(96, 72, 52) },
	AncientOak = { Models = { "OakPack" }, Split = "Models", Height = 46, Trunk = 5, Foliage = C(60, 98, 46), Bark = C(80, 60, 46) },
	Palm = { Models = { "PalmLP" }, Height = 28, Trunk = 2, Foliage = C(70, 136, 70), Bark = C(120, 96, 70) },
	FrostPine = { Models = { "SnowPine" }, Height = 42, Trunk = 3, Foliage = C(50, 86, 70), Bark = C(84, 66, 54) },
	CharredTree = { Models = { "DeadTree" }, Height = 28, Trunk = 2.2, Color = C(44, 36, 34) },
	Boulder = { Models = { "RockLP" }, Split = "Parts", Height = 7, Solid = true, Color = C(120, 118, 114) },
	MossRock = { Models = { "RockLP" }, Split = "Parts", Height = 9, Solid = true, Color = C(100, 116, 88) },
	SeaRock = { Models = { "RockLP" }, Split = "Parts", Height = 8, Solid = true, Color = C(178, 170, 150) },
	SkyStone = { Models = { "RockLP" }, Split = "Parts", Height = 10, Solid = true, Color = C(168, 178, 198) },
	Bush = { Models = { "BushLP" }, Height = 5, Foliage = C(66, 108, 50) },
	Fern = { Models = { "GrassTuft", "GrassTuft2" }, Height = 3.2, Foliage = C(84, 128, 58) },
	Mushrooms = { Models = { "Mushrooms" }, Height = 2.6 },
	GlowShroom = { Models = { "Mushrooms" }, Height = 4.5, Color = C(70, 170, 150), Material = Enum.Material.SmoothPlastic,
		Light = { Color = C(90, 230, 190), Range = 10, Brightness = 0.6 } },
	BerryBush = { Models = { "BerryBushLP" }, Height = 4.2 },
	Flowers = { Models = { "FlowerBed" }, Height = 1.4 },
	Coral = { Models = { "CoralSet" }, Split = "Models", Height = 5 },
	Kelp = { Models = { "KelpLP" }, Height = 8 },
	LavaVent = { Models = { "VolcanoLP" }, Height = 10, Solid = true },
	CoalRock = { Models = { "CoalOreLP" }, Height = 5, Solid = true },
	IronRock = { Models = { "IronOreLP" }, Height = 6, Solid = true },
	ObsidianSpire = { Models = { "ObsidianEgg" }, Height = 9, Solid = true },
	IceSpire = { Models = { "IceSpikeLP" }, Height = 15, Solid = true },
	TerraCrystal = { Models = { "CrystalGreen" }, Height = 10, Solid = true, Light = { Color = C(130, 240, 100), Range = 14, Brightness = 0.9 }, Sparkle = C(170, 255, 140) },
	TideCrystal = { Models = { "CrystalBlue" }, Height = 9, Solid = true, Light = { Color = C(90, 210, 255), Range = 14, Brightness = 0.9 }, Sparkle = C(160, 230, 255) },
	GaleCrystal = { Models = { "CrystalWhite" }, Height = 7, Solid = true, Light = { Color = C(210, 235, 255), Range = 14, Brightness = 0.9 }, Sparkle = C(235, 245, 255) },
	EmberCrystal = { Models = { "CrystalRed" }, Height = 10, Solid = true, Light = { Color = C(255, 120, 40), Range = 14, Brightness = 1 }, Sparkle = C(255, 190, 90) },
}
PropBuilder.Store = STORE
local storeVariants = {}

-- โมเดลย่อยของแพ็ก (ถ้ามีหลายชิ้นวางแยกกัน) หรือทั้งโมเดล
local function variantsOf(model, split)
	local subs = {}
	if split == "Parts" then
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("BasePart") then
				table.insert(subs, c)
			end
		end
		return subs
	end
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("Model") and c:FindFirstChildWhichIsA("BasePart", true) then
			table.insert(subs, c)
		end
	end
	if #subs >= 2 or (split == "Models" and #subs >= 1) then
		return subs
	end
	return { model }
end

local variantSeed = 0
local function normalize(kind, src, spec)
	variantSeed += 3
	local m = Instance.new("Model")
	m.Name = kind
	local parts = src:IsA("BasePart") and { src } or src:GetDescendants()
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") then
			local c = d:Clone()
			c:ClearAllChildren()
			for _, k in ipairs(d:GetChildren()) do
				if not k:IsA("BasePart") and not k:IsA("Model") and not k:IsA("JointInstance") and not k:IsA("WeldConstraint") then
					k:Clone().Parent = c
				end
			end
			c.Anchored = true
			c.CanCollide = spec.Solid == true
			c.CanTouch = false
			c.CastShadow = true
			-- ปรับสีให้เป็นธรรมชาติ (ใบเขียวเข้ม/เปลือกน้ำตาล) + ต่างกันเล็กน้อยต่อแบบ
			local col = c.Color
			local green = col.G > col.R * 1.08 and col.G > col.B * 1.02
			local white = col.R > 0.82 and col.G > 0.82 and col.B > 0.82
			if white and spec.DropWhite then
				c:Destroy()
				continue
			elseif spec.Color then
				c.Color = spec.Color
				if spec.Material then
					c.Material = spec.Material
				end
			elseif green and spec.Foliage then
				local h, sat, v = spec.Foliage:ToHSV()
				c.Color = Color3.fromHSV((h + (variantSeed % 7 - 3) * 0.006) % 1, sat, math.clamp(v * (0.92 + (variantSeed % 5) * 0.04), 0, 1))
			elseif not green and not white and spec.Bark then
				c.Color = spec.Bark
			end
			c.Parent = m
		end
	end
	local cf, size = m:GetBoundingBox()
	if size.Y <= 0.01 then
		return nil
	end
	m.WorldPivot = CF(cf.Position - V(0, size.Y / 2, 0))
	pcall(function()
		m:ScaleTo(spec.Height / size.Y)
	end)
	m:PivotTo(CF(0, 0, 0))
	if spec.Stretch then
		-- ยืดแนวตั้ง (หินก้อน -> เสาหิน/ผลึก) โดยฐานยังแตะพื้น
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Size = V(p.Size.X * 0.75, p.Size.Y * spec.Stretch, p.Size.Z * 0.75)
				p.CFrame = CF(p.Position.X * 0.75, p.Position.Y * spec.Stretch, p.Position.Z * 0.75) * p.CFrame.Rotation
			end
		end
	end
	local host = m:FindFirstChildWhichIsA("BasePart")
	if host and spec.Light then
		local l = Instance.new("PointLight")
		l.Color = spec.Light.Color
		l.Range = spec.Light.Range
		l.Brightness = spec.Light.Brightness
		l.Shadows = false
		l.Parent = host
	end
	if host and spec.Sparkle then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 3
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.LightEmission = 1
		e.Color = ColorSequence.new(spec.Sparkle)
		e.Parent = host
	end
	if spec.Trunk then
		local h = spec.Height * 0.45
		local col = Instance.new("Part")
		col.Name = "Collider"
		col.Shape = Enum.PartType.Cylinder
		col.Size = V(h, spec.Trunk, spec.Trunk)
		col.CFrame = CF(0, h / 2, 0) * ANG(0, 0, math.pi / 2)
		col.Transparency = 1
		col.Anchored = true
		col.CanCollide = true
		col.CastShadow = false
		col.Parent = m
	end
	m.Parent = getTemp()
	return m
end

function storeTemplates(kind)
	if storeVariants[kind] ~= nil then
		return storeVariants[kind]
	end
	storeVariants[kind] = false
	local spec = STORE[kind]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Props")
	if not (spec and folder) then
		return false
	end
	local list = {}
	for _, name in ipairs(spec.Models) do
		local src = folder:FindFirstChild(name)
		if src then
			for _, v in ipairs(variantsOf(src, spec.Split)) do
				local t = normalize(kind, v, spec)
				if t then
					table.insert(list, t)
				end
			end
		end
	end
	if #list > 0 then
		storeVariants[kind] = list
	end
	return storeVariants[kind]
end

function PropBuilder.GetTemplate(kind, rng)
	local list = storeTemplates(kind)
	if list then
		return list[(rng or Random.new()):NextInteger(1, #list)]
	end
	if templates[kind] and templates[kind].Parent then
		return templates[kind]
	end
	-- โมเดลจาก Blender (ถ้ามี)
	local t
	if MeshProps.Has(kind) then
		-- โมเดลจริงจาก Blender (สวมผิวฝั่ง client)
		t = MeshProps.Build(kind)
		t.Parent = getTemp()
		templates[kind] = t
		return t
	end
	do
		local spec = Kinds[kind]
		if not spec then
			return nil
		end
		t = finishTemplate(kind, spec.Build())
	end
	templates[kind] = t
	return t
end

function PropBuilder.ClearTemplates()
	for _, t in pairs(templates) do
		t:Destroy()
	end
	table.clear(templates)
	table.clear(storeVariants)
	if tempFolder then
		tempFolder:Destroy()
		tempFolder = nil
	end
end

local function addLight(model, spec, rng)
	if not spec or rng:NextNumber() > spec.Chance then
		return
	end
	local host = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) or model
	if host then
		local l = Instance.new("PointLight")
		l.Color = spec.Color
		l.Range = spec.Range
		l.Brightness = spec.Brightness
		l.Shadows = false
		l.Parent = host
	end
end

-- วาง 1 ชิ้น
function PropBuilder.Place(kind, position, yaw, scale, parent, rng)
	local t = PropBuilder.GetTemplate(kind, rng)
	if not t then
		return nil
	end
	local spec = Kinds[kind] or {}
	local inst = t:Clone()
	if inst:IsA("Model") then
		if scale ~= 1 then
			-- คูณกับสเกลเดิมของแม่แบบ (โมเดล Store ถูกย่อให้ได้ Height ไว้แล้ว) — ScaleTo(scale) ตรงๆ = กลับไปขนาดดิบของโมเดล
			pcall(function()
				inst:ScaleTo(inst:GetScale() * scale)
			end)
		end
	elseif inst:IsA("BasePart") and scale ~= 1 then
		inst.Size *= scale
	end
	inst:PivotTo(CF(position) * ANG(0, yaw, 0))
	if spec.NoCollide then
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	if spec.Node then
		CollectionService:AddTag(inst, "ResourceNode")
		inst:SetAttribute("Node", spec.Node.Node)
		inst:SetAttribute("Yield", spec.Node.Yield)
		inst:SetAttribute("HP", math.floor(spec.Node.HP * math.max(scale, 0.7) + 0.5))
		inst:SetAttribute("MaxHP", inst:GetAttribute("HP"))
		inst:SetAttribute("YieldPerHP", spec.Node.YieldPerHP or 1)
		if spec.Node.Bonus then
			inst:SetAttribute("Bonus", spec.Node.Bonus)
		end
		if spec.Node.Amount then
			inst:SetAttribute("Amount", spec.Node.Amount)
		end
		inst:SetAttribute("Regrow", spec.Node.Regrow or 240)
	end
	if spec.Hazard then
		CollectionService:AddTag(inst, "Hazard")
		inst:SetAttribute("Hazard", spec.Hazard)
	end
	inst:SetAttribute("Kind", kind)
	if inst:IsA("Model") then
		-- สตรีมทั้งต้นพร้อมกัน + ไกลๆ แสดงเป็นเมชความละเอียดต่ำ (ประหยัดเครื่อง)
		pcall(function()
			inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			inst.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
		end)
	end
	addLight(inst, spec.Light, rng or Random.new())
	inst.Parent = parent
	return inst
end

---------------------------------------------------------------- กระจายของทั่วแมพ
local function pickKind(list, rng)
	local total = 0
	for _, e in ipairs(list) do
		total += e.Weight
	end
	local r = rng:NextNumber() * total
	for _, e in ipairs(list) do
		r -= e.Weight
		if r <= 0 then
			return e.Kind
		end
	end
	return list[#list].Kind
end

function PropBuilder.Scatter(layout, parent, opts)
	opts = opts or {}
	local rng = Random.new(layout.Seed + 4242)
	local density = opts.Density or 1
	local cell = 34 / math.sqrt(density)
	local half = layout.Half - layout.EdgeOcean * 0.6
	local water = layout.WaterLevel
	local avoid = {}
	for _, sp in ipairs(layout.Specials) do
		table.insert(avoid, { sp.Position, sp.Radius or (sp.Kind == "Lair" and 90 or 40) })
		local padC, padR = SiteSpec.Pad(sp.Kind, sp.Element, sp.Position)
		if padC then
			table.insert(avoid, { padC, padR + 6 }) -- อาคารใหญ่ของจุดนี้
		end
	end
	table.insert(avoid, { Vector3.new(0, 0, 0), 140 }) -- ลานโล่งรอบแคมป์ (พื้นที่สร้างฐานกว้างๆ ไม่ให้ต้นไม้เบียด)
	table.insert(avoid, { Vector3.new(0, 0, -72), 42 }) -- บ้านพักนายพราน
	table.insert(avoid, { Vector3.new(36, 0, 22), 14 }) -- โรงเก็บของ
	local count = 0
	local t0 = os.clock()
	local x = -half
	while x < half do
		local z = -half
		while z < half do
			local px = x + rng:NextNumber(0, cell)
			local pz = z + rng:NextNumber(0, cell)
			local h, biome, lava = layout:HeightAt(px, pz)
			local data = Biomes.Data[biome]
			local chance = (biome == "Heart") and 0.8 or 0.5
			if biome == "Water" then
				chance = 0.35
			end
			-- ป่าทึบ: ไบโอมป่าวางหลายชิ้นต่อช่อง
			local tries = data.PropDensity or 1
			for t = 1, math.ceil(tries) do
			local cx = (t == 1) and px or (x + rng:NextNumber(0, cell))
			local cz = (t == 1) and pz or (z + rng:NextNumber(0, cell))
			if t > 1 then
				h, biome, lava = layout:HeightAt(cx, cz)
				if biome ~= data.Id and Biomes.Data[biome] ~= data then
					break
				end
			end
			local px, pz = cx, cz
			if not lava and rng:NextNumber() < chance * math.min(1, tries - (t - 1)) then
				local kind = pickKind(data.Props, rng)
				local spec = Kinds[kind]
				local ok = spec ~= nil
				if ok then
					if spec.Underwater then
						ok = h < water - 3 and h > water - 40
					else
						ok = h > water + 1.5
					end
				end
				if ok then
					-- ความชัน
					local h2 = layout:HeightAt(px + 5, pz)
					local h3 = layout:HeightAt(px, pz + 5)
					if math.abs(h2 - h) > 4 or math.abs(h3 - h) > 4 then
						ok = false
					end
				end
				if ok then
					for _, a in ipairs(avoid) do
						local d = Vector3.new(px - a[1].X, 0, pz - a[1].Z).Magnitude
						if d < a[2] then
							ok = false
							break
						end
					end
				end
				-- รอบแคมป์ต้นไม้บางลง (ขอบลาน 35% -> ค่อยๆ หนาขึ้นจนปกติที่ระยะ 340)
				if ok then
					local dc = math.sqrt(px * px + pz * pz)
					if dc < 340 and rng:NextNumber() > 0.35 + 0.65 * math.clamp((dc - 140) / 200, 0, 1) then
						ok = false
					end
				end
				if ok then
					local s = rng:NextNumber(spec.Scale[1], spec.Scale[2])
					PropBuilder.Place(kind, Vector3.new(px, h - 0.6, pz), rng:NextNumber(0, math.pi * 2), s, parent, rng)
					count += 1
				end
			end
			end
			z += cell
			if opts.Yield and os.clock() - t0 > (opts.Budget or 0.03) then
				task.wait()
				t0 = os.clock()
			end
		end
		x += cell
	end
	-- กำแพงป่าสนรอบแคมป์ (ต้นไม้ชิดลานโล่ง ตัดได้)
	for _ = 1, math.floor(45 * math.min(density, 1) + 0.5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = 78 + rng:NextNumber() ^ 1.3 * 70
		local px, pz = math.cos(a) * r, math.sin(a) * r
		local h = layout:HeightAt(px, pz)
		if h > water + 1.5 and Vector3.new(px, 0, pz + 72).Magnitude > 44 then
			local kind = (rng:NextNumber() < 0.75) and "GiantPine" or "Oak"
			local spec = Kinds[kind]
			PropBuilder.Place(kind, Vector3.new(px, h - 0.6, pz), rng:NextNumber(0, math.pi * 2), rng:NextNumber(spec.Scale[2], spec.Scale[2] * 1.25), parent, rng)
			count += 1
		end
	end
	-- ต้นไม้บนเกาะลอยฟ้า
	for _, isl in ipairs(layout.FloatingIslands) do
		for i = 1, math.floor(isl.R / 9) do
			local ang = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, isl.R * 0.75)
			local kind = (i % 3 == 0) and "GaleCrystal" or "FrostPine"
			PropBuilder.Place(kind, Vector3.new(isl.X + math.cos(ang) * r, isl.Y, isl.Z + math.sin(ang) * r), rng:NextNumber(0, 6.28), rng:NextNumber(0.7, 1.1), parent, rng)
			count += 1
		end
	end
	return count
end

-- หินใหญ่จาก Terrain (ไม่กินชิ้นส่วน)
function PropBuilder.TerrainBoulders(layout, opts)
	local terrain = workspace.Terrain
	local rng = Random.new(layout.Seed + 99)
	local half = layout.Half - layout.EdgeOcean
	local n = math.floor(layout.Size * layout.Size / 90000 * (opts and opts.Density or 1))
	for _ = 1, n do
		local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
		local h, biome = layout:HeightAt(x, z)
		local r = math.sqrt(x * x + z * z)
		if r > 120 then
			if biome == "Water" and h < layout.WaterLevel - 4 and rng:NextNumber() < 0.5 then
				-- เสาหินกลางทะเล (sea stack)
				local top = layout.WaterLevel + rng:NextNumber(20, 60)
				local rad0 = rng:NextNumber(10, 20)
				terrain:FillCylinder(CFrame.new(x, (h + top) / 2, z), top - h, rad0, Enum.Material.Limestone)
				terrain:FillBall(Vector3.new(x, top, z), rad0 * 1.05, Enum.Material.LeafyGrass)
			elseif h > layout.WaterLevel + 2 then
				local mat = ({ Earth = Enum.Material.Rock, Air = Enum.Material.Slate, Fire = Enum.Material.Basalt, Heart = Enum.Material.Rock })[biome]
				if mat then
					local s = rng:NextNumber(5, 14)
					terrain:FillBall(Vector3.new(x, h + s * 0.3, z), s, mat)
					terrain:FillBall(Vector3.new(x + s * 0.6, h, z + s * 0.3), s * 0.6, mat)
				end
			end
		end
	end
end

---------------------------------------------------------------- สถานที่พิเศษ
local ELEMENT_COLOR = {
	Earth = C(130, 240, 100), Water = C(80, 210, 255), Air = C(225, 236, 255), Fire = C(255, 110, 30),
}
PropBuilder.ElementColor = ELEMENT_COLOR

local function fire(parent, size, color)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.2
	f.Color = color or C(255, 140, 40)
	f.SecondaryColor = C(255, 60, 10)
	f.Parent = parent
	return f
end

-- ดินฐานใต้ฉากหลังร้านค้า ต่อธาตุ
local SEAT_MAT = { Earth = Enum.Material.Ground, Water = Enum.Material.Sand, Air = Enum.Material.Snow, Fire = Enum.Material.Basalt }

-- หันหน้า (-Z) เข้าหาแคมป์กลางแมพ
local faceCamp = SiteSpec.Frame

local function light(parent, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l.Parent = parent
	return l
end

-- แคมป์กลาง: กองไฟ + โต๊ะคราฟต์ + เต็นท์ + ที่นั่ง
-- วางโมเดลจาก Store (Assets.Props.<name>) ปรับสูงตาม height · คืน nil ถ้าไม่มี
local CAMP_STORE = {
	CampLodge = { Height = 26, Solid = true },
	CampShack = { Height = 11, Solid = true },
	LogBench = { Height = 2.3, Solid = true },
	LampPost = { Height = 13, Solid = true },
	Crate = { Height = 3.6, Solid = true },
	LogPileStore = { Height = 4.6, Solid = true },
	Fence = { Height = 4.2, Solid = true, Color = C(98, 72, 52), Material = Enum.Material.Wood },
	SleepingBagStore = { Height = 1.1 },
}
local campCache = {}
function PropBuilder.StoreModel(name, cf, parent)
	local spec = CAMP_STORE[name]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Props") and assets.Props:FindFirstChild(name)
	if not (spec and src) then
		return nil
	end
	if not campCache[name] then
		campCache[name] = normalize(name, src, spec)
	end
	if not campCache[name] then
		return nil
	end
	local m = campCache[name]:Clone()
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- โมเดลที่ Import 3D เข้ามา (Assets.Props.<name>, MeshPart+SurfaceAppearance) -> วางเท้าแตะพื้นที่ cf ขยายให้กว้าง width
function PropBuilder.Imported(name, cf, width, parent, collide)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Props") and assets.Props:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if collide and d.Transparency < 0.95 then
				-- ตัวแปลงโมเดลตั้งทุกชิ้นให้ทะลุได้ (ไว้ใช้กับสัตว์) -> สิ่งก่อสร้างต้องชน/ยืนได้จริง
				d.CanCollide = true
				d.CanQuery = true
				d.Massless = false
			end
		elseif d:IsA("Bone") or d:IsA("AnimationController") or d:IsA("Script") then
			-- ของนิ่ง: ตัดกระดูกทิ้ง (กระดูกจากไฟล์ทำให้เมชเลื่อนจมดิน)
			d:Destroy()
		end
	end
	-- โมเดลเก่าบางตัวเก็บทั้งโมเดลกลับหัว (ชิ้นส่วนเกือบทั้งหมดหงายท้อง) -> พลิกกลับให้ตั้งตรง
	local up, down = 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local y = d.CFrame.UpVector.Y
			if y > 0.5 then
				up += 1
			elseif y < -0.5 then
				down += 1
			end
		end
	end
	if down > 50 and down > up * 3 then
		m:PivotTo(ANG(math.pi, 0, 0) * m:GetPivot())
	end
	local bcf, size = m:GetBoundingBox()
	m.WorldPivot = CF(bcf.Position - V(0, size.Y / 2, 0))
	pcall(function()
		m:ScaleTo(m:GetScale() * width / math.max(size.X, size.Z))
	end)
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- วางโมเดลร้านค้าเป็นฉากหลัง: ด้านหน้า (-Z ของโมเดล) หันเข้าหาลาน, ขอบใกล้สุดห่างจากกลางลาน gap stud ไปทาง +Z ของ frame
--   gap = nil -> วางกลางลานพอดี (เช่นโคลอสเซียมล้อมลาน) · yaw = มุมแก้ทิศเฉพาะโมเดล (องศา)
function PropBuilder.Backdrop(name, frame, width, gap, parent, opts)
	opts = opts or {}
	local yaw = rad(opts.Yaw or 0)
	local m = PropBuilder.Imported(name, frame * ANG(0, yaw, 0), width, parent, true)
	if not m then
		return nil
	end
	-- ซ่อนชิ้นที่บังตัวอาคาร (เช่นเปลือกหลังคาทรงพีระมิดของพระราชวังน้ำแข็ง)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and opts.Hide and table.find(opts.Hide, d.Name) then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	local bcf, size = m:GetBoundingBox()
	local lp = frame:PointToObjectSpace(bcf.Position)
	local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	local halfZ = (size.Z * c + size.X * s) / 2
	local shiftZ = gap and (gap - (lp.Z - halfZ)) or -lp.Z
	m:PivotTo(CF(frame:VectorToWorldSpace(V(-lp.X, 0, shiftZ))) * m:GetPivot())
	-- วางก้นอาคารบนผิว Terrain จริง (ค่ากลางของหลายจุดใต้ฐาน) -> ไม่จม/ไม่ลอย · ไม่เจอพื้น (กลางอากาศ) = คงระดับเดิม
	local groundY, sunk
	do
		local bcf2, size2 = m:GetBoundingBox()
		local bottom = bcf2.Position.Y - size2.Y / 2
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hs = {}
		for _, o in ipairs({ { 0, 0 }, { 0.3, 0.3 }, { -0.3, 0.3 }, { 0.3, -0.3 }, { -0.3, -0.3 } }) do
			local p = bcf2 * V(size2.X * o[1], 0, size2.Z * o[2])
			local hit = workspace:Raycast(V(p.X, bottom + 40, p.Z), V(0, -80, 0), rp)
			if hit then
				table.insert(hs, hit.Position.Y)
			end
		end
		if #hs >= 3 then
			table.sort(hs)
			local ground = hs[math.ceil(#hs / 2)]
			m:PivotTo(CF(0, ground - (opts.Sink or 0.5) - bottom, 0) * m:GetPivot())
			groundY = ground
		end
	end
	-- ทรงเกาะ/แท่นยกขอบ: ผิวบนตรงขอบรอบตัว (ค่ากลาง) สูงกว่าพื้น -> จมลงให้ขอบเสมอพื้น (ส่วนหินใต้เกาะจมดินไป)
	if not opts.WaterLevel and groundY then
		local home = m.Parent
		m.Parent = workspace
		local bcf4, size4 = m:GetBoundingBox()
		local bottom = bcf4.Position.Y - size4.Y / 2
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { m }
		local hs = {}
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local p = bcf4 * V(math.cos(a) * size4.X * 0.4, 0, math.sin(a) * size4.Z * 0.4)
			local hit = workspace:Raycast(V(p.X, bottom + size4.Y + 5, p.Z), V(0, -(size4.Y + 10), 0), rp)
			if hit and hit.Position.Y - bottom < size4.Y * 0.4 then
				table.insert(hs, hit.Position.Y - bottom)
			end
		end
		m.Parent = home
		if #hs >= 10 then
			table.sort(hs)
			local edge = hs[math.ceil(#hs / 2)]
			-- เฉพาะฐานเกาะเตี้ยๆ (ซากปรักหักพัง) — ขอบสูงกว่านี้ = ตัวอาคาร/เกาะสูง ห้ามจม (เคยจมซุ้ม/วิหารจนเหลือแต่ยอด)
			if edge > 1.5 and edge <= math.min(14, size4.Y * 0.25) then
				sunk = edge - 0.3
				m:PivotTo(CF(0, -sunk, 0) * m:GetPivot())
			end
		end
	end
	-- อาคารกลางน้ำ: ลดระดับให้แผ่นพื้นของโมเดล (ค่ากลางของท้องโมเดล) อยู่พอดีผิวน้ำ เสา/ฐานล่างจมน้ำไป
	if opts.WaterLevel then
		local home = m.Parent
		m.Parent = workspace
		local bcf3, size3 = m:GetBoundingBox()
		local bottom = bcf3.Position.Y - size3.Y / 2
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { m }
		local hs = {}
		for gx = -0.4, 0.4, 0.1 do
			for gz = -0.4, 0.4, 0.1 do
				local p = bcf3 * V(size3.X * gx, 0, size3.Z * gz)
				local hit = workspace:Raycast(V(p.X, bottom - 2, p.Z), V(0, size3.Y * 0.5, 0), rp)
				if hit then
					table.insert(hs, hit.Position.Y - bottom)
				end
			end
		end
		m.Parent = home
		if #hs >= 5 then
			table.sort(hs)
			local plate = hs[math.ceil(#hs / 2)]
			if plate > 3 then
				m:PivotTo(CF(0, opts.WaterLevel + 0.3 - (bottom + plate), 0) * m:GetPivot())
			end
		end
	end
	if opts.Material ~= false then
		local home = m.Parent
		m.Parent = workspace -- ยิง ray ใส่ตัวโมเดลได้เฉพาะตอนอยู่ใน workspace
		PropBuilder.Seat(m, opts.Material or Enum.Material.Rock, opts.KeepTerrain, opts.WaterLevel, groundY, sunk)
		m.Parent = home
	end
	return m
end

-- ปรับ Terrain ใต้โมเดลให้รับพอดี: เติมฐานดินใต้ทั้งหมด (ไม่ลอย) + ขุดเนินที่ทะลุขึ้นมาในตัวโมเดลออก
function PropBuilder.Seat(m, material, keepTerrain, waterLevel, groundY, sunk)
	local terrain = workspace.Terrain
	local bcf, size = m:GetBoundingBox()
	local rawBottom = bcf.Position.Y - size.Y / 2
	local bottom = groundY or rawBottom -- ระดับพื้นที่อาคารตั้ง (อาคารที่จมฐานลงไป: ก้นจริงอยู่ใต้ดิน)
	local rot = bcf - bcf.Position
	local x, z = bcf.Position.X, bcf.Position.Z
	pcall(function()
		if not keepTerrain then
			-- ขุดเนินที่โผล่เข้ามาในตัวอาคาร (เหนือระดับพื้นเท่านั้น)
			local top = rawBottom + size.Y
			terrain:FillBlock(CF(x, (bottom + 1 + top) / 2, z) * rot, V(size.X * 0.9, math.max(top - bottom - 1, 1), size.Z * 0.9), Enum.Material.Air)
		end
		-- ฐานลาดลงแบบกลม (ไม่ใช่บล็อกสี่เหลี่ยมที่กลายเป็นหน้าผาขวางทาง) ใช้ได้ทั้งบนพื้นและบนเกาะลอยฟ้า
		local r = math.sqrt(size.X * size.X + size.Z * size.Z) / 2
		terrain:FillCylinder(CF(x, bottom - 3.5, z), 6, r * 0.82, material)
		terrain:FillCylinder(CF(x, bottom - 12, z), 12, r * 0.65, material)
		terrain:FillCylinder(CF(x, bottom - 26, z), 16, r * 0.42, material)
		if sunk then
			return -- จมฐานลงดินแล้ว ไม่ต้องถมใต้ท้อง
		end
		-- ดินแนบใต้ท้องโมเดลทุกจุด (เกาะลอย/แท่นขอบยก/ฐานลาด) -> ไม่เห็นช่องว่างลอย · ใต้ซุ้ม/หลังคาสูงไม่เติม
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { m }
		local step = 8
		local reach = 6 -- ถมเฉพาะช่องเล็กใต้ท้อง (ช่องสูงไม่ถม -> ไม่เกิดเสาดินสี่เหลี่ยม)
		for gx = -size.X * 0.48, waterLevel and -size.X or size.X * 0.48, step do -- กลางน้ำ: ไม่ถมดินใต้ท้อง (ปล่อยเป็นน้ำ)
			for gz = -size.Z * 0.48, size.Z * 0.48, step do
				local p = bcf * V(gx, 0, gz)
				local hit = workspace:Raycast(V(p.X, bottom - 2, p.Z), V(0, reach + 2, 0), rp)
				if hit then
					local h = hit.Position.Y - bottom
					if h > 0.8 then
						terrain:FillBlock(CF(p.X, bottom + (h - 6) / 2, p.Z) * rot, V(step + 1.5, h + 6, step + 1.5), material)
					end
				end
			end
		end
		-- รังกลางน้ำ: เติมน้ำคืนในส่วนที่ขุดออก
		if waterLevel and bottom < waterLevel then
			terrain:FillBlock(CF(x, (bottom + 1 + waterLevel) / 2, z) * rot, V(size.X * 0.92, waterLevel - bottom - 1, size.Z * 0.92), Enum.Material.Water)
		end
	end)
end

-- หาพื้นโล่งในอาคาร (ไม่มีตึก/ยอดแหลมทับ) ใกล้กลางที่สุด -> จุดเกิด/ลานสู้ของบอส
local function openFloor(model, center, groundY, radius)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { model, workspace.Terrain }
	local function floorAt(x, z)
		local hit = workspace:Raycast(V(x, groundY + 45, z), V(0, -70, 0), rp)
		return hit and hit.Position.Y or groundY - 99
	end
	local best, bestScore
	for r = 0, radius, 12 do
		local n = r == 0 and 1 or math.floor(r / 5)
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
			local y = floorAt(x, z)
			if math.abs(y - groundY) < 6 then
				local open = 0
				for j = 0, 7 do
					local b = j / 8 * math.pi * 2
					for _, d in ipairs({ 14, 28 }) do
						if math.abs(floorAt(x + math.cos(b) * d, z + math.sin(b) * d) - y) < 4 then
							open += 1
						end
					end
				end
				local score = open * 10 - r * 0.25
				if not bestScore or score > bestScore then
					best, bestScore = V(x, y, z), score
				end
			end
		end
	end
	return best
end
PropBuilder.OpenFloor = openFloor

-- ---------------------------------------------------------------- ลานเล่นบนตัวอาคาร + ทางขึ้น
-- หาพื้นราบบนตัวอาคารที่ยืนได้ (หัวโล่งพอ) ผืนใหญ่สุด เน้นลานยกสูง (ชั้นบน/แท่นวิหาร) -> วางของเล่นบนอาคารจริง
--   คืน { Center, Y, Cells = { Vector3 }, Entry = จุดขอบลานฝั่งแคมป์ } หรือ nil
function PropBuilder.PlayArea(model, frame, opts)
	opts = opts or {}
	local home = model.Parent
	model.Parent = workspace
	local bcf, size = model:GetBoundingBox()
	local top = bcf.Position.Y + size.Y / 2
	local bottom = bcf.Position.Y - size.Y / 2
	local groundY = frame.Position.Y
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { model }
	local step = opts.Step or 5
	local cols = {}
	local nx = math.floor(size.X * 0.48 / step)
	local nz = math.floor(size.Z * 0.48 / step)
	for ix = -nx, nx do
		for iz = -nz, nz do
			local p = bcf * V(ix * step, 0, iz * step)
			local y0 = top + 4
			local list = {}
			for _ = 1, 4 do
				local hit = workspace:Raycast(V(p.X, y0, p.Z), V(0, -(y0 - bottom + 2), 0), rp)
				if not hit then
					break
				end
				if hit.Normal.Y > 0.88 then
					local head = workspace:Raycast(hit.Position + V(0, 0.4, 0), V(0, opts.Headroom or 9, 0), rp)
					if not head then
						table.insert(list, hit.Position)
					end
				end
				y0 = hit.Position.Y - 0.7
			end
			cols[ix .. "," .. iz] = list
		end
	end
	-- รวมช่องที่ติดกันและสูงใกล้กันเป็นผืน
	local seen, best, bestScore = {}, nil, nil
	for key, list in pairs(cols) do
		for li, p0 in ipairs(list) do
			local id = key .. "#" .. li
			if not seen[id] then
				seen[id] = true
				local cluster, queue = {}, { { key, p0 } }
				while #queue > 0 do
					local cur = table.remove(queue)
					table.insert(cluster, cur[2])
					local cx, cz = cur[1]:match("(-?%d+),(-?%d+)")
					cx, cz = tonumber(cx), tonumber(cz)
					for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
						local nk = (cx + o[1]) .. "," .. (cz + o[2])
						for nj, q in ipairs(cols[nk] or {}) do
							local nid = nk .. "#" .. nj
							if not seen[nid] and math.abs(q.Y - cur[2].Y) < 1.6 then
								seen[nid] = true
								table.insert(queue, { nk, q })
							end
						end
					end
				end
				local h = cluster[1].Y - groundY
				local ok = #cluster >= (opts.MinCells or 6) and (h > 2.5 or opts.AllowGround)
				if ok then
					local score = #cluster * (1 + math.clamp(h / 30, 0, 1.5))
					if not bestScore or score > bestScore then
						best, bestScore = cluster, score
					end
				end
			end
		end
	end
	model.Parent = home
	if not best then
		return nil
	end
	local sum = V()
	for _, p in ipairs(best) do
		sum += p
	end
	local mean = sum / #best
	-- จุดกลาง = ช่องจริงที่ใกล้ค่าเฉลี่ยสุด (ลานรูปตัว L ไม่ไปตกนอกพื้น) · ทางเข้า = ช่องฝั่งแคมป์สุด
	local center, entry
	for _, p in ipairs(best) do
		if not center or (p - mean).Magnitude < (center - mean).Magnitude then
			center = p
		end
		if not entry or frame:PointToObjectSpace(p).Z < frame:PointToObjectSpace(entry).Z then
			entry = p
		end
	end
	return { Center = center, Y = center.Y, Cells = best, Entry = entry }
end

-- เลือก n ช่องในลานให้ห่างกันมากสุด (วางเสารูน/ของหลายชิ้น)
function PropBuilder.SpreadCells(area, n, avoid)
	local picks = {}
	for _ = 1, n do
		local bestP, bestD
		for _, p in ipairs(area.Cells) do
			local d = math.huge
			for _, q in ipairs(picks) do
				d = math.min(d, (p - q).Magnitude)
			end
			for _, q in ipairs(avoid or {}) do
				d = math.min(d, (p - q).Magnitude)
			end
			-- ช่องแรก: ใกล้กลางลาน
			if #picks == 0 and not avoid then
				d = -(p - area.Center).Magnitude
			end
			if not bestD or d > bestD then
				bestP, bestD = p, d
			end
		end
		table.insert(picks, bestP)
	end
	return picks
end

-- ทางขึ้นลาน: บันไดหินจากพื้นด้านหน้า (ลองหลายทิศ ไม่ทะลุกำแพง) · ขึ้นไม่ได้จริงๆ = แท่นวาร์ปขึ้น/ลง
function PropBuilder.BuildAccess(area, frame, model, parent, color)
	local entry = area.Entry
	local trp = RaycastParams.new()
	trp.FilterType = Enum.RaycastFilterType.Include
	trp.FilterDescendantsInstances = { workspace.Terrain }
	local mrp = RaycastParams.new()
	mrp.FilterType = Enum.RaycastFilterType.Include
	mrp.FilterDescendantsInstances = { model }
	local function groundAt(p)
		local hit = workspace:Raycast(V(p.X, entry.Y + 60, p.Z), V(0, -400, 0), trp)
		return hit and hit.Position.Y or frame.Position.Y
	end
	if entry.Y - groundAt(entry) < 3 then
		return "ground"
	end
	local home = model.Parent
	model.Parent = workspace
	local stone = { Color = color or C(150, 146, 136), Material = Enum.Material.Slate }
	local built
	for _, deg in ipairs({ 0, 30, -30, 60, -60, 90, -90, 125, -125, 180 }) do
		local d = frame:VectorToWorldSpace(CFrame.Angles(0, rad(deg), 0):VectorToWorldSpace(V(0, 0, -1)))
		d = V(d.X, 0, d.Z).Unit
		-- ความยาวบันได (ชันราว 35°)
		local L, g
		for t = 6, 220, 3 do
			g = groundAt(entry + d * t)
			if t * 0.7 >= entry.Y - g then
				L = t
				break
			end
		end
		if L then
			local clear = true
			for t = 1.5, L, 2 do
				local surf = entry.Y - t / L * (entry.Y - g)
				for _, side in ipairs({ -3, 0, 3 }) do
					local p = entry + d * t + d:Cross(Vector3.yAxis) * side
					if workspace:Raycast(V(p.X, surf + 8, p.Z), V(0, -7.4, 0), mrp) then
						clear = false
						break
					end
				end
				if not clear then
					break
				end
			end
			if clear then
				local stairs = Instance.new("Model")
				stairs.Name = "Stairs"
				local n = math.max(2, math.ceil((entry.Y - g) / 1.4))
				for k = 0, n - 1 do
					local t = (k + 0.5) * L / n
					local topY = entry.Y - (k + 1) * (entry.Y - g) / n + 0.2
					local base = g - 4
					local c = entry + d * t
					P("Part", {
						Name = "Step",
						Size = V(9, topY - base, L / n + 0.15),
						CFrame = CFrame.lookAt(V(c.X, (topY + base) / 2, c.Z), V(c.X, (topY + base) / 2, c.Z) + d),
						Color = stone.Color,
						Material = stone.Material,
					}, stairs)
				end
				stairs.Parent = parent
				built = "stairs"
				break
			end
		end
	end
	model.Parent = home
	if built then
		return built
	end
	-- แท่นวาร์ป: วงแสงบนพื้นหน้าอาคาร <-> จุดขอบลานบนอาคาร
	local dFront = frame:VectorToWorldSpace(V(0, 0, -1))
	local low = entry + V(dFront.X, 0, dFront.Z).Unit * 22
	low = V(low.X, groundAt(low), low.Z)
	local function pad(pos, text, dest)
		local p = P("Part", { Name = "LiftPad", Size = V(0.4, 7, 7), CFrame = CF(pos + V(0, 0.2, 0)) * ANG(0, 0, math.pi / 2), Shape = Enum.PartType.Cylinder, Color = color or C(120, 220, 255), Material = Enum.Material.Neon, CanCollide = false }, parent)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = text
		pr.ObjectText = "แท่นวาร์ป"
		pr.HoldDuration = 0.3
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = p
		pr.Triggered:Connect(function(player)
			local ch = player.Character
			if ch then
				ch:PivotTo(CF(dest + V(0, 4, 0)))
			end
		end)
	end
	pad(low, "ขึ้นไปข้างบน", entry)
	pad(entry, "ลงไปข้างล่าง", low)
	return "lift"
end

function PropBuilder.BuildCamp(position, parent)
	local m = Instance.new("Model")
	m.Name = "Camp"
	-- วางบนพื้นจริง: พื้นที่ลานแคมป์อาจถูกเกลี่ยสูงกว่าจุดที่ส่งมา (เคยทำให้กองไฟจมดิน ~5 stud)
	pcall(function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(position + V(0, 80, 0), V(0, -200, 0), rp)
		if hit then
			position = V(position.X, math.max(position.Y, hit.Position.Y), position.Z)
		end
	end)
	local base = CF(position)
	m:SetAttribute("GroundY", position.Y)
	-- วงหินรอบกองไฟ: หิน low-poly จาก Store (ไม่มีก็ใช้หินปั้น)
	local hasRealLogs = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Props")
		and ReplicatedStorage.Assets.Props:FindFirstChild("CampfireLogs")
	local rocks = storeTemplates("Boulder")
	local ring = Instance.new("Model")
	ring.Name = "CampfireRing" -- ห้ามชื่อซ้ำกับ "Campfire" (กองไฟที่ทำงานจริง)
	for i = 0, hasRealLogs and -1 or 13 do
		local ang = i / 14 * math.pi * 2
		local rcf = base * CF(math.cos(ang) * 5, 0, math.sin(ang) * 5) * ANG(0, -ang + (i % 3) * 0.7, 0)
		if rocks then
			local r = rocks[(i % #rocks) + 1]:Clone()
			pcall(function()
				r:ScaleTo(r:GetScale() * (0.22 + (i % 4) * 0.03))
			end)
			r:PivotTo(rcf * CF(0, -0.3, 0))
			for _, d in ipairs(r:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = C(104, 100, 96):Lerp(C(70, 66, 64), (i % 5) / 5)
				end
			end
			r.Parent = ring
		else
			P("Part", { Size = V(2.4, 1.6, 2), CFrame = rcf * CF(0, 0.6, 0) * ANG(0.2, 0, 0.1), Color = C(110, 106, 100), Material = Enum.Material.Slate }, ring)
		end
	end
	ring.Parent = m
	-- ฟืนจริง (โมเดล Store: ท่อนไม้กระโจม + ไม้นอนฐาน) — ไม่มีก็ใช้ท่อนไม้ปั้น
	local logs = Instance.new("Model")
	logs.Name = "Campfire"
	local real = PropBuilder.Imported("CampfireLogs", base * CF(0, -0.15, 0), 8, logs)
	if real then
		for _, d in ipairs(real:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = d.Name == "Rock"
				if d.Name == "Rock" then
					d.Color = C(118, 112, 104):Lerp(C(84, 80, 76), math.random())
					d.Material = Enum.Material.Slate
				elseif d.Name == "Ash" then
					d.Color = C(46, 40, 36)
					d.Material = Enum.Material.Ground
				else
					d.Color = C(104, 70, 44):Lerp(C(64, 42, 28), math.random())
					d.Material = Enum.Material.Wood
				end
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			elseif d:IsA("SpecialMesh") then
				d.TextureId = ""
			elseif d:IsA("Texture") or d:IsA("Decal") then
				d:Destroy()
			end
		end
	else
		for i = 0, 5 do
			local ang = i / 6 * math.pi * 2
			cylinderY(4.5, 0.8, base * CF(math.cos(ang) * 1.1, 1.6, math.sin(ang) * 1.1) * ANG(math.sin(ang) * 0.5, 0, -math.cos(ang) * 0.5), {
				Color = C(72, 52, 38), Material = Enum.Material.Wood, Name = "Log",
			}, logs)
		end
	end
	P("Part", { Name = "Ash", Shape = Enum.PartType.Cylinder, Size = V(0.3, 6.4, 6.4), CFrame = base * CF(0, 0.1, 0) * ANG(0, 0, math.pi / 2), Color = C(46, 42, 40), Material = Enum.Material.Basalt, CanCollide = false }, logs)
	local core = P("Part", {
		Name = "FireCore", Size = V(1.6, 0.4, 1.6), CFrame = base * CF(0, 1.1, 0), Transparency = 1, CanCollide = false, CanQuery = false,
	}, logs)
	local glow = ellipsoid(V(2.6, 0.5, 2.6), base * CF(0, 0.4, 0), { Name = "Embers", Color = C(255, 120, 30), Material = Enum.Material.Neon, CanCollide = false }, logs)
	glow.Parent = logs
	realFire(core, 1)
	light(core, C(255, 150, 70), 60, 3, true)
	-- ควันลอยเป็นเสาสูง เห็นได้จากในป่า (นำทางกลับแคมป์)
	local smoke = Instance.new("Smoke")
	smoke.Name = "Smoke"
	smoke.Color = C(150, 146, 140)
	smoke.Opacity = 0.08
	smoke.RiseVelocity = 7
	smoke.Size = 2
	smoke.TimeScale = 0.6
	smoke.Parent = core
	logs.PrimaryPart = core
	logs.Parent = m

	-- โต๊ะคราฟต์
	local bench = Instance.new("Model")
	bench.Name = "Workbench"
	local bcf = base * CF(22, 0, -6) * ANG(0, rad(-70), 0)
	local top = P("Part", { Name = "Top", Size = V(9, 1, 4.5), CFrame = bcf * CF(0, 3.5, 0), Color = C(140, 98, 62), Material = Enum.Material.WoodPlanks }, bench)
	for _, o in ipairs({ V(-4, 0, -1.8), V(4, 0, -1.8), V(-4, 0, 1.8), V(4, 0, 1.8) }) do
		P("Part", { Size = V(0.8, 3, 0.8), CFrame = bcf * CF(o + V(0, 1.5, 0)), Color = C(100, 70, 46), Material = Enum.Material.Wood }, bench)
	end
	P("Part", { Size = V(1.6, 0.6, 1), CFrame = bcf * CF(-2, 4.3, 0), Color = C(120, 120, 126), Material = Enum.Material.Metal }, bench)
	P("Part", { Size = V(0.4, 0.4, 3), CFrame = bcf * CF(2, 4.2, 0.4) * ANG(0, 0.4, 0), Color = C(90, 60, 40), Material = Enum.Material.Wood }, bench)
	local sign = P("Part", { Name = "Sign", Size = V(5, 1.6, 0.3), CFrame = bcf * CF(0, 5.6, -2), Color = C(70, 50, 34), Material = Enum.Material.Wood }, bench)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.PixelsPerStud = 40
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🔨 CRAFT"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(255, 220, 150)
	t.Parent = sg
	bench.PrimaryPart = top
	bench.Parent = m
	-- เครื่องย่อยเหล็ก+ไม้ (โมเดล Import) หันหน้าเข้ากองไฟ
	--   กลาง = เครื่องบด (ช่องเติมด้านบน + ฟันบดด้านล่าง + ป้ายจำนวน ไม้|เหล็ก) · ขวา = จุดคราฟต์
	-- โต๊ะคราฟต์ + เครื่องย่อย แยก 2 ชิ้น (โมเดล Import 3D: CampWorkbench / CampForge) หันหน้าเข้ากองไฟ · ชนได้ไม่เดินทะลุ
	--   Workbench.Top = จุดกดคราฟต์ (บนโต๊ะ) · Hopper/GrindOut/StockWood/StockIron = เครื่องย่อย (CampService/CombatClient ใช้ชื่อพวกนี้)
	local newDone = false
	do
		local function onGround(pos)
			pcall(function()
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Include
				rp.FilterDescendantsInstances = { workspace.Terrain }
				local hit = workspace:Raycast(pos + V(0, 60, 0), V(0, -160, 0), rp)
				if hit then
					pos = V(pos.X, math.max(pos.Y, hit.Position.Y), pos.Z)
				end
			end)
			return CFrame.lookAt(pos, pos + (base.Position - pos) * V(1, 0, 1)) -- -Z หันเข้ากองไฟ
		end
		local MODEL_YAW = math.pi -- โมเดล glTF หันหน้า +Z -> หมุนให้ด้านหน้าหัน -Z (เข้ากองไฟ)
		local wbCf = onGround((base * CF(26, 0, -2)).Position)
		local fgCf = onGround((base * CF(20, 0, -26)).Position)
		local wb = PropBuilder.Imported("CampWorkbench", wbCf * ANG(0, MODEL_YAW, 0), 15, bench, true)
		local fg = wb and PropBuilder.Imported("CampForge", fgCf * ANG(0, MODEL_YAW, 0), 15, bench, true)
		if wb and fg then
			newDone = true
			for _, d in ipairs(bench:GetChildren()) do
				if d:IsA("BasePart") then
					d.Transparency = 1
					d.CanCollide = false
					d:ClearAllChildren()
				end
			end
			local _, ws = wb:GetBoundingBox()
			local _, fs = fg:GetBoundingBox()
			-- จุดกดคราฟต์บนหน้าโต๊ะ
			top.CFrame = wbCf * CF(0, ws.Y * 0.45, -ws.Z * 0.25)
			top.Size = V(4, 1, 2)
			-- ช่องโยนของ (บนเครื่องย่อย) + จุดของออก (หน้าเครื่อง)
			P("Part", { Name = "Hopper", Size = V(fs.X * 0.5, fs.Y * 0.45, fs.Z * 0.5), CFrame = fgCf * CF(0, fs.Y * 0.55, 0), Transparency = 1, CanCollide = false, CanQuery = true }, bench)
			P("Part", { Name = "GrindOut", Size = V(1, 1, 1), CFrame = fgCf * CF(0, fs.Y * 0.3, -fs.Z * 0.55), Transparency = 1, CanCollide = false, CanQuery = false }, bench)
			bench.PrimaryPart = top
		end
	end
	local crafterPos = (base * CF(27, 0, -16)).Position
	-- วางบนพื้นจริง (พื้นตรงนั้นอาจสูงกว่าลานกองไฟ)
	pcall(function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(crafterPos + V(0, 60, 0), V(0, -160, 0), rp)
		if hit then
			crafterPos = V(crafterPos.X, math.max(crafterPos.Y, hit.Position.Y), crafterPos.Z)
		end
	end)
	local toFire = (base.Position - crafterPos) * V(1, 0, 1)
	local crafterCf = CFrame.lookAt(crafterPos, crafterPos + toFire) -- ด้านป้าย/ช่องบดของโมเดลหันเข้ากองไฟ
	local crafter = not newDone and PropBuilder.Imported("Crafter", crafterCf, 26, bench)
	if crafter then
		crafter.Name = "CrafterModel"
		for _, d in ipairs(bench:GetChildren()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
				d:ClearAllChildren()
			end
		end
		local _, size = crafter:GetBoundingBox()
		local W, H, D = size.X, size.Y, size.Z
		for _, d in ipairs(crafter:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
		-- พิกัดในโมเดล: x+ = ขวามือเมื่อยืนมองด้านหน้า, z+ = ยื่นออกมาทางด้านหน้า
		local function at(x, y, z)
			return crafterCf * CF(-x * W, y * H, -z * D) * ANG(0, math.pi, 0)
		end
		-- ตำแหน่งวัดจากภาพหน้าตรงของโมเดล (blender: 3D Model/เครื่องย่อยเหล็กกับไม้)
		-- จุดคราฟต์ (ขวา: ลังเครื่องมือ)
		top.CFrame = at(0.2, 0.45, 0.2)
		top.Size = V(W * 0.16, H * 0.2, 2)
		-- ช่องเติมของ (ถังไม้ + ถังเหล็กด้านบนเครื่องบด): ของที่ตกในโซนนี้ถูกบด -> คลังแคมป์
		P("Part", { Name = "Hopper", Size = V(W * 0.32, H * 0.3, D * 0.4), CFrame = at(-0.09, 0.56, 0.12), Transparency = 1, CanCollide = false, CanQuery = true }, bench)
		-- ฟันบดด้านล่าง: ลูกกลิ้งเหล็กมีฟัน 2 แถว ทับแถวฟันในโมเดล (หมุนตอนบด) + จุดของออก
		local out = at(-0.08, 0.12, 0.27)
		P("Part", { Name = "GrindOut", Size = V(1, 1, 1), CFrame = out, Transparency = 1, CanCollide = false, CanQuery = false }, bench)
		for i, y in ipairs({ 0.265, 0.175 }) do
			local roller = P("Part", { Name = "Roller" .. i, Shape = Enum.PartType.Cylinder, Size = V(W * 0.27, H * 0.075, H * 0.075),
				CFrame = at(-0.075, y, 0.235), Color = C(84, 86, 94), Material = Enum.Material.DiamondPlate, CanCollide = false }, bench)
			roller:SetAttribute("Spin", i == 1 and 1 or -1)
			for k = 0, 7 do
				local tooth = P("Part", { Size = V(W * 0.27, H * 0.028, H * 0.022), CFrame = roller.CFrame * ANG(k / 8 * math.pi * 2, 0, 0) * CF(0, H * 0.045, 0),
					Color = C(170, 172, 180), Material = Enum.Material.Metal, CanCollide = false }, roller)
				local w = Instance.new("WeldConstraint")
				w.Part0 = roller
				w.Part1 = tooth
				w.Parent = tooth
				tooth.Anchored = false
			end
		end
		-- ตัวเลขบนป้ายเดิมของโมเดล (ไม้ | เหล็ก) -> แทนด้วยจำนวนจริงในคลังแคมป์
		for _, info in ipairs({ { "StockWood", -0.165, 0.2985 }, { "StockIron", 0.029, 0.3017 } }) do
			local num = P("Part", { Name = info[1], Size = V(W * 0.062, H * 0.075, 0.05), CFrame = at(info[2], 0.735, 0.5 - info[3] + 0.004),
				Color = C(44, 46, 54), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }, bench)
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Back
			sg.PixelsPerStud = 60
			sg.LightInfluence = 0.6
			sg.Parent = num
			local t = Instance.new("TextLabel")
			t.Name = "Label"
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = C(238, 236, 228)
			t.Text = "0"
			t.Parent = sg
		end
		bench.PrimaryPart = top
	elseif not newDone and MeshProps.Has("Workbench") then
		for _, d in ipairs(bench:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Sign" then
				d.Transparency = 1
			end
		end
		local wb = MeshProps.Build("Workbench")
		wb:PivotTo(bcf * ANG(0, math.pi / 2, 0))
		wb.Parent = bench
	end
	-- แคมป์เรียบๆ: มีแค่กองไฟ + โต๊ะคราฟต์ + เครื่องบด (ไม่มีเต็นท์/บ้าน/รั้ว/ของตกแต่ง)
	-- ลานดินโล่ง: เปลี่ยนหญ้า Terrain รอบกองไฟเป็นดิน (สี่เหลี่ยมซ้อนกันให้ขอบเกือบกลม)
	pcall(function()
		local t = workspace.Terrain
		local p0 = base.Position
		for _, half in ipairs({ V(66, 0, 38), V(38, 0, 66), V(54, 0, 54) }) do -- ลานฐานกว้าง (เดิม 32)
			local lo = p0 - half - V(0, 14, 0)
			local hi = p0 + half + V(0, 14, 0)
			t:ReplaceMaterial(Region3.new(lo, hi):ExpandToGrid(4), 4, Enum.Material.Grass, Enum.Material.Ground)
		end
	end)
	m.Parent = parent
	return m
end

-- ศาลเจ้า: กรงลูกสัตว์ธาตุ
function PropBuilder.BuildShrine(sp, parent)
	local el = sp.Element
	local col = ELEMENT_COLOR[el]
	local m = Instance.new("Model")
	m.Name = "Shrine_" .. el
	local base = faceCamp(sp.Position)
	m.WorldPivot = base
	-- ศาลเจ้าจาก Creator Store: อาคารใหญ่เดินเข้าได้ ตั้งหลังกรง (ฝั่งตรงข้ามแคมป์) -> แทนวงเสาหินปั้น
	--   { ชื่อโมเดล, เท่าของความกว้างมาตรฐาน (SiteSpec), หมุนแก้ทิศ }
	local SHRINE_STORE = {
		Earth = { "ShrineEarth", 0.85, 0 }, -- ซุ้มประตูหินโบราณ + ดอกไม้
		Water = { "ShrineWater", 1, 0 }, -- เกาะประตูโทริอิ + ต้นซากุระ
		Air = { "ShrineAir", 1, 0 }, -- พระราชวังน้ำแข็งลายเกลียว
		Fire = { "ShrineFire", 1, 0 }, -- แท่นบูชาปีศาจลาวา
	}
	local ss = SHRINE_STORE[el]
	local spec = SiteSpec.Get("Shrine", el)
	local storeShrine = ss and PropBuilder.Backdrop(ss[1], base, spec.Width * ss[2], spec.Gap, m, { Yaw = ss[3], Material = SEAT_MAT[el] })
	for i = 0, storeShrine and -1 or 5 do
		local ang = i / 6 * math.pi * 2
		local pcf = base * CF(math.cos(ang) * 14, 0, math.sin(ang) * 14)
		local h = 12 + (i % 2) * 5
		P("Part", { Size = V(2.6, h, 2.6), CFrame = pcf * CF(0, h / 2, 0) * ANG(0, ang, 0), Color = C(110, 106, 100), Material = Enum.Material.Slate }, m)
		P("Part", { Size = V(2.8, 0.8, 2.8), CFrame = pcf * CF(0, h * 0.7, 0) * ANG(0, ang, 0), Color = col, Material = Enum.Material.Neon }, m)
	end
	m:SetAttribute("SitePos", sp.Position) -- ตำแหน่งลานเดิม (ใช้สร้างใหม่ตอนเริ่มรอบ)
	-- กรงอยู่บนลานของตัวศาลเจ้า (ขึ้นบันไดไปช่วย) · หาลานไม่ได้ = หน้าศาลเจ้า
	if storeShrine then
		local area = PropBuilder.PlayArea(storeShrine, base, { MinCells = 4, Headroom = 10 })
		if area then
			base = CF(area.Center) * (base - base.Position)
			m.WorldPivot = base
			PropBuilder.BuildAccess(area, faceCamp(sp.Position), storeShrine, m, nil)
		end
	end
	-- กรง
	local cage = Instance.new("Model")
	cage.Name = "Cage"
	-- กรงนกไม้เลื้อยจาก Creator Store (ไม่มี = กรงเหล็กปั้นเหมือนเดิม)
	local storeCage = PropBuilder.Imported("CageLP", base * CF(0, 0, 0), 10, cage, true)
	for i = 0, storeCage and -1 or 9 do
		local ang = i / 10 * math.pi * 2
		cylinderY(9, 0.5, base * CF(math.cos(ang) * 4.6, 6.4, math.sin(ang) * 4.6), { Color = C(60, 60, 64), Material = Enum.Material.Metal, Name = "Bar" }, cage)
	end
	local cageTop = 12.6
	if storeCage then
		local _, cs = storeCage:GetBoundingBox()
		cageTop = cs.Y + 1.6
	else
		cylinderY(0.8, 10.4, base * CF(0, 11, 0), { Color = C(60, 60, 64), Material = Enum.Material.Metal, Name = "Lid" }, cage)
	end
	local seal = ellipsoid(V(3, 3, 3), base * CF(0, cageTop, 0), { Name = "Seal", Color = col, Material = Enum.Material.Neon, CanCollide = false }, cage)
	light(seal, col, 30, 2.5)
	cage.Parent = m
	-- ลำแสงขึ้นฟ้า
	local beamA = Instance.new("Attachment")
	beamA.Position = V(0, 0, 0)
	beamA.Parent = seal
	local top = P("Part", { Name = "BeamTop", Size = V(1, 1, 1), CFrame = base * CF(0, 300, 0), Transparency = 1, CanCollide = false }, m)
	local beamB = Instance.new("Attachment")
	beamB.Parent = top
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamA
	beam.Attachment1 = beamB
	beam.Width0 = 4
	beam.Width1 = 10
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(col)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 0.4
	beam.Parent = seal
	m:SetAttribute("Element", el)
	CollectionService:AddTag(m, "Shrine")
	m.Parent = parent
	return m
end

-- รังบอส: วงหินตั้ง + เตาไฟ + กระดูกยักษ์
function PropBuilder.BuildLair(sp, parent)
	local el = sp.Element
	local col = ELEMENT_COLOR[el]
	local m = Instance.new("Model")
	m.Name = "Lair_" .. el
	local base = faceCamp(sp.Position)
	local R = sp.Floating and 52 or 62
	local stoneColor = ({ Earth = C(96, 100, 90), Water = C(190, 206, 200), Air = C(120, 132, 168), Fire = C(40, 34, 36) })[el]
	local stoneMat = ({ Earth = Enum.Material.Slate, Water = Enum.Material.Limestone, Air = Enum.Material.Slate, Fire = Enum.Material.Basalt })[el]
	-- ฉากหลังจาก Creator Store (ต่อธาตุ) -> แทนวงเสาหินปั้น
	--   { ชื่อโมเดล, เท่าของความกว้างมาตรฐาน (SiteSpec), หมุนแก้ทิศ } · ตั้งฝั่งตรงข้ามแคมป์ หน้าหันเข้าลาน (ดิน = ล้อมลาน)
	local LAIR_STORE = {
		Earth = { "Colosseum", 1, 0 }, -- โคลอสเซียมล้อมลานสู้
		-- น้ำ: ไม่มีอาคาร -> ห้วงน้ำลึก + แท่นหินโผล่พ้นน้ำ (สร้างด้านล่าง)
		Air = { "IcePalace", 1, 0, { "Ceiling", "Pre_Ceiling" } }, -- ห้องโถงพระราชวังน้ำแข็ง (บนเกาะลอยฟ้า) ไม่เอาเปลือกพีระมิด
		Fire = { "FireThrone", 1, 0 }, -- อารีนาบัลลังก์นรก (3D Model/Biome Fire/Solfang/Throne) · ยังไม่ Import = ลานเปิดวงหินตั้ง
	}
	local ls = LAIR_STORE[el]
	local spec = SiteSpec.Get("Lair", el)
	local backdrop = ls
		and PropBuilder.Backdrop(ls[1], base, spec.Width * ls[2], spec.Gap, m, {
			Yaw = ls[3],
			Hide = ls[4],
			Material = SEAT_MAT[el],
			WaterLevel = el == "Water" and sp.Position.Y + 2 or nil, -- ลานรังน้ำอยู่ใต้ผิวน้ำ 2 stud (MapGenerator)
		})
	-- รังน้ำ: แท่นหินโผล่พ้นน้ำ 2 วงรอบห้วงลึก (ผู้เล่นยืน/กระโดดข้ามได้) · บอสว่ายอยู่กลางน้ำ
	if el == "Water" then
		local terrain = workspace.Terrain
		local wl = base.Position.Y + 16 -- ระดับผิวน้ำ (MapGenerator ขุดแอ่งลึก 16 ใต้ผิวน้ำ)
		local floorY = base.Position.Y
		local rngW = Random.new(math.floor(base.Position.X + base.Position.Z))
		for ring, info in ipairs({ { 64, 9, 11 }, { 104, 12, 14 } }) do
			local n = info[2]
			for i = 0, n - 1 do
				local a = (i + (ring == 2 and 0.5 or 0)) / n * math.pi * 2 + rngW:NextNumber(-0.12, 0.12)
				local rad2 = info[1] + rngW:NextNumber(-6, 6)
				local px, pz = base.Position.X + math.cos(a) * rad2, base.Position.Z + math.sin(a) * rad2
				local r = info[3] * rngW:NextNumber(0.8, 1.15)
				local top = wl + rngW:NextNumber(1.2, 3.2)
				pcall(function()
					terrain:FillCylinder(CF(px, (floorY - 4 + top) / 2, pz), top - floorY + 4, r, Enum.Material.Slate)
					terrain:FillCylinder(CF(px, top - 0.6, pz), 1.6, r * 0.92, Enum.Material.Sand)
				end)
			end
		end
		-- จุดเกิดบอส: กลางห้วงน้ำ ที่ผิวน้ำ
		base = CF(base.Position.X, wl - 1.5, base.Position.Z) * (base - base.Position)
	end
	-- รังไฟ: วงลาวาล้อมรอบฐาน (พื้นหินแตกลาวาเรืองแสง + แสงส้มวูบ + ประกายไฟ)
	if el == "Fire" then
		local terrain = workspace.Terrain
		local rb = spec.Width / 2
		if backdrop then
			local _, bs = backdrop:GetBoundingBox()
			rb = math.max(bs.X, bs.Z) / 2
		end
		local r0, gy = rb + 10, base.Position.Y
		local seg = math.ceil(math.pi * 2 * r0 / 10)
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			local cf = CF(base.Position.X + math.cos(a) * r0, gy - 2.5, base.Position.Z + math.sin(a) * r0) * ANG(0, -a, 0)
			pcall(function()
				terrain:FillBlock(cf, V(18, 5, 12), Enum.Material.CrackedLava)
			end)
			if i % 4 == 0 then
				local glowPart = P("Part", { Name = "LavaGlow", Size = V(1, 1, 1), CFrame = cf * CF(0, 3.5, 0), Transparency = 1, CanCollide = false, CanQuery = false }, m)
				light(glowPart, C(255, 110, 30), 26, 1.6)
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(C(255, 180, 60), C(255, 70, 20))
				e.LightEmission, e.LightInfluence = 1, 0
				e.Rate = 6
				e.Lifetime = NumberRange.new(1.5, 2.6)
				e.Speed = NumberRange.new(2, 5)
				e.SpreadAngle = Vector2.new(25, 25)
				e.Acceleration = V(0, 2, 0)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
				e.Parent = glowPart
			end
		end
	end
	-- ลานสู้บอส = พื้นโล่งข้างในรังที่ใกล้กลางที่สุด (ไม่ไปเกิดบนหลังคา/ยอดตึก)
	if backdrop then
		local home = backdrop.Parent
		backdrop.Parent = workspace
		-- พื้นจริงของอาคาร (วังน้ำแข็ง/บัลลังก์ไฟ พื้นยกสูงกว่าดิน ~20) -> หาลานบนพื้นนั้น ไม่ใช่ดินข้างนอก
		local floorY = base.Position.Y
		local rpF = RaycastParams.new()
		rpF.FilterType = Enum.RaycastFilterType.Include
		rpF.FilterDescendantsInstances = { backdrop }
		local best
		for _, off in ipairs({ V(0, 0, 0), V(12, 0, 0), V(-12, 0, 0), V(0, 0, 12), V(0, 0, -12) }) do
			local hit = workspace:Raycast(base.Position + off + V(0, 60, 0), V(0, -90, 0), rpF)
			if hit and hit.Position.Y > floorY - 6 and hit.Position.Y < floorY + 40 then
				best = best and math.min(best, hit.Position.Y) or hit.Position.Y
			end
		end
		floorY = best or floorY
		local spot = openFloor(backdrop, base.Position, floorY, spec.Width * (best and 0.18 or 0.3))
		backdrop.Parent = home
		if spot then
			base = CF(spot) * (base - base.Position)
		end
	end
	for i = 0, (backdrop or el == "Water") and -1 or 9 do
		local ang = i / 10 * math.pi * 2
		local h = 18 + (i % 3) * 6
		local scf = base * CF(math.cos(ang) * R, 0, math.sin(ang) * R) * ANG(rad(math.sin(i) * 6), -ang, rad(math.cos(i) * 5))
		P("Part", { Size = V(5, h, 3.4), CFrame = scf * CF(0, h / 2 - 1, 0), Color = stoneColor, Material = stoneMat }, m)
		-- รูนเรืองแสง
		P("Part", { Size = V(5.2, 1, 3.6), CFrame = scf * CF(0, h * 0.62, 0), Color = col, Material = Enum.Material.Neon }, m)
		if i % 2 == 0 then
			-- เตาไฟ
			local bcf = base * CF(math.cos(ang + 0.31) * (R - 8), 0, math.sin(ang + 0.31) * (R - 8))
			cylinderY(4, 3, bcf * CF(0, 2, 0), { Color = C(50, 48, 50), Material = Enum.Material.Metal }, m)
			local bowl = cylinderY(1, 5, bcf * CF(0, 4.4, 0), { Color = C(60, 56, 56), Material = Enum.Material.Metal }, m)
			fire(bowl, 5, (el == "Fire" or el == "Earth") and C(255, 140, 40) or col)
			light(bowl, col, 34, 2)
		end
	end
	-- ซี่โครงยักษ์ (ซากเหยื่อ)
	for i = 0, (backdrop or el == "Water") and -1 or 5 do
		local z = -12 + i * 5
		cylinderY(22 - math.abs(i - 2.5) * 3, 1.6, base * CF(-24, 6, z) * ANG(0, 0, rad(-38)), { Color = C(226, 218, 196), Material = Enum.Material.SmoothPlastic }, m)
	end
	if not backdrop and el ~= "Water" then
		ellipsoid(V(9, 7, 11), base * CF(-30, 3.5, -22) * ANG(0.3, 0.5, 0.2), { Color = C(232, 226, 206), Material = Enum.Material.SmoothPlastic }, m)
	end
	-- วงเวทกลางลาน
	local sigil = cylinderY(0.3, 36, base * CF(0, 0.2, 0), { Name = "Sigil", Color = col, Material = Enum.Material.Slate, Transparency = 1, CanCollide = false }, m)
	do
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Shape = Enum.ParticleEmitterShape.Cylinder
		mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		mist.Rate = 10
		mist.Lifetime = NumberRange.new(3, 5)
		mist.Speed = NumberRange.new(0.5, 1.5)
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
		mist.Color = ColorSequence.new(col)
		mist.LightEmission = 0.4
		mist.Parent = sigil
		local glow = Instance.new("PointLight")
		glow.Color = col
		glow.Range = 30
		glow.Brightness = 0.8
		glow.Parent = sigil
	end
	sigil:SetAttribute("Element", el)
	local center = P("Part", { Name = "BossSpawn", Size = V(2, 2, 2), CFrame = base * CF(0, 4, 0), Transparency = 1, CanCollide = false }, m)
	center:SetAttribute("Element", el)
	m:SetAttribute("Element", el)
	CollectionService:AddTag(m, "Lair")
	m.Parent = parent
	return m
end

-- ซากปรักหักพัง + หีบ
function PropBuilder.BuildRuins(sp, parent, rng)
	local el = sp.Element
	local m = Instance.new("Model")
	m.Name = "Ruins_" .. el
	local base = faceCamp(sp.Position)
	local stone = ({ Earth = C(130, 126, 116), Water = C(200, 214, 206), Air = C(170, 178, 200), Fire = C(110, 70, 56) })[el]
	-- ซากปรักหักพังจาก Creator Store (เกาะบ้านร้าง) -> ไม่ต้องปั้นเสา/ซุ้ม/พื้นแตก
	local rs = SiteSpec.Get("Ruins", el)
	local storeRuins = PropBuilder.Backdrop("RuinsIsland", base, rs.Width, rs.Gap, m, { Material = SEAT_MAT[el] })
	-- เสา
	for i = 0, storeRuins and -1 or 5 do
		local x = (i % 3 - 1) * 12
		local z = (i < 3) and -8 or 8
		local h = rng:NextNumber(4, 16)
		local pillar = cylinderY(h, 3, base * CF(x, h / 2, z), { Color = stone, Material = Enum.Material.Cobblestone }, m)
		pillar.CFrame *= ANG(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		if h > 12 then
			P("Part", { Size = V(4, 1.4, 4), CFrame = base * CF(x, h + 0.5, z), Color = stone, Material = Enum.Material.Cobblestone }, m)
		end
	end
	-- ซุ้มประตู
	if not storeRuins then
		P("Part", { Size = V(3, 14, 3), CFrame = base * CF(-6, 7, -18), Color = stone, Material = Enum.Material.Brick }, m)
		P("Part", { Size = V(3, 14, 3), CFrame = base * CF(6, 7, -18), Color = stone, Material = Enum.Material.Brick }, m)
		P("Part", { Size = V(16, 3, 3.4), CFrame = base * CF(0, 15, -18), Color = stone, Material = Enum.Material.Brick }, m)
	end
	-- พื้นแตก
	for _ = 1, storeRuins and 0 or 8 do
		P("Part", {
			Size = V(rng:NextNumber(3, 6), 0.8, rng:NextNumber(3, 6)),
			CFrame = base * CF(rng:NextNumber(-14, 14), 0.2, rng:NextNumber(-12, 12)) * ANG(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 3), rng:NextNumber(-0.1, 0.1)),
			Color = stone, Material = Enum.Material.Cobblestone,
		}, m)
	end
	-- หีบ
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	local ccf = base * CF(0, 0, storeRuins and -10 or 0)
	local body = P("Part", { Name = "Body", Size = V(4, 2.6, 2.8), CFrame = ccf * CF(0, 1.3, 0), Color = C(110, 72, 40), Material = Enum.Material.WoodPlanks }, chest)
	P("Part", { Name = "Lid", Size = V(4.1, 1, 2.9), CFrame = ccf * CF(0, 3.1, 0), Color = C(130, 86, 48), Material = Enum.Material.WoodPlanks }, chest)
	P("Part", { Size = V(4.2, 0.4, 3), CFrame = ccf * CF(0, 2.6, 0), Color = C(210, 170, 70), Material = Enum.Material.Metal }, chest)
	P("Part", { Size = V(0.6, 0.8, 0.2), CFrame = ccf * CF(0, 2.4, -1.5), Color = C(230, 190, 80), Material = Enum.Material.Neon }, chest)
	chest.PrimaryPart = body
	local assetsProps = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Props")
	if assetsProps and assetsProps:FindFirstChild("ChestLP") then
		-- หีบสมบัติจาก Creator Store (ชิ้นปั้นเดิมซ่อนไว้เป็นตัวชน/จุดอ้างอิง)
		for _, d in ipairs(chest:GetChildren()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
		PropBuilder.Imported("ChestLP", ccf, 4.6, chest)
	elseif MeshProps.Has("Chest") then
		for _, d in ipairs(chest:GetChildren()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
		local cm = MeshProps.Build("Chest")
		cm:PivotTo(ccf)
		cm.Parent = chest
	end
	chest:SetAttribute("Element", el)
	CollectionService:AddTag(chest, "Chest")
	chest.Parent = m
	m.Parent = parent
	return m
end

-- รอยแยกธาตุ: กลุ่มคริสตัลใหญ่
function PropBuilder.BuildRift(sp, parent, rng)
	local kind = ({ Earth = "TerraCrystal", Water = "TideCrystal", Air = "GaleCrystal", Fire = "EmberCrystal" })[sp.Element]
	local m = Instance.new("Model")
	m.Name = "Rift_" .. sp.Element
	for i = 1, 5 do
		local ang = i / 5 * math.pi * 2
		local r = (i == 1) and 0 or rng:NextNumber(6, 12)
		local pos = sp.Position + V(math.cos(ang) * r, -0.5, math.sin(ang) * r)
		PropBuilder.Place(kind, pos, rng:NextNumber(0, 6.28), (i == 1) and 2.2 or rng:NextNumber(1, 1.5), m, rng)
	end
	m.Parent = parent
	return m
end

-- ลมพัดขึ้น (ธาตุลม)
function PropBuilder.BuildUpdraft(up, parent)
	local h = up.Height
	local zone = P("Part", {
		Name = "Updraft", Size = V(16, h, 16), CFrame = CF(up.Position + V(0, h / 2, 0)),
		Transparency = 1, CanCollide = false, CanQuery = false,
	}, parent)
	zone:SetAttribute("Height", h)
	CollectionService:AddTag(zone, "Updraft")
	local ring = cylinderY(0.4, 16, CF(up.Position + V(0, 0.4, 0)), { Name = "UpdraftRing", Color = C(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.85, CanCollide = false }, parent)
	local att = Instance.new("Attachment")
	att.Parent = ring
	local wind = Instance.new("ParticleEmitter")
	wind.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wind.Rate = 25
	wind.Lifetime = NumberRange.new(3, 4)
	wind.Speed = NumberRange.new(h / 3.5, h / 3)
	wind.EmissionDirection = Enum.NormalId.Top
	wind.SpreadAngle = Vector2.new(6, 6)
	wind.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	wind.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	wind.Color = ColorSequence.new(C(230, 240, 255))
	wind.LightEmission = 0.4
	wind.Parent = att
	return zone
end

-- ขอบแมพ: กำแพงล่องหน
function PropBuilder.BuildBoundary(layout, parent)
	local half = layout.Half
	for i = 0, 3 do
		local ang = i * math.pi / 2
		P("Part", {
			Name = "Boundary", Size = V(layout.Size, 2000, 10),
			CFrame = CF(0, 900, 0) * ANG(0, ang, 0) * CF(0, 0, half + 5),
			Transparency = 1, CanCollide = true, CanQuery = false,
		}, parent)
	end
end

---------------------------------------------------------------- สร้างทั้งโลก
function PropBuilder.BuildWorld(layout, opts)
	opts = opts or {}
	local world = workspace:FindFirstChild("World")
	if world then
		world:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = world
	local sites = Instance.new("Folder")
	sites.Name = "Sites"
	sites.Parent = world

	local rng = Random.new(layout.Seed + 7)
	PropBuilder.TerrainBoulders(layout, opts)
	PropBuilder.BuildBoundary(layout, world)
	local campY = layout:HeightAt(0, 0)
	PropBuilder.BuildCamp(Vector3.new(0, campY, 0), sites)
	for _, sp in ipairs(layout.Specials) do
		if sp.Kind == "Shrine" then
			PropBuilder.BuildShrine(sp, sites)
		elseif sp.Kind == "Lair" then
			PropBuilder.BuildLair(sp, sites)
		elseif sp.Kind == "Ruins" then
			PropBuilder.BuildRuins(sp, sites, rng)
		elseif sp.Kind == "Rift" then
			PropBuilder.BuildRift(sp, sites, rng)
		end
	end
	for _, up in ipairs(layout.Updrafts) do
		PropBuilder.BuildUpdraft(up, sites)
	end
	local n = PropBuilder.Scatter(layout, props, opts)
	world:SetAttribute("PropCount", n)
	PropBuilder.ClearTemplates()
	return world
end

return PropBuilder
