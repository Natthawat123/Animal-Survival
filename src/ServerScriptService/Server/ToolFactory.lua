--[[
	ToolFactory — สร้าง Tool (อาวุธ/เครื่องมือ) พร้อมหน้าตา
	ทุก Tool มี Handle + attribute ItemId; ฝั่ง client กดตี -> Remotes.Attack
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
-- อาวุธ/เครื่องมือที่ใช้โมเดลจริง (ที่เหลือปั้นเอง: คบเพลิง หอก ตรีศูล)
local MESH_TOOLS = { OldAxe = true, StoneAxe = true, IronAxe = true, Pickaxe = true, Bow = true, GaleBow = true, TerraHammer = true, EmberBlade = true, FourfoldBlade = true }
-- ด้าน "หน้า" ของโมเดลจริงแต่ละชิ้น (แกนของชิ้น Handle) = ด้านที่ต้องหันออกไปข้างหน้าตัวละคร (ทิศที่ฟัน/ยิง)
-- วัดจากเมชจริง (PropMeshData): ทุกชิ้นตั้งตามแกน +Y (หัวอยู่บน) แบนตามแกน Z · ใบ/หัวอยู่ด้าน +X หรือ -X
--   ขวานเก่า: ใบด้าน +X · ขวานหิน: ใบด้าน -X (กลับข้างกัน!) · ธนู: หลังคันโค้งด้าน +X (สายอยู่ -X)
--   ขวานเหล็ก/อีเตอร์/ค้อน/ดาบ: สมมาตรซ้ายขวา -> ใช้ +X (คมหันหน้า ด้านแบนหันข้าง)
-- ⚠ ดาบทั้งสองเล่มโมเดลกลับหัว (ด้ามอยู่บน ใบดาบชี้ลง -Y) -> MESH_HEAD บอกว่า "หัว" (ใบ) อยู่ทาง -Y
local MESH_HEAD = {
	EmberBlade = Vector3.new(0, -1, 0),
	FourfoldBlade = Vector3.new(0, -1, 0),
}
local MESH_FRONT = {
	OldAxe = Vector3.new(1, 0, 0),
	StoneAxe = Vector3.new(-1, 0, 0),
	IronAxe = Vector3.new(1, 0, 0),
	Pickaxe = Vector3.new(1, 0, 0),
	Bow = Vector3.new(1, 0, 0),
	GaleBow = Vector3.new(1, 0, 0),
	TerraHammer = Vector3.new(1, 0, 0),
	EmberBlade = Vector3.new(1, 0, 0),
	FourfoldBlade = Vector3.new(1, 0, 0),
}

-- อาวุธจาก Roblox Creator Store (assets/rbxm/Weapons/<ItemId>.rbxmx -> ReplicatedStorage.Assets.Weapons)
-- Length = ความยาวในมือ (stud) · Head/Front = แกนของชิ้น Handle (วัดจากโมเดลจริง) ที่เป็นหัว/คม · ไม่มี = เดาจากรูปทรง
-- Aura = ออร่าธาตุรอบอาวุธ: "Earth" | "Water" | "Wind" | "Fire" | "Rainbow" (เปลวอนิเมะ + ประกาย + เส้นแสงตามรอยฟัน)
local STORE_WEAPONS = {
	OldAxe = { Length = 3.2, Front = Vector3.new(0, 0, -1) }, StoneAxe = { Length = 3.2 }, Pickaxe = { Length = 3.4, Head = Vector3.new(0, 1, 0) },
	Torch = { Length = 3, Fire = true }, Spear = { Length = 6 },
	Bow = { Length = 4.2, Front = Vector3.new(0, 0, 1), Flip = true },
	TerraHammer = { Length = 4.2, Aura = "Earth" },
	TidalTrident = { Length = 5.6, Aura = "Water" },
	GaleBow = { Length = 4.4, Aura = "Wind" },
	EmberBlade = { Length = 4.6, Head = Vector3.new(0, 0, -1), Flip = true, Aura = "Fire" },
	FourfoldBlade = { Length = 4.8, Front = Vector3.new(0, 0, 1), Aura = "Rainbow" },
}

-- ออร่าธาตุ: ประกายลอยรอบตัวอาวุธ + หมอกเรืองแสงบางๆ + แสงส่อง
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 90)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 230, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
})
-- ออร่าธาตุแบบอนิเมะ: เปลวไฟ flipbook ห่อตัวอาวุธ + ประกายดาว + เส้นแสงตามรอยฟัน + แสงเรือง
local FLAME_TEX = "rbxassetid://16676455805" -- เปลวไฟ 4x4 (VFXPack/Auras/Fire-Aura-01)
local STAR_TEX = "rbxassetid://17087151546" -- ประกายดาว (VFXPack/Auras/RNG-Aura-02)
local function seq2(a, b)
	return ColorSequence.new(a, b)
end
local AURAS = {
	Earth = { Tex = FLAME_TEX, Color = seq2(Color3.fromRGB(255, 190, 90), Color3.fromRGB(150, 90, 40)), Light = Color3.fromRGB(230, 150, 70), Emission = 0.6 },
	Water = { Tex = FLAME_TEX, Color = seq2(Color3.fromRGB(80, 200, 255), Color3.fromRGB(20, 90, 255)), Light = Color3.fromRGB(70, 180, 255), Emission = 0.8 },
	Wind = { Tex = FLAME_TEX, Color = seq2(Color3.fromRGB(225, 250, 255), Color3.fromRGB(140, 210, 255)), Light = Color3.fromRGB(220, 240, 255), Emission = 0.45 },
	Fire = { Tex = FLAME_TEX, Color = seq2(Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 40, 20)), Light = Color3.fromRGB(255, 80, 40), Emission = 0.9 },
	Rainbow = { Tex = FLAME_TEX, Color = RAINBOW, Light = Color3.fromRGB(230, 200, 255), Emission = 1 },
}
local function addAura(handle, kind, tool)
	local A = AURAS[kind] or AURAS.Fire
	-- ขอบเขตของอาวุธทั้งชิ้นในพิกัดของ Handle -> แกนยาว + ความหนา
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf = handle.CFrame:ToObjectSpace(p.CFrame)
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local v = cf * (p.Size * Vector3.new(sx, sy, sz))
						lo, hi = lo:Min(v), hi:Max(v)
					end
				end
			end
		end
	end
	local size, mid = hi - lo, (hi + lo) / 2
	local axis = size.X >= size.Y and size.X >= size.Z and Vector3.xAxis or (size.Y >= size.Z and Vector3.yAxis or Vector3.zAxis)
	local len = size:Dot(axis)
	local thick = math.clamp((size.X + size.Y + size.Z - len) / 2, 0.4, 1.4)

	-- กล่องปล่อยอนุภาค (Part ใส ไม่ชน) ครอบตัวอาวุธทั้งชิ้น
	local box = Instance.new("Part")
	box.Name = "AuraBox"
	box.Transparency, box.CanCollide, box.CanQuery, box.CanTouch, box.Massless = 1, false, false, false, true
	box.Size = Vector3.new(math.max(size.X, 0.3), math.max(size.Y, 0.3), math.max(size.Z, 0.3))
	box.CFrame = handle.CFrame * CFrame.new(mid)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = handle, box
	w.Parent = box
	box.Parent = tool

	local function emitter(props)
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence, e.Shape = 0, Enum.ParticleEmitterShape.Box
		e.Color = A.Color
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = box
		return e
	end
	local fs = math.clamp(thick, 0.55, 1)
	-- เปลวออร่าเคลื่อนไหว (flipbook) ลุกท่วมตัวอาวุธ อยู่หลังตัวอาวุธเล็กน้อย
	emitter({
		Texture = A.Tex, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Rate = math.floor(18 + len * 10), Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(0.3, 0.8), LockedToPart = true,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0, 3, 0),
		Rotation = NumberRange.new(-20, 20), LightEmission = A.Emission, Brightness = 2, ZOffset = -0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fs * 0.7), NumberSequenceKeypoint.new(0.5, fs), NumberSequenceKeypoint.new(1, fs * 0.3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.2, 0.05), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})
	-- ประกายดาวลอยวิบวับ
	emitter({
		Texture = STAR_TEX, Rate = math.floor(3 + len), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0.8, 2),
		SpreadAngle = Vector2.new(180, 180), Drag = 3, LightEmission = 1, Brightness = 2.5, Rotation = NumberRange.new(-180, 180), ZOffset = 0.5,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.32), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }),
	})
	-- เส้นแสงตามรอยฟัน (เห็นตอนเหวี่ยงอาวุธ)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = -axis * (len * 0.45), axis * (len * 0.45)
	a0.Parent, a1.Parent = box, box
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color, tr.LightEmission, tr.LightInfluence, tr.Brightness = A.Color, 1, 0, 2
	tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.22, 0.05, false
	tr.Texture, tr.TextureMode = "rbxassetid://16664715772", Enum.TextureMode.Stretch
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	tr.Parent = box
	-- ขอบเรืองแสงสีธาตุรอบตัวอาวุธ
	local hl = Instance.new("Highlight")
	hl.Adornee, hl.DepthMode = tool, Enum.HighlightDepthMode.Occluded
	hl.FillColor, hl.FillTransparency = A.Light, 0.8
	hl.OutlineColor, hl.OutlineTransparency = A.Light, 0.1
	hl.Parent = box
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = A.Light, 9, 1.2
	l.Parent = box
end

local ToolFactory = {}
ToolFactory.StoreWeapons = STORE_WEAPONS

-- โมเดลอาวุธจาก Store -> ชิ้นทั้งหมดเชื่อมกับ Handle (ชิ้นใหญ่สุด) + ย่อขยายให้ยาวตาม Length
local function buildStore(itemId, tool)
	local cfg = STORE_WEAPONS[itemId]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local src = cfg and assets and assets:FindFirstChild("Weapons") and assets.Weapons:FindFirstChild(itemId)
	if not src then
		return nil
	end
	local m = Instance.new("Model")
	for _, c in ipairs(src:GetChildren()) do
		c:Clone().Parent = m
	end
	local parts, big = {}, nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if not big or d.Size.Magnitude > big.Size.Magnitude then
				big = d
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	if not big then
		return nil
	end
	local _, size = m:GetBoundingBox()
	pcall(function()
		m:ScaleTo(m:GetScale() * cfg.Length / math.max(size.X, size.Y, size.Z))
	end)
	for _, p in ipairs(parts) do
		p.Anchored = false
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
		if p ~= big then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = big, p
			w.Parent = big
		end
	end
	big.Name = "Handle"
	-- ย้ายทุกชิ้นขึ้นมาอยู่ใต้ Tool ตรงๆ (Handle ต้องเป็นลูกของ Tool โดยตรง · บางโมเดลซ้อน Model ไว้ข้างใน)
	for _, p in ipairs(parts) do
		p.Parent = tool
	end
	m:Destroy()
	if cfg.Fire then
		-- ไฟที่ปลายคบ: ใส่ในชิ้นหัว (ชิ้นที่ไม่ใช่ด้าม) ถ้ามี · ไม่มีก็ใส่ที่ปลายด้านยาวของด้าม
		local head
		for _, p in ipairs(parts) do
			if p ~= big then
				head = p
			end
		end
		local host = head
		if not host then
			host = Instance.new("Attachment")
			local axis = big.Size.X >= big.Size.Y and big.Size.X >= big.Size.Z and Vector3.xAxis or (big.Size.Y >= big.Size.Z and Vector3.yAxis or Vector3.zAxis)
			host.Position = axis * (big.Size:Dot(axis) / 2)
			host.Parent = big
		end
		local f = Instance.new("Fire")
		f.Size, f.Heat = 2.5, 6
		f.Parent = host
		-- หัวคบ (ชิ้นที่มีไฟ) ต้องชี้ขึ้นตอนถือ: บอกทิศหัวตามแกนหลักของด้าม
		if head then
			local rel = big.CFrame:PointToObjectSpace(head.Position)
			local a = Vector3.new(math.abs(rel.X), math.abs(rel.Y), math.abs(rel.Z))
			if a.X >= a.Y and a.X >= a.Z then
				return big, Vector3.new(math.sign(rel.X), 0, 0)
			elseif a.Y >= a.Z then
				return big, Vector3.new(0, math.sign(rel.Y), 0)
			end
			return big, Vector3.new(0, 0, math.sign(rel.Z))
		end
	end
	return big
end

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
	if ItemModels.Has(itemId) then
		-- โมเดลจาก Creator Store: ห้อยใต้มือ (Handle ใส)
		h.Transparency = 1
		local src, box = ItemModels.Clone(itemId, 2.6 * s)
		for _, p in ipairs(src:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CFrame = h.CFrame * CF(0, -0.4 - box.Y / 2, 0) * p.CFrame
				p.Anchored, p.CanCollide, p.CanTouch, p.Massless = false, false, false, true
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = h, p
				w.Parent = p
			end
		end
		for _, c in ipairs(src:GetChildren()) do
			c.Parent = tool
		end
		src:Destroy()
		tool.GripPos = V(0, 0.3, 0)
		return tool
	end
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

-- front (ไม่บังคับ) = ทิศ "หน้า" ของเครื่องมือในแกนของ Handle (ถ้ารู้จากเมชจริง) — ไม่งั้นเดาจากรูปทรง
function ToolFactory.GripFor(tool, handle, kind, front, headOverride)
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
	if headOverride then
		head = headOverride
		axis = V(math.abs(head.X), math.abs(head.Y), math.abs(head.Z))
		len = ext:Dot(axis)
	end
	local up = V(0, 1, 0)
	local function headUp()
		if head:Dot(up) > 0.999 then
			return CF()
		elseif head:Dot(up) < -0.999 then
			return ANG(math.pi, 0, 0)
		end
		return CFrame.fromAxisAngle(up:Cross(head).Unit, math.acos(math.clamp(up:Dot(head), -1, 1)))
	end
	-- บิดรอบด้ามให้ทิศ f หันไปข้างหน้าตัวละคร (แบบเดียวกับขวานเก่าที่ถือถูกอยู่แล้ว)
	local function faceForward(rot, f)
		local b = rot:VectorToObjectSpace(f)
		return ANG(0, math.atan2(b.X, b.Z) + math.pi, 0)
	end
	if kind == "Bow" then
		-- ธนู: จับกลางคัน (ค่อนไปทางหลังคัน) ตั้งคันขึ้น หลังคันหันไปข้างหน้า สายหันเข้าหาตัว
		local rot = headUp()
		if front then
			local widthAxis = math.abs(front.X) > 0.5 and ext.X or (math.abs(front.Z) > 0.5 and ext.Z or ext.Y)
			return CF(mid + front * widthAxis * 0.25) * rot * faceForward(rot, front)
		end
		return CF(mid) * rot * ANG(0, math.pi / 2, 0)
	end
	local tail = mid - head * (len / 2)
	local grip = tail + head * (len * (kind == "Spear" and 0.35 or 0.18))
	if front then
		local rot = headUp()
		return CF(grip) * rot * faceForward(rot, front)
	end
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
	-- แกน +Y ของมือ R15 (ตอนยกแขนถือของ) ชี้ขึ้น -> หัวเครื่องมือชี้ขึ้น ด้ามตั้งฉากกับแขน
	-- แล้วบิดรอบด้ามให้คม (blade) หันไปข้างหน้า (ทิศที่ฟัน)
	local rot = headUp()
	local twist = CF()
	if blade.Magnitude > 0.01 then
		twist = faceForward(rot, blade)
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
	local handle, headDir = buildStore(itemId, tool)
	if handle then
		local cfg = STORE_WEAPONS[itemId]
		if cfg.Aura then
			addAura(handle, cfg.Aura, tool)
		elseif spec.Light then
			glow(handle, C(255, 245, 220), spec.Light)
		end
		tool.Grip = ToolFactory.GripFor(tool, handle, spec.Kind, cfg.Front, cfg.Head or headDir)
		if cfg.Flip then
			-- หันกลับด้าน 180° รอบแกนด้าม (โมเดลบางชิ้นวางหน้า-หลังสลับกัน)
			tool.Grip *= CFrame.Angles(0, math.pi, 0)
		end
		return tool
	end
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
	local isMesh = MESH_TOOLS[itemId] and MeshProps.Has(itemId)
	tool.Grip = ToolFactory.GripFor(tool, handle, spec.Kind, isMesh and MESH_FRONT[itemId] or nil, isMesh and MESH_HEAD[itemId] or nil)
	return tool
end

return ToolFactory
