--[[
	DropService — ของตกบนพื้นแบบ 99 Nights
	ตัดไม้/ทุบหิน/ล่าสัตว์/เปิดหีบ -> ของเด้งออกมากองบนพื้น -> กด E (หรือคลิกตอนถือกระสอบ) เก็บใส่กระสอบ
	DropService:Spawn(id, n, pos)  ·  ของกองเดียวกันใกล้ๆ รวมเป็นกองเดียว · หายเองหลัง 10 นาที
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Items)

local DropService = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

local LIFETIME = 600
local MAX_DROPS = 350
local STACK_MAX = 10
local MERGE_RADIUS = 3.5
local PICK_RANGE = 20

local folder
local drops = {} -- model -> { Id, Count, Born }
local order = {}

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

local function build(id, n)
	local item = Items.Data[id]
	local m = Instance.new("Model")
	m.Name = "Drop_" .. id
	local look = LOOKS[id]
	local root
	if look then
		root = look(m, n)
	elseif item.Category == "Essence" or item.Category == "Relic" then
		root = gem(m, item.Color or C(255, 255, 255))
	else
		root = bundle(m, item.Color or C(200, 190, 170))
	end
	root.Name = "Root"
	root.CanCollide = true
	root.Massless = false
	for _, p in ipairs(m:GetChildren()) do
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
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Default
	pr.Parent = root
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
	-- รวมกับกองเดิมที่อยู่ใกล้
	for m, d in pairs(drops) do
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
		root.CFrame = CF(pos + V(math.cos(a) * spread * rng:NextNumber(), 2.2, math.sin(a) * spread * rng:NextNumber())) * ANG(0, rng:NextNumber() * 6.28, 0)
		m:SetAttribute("ItemId", id)
		m.Parent = folder
		root.AssemblyLinearVelocity = V(math.cos(a) * 7, 16, math.sin(a) * 7)
		root.AssemblyAngularVelocity = V(rng:NextNumber() * 4, rng:NextNumber() * 4, rng:NextNumber() * 4)
		drops[m] = { Id = id, Count = c, Born = os.clock() }
		table.insert(order, m)
		refresh(m)
		root.Pickup.Triggered:Connect(function(player)
			self:Pickup(player, m)
		end)
		-- ตกถึงพื้นแล้วตรึงไว้ (ประหยัดฟิสิกส์ + ผู้เล่นเตะไม่กระเด็น)
		task.delay(2.5, function()
			if m.Parent and m.PrimaryPart then
				m.PrimaryPart.Anchored = true
			end
		end)
		last = m
	end
	-- จำกัดจำนวนรวม
	while #order > MAX_DROPS do
		local old = table.remove(order, 1)
		if drops[old] then
			self:Remove(old)
		end
	end
	return last
end

---------------------------------------------------------------- เก็บ
function DropService:Pickup(player, m)
	local d = drops[m]
	local char = player.Character
	if not (d and char and m.PrimaryPart) then
		return
	end
	if (char:GetPivot().Position - m.PrimaryPart.Position).Magnitude > PICK_RANGE then
		return
	end
	local inv = self.ctx.Services.InventoryService
	if inv:Capacity(player) <= 0 then
		self.ctx.Notify(player, "ต้องมีกระสอบก่อนถึงจะเก็บของได้", "Error")
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

-- ทิ้งของจากกระสอบลงพื้นหน้าตัว
function DropService:DropFromPlayer(player, id, n)
	local inv = self.ctx.Services.InventoryService
	n = math.clamp(math.floor(tonumber(n) or 1), 1, 999)
	if not (Items.Data[id] and Items.Bulk(id)) then
		return
	end
	n = math.min(n, inv:Count(player, id))
	local char = player.Character
	if n <= 0 or not char then
		return
	end
	inv:Remove(player, id, n)
	local cf = char:GetPivot()
	self:Spawn(id, n, cf.Position + cf.LookVector * 4, { Spread = 0.5 })
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
		if typeof(m) == "Instance" and drops[m] then
			self:Pickup(player, m)
		end
	end)
	ctx.Remotes.Get("DropItem").OnServerEvent:Connect(function(player, id, n)
		if type(id) == "string" then
			self:DropFromPlayer(player, id, n)
		end
	end)
	-- หายเองเมื่อเก่าเกิน
	task.spawn(function()
		while true do
			task.wait(15)
			local now = os.clock()
			for m, d in pairs(drops) do
				if now - d.Born > LIFETIME or not m.Parent then
					self:Remove(m)
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
