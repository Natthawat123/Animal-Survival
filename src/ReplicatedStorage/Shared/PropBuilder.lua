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

-- แม่แบบที่สร้างเสร็จแล้ว (ไว้ Clone) ต้องอยู่นอก workspace — แม่แบบวางอยู่ที่จุด 0,0,0 = กลางแคมป์พอดี
--   แม่แบบที่สร้างหลัง ClearTemplates (วิหาร/ศาลเจ้าตอนเล่น) เคยค้างใน workspace -> ใบโอ๊กยักษ์ครอบกองไฟเป็นพุ่ม
local templateHome: Folder? = nil
local function stashTemplate(t)
	if not templateHome or not templateHome.Parent then
		templateHome = Instance.new("Folder")
		templateHome.Name = "_ASPropTemplates"
		templateHome.Parent = game:GetService("RunService"):IsServer() and game:GetService("ServerStorage") or ReplicatedStorage
	end
	t.Parent = templateHome
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
	stashTemplate(model)
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
	Node = { Node = "Tree", Yield = "Wood", HP = 10, Total = 5 },
	Scale = { 0.9, 1.7 },
	Build = function()
		return pine("GiantPine", C(46, 92, 52), Enum.Material.LeafyGrass, C(88, 62, 46))
	end,
}
Kinds.FrostPine = {
	Node = { Node = "Tree", Yield = "Wood", HP = 9, Total = 5 },
	Scale = { 0.8, 1.4 },
	Build = function()
		return pine("FrostPine", C(96, 140, 140), Enum.Material.Grass, C(96, 84, 80), true)
	end,
}
Kinds.Oak = {
	Node = { Node = "Tree", Yield = "Wood", HP = 8, Total = 4 },
	Scale = { 0.8, 1.2 },
	Build = function()
		return broadTree("Oak", C(96, 150, 58), C(104, 74, 50), 14, 15)
	end,
}
Kinds.AncientOak = {
	Node = { Node = "Tree", Yield = "Wood", HP = 16, Total = 8 },
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
	Node = { Node = "Tree", Yield = "Wood", HP = 7, Total = 4 },
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
	Node = { Node = "Tree", Yield = "Coal", HP = 8, Total = 3, Bonus = "Wood" },
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
	Node = { Node = "Bush", Yield = "Berries", HP = 1, Amount = 2, Bonus = "Fiber", Regrow = 150 },
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
Kinds.Boulder = { Node = { Node = "Rock", Yield = "Stone", HP = 8, Total = 5 }, Scale = { 0.6, 1.4 }, Build = rockKind("Boulder", V(9, 6, 8), C(132, 130, 126), Enum.Material.Slate) }
Kinds.MossRock = {
	Node = { Node = "Rock", Yield = "Stone", HP = 10, Total = 6 }, Scale = { 0.8, 1.8 },
	Build = rockKind("MossRock", V(11, 7, 10), C(98, 102, 96), Enum.Material.Slate, function()
		return { ellipsoid(V(9, 2.4, 8), CF(0, 5.2, 0), { Name = "Moss", Color = C(70, 130, 50), Material = Enum.Material.Grass, CanCollide = false }) }
	end),
}
Kinds.SeaRock = { Node = { Node = "Rock", Yield = "Stone", HP = 8, Total = 5 }, Scale = { 0.8, 2.0 }, Build = rockKind("SeaRock", V(10, 9, 9), C(186, 204, 196), Enum.Material.Limestone) }
Kinds.SkyStone = {
	Node = { Node = "Rock", Yield = "Stone", HP = 8, Total = 5 }, Scale = { 0.7, 1.6 },
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
	Node = { Node = "Rock", Yield = "Iron", HP = 10, Total = 3, Bonus = "Stone" }, Scale = { 0.8, 1.3 },
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
	Node = { Node = "Rock", Yield = "Coal", HP = 10, Total = 4, Bonus = "Stone" }, Scale = { 0.8, 1.3 },
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
		Node = { Node = "Crystal", Yield = element, HP = 8, Total = 2, Regrow = 300 },
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
	stashTemplate(m)
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
		stashTemplate(t)
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
		local hp = math.floor(spec.Node.HP * math.max(scale, 0.7) + 0.5)
		if spec.Node.Node == "Tree" or spec.Node.Node == "Rock" then
			-- ตีด้วยเครื่องมือพื้นฐาน (แรง 1): ต้นเล็ก/หินเล็ก 6 ครั้ง · ต้นใหญ่/หินใหญ่ 10 ครั้ง
			hp = (spec.Node.HP >= 14 or scale >= 1.25) and 10 or 6
		end
		inst:SetAttribute("HP", hp)
		inst:SetAttribute("MaxHP", inst:GetAttribute("HP"))
		-- Total = ได้ของทั้งต้น/ก้อน (ต้นใหญ่ตีนานขึ้นแต่ได้เพิ่มนิดเดียว ไม่ทวีตามขนาด)
		local per = spec.Node.YieldPerHP or 1
		if spec.Node.Total then
			per = spec.Node.Total * math.clamp(scale, 0.8, 1.35) / inst:GetAttribute("HP")
		end
		inst:SetAttribute("YieldPerHP", per)
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
	-- บางโมเดลเก็บทั้งก้อนหมุนผิดแกน (กลับหัว / นอนตะแคง เช่น พื้นหินวงกลม + กระถางไฟที่ "ด้านบน" = แกน X)
	--   นับทิศ UpVector ของชิ้นส่วน: ทิศที่ชิ้นส่วนส่วนใหญ่ชี้ = ด้านบนจริงของโมเดล -> หมุนให้ชี้ขึ้น (+Y)
	local tally = { ["+X"] = 0, ["-X"] = 0, ["+Y"] = 0, ["-Y"] = 0, ["+Z"] = 0, ["-Z"] = 0 }
	local nParts = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			nParts += 1
			local u = d.CFrame.UpVector
			if u.X > 0.7 then
				tally["+X"] += 1
			elseif u.X < -0.7 then
				tally["-X"] += 1
			elseif u.Y > 0.7 then
				tally["+Y"] += 1
			elseif u.Y < -0.7 then
				tally["-Y"] += 1
			elseif u.Z > 0.7 then
				tally["+Z"] += 1
			elseif u.Z < -0.7 then
				tally["-Z"] += 1
			end
		end
	end
	local bestDir, bestN = "+Y", tally["+Y"]
	for dir, n in pairs(tally) do
		if n > bestN then
			bestDir, bestN = dir, n
		end
	end
	-- เฉพาะโมเดลที่รู้แน่ว่าเก็บมานอน (ห้ามเดาจากทิศชิ้นส่วนทุกโมเดล: เสาทรงกระบอกตั้งตรงมีแกน Up แนวนอน -> เคยพลิกซากวิหารลงนอนพื้น)
	local UPRIGHT_FIX = { PlazaCircleLP = true, BrazierLP = true }
	if UPRIGHT_FIX[name] and bestDir ~= "+Y" and bestN >= math.max(20, nParts * 0.6) and bestN > tally["+Y"] * 3 then
		local fix = ({
			["-Y"] = ANG(math.pi, 0, 0), ["+X"] = ANG(0, 0, math.pi / 2), ["-X"] = ANG(0, 0, -math.pi / 2),
			["+Z"] = ANG(-math.pi / 2, 0, 0), ["-Z"] = ANG(math.pi / 2, 0, 0),
		})[bestDir]
		local piv = m:GetPivot()
		m:PivotTo(CF(piv.Position) * fix * (piv - piv.Position))
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

-- ฟืนกองไฟจริง (โมเดล Store: ท่อนไม้กระโจม + หินล้อม + ขี้เถ้า) ทาสีไม้/หินใหม่ · ไม่มีโมเดล = nil
function PropBuilder.CampfireLogs(cf, width, parent)
	local real = PropBuilder.Imported("CampfireLogs", cf, width, parent)
	if not real then
		return nil
	end
	for _, d in ipairs(real:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = d.Name == "Rock"
			d.Reflectance = 0 -- โมเดลต้นฉบับตั้งไม้สะท้อน 0.4 -> สะท้อนฟ้าเป็นไม้สีฟ้าขาว
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
	return real
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
	local real = PropBuilder.CampfireLogs(base * CF(0, -0.15, 0), 8, logs)
	if not real then
		for i = 0, 5 do
			local ang = i / 6 * math.pi * 2
			cylinderY(4.5, 0.8, base * CF(math.cos(ang) * 1.1, 1.6, math.sin(ang) * 1.1) * ANG(math.sin(ang) * 0.5, 0, -math.cos(ang) * 0.5), {
				Color = C(72, 52, 38), Material = Enum.Material.Wood, Name = "Log",
			}, logs)
		end
	end
	P("Part", { Name = "Ash", Shape = Enum.PartType.Cylinder, Size = V(0.3, 6.4, 6.4), CFrame = base * CF(0, 0.1, 0) * ANG(0, 0, math.pi / 2), Color = C(46, 42, 40), Material = Enum.Material.Basalt, CanCollide = false }, logs)
	local core = P("Part", {
		Name = "FireCore", Size = V(1.6, 0.4, 1.6), CFrame = base * CF(0, 1.6, 0), Transparency = 1, CanCollide = false, CanQuery = false,
	}, logs)
	local glow = ellipsoid(V(2.6, 0.5, 2.6), base * CF(0, 0.4, 0), { Name = "Embers", Color = C(255, 120, 30), Material = Enum.Material.Neon, CanCollide = false }, logs)
	glow.Parent = logs
	realFire(core, 1.5) -- เปลวต้องพุ่งพ้นยอดกระโจมฟืน (สเกล 1 โดนท่อนไม้บังมิด เห็นเป็นกองไม้)
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
		-- โต๊ะคราฟต์: โมเดลนี้หันหน้า -Z อยู่แล้ว (หมุน 180° = หันหลังให้กองไฟ) -> ไม่หมุน
		local wb = PropBuilder.Imported("CampWorkbench", wbCf, 15, bench, true)
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
-- ---------------------------------------------------------------- ลานพิธี (ศาลเจ้า/วิหาร)
-- พื้นหินกลมเรียบบนดิน (Part ชนได้จริง) หน้าอาคาร -> ของเล่น (กรง/เสารูน/หีบ) วางบนลานนี้ทั้งหมด เดินถึงได้แน่นอน
--   ไม่พึ่งรูปทรงโมเดล Store (เคยวางของบนหลังคา/ชั้นบนแล้วลอย/ขึ้นไม่ได้)
--   frame = กลางลาน (Y = ระดับพื้นที่ MapGenerator ปรับเรียบไว้) · คืนความสูงผิวลาน
local PLAZA_STONE = {
	Earth = { C(126, 116, 98), Enum.Material.Cobblestone },
	Water = { C(198, 192, 172), Enum.Material.Limestone },
	Air = { C(206, 214, 228), Enum.Material.Marble },
	Fire = { C(64, 54, 52), Enum.Material.Basalt },
}
PropBuilder.PlazaRadius = { Shrine = 24, Sanctum = 32 } -- ต้องเล็กกว่า SiteSpec.Gap (ไม่ให้ลานทับตัวอาคาร)
function PropBuilder.BuildPlaza(frame, radius, el, parent, groundMat, opts)
	local col = ELEMENT_COLOR[el] or C(255, 255, 255)
	local stone = PLAZA_STONE[el] or PLAZA_STONE.Earth
	local mat = groundMat or SEAT_MAT[el] or Enum.Material.Ground
	local p = frame.Position
	local gy = p.Y
	local top = gy + 0.5
	-- ดินใต้ลาน: ล้างเนิน/ต้นไม้ดินที่ยื่นขึ้นมา + ถมฐานให้เต็ม + ขอบลาดลง (ไม่ลอย ไม่เป็นหน้าผา)
	pcall(function()
		local terrain = workspace.Terrain
		terrain:FillCylinder(CF(p.X, gy + 25, p.Z), 50, radius + 4, Enum.Material.Air)
		terrain:FillCylinder(CF(p.X, gy - 5, p.Z), 10, radius + 4, mat)
		for i = 1, 5 do
			terrain:FillCylinder(CF(p.X, gy - 1.2 - i * 2.6, p.Z), 2.8, radius + 4 + i * 3.5, mat)
		end
	end)
	local rot = frame - frame.Position
	-- พื้นลาน: หินปูวงกลมลายแกะจาก Creator Store (PlazaCircleLP) วางบนดินที่ปรับเรียบ · ไม่มีโมเดล = จานหินปั้นแทน
	local floor = PropBuilder.Imported("PlazaCircleLP", CF(p.X, gy + 0.05, p.Z) * rot, radius * 2, parent, true)
	if floor then
		floor.Name = "PlazaFloor"
		local fcf, fsz = floor:GetBoundingBox()
		top = fcf.Position.Y + fsz.Y / 2
	else
		cylinderY(1.6, radius * 2, CF(p.X, top - 0.8, p.Z) * rot, { Name = "PlazaFloor", Color = stone[1], Material = stone[2], CanCollide = true }, parent)
	end
	local base = CF(p.X, top, p.Z) * rot
	-- กระถางไฟเหล็กจาก Store (มีไฟอนุภาคในตัว) 4 มุม + แสงสีธาตุ — บอกตำแหน่งลานจากไกลตอนกลางคืน
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local bcf = base * CF(math.cos(a) * (radius - 3.5), 0, math.sin(a) * (radius - 3.5))
		local br = PropBuilder.Imported("BrazierLP", bcf, 5.5, parent, true)
		local host
		if br then
			br.Name = "PlazaBrazier"
			host = br:FindFirstChildWhichIsA("BasePart", true)
		else
			P("Part", { Name = "PlazaPost", Size = V(2.4, 4, 2.4), CFrame = bcf * CF(0, 2, 0), Color = stone[1], Material = stone[2] }, parent)
			host = cylinderY(1, 3.6, bcf * CF(0, 4.5, 0), { Name = "PlazaBrazier", Color = C(60, 46, 36), Material = Enum.Material.Metal }, parent)
			fire(host, 4, el == "Fire" and C(255, 140, 40) or col)
		end
		if host then
			light(host, col, 28, 1.8)
		end
	end
	-- วงหินรูน (Store: RuneStoneLP) ล้อมกลางลาน หันหน้าเข้ากลาง
	if opts and opts.Stones then
		for k = 0, opts.Stones - 1 do
			local a = k / opts.Stones * math.pi * 2 + math.pi / opts.Stones
			local sp = (base * CF(math.cos(a) * opts.StoneRadius, 0, math.sin(a) * opts.StoneRadius)).Position
			local st = PropBuilder.Imported("RuneStoneLP", CFrame.lookAt(sp, V(p.X, sp.Y, p.Z)), 3.6 + (k % 2) * 0.8, parent, true)
			if st then
				st.Name = "RuneStone"
			end
		end
	end
	-- ออร่าธาตุกลางลาน (อนุภาคจาก VFXPack ของ Store) — ไฟ/น้ำ ใช้ของจริง · ดิน/ลม ย้อมสีธาตุ
	pcall(function()
		local vfx = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("VFX")
		local pack = vfx and vfx:FindFirstChild("VFXPack")
		local auraName = ({ Fire = "Fire-Aura-01", Water = "Water-Aura-01", Earth = "RNG-Aura-01", Air = "RNG-Aura-02" })[el]
		local aura = pack and pack:FindFirstChild(auraName, true)
		local torso = aura and aura:FindFirstChild("Torso")
		if not torso then
			return
		end
		local emitPart = P("Part", {
			Name = "PlazaAura", Size = V(radius * 0.55, 1, radius * 0.55), CFrame = base * CF(0, 0.6, 0),
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
		}, parent)
		for _, e in ipairs(torso:GetChildren()) do
			if e:IsA("ParticleEmitter") then
				local c = e:Clone()
				c.Rate = c.Rate * 4
				local ks = {}
				for _, kp in ipairs(c.Size.Keypoints) do
					table.insert(ks, NumberSequenceKeypoint.new(kp.Time, kp.Value * 2.2, kp.Envelope * 2.2))
				end
				c.Size = NumberSequence.new(ks)
				if c.Name == "Portal" then
					-- หลุมดำกลางวง: เล็กลง/โปร่งขึ้น ให้เห็นสีม่านรอบๆ
					local k2 = {}
					for _, kp in ipairs(c.Size.Keypoints) do
						table.insert(k2, NumberSequenceKeypoint.new(kp.Time, kp.Value * 0.42, kp.Envelope * 0.42))
					end
					c.Size = NumberSequence.new(k2)
					c.Color = ColorSequence.new(col:Lerp(C(0, 0, 0), 0.82))
				end
				if el == "Earth" or el == "Air" then
					c.Color = ColorSequence.new(col)
				end
				c.Parent = emitPart
			end
		end
	end)
	return top
end

-- ---------------------------------------------------------------- มิติ (ศาลเจ้า/วิหาร): ประตูมิติบนพื้น + ห้องข้างในลอยบนฟ้า
-- ข้างนอก = ซุ้มประตูหินจาก Store (PortalArch) ตั้งบนดิน (จมฐานลงดิน ไม่ลอย) · กด E = วาร์ปเข้าห้อง
-- ข้างใน = เกาะลอยฟ้าพื้นราบ (Part) สูง RealmY เหนือจุดเดิม + อาคารประจำจุดจาก Store (8 แบบไม่ซ้ำ ดู REALM_THEME) -> ของเล่นทุกชิ้นวางบนพื้นราบ ไม่ลอย/ไม่จม
--   PortalService (server) อ่านแท็ก "RealmPortal": attribute Dest/DestLook = ปลายทางวาร์ป
PropBuilder.RealmY = 2400
local REALM_STONE = {
	Earth = { C(118, 112, 96), Enum.Material.Cobblestone },
	Water = { C(186, 196, 200), Enum.Material.Limestone },
	Air = { C(214, 222, 236), Enum.Material.Marble },
	Fire = { C(70, 58, 56), Enum.Material.Basalt },
}
local REALM_CRYSTAL = { Earth = "TerraCrystal", Water = "TideCrystal", Air = "GaleCrystal", Fire = "EmberCrystal" }

-- ความสูงพื้น Terrain จริง (ค่าต่ำสุดของหลายจุด) ใต้ตำแหน่ง
local function terrainY(pos, spread)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local lo
	for _, o in ipairs({ { 0, 0 }, { spread, 0 }, { -spread, 0 }, { 0, spread }, { 0, -spread } }) do
		local hit = workspace:Raycast(V(pos.X + o[1], pos.Y + 120, pos.Z + o[2]), V(0, -400, 0), rp)
		if hit then
			lo = lo and math.min(lo, hit.Position.Y) or hit.Position.Y
		end
	end
	return lo or pos.Y
end
PropBuilder.TerrainY = terrainY

-- ธีมของแต่ละมิติ (8 แบบไม่ซ้ำ): ซุ้มประตู / อาคารหลัก / พื้น / ของประดับประจำไบโอม / จุดเด่น / อนุภาคในอากาศ
--   Decor = { ชนิด (PropBuilder.Place), จำนวน, สเกล } · ทุกอย่างจาก Creator Store (ยกเว้นพื้น/แผ่นน้ำ/ธารลาวา)
local REALM_THEME = {
	ShrineEarth = {
		Gate = "GateMossArch", GateW = 30, Building = "ShrineEarth", BW = 100,
		Floor = { C(92, 140, 62), Enum.Material.Grass }, Skirt = { C(96, 78, 58), Enum.Material.Ground },
		Plaza = { C(126, 116, 98), Enum.Material.Cobblestone },
		Decor = { { "AncientOak", 4, 1.1 }, { "Oak", 7, 1 }, { "Flowers", 16, 1.8 }, { "GlowShroom", 10, 1.3 }, { "MossRock", 6, 1.2 }, { "Fern", 18, 1.6 } },
		Feature = "Grove", Air = "Fireflies",
	},
	SanctumEarth = {
		Gate = "GateMystic", GateW = 26, Building = "SanctumEarth", BW = 150,
		Floor = { C(110, 104, 88), Enum.Material.Cobblestone }, Skirt = { C(90, 84, 74), Enum.Material.Slate },
		Plaza = { C(150, 142, 120), Enum.Material.Pavement },
		Decor = { { "TerraCrystal", 8, 1.6 }, { "AncientOak", 3, 1.2 }, { "MossRock", 8, 1.4 }, { "Fern", 12, 1.4 } },
		Feature = "Avenue", Air = "Spores",
	},
	ShrineWater = {
		Gate = "GateStargate", GateW = 30, Building = "ShrineWater", BW = 110,
		Floor = { C(226, 210, 160), Enum.Material.Sand }, Skirt = { C(170, 160, 136), Enum.Material.Sandstone },
		Plaza = { C(232, 226, 210), Enum.Material.Limestone },
		Decor = { { "Palm", 9, 1.1 }, { "Coral", 14, 1.6 }, { "SeaRock", 6, 1.1 }, { "TideCrystal", 4, 1.3 } },
		Feature = "Lagoon", Air = "Bubbles",
	},
	SanctumWater = {
		Gate = "GateDolmen", GateW = 34, Building = "SanctumWater", BW = 140,
		Floor = { C(190, 204, 206), Enum.Material.Limestone }, Skirt = { C(130, 150, 160), Enum.Material.Slate },
		Plaza = { C(214, 226, 230), Enum.Material.Marble },
		Decor = { { "TideCrystal", 10, 1.7 }, { "Coral", 10, 1.4 }, { "Palm", 4, 1 } },
		Feature = "Avenue", Pools = true, Air = "Mist",
	},
	ShrineAir = {
		Gate = "PortalArch", GateW = 26, Building = "ShrineAir", BW = 110,
		Floor = { C(236, 242, 250), Enum.Material.Snow }, Skirt = { C(170, 186, 206), Enum.Material.Glacier },
		Plaza = { C(200, 214, 232), Enum.Material.Ice },
		Decor = { { "FrostPine", 12, 1.1 }, { "IceSpire", 9, 1.2 }, { "SkyStone", 5, 1.2 } },
		Feature = "Snowfield", Air = "Snow",
	},
	SanctumAir = {
		Gate = "GateSkyArch", GateW = 30, Building = "SanctumAir", BW = 160,
		Floor = { C(214, 222, 236), Enum.Material.Marble }, Skirt = { C(160, 174, 200), Enum.Material.Slate },
		Plaza = { C(236, 240, 250), Enum.Material.Marble },
		Decor = { { "GaleCrystal", 10, 1.8 }, { "IceSpire", 7, 1.4 }, { "FrostPine", 4, 1 } },
		Feature = "Avenue", Air = "Wind",
	},
	ShrineFire = {
		Gate = "GateObsidian", GateW = 24, Building = "ShrineFire", BW = 110,
		Floor = { C(52, 44, 44), Enum.Material.Basalt }, Skirt = { C(40, 34, 34), Enum.Material.Basalt },
		Plaza = { C(80, 64, 60), Enum.Material.Slate },
		Decor = { { "CharredTree", 9, 1.1 }, { "ObsidianSpire", 7, 1.3 }, { "LavaVent", 3, 1 }, { "EmberCrystal", 5, 1.3 } },
		Feature = "LavaRiver", Air = "Embers",
	},
	SanctumFire = {
		Gate = "GateBasalt", GateW = 30, Building = "SanctumFire", BW = 150,
		Floor = { C(70, 44, 40), Enum.Material.Slate }, Skirt = { C(44, 32, 30), Enum.Material.Basalt },
		Plaza = { C(96, 70, 62), Enum.Material.Basalt },
		Decor = { { "EmberCrystal", 10, 1.7 }, { "ObsidianSpire", 8, 1.5 }, { "CoalRock", 5, 1.2 } },
		Feature = "Avenue", Moat = true, Air = "Ash",
	},
}
PropBuilder.RealmTheme = REALM_THEME

-- ---------------------------------------------------------------- ม่านประตูมิติ (เต็มช่องประตูทุกรูปทรง)
-- หาช่องประตูจากกล่องของชิ้นส่วนซุ้ม (OBB) บนตารางในระนาบประตู: ช่องว่างที่ซุ้มล้อมซ้าย/ขวา/บน = ช่องประตู
--   ซุ้มที่เป็นเมชชิ้นเดียว (กล่องคลุมทั้งซุ้ม) วัดไม่ได้ -> ช่องโค้งมาตรฐาน (กว้าง 52% สูง 74% หลังคาครึ่งวงกลม)
--   ได้เป็นแถว { v, u0, u1 } -> สร้างแผ่นม่านทีละแถว = พอดีช่องกลม/โค้ง/สี่เหลี่ยม
-- ครึ่งความยาวของชิ้นตามแนวแกน axis (หน่วยเวกเตอร์)
local function extentAlong(p, axis)
	local cf, sz = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector:Dot(axis)) * sz.X + math.abs(cf.UpVector:Dot(axis)) * sz.Y + math.abs(cf.LookVector:Dot(axis)) * sz.Z
end
local function archOpening(parts, F)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local boxes = {}
	for _, q in ipairs(parts) do
		local a0, a1 = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
		local s = q.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local c = F:PointToObjectSpace(q.CFrame * V(s.X * sx, s.Y * sy, s.Z * sz))
					a0, a1 = a0:Min(c), a1:Max(c)
				end
			end
		end
		lo, hi = lo:Min(a0), hi:Max(a1)
		table.insert(boxes, { q, a0, a1 })
	end
	local W, H = hi.X - lo.X, hi.Y - lo.Y
	local step = math.max(0.4, math.max(W, H) / 56)
	local nu, nv = math.floor(W / step), math.floor(H / step)
	-- ดูเฉพาะครึ่งหน้าซุ้ม (ฝั่งคนเดินมา): ซุ้มทรงเตาที่หลังทึบ ก็ยังเจอช่องประตูด้านหน้า
	local dz = { lo.Z + (hi.Z - lo.Z) * 0.15, lo.Z + (hi.Z - lo.Z) * 0.35 }
	local grid = {}
	for j = 0, nv - 1 do
		local v = lo.Y + (j + 0.5) * step
		local row = {}
		local cand = {}
		for _, b in ipairs(boxes) do
			if v >= b[2].Y and v <= b[3].Y then
				table.insert(cand, b)
			end
		end
		for i = 0, nu - 1 do
			local u = lo.X + (i + 0.5) * step
			local solid = false
			for _, b in ipairs(cand) do
				if u >= b[2].X and u <= b[3].X then
					local q = b[1]
					local hs = q.Size / 2
					for _, z in ipairs(dz) do
						local l = q.CFrame:PointToObjectSpace(F * V(u, v, z))
						if math.abs(l.X) <= hs.X and math.abs(l.Y) <= hs.Y and math.abs(l.Z) <= hs.Z then
							solid = true
							break
						end
					end
					if solid then
						break
					end
				end
			end
			row[i] = solid
		end
		grid[j] = row
	end
	-- จุดเริ่ม: ช่องว่างใกล้กลางซุ้มที่สุด (สูง ~40%)
	local ci, cj = math.floor(nu / 2), math.floor(nv * 0.4)
	local start
	for r = 0, math.max(nu, nv) do
		for dj = -r, r do
			for di = -r, r do
				local i, j = ci + di, cj + dj
				if not start and grid[j] and grid[j][i] == false then
					start = { i, j }
				end
			end
		end
		if start then
			break
		end
	end
	if not start then
		return nil
	end
	-- ไล่ช่องว่างที่ติดกัน: ทะลุขอบซ้าย/ขวา/บน = ไม่ใช่ช่องประตู (เป็นอากาศนอกซุ้ม)
	local seen, queue, open = {}, { start }, {}
	seen[start[2] * 10000 + start[1]] = true
	while #queue > 0 do
		local c = table.remove(queue)
		local i, j = c[1], c[2]
		if i <= 0 or i >= nu - 1 or j >= nv - 1 then
			return nil
		end
		open[j] = open[j] or { i, i }
		open[j][1], open[j][2] = math.min(open[j][1], i), math.max(open[j][2], i)
		for _, n in ipairs({ { i + 1, j }, { i - 1, j }, { i, j + 1 }, { i, j - 1 } }) do
			local k = n[2] * 10000 + n[1]
			if n[2] >= 0 and not seen[k] and grid[n[2]] and grid[n[2]][n[1]] == false then
				seen[k] = true
				table.insert(queue, n)
			end
		end
	end
	local rows = {}
	for j = 0, nv - 1 do
		if open[j] then
			table.insert(rows, { lo.Y + (j + 0.5) * step, lo.X + open[j][1] * step, lo.X + (open[j][2] + 1) * step })
		end
	end
	-- ช่องเล็กเกินไป (ร่องระหว่างก้อนหิน) ไม่ใช่ประตู: ต้องสูง >= 35% และกว้าง >= 25% ของซุ้ม
	local maxW = 0
	for _, r in ipairs(rows) do
		maxW = math.max(maxW, r[3] - r[2])
	end
	if #rows * step < H * 0.35 or maxW < W * 0.25 then
		return nil
	end
	-- ม่านอยู่หน้าซุ้ม (ฝั่งคนเดินมา) = ช่องที่แคบที่สุด ไม่จมอยู่ในห้องลึก (ซุ้มทรงเตาหลอม)
	return rows, step, lo.Z + 0.35
end

function PropBuilder.PortalVeil(m, arch, base, col, h, w, round)
	local rot = base - base.Position
	local parts = {}
	if arch then
		for _, d in ipairs(arch:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				table.insert(parts, d)
			end
		end
	end
	-- บานประตู/แผ่นอักษรที่ปิดช่อง (ชิ้นแบนกลางซุ้ม) -> ซ่อน แล้วใช้ช่องของบานนั้นเป็นม่าน
	local doorRect
	if arch and #parts > 1 then
		local acf, as = arch:GetBoundingBox()
		local keep = {}
		for _, q in ipairs(parts) do
			-- แผ่นตั้งตรง (แกนบางสุดอยู่แนวนอน) กลางซุ้ม สูง >= 40% ของซุ้ม = บานประตู/แผ่นอักษร
			local axes = { { q.CFrame.RightVector, q.Size.X }, { q.CFrame.UpVector, q.Size.Y }, { q.CFrame.LookVector, q.Size.Z } }
			table.sort(axes, function(a, b)
				return a[2] < b[2]
			end)
			local thin = axes[1]
			local flat = thin[2] < axes[2][2] * 0.15 and math.abs(thin[1].Y) < 0.3
			local height = extentAlong(q, V(0, 1, 0)) * 2
			local across = (thin[1] * V(1, 0, 1)).Magnitude > 0.01 and V(0, 1, 0):Cross(thin[1] * V(1, 0, 1)).Unit or V(1, 0, 0)
			local width = extentAlong(q, across) * 2
			local off = acf:PointToObjectSpace(q.Position)
			local central = math.abs(off.X) < as.X * 0.2 and math.abs(off.Z) < as.Z * 0.3
			if flat and central and height >= as.Y * 0.4 and width < math.max(as.X, as.Z) * 0.8 then
				q.Transparency = 1
				q.CanCollide = false
				if not doorRect or width * height > doorRect.W * doorRect.H then
					doorRect = { W = width, H = height, Part = q, Across = across }
				end
			else
				table.insert(keep, q)
			end
		end
		parts = keep
	end
	local rows, step, depth, F
	local measured, usedDoor = false, false
	if round and arch then
		-- ซุ้มวงแหวน (ประตูดาว): ม่านวงกลมเต็มวง · วงในกว้าง ~80% ของซุ้ม ศูนย์กลางห่างยอด = รัศมีวงนอก
		local bcf, bs = arch:GetBoundingBox()
		local outer = math.min(bs.X, bs.Y)
		local r = outer * 0.4
		local cy = bs.Y / 2 - outer / 2
		F = CF(bcf.Position) * rot
		step, depth, rows = math.max(0.4, r / 25), 0, {}
		for v = cy - r + step / 2, cy + r, step do
			local half = math.sqrt(math.max(r * r - (v - cy) ^ 2, 0))
			if half > 0.2 then
				table.insert(rows, { v, -half, half })
			end
		end
		measured = true
	end
	if not rows and #parts > 1 then
		local bcf = arch:GetBoundingBox()
		for _, yaw in ipairs({ 0, math.pi / 2 }) do
			F = CF(bcf.Position) * rot * ANG(0, yaw, 0)
			rows, step, depth = archOpening(parts, F)
			if rows then
				measured = true
				break
			end
		end
	end
	if not rows and doorRect then
		usedDoor = true
		-- ช่อง = ขนาดบานประตูที่ซ่อนไป (ยอดโค้งตามความกว้าง)
		local q = doorRect.Part
		F = CFrame.fromMatrix(q.Position, doorRect.Across, V(0, 1, 0))
		local ow, oh = doorRect.W * 0.96, doorRect.H * 0.97
		step, depth, rows = math.max(0.4, oh / 50), -0.3, {}
		-- ยอดโค้งครึ่งวงกลม (ซุ้มประตูส่วนใหญ่โค้งด้านบน) ไม่ให้มุมม่านโผล่เลยกรอบ
		local r = ow / 2
		local top = oh / 2 - r
		for v = -oh / 2 + step / 2, oh / 2, step do
			local half = v > top and math.sqrt(math.max(r * r - (v - top) ^ 2, 0)) or r
			if half > 0.2 then
				table.insert(rows, { v, -half, half })
			end
		end
	end
	if not rows then
		-- ซุ้มเมชชิ้นเดียว: ช่องโค้งมาตรฐาน
		F = CF((base * CF(0, h / 2, 0)).Position) * rot
		local ow, oh = w * 0.52, h * 0.74
		local r = ow / 2
		step, depth, rows = math.max(0.4, oh / 50), 0, {}
		local y0 = -h / 2 + 1.2
		for v = y0 + step / 2, y0 + oh, step do
			local half = r
			local top = y0 + oh - r
			if v > top then
				half = math.sqrt(math.max(r * r - (v - top) ^ 2, 0))
			end
			if half > 0.2 then
				table.insert(rows, { v, -half, half })
			end
		end
	end
	-- รวมแถวที่กว้างเท่ากันเป็นแผ่นเดียว (ลดจำนวนชิ้น)
	local slabs = {}
	for _, r in ipairs(rows) do
		local last = slabs[#slabs]
		if last and math.abs(last.U0 - r[2]) < step * 0.6 and math.abs(last.U1 - r[3]) < step * 0.6 and math.abs(r[1] - last.V1) < step * 1.5 then
			last.V1 = r[1]
		else
			table.insert(slabs, { V0 = r[1], V1 = r[1], U0 = r[2], U1 = r[3] })
		end
	end
	local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
	for _, sl in ipairs(slabs) do
		u0, u1 = math.min(u0, sl.U0), math.max(u1, sl.U1)
		v0, v1 = math.min(v0, sl.V0 - step / 2), math.max(v1, sl.V1 + step / 2)
	end
	local cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
	local ow, oh = u1 - u0, v1 - v0
	m:SetAttribute("VeilInfo", string.format("%s %.1fx%.1f slabs=%d", usedDoor and "door" or (measured and "measured" or "fallback"), ow, oh, #slabs))
	-- ชิ้นของซุ้มที่ยืนบังกลางม่าน (เสา/รูปปั้นกลางช่อง) -> ซ่อน · ไม่แตะแผ่นอักษรเรืองแสง (Neon แบน)
	local mid = F * CF(cu, cv, depth)
	for _, q in ipairs(parts) do
		local sz = { q.Size.X, q.Size.Y, q.Size.Z }
		table.sort(sz)
		local runePanel = q.Material == Enum.Material.Neon and sz[1] < sz[2] * 0.15
		if not runePanel and q.Transparency < 1 then
			local hs = q.Size / 2
			for _, dzz in ipairs({ -6, -4, -2, -0.5, 0.5 }) do
				local l = q.CFrame:PointToObjectSpace((mid * CF(0, 0, dzz)).Position)
				if math.abs(l.X) <= hs.X and math.abs(l.Y) <= hs.Y and math.abs(l.Z) <= hs.Z and q.Size.Magnitude < math.max(w, h) * 1.2 then
					q.Transparency = 1
					q.CanCollide = false
					break
				end
			end
		end
	end
	-- ตัวกด (ล่องหน คลุมทั้งช่อง) = PortalVeil ที่ PortalService อ่าน
	local veil = P("Part", {
		Name = "PortalVeil", Size = V(ow, oh, 0.6), CFrame = F * CF(cu, cv, depth),
		Transparency = 1, CanCollide = false, CanQuery = true, CanTouch = false,
	}, m)
	-- ผิวม่าน: แผ่นแสงสีธาตุตามรูปช่อง (นีออนโปร่ง) + ชั้นสนามพลังไหวๆ
	for _, sl in ipairs(slabs) do
		local sw, sh = sl.U1 - sl.U0, sl.V1 - sl.V0 + step
		local cf = F * CF((sl.U0 + sl.U1) / 2, (sl.V0 + sl.V1) / 2, depth)
		-- ชั้นลึก (สีธาตุเข้ม) ให้ดูเป็นอุโมงค์ ไม่ใช่แผ่นขาว + สนามพลังไหวสีธาตุ + แสงเรือง
		P("Part", { Name = "VeilDeep", Size = V(sw, sh, 0.1), CFrame = cf * CF(0, 0, 0.25), Color = col:Lerp(C(0, 0, 0), 0.7), Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, m)
		P("Part", { Name = "VeilGlow", Size = V(sw, sh, 0.15), CFrame = cf, Color = col, Material = Enum.Material.Neon, Transparency = 0.82,
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, m)
		P("Part", { Name = "VeilField", Size = V(sw, sh, 0.3), CFrame = cf * CF(0, 0, -0.15), Color = col, Material = Enum.Material.ForceField,
			Transparency = 0.2, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, m)
	end
	-- วังวนมิติ (แพ็ก VFX: Portal-01) กลางช่อง: วงแสงหมุน + หลุมดำกลาง + แรงดูดเข้า · ย่อขยายตามช่อง สีตามธาตุ
	local d = math.min(ow, oh) * 0.78 -- วงวนเล็กกว่าช่อง: เห็นม่านเรืองแสงรอบวง
	local vfx = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("VFX")
	local pack = vfx and vfx:FindFirstChild("VFXPack")
	local src = pack and pack:FindFirstChild("Anime") and pack.Anime:FindFirstChild("Portal-01")
	local att = Instance.new("Attachment")
	att.Name = "Vortex"
	att.Parent = veil
	if src then
		local k = d / 6
		for _, e in ipairs(src:GetDescendants()) do
			if e:IsA("ParticleEmitter") then
				local c = e:Clone()
				local ks = {}
				for _, kp in ipairs(c.Size.Keypoints) do
					table.insert(ks, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
				end
				c.Size = NumberSequence.new(ks)
				if c.Name ~= "Portal" then
					c.Color = ColorSequence.new(col:Lerp(C(255, 255, 255), 0.25), col)
				end
				c.Parent = att
			end
		end
	end
	-- ประกายลอยในม่าน + แสงส่องพื้นหน้าประตู
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 22
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(0.3, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(col:Lerp(C(255, 255, 255), 0.4))
	e.LightEmission = 1
	e.Parent = veil
	light(veil, col, math.max(30, d * 2.5), 2.4)
	return veil
end

-- ซุ้มประตูมิติ (frame: -Z หันเข้าหาคนเดินมา) · เท้าซุ้มจมดิน 1.5 stud · คืน model, ชิ้นม่าน (ตัวกด), ฐาน
--   opts.Model/Width = โมเดลซุ้มจาก Store (ต่างกันทุกจุด) · opts.Floor = ความสูงพื้น (ในมิติ ไม่มี Terrain)
function PropBuilder.BuildPortal(frame, el, parent, opts)
	opts = opts or {}
	local col = ELEMENT_COLOR[el] or C(255, 255, 255)
	local rot = frame - frame.Position
	local gy = opts.Floor or terrainY(frame.Position, 7)
	local base = CF(frame.Position.X, gy - (opts.Floor and 0.3 or 1.5), frame.Position.Z) * rot
	local m = Instance.new("Model")
	m.Name = opts.Name or "Portal"
	local arch = PropBuilder.Imported(opts.Model or "PortalArch", base, opts.Width or 24, m, true)
		or PropBuilder.Imported("PortalArch", base, 24, m, true)
	local h, w = 18, 12
	if arch then
		local _, s = arch:GetBoundingBox()
		h, w = s.Y, math.max(s.X, s.Z)
	end
	local veil = PropBuilder.PortalVeil(m, arch, base, col, h, w, opts.Model == "GateStargate")
	-- ข้างนอก: ฐานดินรอบเท้าซุ้ม + ของประดับประจำไบโอมล้อมซุ้ม (บอกจากไกลว่าเป็นจุดของธาตุไหน)
	if not opts.Floor then
		pcall(function()
			workspace.Terrain:FillCylinder(CF(frame.Position.X, gy - 3, frame.Position.Z), 4, 18, SEAT_MAT[el] or Enum.Material.Ground)
		end)
		local th = opts.Theme
		if th then
			local rng = Random.new(math.floor(frame.Position.X * 7 + frame.Position.Z))
			local k = 0
			for _, d in ipairs(th.Decor) do
				for _ = 1, math.min(2, d[2]) do
					-- เฉพาะข้าง/หลังซุ้ม (มุม 20°-160° ฝั่ง +Z) ไม่บังทางเข้า
					local a = math.rad(20 + (k % 7) / 6 * 140) + rng:NextNumber(-0.12, 0.12)
					k += 1
					local p = (base * CF(math.cos(a) * rng:NextNumber(18, 28), 0, math.sin(a) * rng:NextNumber(14, 26))).Position
					local inst = PropBuilder.Place(d[1], V(p.X, terrainY(p, 2) - 0.6, p.Z), rng:NextNumber(0, 6.28), d[3] * 0.8, m, rng)
					if inst then
						CollectionService:RemoveTag(inst, "ResourceNode")
					end
				end
			end
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Enter"
	prompt.ActionText = opts.Action or "เข้าสู่มิติ"
	prompt.ObjectText = opts.Label or ""
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = veil
	CollectionService:AddTag(veil, "RealmPortal")
	m.Parent = parent
	return m, veil, base
end

-- อนุภาคบรรยากาศทั่วทั้งมิติ (กล่องล่องหนเหนือพื้น)
local AIR_FX = {
	Fireflies = { C(190, 255, 120), 0.35, 6, { 0.5, 1.5 }, V(0, 0.6, 0), 40 },
	Spores = { C(220, 255, 170), 0.5, 7, { 0.3, 1 }, V(0, 0.8, 0), 30 },
	Bubbles = { C(190, 240, 255), 0.45, 5, { 1, 3 }, V(0, 3, 0), 40 },
	Mist = { C(210, 236, 255), 4, 8, { 0.5, 1.2 }, V(0, 0.2, 0), 10 },
	Snow = { C(255, 255, 255), 0.5, 8, { 2, 5 }, V(1.5, -5, 0), 90 },
	Wind = { C(230, 240, 255), 0.4, 4, { 14, 22 }, V(0, 0, 0), 40 },
	Embers = { C(255, 150, 60), 0.4, 5, { 2, 5 }, V(0, 5, 0), 70 },
	Ash = { C(120, 110, 110), 0.6, 8, { 0.5, 1.5 }, V(0.5, -1.5, 0), 50 },
}

-- ห้องมิติบนฟ้าเหนือ xz: เกาะลอยฟ้าพื้นราบ + อาคารประจำจุด (Store) + ของประดับไบโอม + จุดเด่น
--   คืน room model, กลางลาน (CFrame บนผิวพื้น), จุดยืนตอนวาร์ปเข้า, ความสูงผิวพื้น
function PropBuilder.BuildRealmRoom(el, xz, parent, name, rot, key)
	local th = REALM_THEME[key] or REALM_THEME["Shrine" .. el] or REALM_THEME.ShrineEarth
	local col = ELEMENT_COLOR[el] or C(255, 255, 255)
	local m = Instance.new("Model")
	m.Name = name or ("Realm_" .. el)
	m:SetAttribute("RealmKey", key)
	m:SetAttribute("FloorTop", PropBuilder.RealmY + 0.5) -- ความสูงผิวพื้นเกาะ (พื้นเป็นทรงกระบอกนอน ห้ามอ่านจาก Size.Y)
	local R = 120
	local top = PropBuilder.RealmY + 0.5
	local center = CF(xz.X, top, xz.Z) * (rot or CFrame.identity)
	local rng = Random.new(#key * 977 + math.floor(xz.X))
	-- เกาะลอยฟ้า: พื้นบนราบ (ชนได้) + ชั้นหินเรียวลงด้านล่าง
	cylinderY(4, R * 2, CF(xz.X, top - 2, xz.Z), { Name = "RealmFloor", Color = th.Floor[1], Material = th.Floor[2] }, m)
	for i, s in ipairs({ { 10, 0.96 }, { 16, 0.8 }, { 20, 0.6 }, { 22, 0.38 }, { 18, 0.18 } }) do
		local y = top - 4 - (i == 1 and s[1] / 2 or 0)
		local acc = 4
		for j = 1, i - 1 do
			acc += ({ 10, 16, 20, 22, 18 })[j]
		end
		cylinderY(s[1], R * 2 * s[2], CF(xz.X, top - acc - s[1] / 2, xz.Z), { Name = "RealmSkirt", Color = th.Skirt[1], Material = th.Skirt[2], CanCollide = false }, m)
		local _ = y
	end
	-- ผนังล่องหนรอบขอบเกาะ (กันตก)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		P("Part", {
			Name = "RealmBound", Size = V(2, 80, R * 2 * math.pi / 24 + 2), CFrame = CF(xz.X, top + 40, xz.Z) * ANG(0, -a, 0) * CF(R - 1, 0, 0),
			Transparency = 1, CanCollide = true, CanQuery = false,
		}, m)
	end
	-- อาคารหลักประจำจุด (8 หลังไม่ซ้ำ) ตั้งหลังลาน หน้าหันเข้าลาน · ขอบหน้าอาคารที่ z = +30
	local building = PropBuilder.Imported(th.Building, center, th.BW, m, true)
	if building then
		local bcf, bsz = building:GetBoundingBox()
		local lp = center:PointToObjectSpace(bcf.Position)
		local halfZ = math.max(bsz.X, bsz.Z) / 2
		local depth = bsz.Z
		-- ลึกเกินเกาะ -> ย่อ
		if 30 + depth > R - 6 then
			pcall(function()
				building:ScaleTo(building:GetScale() * (R - 36) / depth)
			end)
			bcf, bsz = building:GetBoundingBox()
			lp = center:PointToObjectSpace(bcf.Position)
		end
		local _ = halfZ
		building:PivotTo(CF(center:VectorToWorldSpace(V(-lp.X, 0, 30 - (lp.Z - bsz.Z / 2)))) * building:GetPivot())
		-- วางฐานหลักของอาคารบนพื้นเกาะ: ยิงตรวจจากใต้อาคารขึ้นไป 9x9 จุด -> ค่ากลางของระดับใต้ท้องอาคาร = ฐานจริง
		--   (ก้นกล่องรวม = ชิ้นที่ห้อยต่ำสุด เช่นเสา/บันได -> ปราสาทเคยลอยกลางอากาศ) ชิ้นที่ต่ำกว่าฐานจมลงใต้พื้นเกาะ
		local b2, s2 = building:GetBoundingBox()
		local low = b2.Position.Y - s2.Y / 2
		local home = m.Parent
		m.Parent = workspace
		local rpB = RaycastParams.new()
		rpB.FilterType = Enum.RaycastFilterType.Include
		rpB.FilterDescendantsInstances = { building }
		local hs = {}
		for gx = -4, 4 do
			for gz = -4, 4 do
				local p = b2 * V(s2.X * gx / 10, 0, s2.Z * gz / 10)
				local hit = workspace:Raycast(V(p.X, low - 2, p.Z), V(0, s2.Y * 0.6 + 4, 0), rpB)
				if hit then
					table.insert(hs, hit.Position.Y)
				end
			end
		end
		m.Parent = home
		table.sort(hs)
		local baseY = #hs >= 6 and hs[math.ceil(#hs * 0.5)] or low
		building:PivotTo(CF(0, (top - 0.4) - baseY, 0) * building:GetPivot())
		building.Name = "RealmBuilding"
	end
	-- ลานกลาง (ทุกมิติ) + ทางเดินจากจุดเข้าถึงลาน
	cylinderY(0.3, 64, center * CF(0, 0.15, 0), { Name = "RealmPlaza", Color = th.Plaza[1], Material = th.Plaza[2], CanCollide = false, CanQuery = false }, m)
	local runeC = Color3.new(col.R * 0.6, col.G * 0.6, col.B * 0.6)
	cylinderY(0.32, 50, center * CF(0, 0.16, 0), { Name = "RealmRune", Color = runeC, Material = Enum.Material.Slate, CanCollide = false, CanQuery = false }, m)
	cylinderY(0.34, 46, center * CF(0, 0.17, 0), { Name = "RealmRuneIn", Color = th.Plaza[1], Material = th.Plaza[2], CanCollide = false, CanQuery = false }, m)
	P("Part", { Name = "RealmPath", Size = V(14, 0.3, 64), CFrame = center * CF(0, 0.15, -64), Color = th.Plaza[1], Material = th.Plaza[2], CanCollide = false, CanQuery = false }, m)
	-- จุดที่ห้ามวางของประดับ: ลานกลาง / ทางเดิน / อาคาร / จุดเข้า
	local function blocked(x, z)
		if x * x + z * z < 40 * 40 then
			return true
		end
		if math.abs(x) < 16 and z < 0 then
			return true
		end
		if z > 22 and math.abs(x) < th.BW * 0.55 then
			return true
		end
		return false
	end
	local function spot(minR, maxR)
		for _ = 1, 30 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(minR, maxR)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not blocked(x, z) then
				return x, z
			end
		end
		return nil
	end
	-- ของประดับประจำไบโอม (Store)
	for _, d in ipairs(th.Decor) do
		for _ = 1, d[2] do
			local x, z = spot(44, R - 10)
			if x then
				local p = (center * CF(x, 0, z)).Position
				local inst = PropBuilder.Place(d[1], V(p.X, top - 0.5, p.Z), rng:NextNumber(0, 6.28), d[3] * rng:NextNumber(0.85, 1.15), m, rng)
				if inst then
					CollectionService:RemoveTag(inst, "ResourceNode")
				end
			end
		end
	end
	-- จุดเด่นของแต่ละมิติ
	if th.Feature == "Avenue" then
		-- วิหาร: ทางเดินพิธีจากจุดเข้าถึงลาน — คู่หินรูน + กระถางไฟ เรียงสองข้าง
		for i = 0, 3 do
			local z = -96 + 14 + i * 16
			for _, sx in ipairs({ -13, 13 }) do
				local p = (center * CF(sx, 0, z)).Position
				PropBuilder.Imported("RuneStoneLP", CFrame.lookAt(V(p.X, top - 0.8, p.Z), (center * CF(0, 0, z)).Position + V(0, top - 0.8 - center.Y, 0)), 6.5, m, true)
				local bp = (center * CF(sx * 1.45, 0, z + 8)).Position
				local br = PropBuilder.Imported("BrazierLP", CF(bp.X, top, bp.Z), 5.5, m, true)
				local host = br and br:FindFirstChildWhichIsA("BasePart", true)
				if host then
					light(host, col, 26, 1.6)
				end
			end
		end
	else
		-- ศาลเจ้า: กระถางไฟ 6 ใบรอบลาน
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + math.pi / 6
			local p = (center * CF(math.cos(a) * 36, 0, math.sin(a) * 36)).Position
			local br = PropBuilder.Imported("BrazierLP", CF(p.X, top, p.Z), 5.5, m, true)
			local host = br and br:FindFirstChildWhichIsA("BasePart", true)
			if host then
				light(host, col, 26, 1.6)
			end
		end
	end
	if th.Feature == "Lagoon" or th.Pools then
		-- แอ่งน้ำใส (แผ่นน้ำทะเลเรืองฟ้า) รอบเกาะ
		for _ = 1, th.Pools and 4 or 7 do
			local x, z = spot(50, R - 22)
			if x then
				local r = rng:NextNumber(8, 15)
				cylinderY(0.4, r * 2, center * CF(x, 0.22, z), { Name = "RealmPool", Color = C(70, 190, 220), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.2, CanCollide = false, CanQuery = false }, m)
				cylinderY(0.3, r * 2 + 3, center * CF(x, 0.12, z), { Name = "RealmPoolRim", Color = C(240, 230, 200), Material = Enum.Material.Sand, CanCollide = false, CanQuery = false }, m)
			end
		end
	end
	if th.Feature == "LavaRiver" or th.Moat then
		-- ธารลาวา: แถบหินแตกลาวาเรืองส้ม (แสง + ประกายไฟ) โค้งรอบเกาะ
		local n = th.Moat and 28 or 20
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local r = th.Moat and 52 or (80 + math.sin(a * 3) * 18)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not (math.abs(x) < 16 and z < 0) and not (z > 22 and math.abs(x) < th.BW * 0.55) then
				local seg = P("Part", {
					Name = "RealmLava", Size = V(7, 0.4, 2 * math.pi * r / n + 1.5), CFrame = center * CF(x, 0.22, z) * ANG(0, -a, 0),
					Color = C(255, 140, 50), Material = Enum.Material.CrackedLava, CanCollide = false, CanQuery = false,
				}, m)
				if k % 2 == 0 then
					light(seg, C(255, 120, 40), 22, 2)
				end
			end
		end
	end
	if th.Feature == "Snowfield" then
		-- เกาะน้ำแข็งลอยเล็กๆ รอบเกาะใหญ่
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2 + 0.4
			local r = R + rng:NextNumber(20, 45)
			local p = (center * CF(math.cos(a) * r, rng:NextNumber(10, 40), math.sin(a) * r)).Position
			local s = rng:NextNumber(10, 20)
			ellipsoid(V(s * 2, s * 0.6, s * 1.6), CF(p), { Name = "RealmIslet", Color = C(214, 230, 248), Material = Enum.Material.Glacier, CanCollide = false }, m)
			PropBuilder.Place("FrostPine", p + V(0, s * 0.25, 0), rng:NextNumber(0, 6), 0.6, m, rng)
		end
	end
	if th.Feature == "Grove" then
		-- ต้นไม้ยักษ์คู่ขนาบลาน
		for _, sx in ipairs({ -1, 1 }) do
			local p = (center * CF(sx * 58, 0, 6)).Position
			local t = PropBuilder.Place("AncientOak", V(p.X, top - 0.5, p.Z), rng:NextNumber(0, 6), 1.6, m, rng)
			if t then
				CollectionService:RemoveTag(t, "ResourceNode")
			end
		end
	end
	-- อนุภาคในอากาศทั่วมิติ
	local fx = AIR_FX[th.Air]
	if fx then
		local box = P("Part", { Name = "RealmAir", Size = V(R * 1.8, 1, R * 1.8), CFrame = CF(xz.X, top + (fx[5].Y < 0 and 60 or 3), xz.Z), Transparency = 1, CanCollide = false, CanQuery = false }, m)
		local e = Instance.new("ParticleEmitter")
		e.Texture = th.Air == "Mist" and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = fx[5].Y < 0 and Enum.NormalId.Bottom or Enum.NormalId.Top
		e.Color = ColorSequence.new(fx[1])
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fx[2]), NumberSequenceKeypoint.new(1, fx[2] * 0.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, th.Air == "Mist" and 0.8 or 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(fx[3] * 0.7, fx[3])
		e.Speed = NumberRange.new(fx[4][1], fx[4][2])
		e.Acceleration = fx[5]
		e.Rate = fx[6]
		e.LightEmission = (th.Air == "Fireflies" or th.Air == "Embers") and 1 or 0.3
		e.SpreadAngle = th.Air == "Wind" and Vector2.new(5, 5) or Vector2.new(30, 30)
		if th.Air == "Wind" then
			e.EmissionDirection = Enum.NormalId.Right
		end
		e.Parent = box
	end
	-- แสงรวมของมิติ (สีธาตุอ่อนๆ)
	local sun = P("Part", { Name = "RealmLight", Size = V(1, 1, 1), CFrame = CF(xz.X, top + 45, xz.Z), Transparency = 1, CanCollide = false, CanQuery = false }, m)
	light(sun, col:Lerp(Color3.new(1, 1, 1), 0.55), 140, 1.2)
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	m.Parent = parent
	local entry = (center * CF(0, 3, -84)).Position
	return m, center, entry, top
end

-- มิติทั้งชุด: ประตูข้างนอก (frame) + ห้องบนฟ้า + ประตูกลับในห้อง · kind = "Shrine" | "Sanctum" · คืน room, center (CFrame พื้นกลางลาน)
function PropBuilder.BuildRealm(frame, el, parent, label, action, kind)
	local key = (kind or "Shrine") .. el
	local th = REALM_THEME[key]
	local outside, outVeil = PropBuilder.BuildPortal(frame, el, parent, {
		Name = "PortalOut", Label = label, Action = action or "เข้าสู่มิติ", Model = th and th.Gate, Width = th and th.GateW, Theme = th,
	})
	local room, center, entry, top = PropBuilder.BuildRealmRoom(el, frame.Position, parent, "Realm", frame - frame.Position, key)
	-- ประตูกลับ: หลังจุดยืนตอนเข้า (ซุ้มเดียวกับข้างนอก ช่องประตูหันเข้าลาน)
	local backPos = (center * CF(0, 0, -96)).Position
	local _, backVeil = PropBuilder.BuildPortal(CFrame.lookAt(backPos, V(center.X, top, center.Z)), el, room, {
		Name = "PortalBack", Floor = top, Label = label, Action = "กลับออกไปข้างนอก", Model = th and th.Gate, Width = th and th.GateW,
	})
	local outFront = (frame * CF(0, 0, -11)).Position
	local outGround = terrainY(outFront, 2)
	outVeil:SetAttribute("Dest", entry)
	outVeil:SetAttribute("DestLook", V(center.X, entry.Y, center.Z))
	backVeil:SetAttribute("Dest", V(outFront.X, outGround + 3, outFront.Z))
	backVeil:SetAttribute("DestLook", V(outFront.X, outGround + 3, outFront.Z) + (outFront - frame.Position) * 3)
	outside:SetAttribute("Realm", true)
	return room, center
end

function PropBuilder.BuildShrine(sp, parent)
	local el = sp.Element
	local col = ELEMENT_COLOR[el]
	local m = Instance.new("Model")
	m.Name = "Shrine_" .. el
	local base = faceCamp(sp.Position)
	m.WorldPivot = base
	-- ประตูมิติบนพื้น -> ห้องในปราสาทบนฟ้า · กรง + ผู้พิทักษ์อยู่กลางห้อง (พื้นหินเรียบ ไม่ลอย/ไม่จม)
	local TH = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี" }
	local _, center = PropBuilder.BuildRealm(base, el, m, "ศาลเจ้า" .. (TH[el] or ""), "เข้าศาลเจ้า", "Shrine")
	base = center * (base - base.Position)
	m.WorldPivot = base
	m:SetAttribute("SitePos", sp.Position) -- ตำแหน่งลานเดิม (ใช้สร้างใหม่ตอนเริ่มรอบ)
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
-- ผลึกตกแต่ง (ไม่ใช่จุดเก็บของ)
local function decoCrystal(kind, pos, yaw, scale, parent)
	local c = PropBuilder.Place(kind, pos, yaw, scale, parent)
	if c then
		CollectionService:RemoveTag(c, "ResourceNode")
	end
	return c
end
PropBuilder.DecoCrystal = decoCrystal -- เสาผลึกตอนช่วยลูกสัตว์สำเร็จ (SpiritService)

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- ห้องบอสน้ำแข็ง (ลม/เยติ): ลานน้ำแข็งเงา + กำแพงหน้าผาน้ำแข็งล้อมรอบ (Terrain ชนได้จริง) เปิดทางเข้าฝั่งแคมป์
--   ยอดน้ำแข็ง (IceSpikeLP) บนกำแพง/ตีนกำแพง · บัลลังก์ยอดน้ำแข็งยักษ์หลังบอส · ผลึกเรืองแสง · หิมะตก + หมอกเย็น + แสงเหนือ
local function decorIceLair(m, base, R, col, floating)
	local terrain = workspace.Terrain
	local rng = Random.new(math.floor(base.Position.X * 3 + base.Position.Z))
	local gy = base.Position.Y
	local function at(a, r, y)
		return base * CF(math.cos(a) * r, y or 0, math.sin(a) * r)
	end
	local ENTRY = -math.pi / 2 -- -Z ของ Frame = ฝั่งแคมป์
	local function gapDist(a)
		return math.abs((a - ENTRY + math.pi) % (math.pi * 2) - math.pi)
	end
	pcall(function()
		-- พื้นลานน้ำแข็ง + ลายวงเวทน้ำแข็งสีฟ้า
		terrain:FillCylinder(CF(base.X, gy - 1, base.Z), 2, R + 6, Enum.Material.Glacier)
		for _, ring in ipairs({ { 26, Enum.Material.Ice }, { 22, Enum.Material.Glacier }, { 12, Enum.Material.Ice }, { 9, Enum.Material.Glacier } }) do
			terrain:FillCylinder(CF(base.X, gy - 0.9, base.Z), 1.9, ring[1], ring[2])
		end
	end)
	-- กำแพงหน้าผาน้ำแข็ง (ไม่ทำบนเกาะลอย — ขอบเกาะจะลอยกลางฟ้า)
	if not floating then
		local N = 30
		for i = 0, N - 1 do
			local a = i / N * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
			if gapDist(a) > 0.42 then
				local r = R + 18 + rng:NextNumber(-3, 6)
				local h = rng:NextNumber(20, 36)
				local mat = (i % 3 == 0) and Enum.Material.Ice or Enum.Material.Glacier
				local cf = at(a, r, h / 2 - 12) * ANG(0, -a, 0) * ANG(rad(rng:NextNumber(-6, 6)), 0, rad(rng:NextNumber(-4, 10)))
				pcall(function()
					terrain:FillBlock(cf, V(rng:NextNumber(10, 16), h + 24, rng:NextNumber(12, 18)), mat)
					terrain:FillBall(at(a, r, h - 1).Position, rng:NextNumber(4, 6), Enum.Material.Snow)
				end)
				if i % 3 == 1 then
					local top = at(a, r, h - 2).Position
					PropBuilder.Place("IceSpire", top, -a, rng:NextNumber(1.4, 2.2), m)
				end
				-- ยอดน้ำแข็งตีนกำแพงด้านใน
				if i % 2 == 0 then
					local p = at(a + 0.05, R + 7, 0).Position
					PropBuilder.Place("IceSpire", V(p.X, terrainY(p, 2) - 1.2, p.Z), rng:NextNumber(0, 6.28), rng:NextNumber(1.1, 1.9), m)
				end
			end
		end
		-- เสายอดน้ำแข็งยักษ์ 2 ข้างทางเข้า
		for _, s in ipairs({ -1, 1 }) do
			local p = at(ENTRY + s * 0.5, R + 12, 0).Position
			PropBuilder.Place("IceSpire", V(p.X, terrainY(p, 3) - 2, p.Z), 0, 3, m)
		end
	end
	-- บัลลังก์น้ำแข็งหลังบอส (ฝั่งตรงข้ามทางเข้า): กลุ่มยอดน้ำแข็งยักษ์ + ผลึกเรืองแสง
	for k = -2, 2 do
		local p = at(-ENTRY + k * 0.13, R + 2 + math.abs(k) * 2, 0).Position
		PropBuilder.Place("IceSpire", V(p.X, terrainY(p, 3) - 2, p.Z), k * 0.4, 4.2 - math.abs(k) * 0.7, m)
	end
	for _, s in ipairs({ -1, 1 }) do
		local p = at(-ENTRY + s * 0.36, R - 4, 0).Position
		decoCrystal("GaleCrystal", V(p.X, terrainY(p, 2) - 0.5, p.Z), s, 2.2, m)
	end
	-- ผลึกฟ้า/ขาวเรืองแสงรอบลาน
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		if gapDist(a) > 0.5 then
			local p = at(a, R - 5, 0).Position
			decoCrystal(i % 2 == 0 and "TideCrystal" or "GaleCrystal", V(p.X, terrainY(p, 2) - 0.5, p.Z), a, 1.4, m)
		end
	end
	-- หิมะตก + หมอกเย็นเลียพื้น
	local sky = P("Part", { Name = "IceSnowfall", Size = V(R * 2.4, 1, R * 2.4), CFrame = base * CF(0, 55, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
	emitter(sky, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Bottom, Rate = 70,
		Lifetime = NumberRange.new(7, 9), Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(0.35), Color = ColorSequence.new(C(240, 250, 255)), LightEmission = 0.4,
		RotSpeed = NumberRange.new(-60, 60),
	})
	local floor = P("Part", { Name = "IceMist", Size = V(R * 1.8, 1, R * 1.8), CFrame = base * CF(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
	emitter(floor, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", EmissionDirection = Enum.NormalId.Top, Rate = 5,
		Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(C(200, 235, 255)), LightEmission = 0.2,
	})
	light(floor, C(150, 210, 255), 60, 0.9)
	-- แสงเหนือ (ออโรรา) พาดฟ้าเหนือห้องบอส
	local anchor = P("Part", { Name = "Aurora", Size = V(1, 1, 1), CFrame = base, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
	for k = 0, 2 do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = anchor, anchor
		a0.WorldPosition = (base * CF(-R * 2, 85 + k * 10, R * 0.6 + k * 22)).Position
		a1.WorldPosition = (base * CF(R * 2, 92 + k * 8, R * 0.9 + k * 18)).Position
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = 34 - k * 6, 26 - k * 4
		b.CurveSize0, b.CurveSize1 = 40 - k * 15, -30 + k * 12
		b.Segments = 40
		b.LightEmission, b.LightInfluence = 1, 0
		b.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(90, 255, 200)), ColorSequenceKeypoint.new(0.5, C(110, 200, 255)), ColorSequenceKeypoint.new(1, C(190, 140, 255)) })
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.62 + k * 0.08), NumberSequenceKeypoint.new(0.7, 0.62 + k * 0.08), NumberSequenceKeypoint.new(1, 1) })
		b.FaceCamera = true
		b.Parent = anchor
	end
end

-- ห้องบอสน้ำ (โมซาซอรัส): ลากูนน้ำใสกลางทะเล · เกาะหินปะการังให้ยืนสู้ (ปาล์ม/ผลึก/กระถางไฟฟ้า)
--   ก้นลากูน = สวนปะการัง/สาหร่าย + ผลึกเรืองแสงใต้น้ำ (มองทะลุน้ำเห็น) · กลางลากูน = วังน้ำวน (VFXPack) · ไอน้ำ/ประกายเหนือผิวน้ำ
local function decorWaterLair(m, base, wl, floorY, islands, col)
	local rng = Random.new(math.floor(base.Position.X + base.Position.Z * 7))
	for idx, isl in ipairs(islands) do
		local p = V(isl.X, isl.Top, isl.Z)
		if isl.Ring == 1 then
			if idx % 2 == 0 then
				decoCrystal("TideCrystal", p - V(0, 0.4, 0), rng:NextNumber(0, 6.28), 1.3, m)
			else
				local br = PropBuilder.Imported("BrazierLP", CF(p.X, p.Y - 0.3, p.Z), 5, m, true)
				local host = br and br:FindFirstChildWhichIsA("BasePart", true)
				if host then
					light(host, C(90, 220, 255), 34, 2)
				end
			end
		else
			-- เกาะวงนอก: ปาล์ม 1-2 ต้น (ตกแต่ง ไม่ใช่ต้นไม้ให้ตัด)
			for _ = 1, rng:NextInteger(1, 2) do
				local o = V(rng:NextNumber(-0.4, 0.4) * isl.R, 0, rng:NextNumber(-0.4, 0.4) * isl.R)
				local palm = PropBuilder.Place("Palm", p + o - V(0, 0.5, 0), rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3), m)
				if palm then
					CollectionService:RemoveTag(palm, "ResourceNode")
				end
			end
		end
		-- ปะการังรอบขอบเกาะ (แนวผิวน้ำ)
		for k = 1, 3 do
			local a = rng:NextNumber(0, 6.28)
			local q = V(isl.X + math.cos(a) * isl.R * 1.05, wl - 2.5, isl.Z + math.sin(a) * isl.R * 1.05)
			PropBuilder.Place("Coral", q, a, rng:NextNumber(1.2, 2), m)
		end
	end
	-- สวนปะการัง/สาหร่ายใต้น้ำ + ผลึกเรืองแสงก้นลากูน
	for i = 1, 70 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(18, 140)
		local q = V(base.X + math.cos(a) * r, floorY, base.Z + math.sin(a) * r)
		local gy = terrainY(V(q.X, wl + 10, q.Z), 1)
		if gy < wl - 3 then
			PropBuilder.Place(i % 3 == 0 and "Kelp" or "Coral", V(q.X, gy - 0.3, q.Z), a, rng:NextNumber(1.2, 2.4), m)
		end
	end
	for i = 0, 9 do
		local a, r = i / 10 * math.pi * 2 + 0.3, rng:NextNumber(30, 120)
		local q = V(base.X + math.cos(a) * r, 0, base.Z + math.sin(a) * r)
		local gy = terrainY(V(q.X, wl + 10, q.Z), 1)
		if gy < wl - 4 then
			decoCrystal("TideCrystal", V(q.X, gy - 0.4, q.Z), a, 1.8, m)
			local glow = P("Part", { Name = "ReefGlow", Size = V(1, 1, 1), CFrame = CF(q.X, gy + 4, q.Z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
			light(glow, C(70, 200, 255), 40, 1.6)
		end
	end
	-- วังน้ำวนกลางลากูน (ออร่าน้ำจาก VFXPack) + ฟองวนรอบ
	local vortex = P("Part", { Name = "LagoonVortex", Size = V(34, 1, 34), CFrame = CF(base.X, wl + 0.3, base.Z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
	pcall(function()
		local vfx = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("VFX")
		local pack = vfx and vfx:FindFirstChild("VFXPack")
		local aura = pack and pack:FindFirstChild("Water-Aura-01", true)
		local torso = aura and aura:FindFirstChild("Torso")
		for _, e in ipairs(torso and torso:GetChildren() or {}) do
			if e:IsA("ParticleEmitter") then
				local c = e:Clone()
				c.Rate = c.Rate * 3
				local ks = {}
				for _, kp in ipairs(c.Size.Keypoints) do
					table.insert(ks, NumberSequenceKeypoint.new(kp.Time, kp.Value * 3, kp.Envelope * 3))
				end
				c.Size = NumberSequence.new(ks)
				c.Parent = vortex
			end
		end
	end)
	emitter(vortex, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", EmissionDirection = Enum.NormalId.Top, Rate = 14,
		Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(70, 70),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(C(220, 248, 255)), RotSpeed = NumberRange.new(40, 90),
	})
	light(vortex, C(80, 210, 255), 50, 1.8)
	-- ไอน้ำเหนือผิวน้ำ + ประกายแสงลอย
	local mist = P("Part", { Name = "LagoonMist", Size = V(260, 1, 260), CFrame = CF(base.X, wl + 1, base.Z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, m)
	emitter(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds", EmissionDirection = Enum.NormalId.Top, Rate = 12,
		Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.3, 0.9), SpreadAngle = Vector2.new(40, 40),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 18) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(C(200, 240, 255)),
	})
	emitter(mist, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Top, Rate = 30,
		Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(C(140, 230, 255)), LightEmission = 1,
	})
end

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
		-- ลม: ไม่มีอาคาร (พระราชวังน้ำแข็งเดิมทำบอสตกพื้น/ฐานลอย/เดินไม่ได้) -> ลานหิมะเปิด ล้อมด้วยหินรูน+ยอดน้ำแข็ง (Store)
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
	-- รังไฟ (บัลลังก์ยกสูง ~20): จมทั้งบัลลังก์ลงให้พื้นลานบนบัลลังก์เสมอพื้นดิน
	--   (บอส/วงเตือน/เอฟเฟกต์สกิลอ้างอิงพื้น Terrain -> เคยจมลงในพื้นบัลลังก์ทั้งตัวบอสและสกิล)
	if backdrop and el == "Fire" then
		local home = backdrop.Parent
		backdrop.Parent = workspace
		local rpT = RaycastParams.new()
		rpT.FilterType = Enum.RaycastFilterType.Include
		rpT.FilterDescendantsInstances = { backdrop }
		local hs = {}
		for _, off in ipairs({ V(0, 0, 0), V(14, 0, 0), V(-14, 0, 0), V(0, 0, 14), V(0, 0, -14), V(10, 0, 10), V(-10, 0, -10) }) do
			local hit = workspace:Raycast(base.Position + off + V(0, 80, 0), V(0, -120, 0), rpT)
			if hit and hit.Normal.Y > 0.8 then
				table.insert(hs, hit.Position.Y)
			end
		end
		backdrop.Parent = home
		if #hs >= 3 then
			table.sort(hs)
			local floorY = hs[math.ceil(#hs / 2)]
			local ground = terrainY(base.Position, 20)
			local drop = floorY - (ground + 0.3)
			if drop > 1 then
				backdrop:PivotTo(CF(0, -drop, 0) * backdrop:GetPivot())
				pcall(function()
					-- ขุดดินที่ทะลุขึ้นมาบนลานบัลลังก์หลังจม
					local bcf, bsz = backdrop:GetBoundingBox()
					workspace.Terrain:FillBlock(CF(bcf.Position.X, ground + 0.3 + 20, bcf.Position.Z) * bcf.Rotation, V(bsz.X * 0.85, 40, bsz.Z * 0.85), Enum.Material.Air)
				end)
			end
		end
	end
	-- รังน้ำ: แท่นหินโผล่พ้นน้ำ 2 วงรอบห้วงลึก (ผู้เล่นยืน/กระโดดข้ามได้) · บอสว่ายอยู่กลางน้ำ
	if el == "Water" then
		local terrain = workspace.Terrain
		local wl = base.Position.Y + 16 -- ระดับผิวน้ำ (MapGenerator ขุดแอ่งลึก 16 ใต้ผิวน้ำ)
		local floorY = base.Position.Y
		local rngW = Random.new(math.floor(base.Position.X + base.Position.Z))
		local islands = {}
		for ring, info in ipairs({ { 64, 9, 11 }, { 104, 12, 14 } }) do
			local n = info[2]
			for i = 0, n - 1 do
				local a = (i + (ring == 2 and 0.5 or 0)) / n * math.pi * 2 + rngW:NextNumber(-0.12, 0.12)
				local rad2 = info[1] + rngW:NextNumber(-6, 6)
				local px, pz = base.Position.X + math.cos(a) * rad2, base.Position.Z + math.sin(a) * rad2
				local r = info[3] * rngW:NextNumber(0.8, 1.15)
				local top = wl + rngW:NextNumber(1.2, 3.2)
				pcall(function()
					-- เกาะหินปะการัง: ฐานหินปูนขาว + ขอบหินลาดลงน้ำ + หาดทรายบนยอด
					terrain:FillCylinder(CF(px, (floorY - 4 + top) / 2, pz), top - floorY + 4, r, Enum.Material.Limestone)
					-- ขอบหินขรุขระรอบเกาะ (ก้อนหินเล็กเหลื่อมกันที่แนวน้ำ ไม่ให้เป็นทรงกระบอกเรียบ/โดมกลม)
					for k = 0, 4 do
						local ka = a + k / 5 * math.pi * 2 + rngW:NextNumber(-0.3, 0.3)
						local kr = r * rngW:NextNumber(0.75, 0.95)
						terrain:FillBall(V(px + math.cos(ka) * kr, wl - rngW:NextNumber(1, 2.5), pz + math.sin(ka) * kr), r * rngW:NextNumber(0.35, 0.5), k % 2 == 0 and Enum.Material.Rock or Enum.Material.Limestone)
					end
					terrain:FillCylinder(CF(px, top - 0.6, pz), 1.6, r * 0.92, Enum.Material.Sand)
				end)
				table.insert(islands, { X = px, Z = pz, Top = top, R = r, Ring = ring })
			end
		end
		-- จุดเกิดบอส: กลางห้วงน้ำ ที่ผิวน้ำ
		base = CF(base.Position.X, wl - 1.5, base.Position.Z) * (base - base.Position)
		pcall(decorWaterLair, m, base, wl, floorY, islands, col)
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
	-- ไม่มีอาคาร (ลม/ไฟที่ยังไม่มีบัลลังก์): วงหินรูน + กระถางไฟ + ยอดน้ำแข็ง จาก Store ตั้งบนดินจริงทีละชิ้น (จมฐานกันลอย)
	if not backdrop and el ~= "Water" then
		local gy0 = terrainY(base.Position, 10)
		base = CF(base.Position.X, gy0, base.Position.Z) * (base - base.Position)
		for i = 0, 9 do
			local ang = i / 10 * math.pi * 2
			local p = (base * CF(math.cos(ang) * R, 0, math.sin(ang) * R)).Position
			local gy = terrainY(p, 3)
			PropBuilder.Imported("RuneStoneLP", CFrame.lookAt(V(p.X, gy - 1.2, p.Z), V(base.X, gy - 1.2, base.Z)), 6 + (i % 3) * 1.5, m, true)
			if i % 2 == 0 then
				local bp = (base * CF(math.cos(ang + 0.31) * (R - 9), 0, math.sin(ang + 0.31) * (R - 9))).Position
				local by = terrainY(bp, 2)
				local br = PropBuilder.Imported("BrazierLP", CF(bp.X, by - 0.3, bp.Z), 6, m, true)
				local host = br and br:FindFirstChildWhichIsA("BasePart", true)
				if host then
					light(host, col, 34, 2)
				end
			end
		end
		if el == "Air" then
			local ok, err = pcall(decorIceLair, m, base, R, col, sp.Floating)
			if not ok then
				warn("[AS] ห้องบอสน้ำแข็ง:", err)
			end
		end
	end
	for i = 0, -1 do
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
	for i = 0, -1 do -- (ซี่โครงปั้น: เลิกใช้)
		local z = -12 + i * 5
		cylinderY(22 - math.abs(i - 2.5) * 3, 1.6, base * CF(-24, 6, z) * ANG(0, 0, rad(-38)), { Color = C(226, 218, 196), Material = Enum.Material.SmoothPlastic }, m)
	end
	if false then
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
	-- ซากวิหารโบราณจาก Creator Store (4 แบบ: เสาเรียงพังๆ / วิหารกรีก / ศาลาโดม / พีระมิด) สลับกันไม่ให้ซ้ำในไบโอมเดียว
	--   ย้อมสีหินตามธาตุ (ตะไคร่/หินทราย/หินน้ำแข็ง/หินภูเขาไฟ) · ตั้งบนลานที่ MapGenerator ปรับเรียบ (SiteSpec Ruins) จมฐาน 1.5 กันลอย
	local RUIN_MODELS = { { "RuinColonnade", 54 }, { "RuinTemple", 50 }, { "RuinRotunda", 34 }, { "RuinPyramid", 52 } }
	local EL_IDX = { Earth = 0, Water = 1, Air = 2, Fire = 3 }
	PropBuilder.RuinCount = PropBuilder.RuinCount or {}
	PropBuilder.RuinCount[el] = (PropBuilder.RuinCount[el] or 0) + 1
	local pick = RUIN_MODELS[((EL_IDX[el] or 0) + PropBuilder.RuinCount[el] - 1) % #RUIN_MODELS + 1]
	local TINT = {
		Earth = { C(150, 160, 130), Enum.Material.Cobblestone }, Water = { C(222, 206, 168), Enum.Material.Sandstone },
		Air = { C(206, 218, 236), Enum.Material.Marble }, Fire = { C(84, 64, 60), Enum.Material.Basalt },
	}
	local gy0 = terrainY(base.Position, 12)
	base = CF(base.Position.X, gy0, base.Position.Z) * (base - base.Position)
	local storeRuins = PropBuilder.Imported(pick[1], base * CF(0, -1.5, 0), pick[2], m, true)
	local chestY = gy0
	if storeRuins then
		storeRuins.Name = "RuinBuilding"
		local tint = TINT[el]
		for _, d in ipairs(storeRuins:GetDescendants()) do
			if d:IsA("BasePart") and not d:IsA("MeshPart") then
				local c = d.Color
				local lum = (c.R + c.G + c.B) / 3
				d.Color = Color3.new(tint[1].R * (0.55 + lum * 0.6), tint[1].G * (0.55 + lum * 0.6), tint[1].B * (0.55 + lum * 0.6))
				if d.Material == Enum.Material.Plastic or d.Material == Enum.Material.SmoothPlastic then
					d.Material = tint[2]
				end
			end
		end
		-- หีบตั้งบนพื้นจริงของซาก (ฐานยก/ขั้นบันได) ตรงกลาง
		local home = m.Parent
		m.Parent = workspace
		local rpR = RaycastParams.new()
		rpR.FilterType = Enum.RaycastFilterType.Include
		rpR.FilterDescendantsInstances = { storeRuins, workspace.Terrain }
		local hit = workspace:Raycast(base.Position + V(0, 8, 0), V(0, -40, 0), rpR)
		if hit and hit.Position.Y < gy0 + 7 then
			chestY = hit.Position.Y
		end
		m.Parent = home
	end
	base = CF(base.Position.X, chestY, base.Position.Z) * (base - base.Position)
	-- พื้นจริงตรงจุดนั้น (ซาก/ดิน) — กระถางไฟ/ผลึกอยู่นอกแท่นกลาง ใช้ความสูงของหีบตรงๆ จะลอย
	local function floorAt(p)
		local home = m.Parent
		m.Parent = workspace
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = storeRuins and { storeRuins, workspace.Terrain } or { workspace.Terrain }
		local hit = workspace:Raycast(V(p.X, chestY + 8, p.Z), V(0, -40, 0), rp)
		m.Parent = home
		return hit and hit.Position.Y or terrainY(p, 2)
	end
	-- กระถางไฟ 2 ใบหน้าซาก + ผลึกธาตุข้างหีบ
	for _, x in ipairs({ -7, 7 }) do
		local p = (base * CF(x, 0, -6)).Position
		local br = PropBuilder.Imported("BrazierLP", CF(p.X, floorAt(p) - 0.2, p.Z), 4.5, m, true)
		local host = br and br:FindFirstChildWhichIsA("BasePart", true)
		if host then
			light(host, ELEMENT_COLOR[el] or C(255, 170, 80), 24, 1.5)
		end
	end
	local storeRuinsDone = storeRuins
	local cr = REALM_CRYSTAL[el]
	if cr then
		local p = (base * CF(5, 0, 4)).Position
		local c = PropBuilder.Place(cr, V(p.X, floorAt(p) - 0.4, p.Z), 0, 0.7, m)
		if c then
			CollectionService:RemoveTag(c, "ResourceNode")
		end
	end
	storeRuins = storeRuinsDone
	-- หีบ
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	local ccf = base * CF(0, -0.2, 0)
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
