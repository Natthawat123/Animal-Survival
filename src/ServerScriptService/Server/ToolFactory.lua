--[[
	ToolFactory — สร้าง Tool (อาวุธ/เครื่องมือ) พร้อมหน้าตา
	ทุก Tool มี Handle + attribute ItemId; ฝั่ง client กดตี -> Remotes.Attack
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)
-- อาวุธ/เครื่องมือที่ใช้โมเดลจริง (ที่เหลือปั้นเอง: คบเพลิง หอก ตรีศูล)
local MESH_TOOLS = { OldAxe = true, StoneAxe = true, IronAxe = true, Pickaxe = true, Bow = true, GaleBow = true, TerraHammer = true, EmberBlade = true, FourfoldBlade = true }

local ToolFactory = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

local function part(tool, name, size, color, material, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name = name
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = tool
	return p
end

-- ติดชิ้นกับ Handle ด้วยตำแหน่งสัมพัทธ์
local function attach(handle, p, offset)
	p.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
end

local function glow(p, color, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 2
	l.Shadows = false
	l.Parent = p
	return l
end

-- ด้าม (Handle) ตั้งตามแกน Y, จับที่ล่างของด้าม
local function shaft(tool, length, thickness, color, material)
	local h = part(tool, "Handle", V(thickness, length, thickness), color, material or Enum.Material.Wood)
	h.CFrame = CF(0, 0, 0)
	return h
end

local Shapes = {}

local function axeHead(tool, h, len, color, material, edge)
	local head = part(tool, "Head", V(0.5, 1.4, 1.9), color, material)
	attach(h, head, CF(0, len * 0.42, -0.7))
	local blade = part(tool, "Blade", V(0.35, 1.9, 0.9), edge, Enum.Material.Metal, "Wedge")
	attach(h, blade, CF(0, len * 0.42, -1.9) * ANG(0, math.pi, 0))
end

Shapes.OldAxe = function(tool)
	local h = shaft(tool, 4, 0.4, C(120, 86, 56))
	axeHead(tool, h, 4, C(110, 110, 116), Enum.Material.CorrodedMetal, C(150, 150, 156))
end
Shapes.StoneAxe = function(tool)
	local h = shaft(tool, 4, 0.45, C(110, 80, 52))
	axeHead(tool, h, 4, C(130, 128, 124), Enum.Material.Slate, C(160, 156, 150))
	local wrap = part(tool, "Wrap", V(0.55, 0.8, 0.55), C(170, 200, 110), Enum.Material.Fabric)
	attach(h, wrap, CF(0, 1.4, 0))
end
Shapes.IronAxe = function(tool)
	local h = shaft(tool, 4.4, 0.45, C(80, 58, 40))
	axeHead(tool, h, 4.4, C(70, 74, 82), Enum.Material.Metal, C(210, 214, 222))
end
Shapes.Pickaxe = function(tool)
	local h = shaft(tool, 4.2, 0.42, C(110, 80, 52))
	local head = part(tool, "Head", V(0.45, 0.5, 4), C(120, 120, 128), Enum.Material.Metal)
	attach(h, head, CF(0, 1.8, 0) * ANG(0.15, 0, 0))
end
Shapes.Spear = function(tool)
	local h = shaft(tool, 7, 0.35, C(130, 96, 62))
	local tip = part(tool, "Tip", V(0.25, 1.6, 0.6), C(236, 228, 210), Enum.Material.SmoothPlastic, "Wedge")
	attach(h, tip, CF(0, 4.2, 0))
	local wrap = part(tool, "Wrap", V(0.45, 0.6, 0.45), C(160, 60, 50), Enum.Material.Fabric)
	attach(h, wrap, CF(0, 3.2, 0))
end
Shapes.Torch = function(tool)
	local h = shaft(tool, 3, 0.4, C(100, 72, 46))
	local head = part(tool, "Flame", V(0.7, 0.8, 0.7), C(255, 160, 60), Enum.Material.Neon, "Ball")
	attach(h, head, CF(0, 1.7, 0))
	local f = Instance.new("Fire")
	f.Size = 2.5
	f.Heat = 6
	f.Parent = head
	local l = glow(head, C(255, 170, 90), Items.Tools.Torch.Light)
	l.Shadows = true
end
Shapes.Bow = function(tool)
	local h = shaft(tool, 1.2, 0.35, C(120, 86, 56))
	for i = -1, 1, 2 do
		local limb = part(tool, "Limb", V(0.25, 2.6, 0.35), C(140, 100, 60), Enum.Material.Wood)
		attach(h, limb, CF(0, i * 1.6, 0.5) * ANG(i * -0.45, 0, 0))
	end
	local string_ = part(tool, "String", V(0.06, 4.8, 0.06), C(240, 236, 220), Enum.Material.SmoothPlastic)
	attach(h, string_, CF(0, 0, 1.15))
end
Shapes.TerraHammer = function(tool)
	local h = shaft(tool, 5, 0.5, C(90, 70, 50))
	local head = part(tool, "Head", V(1.8, 1.8, 3.4), C(96, 100, 86), Enum.Material.Slate)
	attach(h, head, CF(0, 2.4, 0))
	for i = -1, 1, 2 do
		local crystal = part(tool, "Crystal", V(0.7, 1.4, 0.7), C(130, 240, 100), Enum.Material.Neon)
		attach(h, crystal, CF(0, 3.4, i * 1) * ANG(i * 0.4, 0, 0))
	end
	glow(head, C(130, 240, 100), 12)
end
Shapes.TidalTrident = function(tool)
	local h = shaft(tool, 7, 0.35, C(60, 110, 150), Enum.Material.Metal)
	for i = -1, 1 do
		local prong = part(tool, "Prong", V(0.25, 1.8, 0.25), C(110, 220, 255), Enum.Material.Neon)
		attach(h, prong, CF(i * 0.55, 4.2 - math.abs(i) * 0.3, 0))
	end
	local bar = part(tool, "Bar", V(1.5, 0.3, 0.3), C(80, 150, 200), Enum.Material.Metal)
	attach(h, bar, CF(0, 3.3, 0))
	glow(bar, C(90, 210, 255), 12)
end
Shapes.GaleBow = function(tool)
	local h = shaft(tool, 1.2, 0.35, C(210, 220, 240), Enum.Material.Metal)
	for i = -1, 1, 2 do
		local limb = part(tool, "Limb", V(0.25, 3.2, 0.4), C(230, 240, 255), Enum.Material.Neon)
		attach(h, limb, CF(0, i * 1.9, 0.6) * ANG(i * -0.5, 0, 0))
		local feather = part(tool, "Feather", V(0.1, 1.2, 0.8), C(150, 200, 255), Enum.Material.Neon, "Wedge")
		attach(h, feather, CF(0, i * 3.3, 1.2))
	end
	local string_ = part(tool, "String", V(0.06, 5.8, 0.06), C(200, 230, 255), Enum.Material.Neon)
	attach(h, string_, CF(0, 0, 1.4))
	glow(h, C(200, 230, 255), 10)
end
Shapes.EmberBlade = function(tool)
	local h = shaft(tool, 1.6, 0.4, C(40, 30, 30), Enum.Material.Metal)
	local guard = part(tool, "Guard", V(2.2, 0.4, 0.6), C(60, 40, 36), Enum.Material.Metal)
	attach(h, guard, CF(0, 0.9, 0))
	local blade = part(tool, "Blade", V(0.35, 5.6, 1.2), C(40, 30, 30), Enum.Material.Basalt)
	attach(h, blade, CF(0, 3.8, 0))
	local edge = part(tool, "Edge", V(0.4, 5.4, 0.25), C(255, 120, 30), Enum.Material.Neon)
	attach(h, edge, CF(0, 3.8, -0.6))
	local f = Instance.new("Fire")
	f.Size = 2
	f.Heat = 5
	f.Parent = blade
	glow(blade, C(255, 120, 40), Items.Tools.EmberBlade.Light)
end
Shapes.FourfoldBlade = function(tool)
	local h = shaft(tool, 1.8, 0.4, C(30, 30, 36), Enum.Material.Metal)
	local guard = part(tool, "Guard", V(2.8, 0.5, 0.7), C(230, 200, 120), Enum.Material.Metal)
	attach(h, guard, CF(0, 1, 0))
	local blade = part(tool, "Blade", V(0.4, 6.4, 1.3), C(240, 244, 255), Enum.Material.Glass)
	attach(h, blade, CF(0, 4.3, 0))
	local colors = { C(130, 240, 100), C(80, 210, 255), C(230, 240, 255), C(255, 120, 30) }
	for i, col in ipairs(colors) do
		local rune = part(tool, "Rune", V(0.45, 0.7, 0.5), col, Enum.Material.Neon)
		attach(h, rune, CF(0, 2 + i * 1.2, 0))
	end
	glow(blade, C(255, 245, 220), Items.Tools.FourfoldBlade.Light)
end

-- กระสอบ: ถุงผ้าผูกเชือก สะพายในมือ
local function buildSack(itemId)
	local tool = Instance.new("Tool")
	tool.Name = Items.DisplayName(itemId)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", itemId)
	tool:SetAttribute("Kind", "Sack")
	tool.ToolTip = string.format("ความจุ %d ชิ้น · คลิกของบนพื้นเพื่อเก็บ", Items.Sacks[itemId])
	local s = itemId == "GiantSack" and 1.35 or (itemId == "GoodSack" and 1.15 or 1)
	local color = Items.SackColor[itemId]
	local h = part(tool, "Handle", V(0.4, 1.2, 0.4), C(120, 90, 60), Enum.Material.Fabric)
	local body = part(tool, "Bag", V(2.2, 2.4, 2.2) * s, color, Enum.Material.Fabric, "Ball")
	attach(h, body, CF(0, -1.6 * s, 0))
	local neck = part(tool, "Neck", V(0.9, 0.5, 0.9) * s, color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric, "Cylinder")
	attach(h, neck, CF(0, -0.45 * s, 0) * ANG(0, 0, math.pi / 2))
	local rope = part(tool, "Rope", V(1.0, 0.18, 1.0) * s, C(200, 170, 110), Enum.Material.Fabric, "Cylinder")
	attach(h, rope, CF(0, -0.55 * s, 0) * ANG(0, 0, math.pi / 2))
	if itemId ~= "OldSack" then
		local patch_ = part(tool, "Patch", V(0.8, 0.8, 0.1), C(220, 200, 150), Enum.Material.Fabric)
		attach(h, patch_, CF(0, -1.6 * s, -1.08 * s))
	end
	tool.GripPos = V(0, 0.3, 0)
	return tool
end

function ToolFactory.GripFor(tool, handle, kind)
	local lo = V(math.huge, math.huge, math.huge)
	local hi = -lo
	local centroid, mass = V(), 0
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") then
			local rel = handle.CFrame:ToObjectSpace(p.CFrame)
			local h = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local c = rel * V(h.X * sx, h.Y * sy, h.Z * sz)
						lo = V(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
						hi = V(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
					end
				end
			end
			local m = p.Size.X * p.Size.Y * p.Size.Z
			centroid += rel.Position * m
			mass += m
		end
	end
	if mass <= 0 then
		return CF()
	end
	centroid /= mass
	local ext = hi - lo
	local mid = (lo + hi) / 2
	-- แกนยาวสุด + ด้านที่หนักกว่า = หัว
	local axis
	if ext.X >= ext.Y and ext.X >= ext.Z then
		axis = V(1, 0, 0)
	elseif ext.Y >= ext.Z then
		axis = V(0, 1, 0)
	else
		axis = V(0, 0, 1)
	end
	local len = ext:Dot(axis)
	local sign = ((centroid - mid):Dot(axis) >= 0) and 1 or -1
	local head = axis * sign
	if kind == "Bow" then
		-- ธนู: จับกลางคันธนู ตั้งคันขึ้น
		local grip = mid
		local up = V(0, 1, 0)
		local rot = (head:Dot(up) > 0.999 or head:Dot(up) < -0.999) and CF() or CFrame.fromAxisAngle(up:Cross(head).Unit, math.acos(math.clamp(up:Dot(head), -1, 1)))
		return CF(grip) * rot * ANG(0, math.pi / 2, 0)
	end
	local tail = mid - head * (len / 2)
	local grip = tail + head * (len * (kind == "Spear" and 0.35 or 0.18))
	-- ทิศคม: ส่วนหัว (30% บนสุด) ยื่นออกจากแนวด้ามไปทางไหน -> ให้หันไปข้างหน้า
	local blade, bmass = V(), 0
	local topLo, topHi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") then
			local c = handle.CFrame:ToObjectSpace(p.CFrame).Position
			if (c - mid):Dot(head) > len * 0.2 then
				local perp = (c - mid) - head * (c - mid):Dot(head)
				local m = p.Size.X * p.Size.Y * p.Size.Z
				blade += perp * m
				bmass += m
				topLo = V(math.min(topLo.X, c.X - p.Size.X / 2), math.min(topLo.Y, c.Y - p.Size.Y / 2), math.min(topLo.Z, c.Z - p.Size.Z / 2))
				topHi = V(math.max(topHi.X, c.X + p.Size.X / 2), math.max(topHi.Y, c.Y + p.Size.Y / 2), math.max(topHi.Z, c.Z + p.Size.Z / 2))
			end
		end
	end
	if bmass > 0 then
		blade /= bmass
	end
	if bmass == 0 then
		-- เครื่องมือชิ้นเดียว (เมชเดียว): ส่วนหัวกว้างสุดตามแกนที่ตั้งฉากกับด้าม
		topLo, topHi = lo, hi
	end
	if blade.Magnitude < 0.05 then
		-- หัวสมมาตร (เช่น ขวานสองคม): ใช้แกนที่กว้างสุดของส่วนหัว
		local e = topHi - topLo
		local cands = {}
		for _, ax in ipairs({ V(1, 0, 0), V(0, 1, 0), V(0, 0, 1) }) do
			if math.abs(ax:Dot(head)) < 0.5 then
				table.insert(cands, { ax, e:Dot(ax) })
			end
		end
		table.sort(cands, function(x, y)
			return x[2] > y[2]
		end)
		blade = cands[1] and cands[1][1] or V()
	end
	-- หมุนให้ +Y ของด้ามมาตรฐาน = ทิศหัว แล้วใช้มุมจับแบบเดียวกับด้ามปั้น
	local up = V(0, 1, 0)
	local rot
	if head:Dot(up) > 0.999 then
		rot = CF()
	elseif head:Dot(up) < -0.999 then
		rot = ANG(math.pi, 0, 0)
	else
		rot = CFrame.fromAxisAngle(up:Cross(head).Unit, math.acos(math.clamp(up:Dot(head), -1, 1)))
	end
	-- แกน +Y ของมือ R15 (ตอนยกแขนถือของ) ชี้ขึ้น -> หัวเครื่องมือชี้ขึ้น ด้ามตั้งฉากกับแขน
	-- แล้วบิดรอบด้ามให้คม (blade) หันไปทาง +Z ของมือ = ข้างหน้า
	local twist = CF()
	if blade.Magnitude > 0.01 then
		local b = rot:VectorToObjectSpace(blade)
		twist = ANG(0, math.atan2(b.X, b.Z) + math.pi, 0) -- คมหันไปข้างหน้า (ทิศที่ฟัน)
	end
	return CF(grip) * rot * twist
end

function ToolFactory.Build(itemId)
	if Items.Sacks[itemId] then
		return buildSack(itemId)
	end
	local spec = Items.Tools[itemId]
	local shape = Shapes[itemId]
	if not (spec and shape) then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = Items.DisplayName(itemId)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", itemId)
	tool:SetAttribute("Kind", spec.Kind)
	local handle
	if MESH_TOOLS[itemId] and MeshProps.Has(itemId) then
		handle = MeshProps.BuildTool(itemId, tool)
		if spec.Light then
			glow(handle, itemId == "EmberBlade" and C(255, 120, 40) or C(255, 245, 220), spec.Light)
		end
		if itemId == "EmberBlade" then
			local f = Instance.new("Fire")
			f.Size = 2
			f.Heat = 5
			f.Parent = handle
		end
	else
		shape(tool)
		handle = tool:FindFirstChild("Handle")
	end
	-- ท่าถือ: หาแกนยาวของเครื่องมือจริง (โมเดลแต่ละชิ้นวางแกนไม่เหมือนกัน) -> หัว (ใบขวาน/ใบดาบ) ชี้ขึ้น มือจับใกล้ปลายด้าม
	tool.Grip = ToolFactory.GripFor(tool, handle, spec.Kind)
	return tool
end

return ToolFactory
