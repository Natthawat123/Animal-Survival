--[[
	DropService — ของตกบนพื้นแบบ 99 Nights
	ตัดไม้/ทุบหิน/ล่าสัตว์/เปิดหีบ -> ของเด้งออกมากองบนพื้น -> กด E (หรือคลิกตอนถือกระสอบ) เก็บใส่กระสอบ
	DropService:Spawn(id, n, pos)  ·  ของกองเดียวกันใกล้ๆ รวมเป็นกองเดียว
	· ฟิสิกส์คิดบนเซิร์ฟเวอร์ (กันตกทะลุพื้นที่เครื่องผู้เล่นยังโหลดไม่ถึง) แล้วตรึงลงพื้นด้วย raycast
	· ของในแคมป์ไม่หาย · นอกแคมป์หายเองหลัง 15 นาที
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Items = require(ReplicatedStorage.Shared.Items)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)

local DropService = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

local LIFETIME = 900
local MAX_DROPS = 350
local STACK_MAX = 10
local MERGE_RADIUS = 3.5
local PICK_RANGE = 20
local PROMPT_RANGE = 12 -- ตรงกับ FOCUS_RANGE ฝั่ง client
local SETTLE_MAX = 4 -- วินาที: ปล่อยฟิสิกส์เด้งได้นานสุดก่อนตรึง
local FALL_LIMIT = 40 -- ตกต่ำกว่าจุดเกิดเกินนี้ = ทะลุโลก -> ย้ายกลับขึ้นพื้น

local folder
local drops = {} -- model -> { Id, Count, Born }
local order = {}

---------------------------------------------------------------- หาพื้นใต้ของ
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = false -- ตกน้ำ = ลอยบนผิวน้ำ ไม่จมหาย

local function groundBelow(x, z, top)
	local ex = { folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	local animals = Workspace:FindFirstChild("Animals")
	if animals then
		table.insert(ex, animals)
	end
	rayParams.FilterDescendantsInstances = ex
	return Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -300, 0), rayParams)
end

-- ผิวดินจริง (Terrain อย่างเดียว ไม่สนกิ่งไม้/หลังคา/โต๊ะ) · น้ำ = ผิวน้ำ
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.IgnoreWater = false
local function terrainTop(x, z, top)
	terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
	return Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -600, 0), terrainParams)
end

-- พื้นที่ของควรวาง: ของที่ชนได้ใต้ตัวของ (พื้นอาคาร/โต๊ะ) ถ้าอยู่ไม่ต่ำกว่าผิวดิน · ไม่งั้น = ผิวดิน
--   ของจมดิน/ทะลุลงไป -> ได้ผิวดินเสมอ (ไม่วางไว้ใต้ดิน) · ใต้กิ่งไม้/หลังคา -> ไม่ไปค้างข้างบน
local function surfaceFor(pos, origin)
	local T = terrainTop(pos.X, pos.Z, math.max(pos.Y, origin.Y) + 60)
	if T and T.Position.Y > pos.Y + 8 then
		-- เหนือหัวเป็นเพดานดิน (ถ้ำ/เกาะลอย) -> หาผิวที่ใกล้ระดับตัวของแทน
		T = terrainTop(pos.X, pos.Z, pos.Y + 2) or T
	end
	local S = groundBelow(pos.X, pos.Z, pos.Y + 1.5)
	if S and (not T or S.Position.Y >= T.Position.Y - 0.5) then
		return S
	end
	return T
end

-- ตรึงของลงพื้น: ถ้าวางอยู่บนพื้นดีแล้วไม่ขยับ (ท่าล้มตามธรรมชาติ) · ลอย/จมดิน/ทะลุโลก -> วางใหม่บนผิวพื้น
local function place(m, origin, force)
	local root = m.PrimaryPart
	if not (root and m.Parent) then
		return
	end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local pos = root.Position
	local hit = pos.Y > origin.Y - FALL_LIMIT and surfaceFor(pos, origin)
	if not hit then
		pos = origin
		hit = surfaceFor(origin, origin)
	end
	if hit then
		local half = root.Size.Y / 2
		local gap = pos.Y - (hit.Position.Y + half)
		-- จมดินแม้นิดเดียว / ลอยเกินครึ่งตัว -> วางใหม่บนผิว (นอนเอียงตามธรรมชาติบนพื้นปล่อยไว้)
		if force or pos ~= root.Position or gap < -0.35 or gap > math.max(root.Size.X, root.Size.Y, root.Size.Z) * 0.6 then
			local _, ry = root.CFrame:ToEulerAnglesYXZ()
			m:PivotTo(CF(hit.Position + V(0, half, 0)) * ANG(0, ry, 0))
		end
	end
	-- ตรึงแล้วไม่ต้องชนกับผู้เล่น (กล่องใสของโมเดล Store จะได้ไม่ขวางทาง) · เมาส์ยังชี้โดน
	root.CanCollide = false
end

local function settle(m, origin)
	task.spawn(function()
		local root = m.PrimaryPart
		local t0 = os.clock()
		local still = 0
		while m.Parent and root.Parent and not root.Anchored do
			task.wait(0.2)
			local t = os.clock() - t0
			if root.Position.Y < origin.Y - FALL_LIMIT or t > SETTLE_MAX then
				break
			end
			if t > 0.6 and root.AssemblyLinearVelocity.Magnitude < 1 then
				still += 1
				if still >= 2 then
					break
				end
			else
				still = 0
			end
		end
		place(m, origin)
	end)
end

---------------------------------------------------------------- หน้าตาของแต่ละชนิด
local function piece(model, size, color, material, shape, cf)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.Massless = true
	p.CFrame = cf or CF()
	p.Parent = model
	return p
end

local function log(m, cf, len)
	local bark = piece(m, V(len, 0.95, 0.95), C(104, 72, 46), Enum.Material.Wood, Enum.PartType.Cylinder, cf)
	for i = -1, 1, 2 do
		piece(m, V(0.06, 0.82, 0.82), C(206, 168, 112), Enum.Material.Wood, Enum.PartType.Cylinder, cf * CF(i * len / 2, 0, 0))
	end
	return bark
end

local function rock(m, cf, color, material, s)
	s = s or 1
	local r = piece(m, V(1.5, 1.05, 1.3) * s, color, material or Enum.Material.Slate, Enum.PartType.Ball, cf)
	piece(m, V(0.9, 0.8, 0.9) * s, color:Lerp(Color3.new(0, 0, 0), 0.12), material or Enum.Material.Slate, Enum.PartType.Ball, cf * CF(0.45 * s, 0.15 * s, 0.2 * s))
	return r
end

local LOOKS = {
	Wood = function(m, n)
		local root = log(m, CF(), 2.6)
		if n >= 3 then
			log(m, CF(0.2, 0, 0.95) * ANG(0, 0.15, 0), 2.4)
			log(m, CF(0.1, 0.8, 0.48) * ANG(0, -0.1, 0), 2.5)
		elseif n == 2 then
			log(m, CF(0.2, 0, 0.95) * ANG(0, 0.15, 0), 2.4)
		end
		return root
	end,
	Stone = function(m)
		return rock(m, CF(), C(140, 140, 146))
	end,
	Coal = function(m)
		return rock(m, CF(), C(34, 32, 36), Enum.Material.Basalt, 0.85)
	end,
	Iron = function(m)
		local r = rock(m, CF(), C(120, 108, 100))
		for i = 1, 3 do
			piece(m, V(0.3, 0.3, 0.3), C(214, 140, 90), Enum.Material.Metal, Enum.PartType.Ball, CF(math.cos(i * 2) * 0.55, 0.35, math.sin(i * 2) * 0.5))
		end
		return r
	end,
	Fiber = function(m)
		local r = piece(m, V(1.6, 0.7, 0.7), C(150, 186, 92), Enum.Material.Grass, Enum.PartType.Cylinder)
		piece(m, V(0.2, 0.78, 0.78), C(120, 90, 60), Enum.Material.Fabric, Enum.PartType.Cylinder)
		return r
	end,
	Pelt = function(m)
		local r = piece(m, V(2.2, 0.25, 1.6), C(150, 110, 76), Enum.Material.Fabric)
		piece(m, V(1.8, 0.26, 1.2), C(176, 136, 96), Enum.Material.Fabric, nil, CF(0, 0.05, 0))
		return r
	end,
	Bone = function(m)
		local r = piece(m, V(1.8, 0.32, 0.32), C(232, 226, 206), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for i = -1, 1, 2 do
			piece(m, V(0.5, 0.5, 0.5), C(236, 230, 212), Enum.Material.SmoothPlastic, Enum.PartType.Ball, CF(i * 0.9, 0, 0.15))
			piece(m, V(0.5, 0.5, 0.5), C(236, 230, 212), Enum.Material.SmoothPlastic, Enum.PartType.Ball, CF(i * 0.9, 0, -0.15))
		end
		return r
	end,
	Berries = function(m)
		local leaf = piece(m, V(1.2, 0.15, 1.2), C(70, 130, 60), Enum.Material.Grass)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			piece(m, V(0.42, 0.42, 0.42), C(190, 34, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball, CF(math.cos(a) * 0.32, 0.25, math.sin(a) * 0.32))
		end
		return leaf
	end,
	RawMeat = function(m)
		local r = piece(m, V(1.4, 0.6, 1), C(206, 80, 84), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(m, V(0.9, 0.18, 0.18), C(240, 232, 214), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, CF(0.8, 0, 0))
		return r
	end,
	CookedMeat = function(m)
		local r = piece(m, V(1.4, 0.6, 1), C(136, 70, 36), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(m, V(0.9, 0.18, 0.18), C(240, 232, 214), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, CF(0.8, 0, 0))
		return r
	end,
}

local function gem(m, color)
	local r = piece(m, V(0.9, 1.3, 0.9), color, Enum.Material.Neon, nil, ANG(0, math.rad(45), 0))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 10
	l.Brightness = 1.5
	l.Shadows = false
	l.Parent = r
	return r
end

local function bundle(m, color)
	local r = piece(m, V(1.2, 1, 1.2), color, Enum.Material.Fabric)
	piece(m, V(1.25, 0.2, 1.25), C(120, 90, 60), Enum.Material.Fabric, nil, CF(0, 0.2, 0))
	return r
end

-- ขนาดของตก (ด้านยาวสุด, stud) เมื่อใช้โมเดลจาก Creator Store
local STORE_SIZE = {
	Fiber = 1.8, Bone = 1.9, Berries = 1.9, RawMeat = 1.6, CookedMeat = 1.6, Stew = 1.6, Bandage = 1.4,
	Wood = 2.4, Pelt = 2, TerraCore = 1.4, TidePearl = 1.3, GaleFeather = 1.8,
	Stone = 1.8, Iron = 1.7, Coal = 1.8, BeastHeart = 1.5, Medkit = 1.4, EmberShard = 1.5,
}

-- โมเดลจาก Store: กล่องใส (Root ชนพื้น) + ชิ้นโมเดลเชื่อมติด
local function storeLook(m, id)
	local src, box = ItemModels.Clone(id, STORE_SIZE[id] or 1.7)
	local root = piece(m, Vector3.new(math.max(box.X, 0.4), math.max(box.Y, 0.4), math.max(box.Z, 0.4)), C(255, 255, 255))
	root.Transparency = 1
	for _, p in ipairs(src:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.Massless = false, false, false, true
		end
	end
	for _, c in ipairs(src:GetChildren()) do
		c.Parent = m
	end
	src:Destroy()
	-- พลังธาตุ/ของหายาก: เรืองแสงสีของไอเทม (มองเห็นตอนกลางคืน)
	local item = Items.Data[id]
	if item.Category == "Essence" or item.Category == "Relic" then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = item.Color or C(255, 255, 255), 10, 1.5, false
		l.Parent = root
	end
	return root
end

-- ออร่าของพลังธาตุ: เปลวไฟอนิเมะเกาะตัว + ประกายดาว (เหมือนอาวุธธาตุ)
local ESSENCE_AURA = {
	TerraCore = { C(255, 200, 90), C(170, 110, 40) },
	GaleFeather = { C(235, 250, 255), C(150, 215, 255) },
	EmberShard = { C(255, 140, 40), C(255, 40, 20) },
	BeastHeart = { C(255, 90, 140), C(200, 20, 60) },
}
local function essenceAura(root, id)
	local col = ESSENCE_AURA[id]
	if not col then
		return
	end
	local seq = ColorSequence.new(col[1], col[2])
	local s = math.max(root.Size.X, root.Size.Y, root.Size.Z)
	local f = Instance.new("ParticleEmitter")
	f.Texture = "rbxassetid://16676455805" -- เปลวไฟ 4x4 (VFXPack Fire-Aura)
	f.FlipbookLayout, f.FlipbookMode = Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookMode.OneShot
	f.Color, f.LightEmission, f.LightInfluence, f.Brightness = seq, 0.8, 0, 2
	f.Shape, f.LockedToPart, f.ZOffset = Enum.ParticleEmitterShape.Box, true, -0.3
	f.Rate, f.Lifetime, f.Speed = 16, NumberRange.new(0.4, 0.6), NumberRange.new(0.4, 0.9)
	f.EmissionDirection, f.SpreadAngle, f.Acceleration = Enum.NormalId.Top, Vector2.new(15, 15), V(0, 3, 0)
	f.Rotation = NumberRange.new(-20, 20)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.45), NumberSequenceKeypoint.new(0.5, s * 0.6), NumberSequenceKeypoint.new(1, s * 0.2) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
	f.Parent = root
	local st = Instance.new("ParticleEmitter")
	st.Texture = "rbxassetid://17087151546" -- ประกายดาว (VFXPack RNG-Aura)
	st.Color, st.LightEmission, st.LightInfluence, st.Brightness = seq, 1, 0, 3
	st.Shape, st.Rate, st.Lifetime = Enum.ParticleEmitterShape.Box, 6, NumberRange.new(0.6, 1)
	st.Speed, st.SpreadAngle, st.Drag = NumberRange.new(0.8, 2), Vector2.new(180, 180), 3
	st.Rotation = NumberRange.new(-180, 180)
	st.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0) })
	st.Parent = root
end

-- เศษอัคคี: กระจุกคริสตัลแดงแหลม (โมเดลที่เลือกเป็น Union ดึงมาใช้ไม่ได้ เลยปั้นทรงเดียวกัน)
local function emberCrystal(m)
	local glass, core = C(235, 45, 35), C(255, 120, 60)
	local root = piece(m, V(0.42, 1.9, 0.42), glass, Enum.Material.Glass, nil, CF(0, 0.15, 0) * ANG(0, math.rad(45), 0))
	root.Transparency = 0.1
	piece(m, V(0.18, 1.5, 0.18), core, Enum.Material.Neon, nil, CF(0, 0.1, 0))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local h = 0.8 + (i % 2) * 0.35
		local p = piece(m, V(0.26, h, 0.26), glass, Enum.Material.Glass, nil,
			CF(math.cos(a) * 0.3, -0.75 + h / 2, math.sin(a) * 0.3) * ANG(math.sin(a) * 0.5, a, -math.cos(a) * 0.5))
		p.Transparency = 0.1
	end
	return root
end

local function build(id, n)
	local item = Items.Data[id]
	local m = Instance.new("Model")
	m.Name = "Drop_" .. id
	-- สตรีมมิ่งส่งทั้งโมเดลทีเดียว (ไม่งั้น client อาจได้ชิ้นส่วนแต่ไม่ได้ Root -> ชี้/เก็บไม่ได้)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local look = LOOKS[id]
	local root
	if ItemModels.Has(id) then
		root = storeLook(m, id)
	elseif id == "EmberShard" then
		root = emberCrystal(m)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = item.Color, 10, 1.5, false
		l.Parent = root
	elseif look then
		root = look(m, n)
	elseif item.Category == "Essence" or item.Category == "Relic" then
		root = gem(m, item.Color or C(255, 255, 255))
	else
		root = bundle(m, item.Color or C(200, 190, 170))
	end
	essenceAura(root, id)
	root.Name = "Root"
	root.CanCollide = true
	root.Massless = false
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	m.PrimaryPart = root
	-- ป้ายชื่อ (เห็นเมื่อเข้าใกล้)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(120, 26)
	bb.StudsOffsetWorldSpace = V(0, 1.8, 0)
	bb.MaxDistance = 28
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 15
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Parent = bb
	bb.Parent = root
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Pickup"
	pr.ActionText = "เก็บใส่กระสอบ"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 0
	pr.MaxActivationDistance = PROMPT_RANGE
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Default
	pr.Enabled = false -- client เปิดเฉพาะชิ้นที่โฟกัส (กรอบขาว)
	pr.Parent = root
	if item.Category == "Food" or item.Category == "Medical" then
		local use = Instance.new("ProximityPrompt")
		use.Name = "Use"
		use.ActionText = item.Category == "Food" and "กิน" or "ใช้"
		use.KeyboardKeyCode = Enum.KeyCode.R
		use.HoldDuration = 0.4
		use.MaxActivationDistance = PROMPT_RANGE
		use.RequiresLineOfSight = false
		use.Enabled = false
		use.UIOffset = Vector2.new(0, 60)
		use.Parent = root
	end
	return m, root
end

local function refresh(m)
	local d = drops[m]
	if not d then
		return
	end
	local name = Items.DisplayName(d.Id)
	local text = d.Count > 1 and (name .. " ×" .. d.Count) or name
	local root = m.PrimaryPart
	root.Label.Text.Text = text
	root.Pickup.ObjectText = text
	m:SetAttribute("Count", d.Count)
end

function DropService:Remove(m)
	drops[m] = nil
	m:Destroy()
end

---------------------------------------------------------------- สร้างของตก
function DropService:Spawn(id, n, pos, opts)
	n = math.floor(n or 1)
	if n <= 0 or not Items.Data[id] then
		return
	end
	opts = opts or {}
	-- รวมกับกองเดิมที่อยู่ใกล้ (ของที่โยนไม่รวม จะได้ลอยไปถึงเป้า)
	for m, d in pairs((opts.Velocity or opts.Arc) and {} or drops) do
		if d.Id == id and d.Count < STACK_MAX and m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < MERGE_RADIUS then
			local add = math.min(n, STACK_MAX - d.Count)
			d.Count += add
			d.Born = os.clock()
			n -= add
			refresh(m)
			if n <= 0 then
				return m
			end
		end
	end
	local last
	while n > 0 do
		local c = math.min(n, STACK_MAX)
		n -= c
		local m, root = build(id, c)
		local rng = self.rng
		local a = rng:NextNumber() * math.pi * 2
		local spread = opts.Spread or 2.5
		-- ย้ายทั้งโมเดล (PivotTo) ไม่ใช่แค่ Root: ตอนยังไม่อยู่ใน Workspace รอยเชื่อมยังไม่ทำงาน
		-- ถ้าย้ายแค่ Root ชิ้นที่มองเห็นจะค้างอยู่ที่จุด 0,0,0 ใต้ดิน (เห็นแต่ป้ายชื่อ)
		if opts.Velocity or opts.Arc then
			m:PivotTo(CF(pos) * ANG(0, rng:NextNumber() * 6.28, 0))
		else
			m:PivotTo(CF(pos + V(math.cos(a) * spread * rng:NextNumber(), 2.2, math.sin(a) * spread * rng:NextNumber())) * ANG(0, rng:NextNumber() * 6.28, 0))
		end
		m:SetAttribute("ItemId", id)
		m.Parent = folder
		-- เซิร์ฟเวอร์คิดฟิสิกส์เอง: ถ้าให้เครื่องผู้เล่นคิด ของจะตกทะลุพื้นที่ยังสตรีมมาไม่ถึง
		pcall(root.SetNetworkOwner, root, nil)
		root.AssemblyLinearVelocity = opts.Velocity or V(math.cos(a) * 7, 16, math.sin(a) * 7)
		root.AssemblyAngularVelocity = V(rng:NextNumber() * 4, rng:NextNumber() * 4, rng:NextNumber() * 4)
		drops[m] = { Id = id, Count = c, Born = os.clock(), By = opts.By }
		table.insert(order, m)
		refresh(m)
		root.Pickup.Triggered:Connect(function(player)
			self:Pickup(player, m)
		end)
		local use = root:FindFirstChild("Use")
		if use then
			use.Triggered:Connect(function(player)
				self:UseDrop(player, m)
			end)
		end
		-- โยนเข้าเป้า (กองไฟ/เครื่องบด): ลอยเป็นเส้นโค้งด้วยสคริปต์ ไม่ใช้ฟิสิกส์
		--   (เดิมใช้ความเร็ว -> ชนตัวผู้เล่น/กระสอบในมือ/ท่อนฟืนแล้วพุ่งขึ้นฟ้า)
		if opts.Arc then
			root.Anchored = true
			root.CanCollide = false
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			local from, to = pos, opts.Arc
			local dur = math.clamp((to - from).Magnitude / 22, 0.35, 0.9)
			local h = 2.5 + (to - from).Magnitude * 0.12
			local spin = rng:NextNumber() * 6.28
			task.spawn(function()
				local t0 = os.clock()
				while m.Parent and root.Parent do
					local k = math.min((os.clock() - t0) / dur, 1)
					local p = from:Lerp(to, k) + V(0, 4 * h * k * (1 - k), 0)
					m:PivotTo(CF(p) * ANG(k * 4, spin, k * 2))
					if k >= 1 then
						break
					end
					task.wait()
				end
				place(m, to, true)
			end)
			last = m
			continue
		end
		-- หยุดเด้งแล้วตรึงลงพื้น (ประหยัดฟิสิกส์ + ผู้เล่นเตะไม่กระเด็น + กันลอย/จมดิน)
		if opts.Place then
			-- วางลงพื้นทันที ไม่ปล่อยฟิสิกส์ (ของที่ผู้เล่นทิ้ง: ไม่ชนตัว/กระสอบแล้วกระเด็น)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			place(m, pos + V(0, 1, 0), true)
		else
			settle(m, pos + V(0, 1, 0))
		end
		last = m
	end
	-- จำกัดจำนวนรวม: ทิ้งของเก่านอกแคมป์ก่อน (ของที่กองไว้ในแคมป์ไม่โดน)
	if #order > MAX_DROPS then
		local keep = {}
		local over = -MAX_DROPS
		for _ in pairs(drops) do
			over += 1
		end
		for _, old in ipairs(order) do
			if drops[old] and over > 0 and not self:InCamp(old) then
				over -= 1
				self:Remove(old)
			elseif drops[old] then
				table.insert(keep, old)
			end
		end
		while #keep > MAX_DROPS do
			self:Remove(table.remove(keep, 1))
		end
		order = keep
	end
	return last
end

function DropService:InCamp(m)
	local camp = self.ctx.CampPosition
	local r = m.PrimaryPart
	if not (camp and r) then
		return false
	end
	local cs = self.ctx.Services.CampService
	local radius = cs and cs.CampRadius and cs:CampRadius() or 60
	return ((r.Position - camp) * V(1, 0, 1)).Magnitude <= radius + 10
end

---------------------------------------------------------------- เก็บ
function DropService:Pickup(player, m)
	local d = drops[m]
	local char = player.Character
	if not (d and char and m.PrimaryPart) or self.ctx.Services.SurvivalService:IsIncapacitated(player) then
		return
	end
	if (char:GetPivot().Position - m.PrimaryPart.Position).Magnitude > PICK_RANGE then
		return
	end
	-- ต้องถือกระสอบในมือก่อนถึงจะเก็บได้ (แบบ 99 Nights)
	local inv = self.ctx.Services.InventoryService
	if not inv:HoldingSack(player) then
		self.ctx.Notify(player, "🎒 ถือกระสอบก่อน (เลือกกระสอบในแถบเครื่องมือ) แล้วค่อยเก็บของ", "Info")
		return
	end
	local got = inv:AddToSack(player, d.Id, d.Count)
	if got <= 0 then
		self.ctx.Notify(player, string.format("🎒 กระสอบเต็ม (%d/%d) — กลับไปเทของที่โต๊ะคราฟต์ในแคมป์", inv:Used(player), inv:Capacity(player)), "Warn")
		return
	end
	d.Count -= got
	if d.Count <= 0 then
		self:Remove(m)
	else
		refresh(m)
	end
end

-- กิน/ใช้ของบนพื้น 1 ชิ้น
function DropService:UseDrop(player, m)
	local d = drops[m]
	local char = player.Character
	if not (d and char and m.PrimaryPart) or self.ctx.Services.SurvivalService:IsIncapacitated(player)
		or (char:GetPivot().Position - m.PrimaryPart.Position).Magnitude > PICK_RANGE then
		return
	end
	local inv = self.ctx.Services.InventoryService
	local before = inv:Count(player, d.Id)
	inv:Add(player, d.Id, 1, true)
	self.ctx.Services.SurvivalService:UseItem(player, d.Id)
	if inv:Count(player, d.Id) > before then
		-- ใช้ไม่สำเร็จ (เช่นเลือดเต็ม) -> เอาคืนออกจากกระสอบ ของยังอยู่บนพื้น
		inv:Remove(player, d.Id, 1)
		return
	end
	d.Count -= 1
	if d.Count <= 0 then
		self:Remove(m)
	else
		refresh(m)
	end
end

-- ของตกในรัศมี (ใช้กับกองไฟ)
function DropService:Near(pos, radius, height)
	local out = {}
	for m, d in pairs(drops) do
		local r = m.PrimaryPart
		if r then
			local off = r.Position - pos
			if Vector3.new(off.X, 0, off.Z).Magnitude < radius and math.abs(off.Y) < (height or radius) then
				table.insert(out, { Model = m, Id = d.Id, Count = d.Count, By = d.By })
			end
		end
	end
	return out
end

-- โยนของจากมือเป็นวิถีโค้งไปตกที่ target
function DropService:Throw(player, id, n, target)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local from = head.Position + Vector3.new(0, 1, 0)
	self:Spawn(id, n, from, { Arc = target, By = player })
end

-- ทิ้งของจากกระสอบ: ถ้ายืนใกล้กองไฟ -> โยนเข้ากองไฟเลย ไม่งั้นวางหน้าตัว
function DropService:DropFromPlayer(player, id, n)
	local inv = self.ctx.Services.InventoryService
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 999)
	if not inv:HoldingSack(player) then
		return
	end
	if id == nil then
		id = inv:LastItem(player)
	end
	if not (id and Items.Data[id] and Items.Bulk(id)) then
		return
	end
	n = math.min(n, inv:Count(player, id))
	local char = player.Character
	if n <= 0 or not char then
		return
	end
	inv:Remove(player, id, n)
	inv:PopOrder(player, id)
	local cf = char:GetPivot()
	local fire = self.ctx.Services.CampService:FirePosition()
	if fire and (cf.Position - fire).Magnitude < 18 then
		self:Throw(player, id, n, fire + Vector3.new(0, 1, 0))
	else
		self:Spawn(id, n, cf.Position + cf.LookVector * 5, { Spread = 0.5, Place = true })
	end
end

function DropService:Init(ctx)
	self.ctx = ctx
	self.rng = Random.new()
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = Workspace
end

function DropService:Start(ctx)
	ctx.Remotes.Get("PickupDrop").OnServerEvent:Connect(function(player, m)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		if typeof(m) == "Instance" and drops[m] then
			self:Pickup(player, m)
		end
	end)
	ctx.Remotes.Get("DropItem").OnServerEvent:Connect(function(player, id, n)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		if id == nil or type(id) == "string" then
			self:DropFromPlayer(player, id, n)
		end
	end)
	-- หายเองเมื่อเก่าเกิน (ยกเว้นในแคมป์) + เช็กของที่ตรึงแล้วลอยค้าง (เช่นพื้นเดิมเป็นต้นไม้ที่โดนตัดไป)
	task.spawn(function()
		while true do
			task.wait(15)
			local now = os.clock()
			for m, d in pairs(drops) do
				local r = m.PrimaryPart
				if not (m.Parent and r) then
					self:Remove(m)
				elseif now - d.Born > LIFETIME and not self:InCamp(m) then
					self:Remove(m)
				elseif r.Anchored then
					local surf = surfaceFor(r.Position, r.Position)
					local gap = surf and (r.Position.Y - r.Size.Y / 2 - surf.Position.Y)
					if not surf or gap > 1.5 or gap < -1 then
						place(m, r.Position, true) -- ลอย/จมดิน -> วางใหม่บนผิว
					end
				end
			end
			local keep = {}
			for _, m in ipairs(order) do
				if drops[m] then
					table.insert(keep, m)
				end
			end
			order = keep
		end
	end)
end

return DropService
