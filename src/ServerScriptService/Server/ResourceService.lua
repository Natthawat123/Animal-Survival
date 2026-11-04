--[[
	ResourceService — ของที่เก็บได้ในโลก (แท็ก ResourceNode จาก PropBuilder)
	ตี/ฟัน -> ได้ของตามดาเมจ -> หมดแล้ว (ต้นไม้ล้ม/หินแตก) -> งอกใหม่ภายหลัง
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local ResourceService = {}

function ResourceService:Init(ctx)
	self.ctx = ctx
	self.overlap = OverlapParams.new()
	self.overlap.FilterType = Enum.RaycastFilterType.Include
	self.felled = {} -- [ต้นไม้ที่ล้ม] = วันที่ล้ม (State.Night)
end

-- หา node ใกล้จุดนั้นที่สุด
-- รัศมีฐานของ node (ลำต้น/ตัวหิน) แนวนอน: ต้นไม้ใช้ Collider ลำต้น · อื่นๆ ใช้กรอบโมเดล
function ResourceService:Footprint(node)
	local col = node:FindFirstChild("Collider")
	if col and col:IsA("BasePart") then
		return math.max(col.Size.Y, col.Size.Z) / 2
	end
	if node:IsA("Model") then
		local _, size = node:GetBoundingBox()
		return math.clamp(math.min(size.X, size.Z) / 2, 0.5, 8)
	elseif node:IsA("BasePart") then
		return math.clamp(math.min(node.Size.X, node.Size.Z) / 2, 0.5, 8)
	end
	return 1.5
end

function ResourceService:FindNode(position, radius)
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	self.overlap.FilterDescendantsInstances = { world }
	local parts = Workspace:GetPartBoundsInRadius(position, radius, self.overlap)
	local best, bestD
	for _, p in ipairs(parts) do
		local node = p:FindFirstAncestorWhichIsA("Model")
		while node and not CollectionService:HasTag(node, "ResourceNode") do
			node = node.Parent and node.Parent:IsA("Model") and node.Parent or nil
		end
		if node and not node:GetAttribute("Depleted") then
			local d = (p.Position - position).Magnitude
			if not bestD or d < bestD then
				best, bestD = node, d
			end
		end
	end
	return best
end

local function setVisible(node, visible)
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") then
			if visible then
				d.Transparency = d:GetAttribute("OrigT") or 0
				d.CanCollide = d:GetAttribute("OrigC") ~= false
			else
				if d:GetAttribute("OrigT") == nil then
					d:SetAttribute("OrigT", d.Transparency)
					d:SetAttribute("OrigC", d.CanCollide)
				end
				d.Transparency = 1
				d.CanCollide = false
			end
			d.CanQuery = visible
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") then
			d.Enabled = visible
		end
	end
end

function ResourceService:Fell(node, from)
	node:SetAttribute("Depleted", true)
	local kind = node:GetAttribute("Node")
	-- แอนิเมชันล้ม/แตกเล่นฝั่งเครื่องผู้เล่น (BreakFX: โคลนโมเดลไปเล่นลื่นๆ ตามวัสดุ — ต้นไม้ล้มตามทิศที่ฟัน/หินแตกเป็นก้อน/คริสตัลแตกเป็นเศษ)
	-- เซิร์ฟเวอร์แค่ซ่อนของจริง (หน่วงนิดให้เครื่องผู้เล่นโคลนทันก่อน)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("NodeBreak", { Node = node, Kind = kind, Position = node:GetPivot().Position, From = from, Yield = node:GetAttribute("Yield") })
	task.delay(0.3, function()
		if node:GetAttribute("Depleted") then
			setVisible(node, false)
		end
	end)
	if kind == "Tree" then
		-- ต้นไม้: งอกใหม่ตามจำนวนวันในเกม (นับวันที่ข้ามด้วยเตียง/ศาลเจ้าด้วย) ไม่ใช่วินาที
		self.felled[node] = self.ctx.State:GetAttribute("Night") or 1
		return
	end
	local regrow = node:GetAttribute("Regrow") or 240
	task.delay(regrow, function()
		self:Regrow(node)
	end)
end

function ResourceService:Regrow(node)
	self.felled[node] = nil
	if node.Parent then
		node:SetAttribute("HP", node:GetAttribute("MaxHP"))
		node:SetAttribute("Depleted", false)
		setVisible(node, true)
	end
end

-- วันเปลี่ยน: ต้นที่ล้มครบ Config.TreeRegrowDays คืน -> ทยอยงอกคืน (คืนละ TreeRegrowChance ต่อต้น ไม่ขึ้นพร้อมกันทั้งป่า)
-- เริ่มรอบใหม่ (วันนับถอยกลับ) งอกคืนทั้งหมด
function ResourceService:CheckTrees()
	local night = self.ctx.State:GetAttribute("Night") or 1
	for node, at in pairs(self.felled) do
		if night < at or (night >= at + Config.TreeRegrowDays and math.random() < Config.TreeRegrowChance) then
			self:Regrow(node)
		end
	end
end

-- ตี node: power = แรงของเครื่องมือ (Chop/Mine) · พุ่มเบอร์รี่ = ฟันไม่พัง ไม่ได้อะไร
function ResourceService:Hit(player, node, tool)
	local kind = node:GetAttribute("Node")
	local surv = self.ctx.Services.SurvivalService
	if kind == "Bush" then
		return false -- พุ่มเบอร์รี่: ฟันไม่ได้อะไร (กินที่พุ่มอย่างเดียว)
	end
	local power
	if kind == "Tree" then
		power = (tool.Chop or 0) * surv:Perk(player, "ChopMult", 1)
	else
		power = (tool.Mine or 0) * surv:Perk(player, "MineMult", 1)
	end
	if power <= 0 then
		self.ctx.Notify(player, kind == "Tree" and "You need an axe to chop wood" or "You need an axe/pickaxe to break this", "Error")
		return false
	end
	if kind == "Tree" or kind == "Rock" then
		power = math.max(power, 1) -- เครื่องมืออ่อนสุดก็ตีครบ 6/10 ครั้ง ไม่ลากยาวกว่านั้น · เครื่องมือแรงกว่า = เร็วกว่า
	end
	local hp = node:GetAttribute("HP") or 1
	local dealt = math.min(hp, power)
	hp -= dealt
	node:SetAttribute("HP", hp)
	local yield = node:GetAttribute("Yield")
	local per = node:GetAttribute("YieldPerHP") or 1
	-- เก็บเศษไว้ (ทศนิยม) ต่อ node ต่อคน
	local key = "Frac_" .. player.UserId
	local amount = dealt * per * Config.LootMult + (node:GetAttribute(key) or 0)
	local whole = hp <= 0 and math.floor(amount + 0.5) or math.floor(amount) -- ทุบจบ = ปัดเศษที่ค้าง
	node:SetAttribute(key, hp <= 0 and 0 or amount - whole)
	local drops = self.ctx.Services.DropService
	local nodePos = node:GetPivot().Position
	local toward = player.Character and player.Character:GetPivot().Position or nodePos
	-- ของต้องตกนอกตัว node ฝั่งที่ผู้เล่นยืน (ต้นใหญ่/หินก้อนโต เคยตกเข้าไปในลำต้น/ในหิน)
	local dir = (toward - nodePos) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.xAxis
	local radius = self:Footprint(node)
	local dropPos = nodePos + dir * (radius + 2)
	local dropOpts = { Dir = dir, Avoid = node, Spread = 2 }
	if whole > 0 then
		drops:Spawn(yield, whole, dropPos, dropOpts)
	end
	local quests = self.ctx.Services.QuestService
	if quests and whole > 0 then
		quests:Progress(player, "Gather", whole, yield)
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("NodeHit", { Position = node:GetPivot().Position, Kind = kind, Node = node })
	if hp <= 0 then
		local bonus = node:GetAttribute("Bonus")
		if bonus then
			drops:SpawnLoot(bonus, 2, dropPos, dropOpts)
			if quests then
				quests:Progress(player, "Gather", 2, bonus)
			end
		end
		if kind == "Tree" and yield == "Wood" then
			drops:Spawn("Wood", 1, dropPos, dropOpts)
			if quests then
				quests:Progress(player, "Gather", 1, "Wood")
			end
		end
		local pos = player.Character and player.Character:GetPivot().Position or node:GetPivot().Position
		self:Fell(node, pos)
	end
	return true
end

---------------------------------------------------------------- พุ่มเบอร์รี่
-- พุ่มไม่มีวันพัง: พุ่มละ 6-7 ลูก (ลูกจริงในโมเดล) เก็บ/กินทีละลูก -> ลูกนั้นหายจากพุ่ม
--   เก็บหมดพุ่มแล้ว -> รอ BERRY_COOLDOWN วัน (นับจาก State.Night) ถึงงอกคืนเต็มพุ่มทีเดียว
--   [E] กินเบอร์รี่ที่พุ่ม · [F] เก็บใส่กระสอบ (เต็ม = หล่นข้างพุ่ม)
local BERRY_MIN, BERRY_MAX = 6, 7
local BERRY_COOLDOWN = 4 -- วัน
local bushes = {} -- [node] = { Berries = {part}, Max, Count, EmptyNight, Pick, Eat }

-- ลูกเบอร์รี่ = ชิ้นเล็กในโมเดลพุ่ม (เล็กกว่า 30% ของใบพุ่ม) · โมเดลที่ไม่มีลูกแยก -> ปั้นลูกกลมวางรอบพุ่ม
local function berryParts(node)
	local parts, biggest = {}, 0
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			biggest = math.max(biggest, d.Size.Magnitude)
		end
	end
	local out = {}
	for _, d in ipairs(parts) do
		if d.Size.Magnitude < biggest * 0.3 then
			table.insert(out, d)
		end
	end
	if #out >= 3 then
		return out
	end
	for _, d in ipairs(parts) do
		if d.Name == "Berries" then
			d.Transparency = 1
		end
	end
	local cf, size = node:GetBoundingBox()
	local rng = Random.new(math.floor(cf.X * 7 + cf.Z * 13))
	out = {}
	for i = 1, 6 do
		local ang = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local h = rng:NextNumber(-0.15, 0.3)
		local r = math.sqrt(math.max(0.05, 1 - (h * 2) ^ 2)) * 0.48
		local b = Instance.new("Part")
		b.Name = "Berry"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * math.clamp(size.Y * 0.14, 0.5, 1.1)
		b.Color = Color3.fromRGB(214, 40, 90)
		b.Material = Enum.Material.SmoothPlastic
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
		b.CFrame = CFrame.new(cf.Position + Vector3.new(math.cos(ang) * size.X * r, h * size.Y, math.sin(ang) * size.Z * r))
		b.Parent = node
		table.insert(out, b)
	end
	return out
end

local function showBerries(st)
	-- ลูกในโมเดลน้อยกว่าจำนวนเก็บได้ -> โชว์ตามสัดส่วน
	local shown = math.ceil(st.Count * #st.Berries / st.Max)
	for i, b in ipairs(st.Berries) do
		if b:GetAttribute("OrigT") == nil then
			b:SetAttribute("OrigT", b.Transparency)
		end
		b.Transparency = i <= shown and b:GetAttribute("OrigT") or 1
	end
	local max = st.Max
	st.Node:SetAttribute("Berries", st.Count)
	local txt = string.format("Berry Bush %d/%d", st.Count, max)
	st.Eat.ObjectText = txt
	st.Eat.Enabled = st.Count > 0
	st.Pick.ObjectText = txt
	st.Pick.Enabled = st.Count > 0
end

-- เอาลูกเบอร์รี่ 1 ลูกออกจากพุ่ม: how = "Sack" (เก็บใส่กระสอบ) / "Eat" (กินเลย) / "Drop" (หล่นพื้น)
function ResourceService:PickBerry(player, node, how)
	local st = bushes[node]
	if not st or st.Count <= 0 then
		return false
	end
	local inv = self.ctx.Services.InventoryService
	local surv = self.ctx.Services.SurvivalService
	st.Count -= 1
	if st.Count <= 0 then
		st.EmptyNight = self.ctx.State:GetAttribute("Night") or 1 -- เริ่มนับคูลดาวน์ตอนพุ่มหมด
	end
	showBerries(st)
	local pos = node:GetPivot().Position
	if how == "Eat" then
		inv:Add(player, "Berries", 1, true)
		surv:UseItem(player, "Berries")
	elseif how == "Sack" and inv:Space(player) >= 1 then
		inv:AddToSack(player, "Berries", 1)
	else
		local toward = player.Character and player.Character:GetPivot().Position or pos
		local dir = (toward - pos) * Vector3.new(1, 0, 1)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.xAxis
		self.ctx.Services.DropService:Spawn("Berries", 1, pos + dir * (self:Footprint(node) + 2), { Dir = dir, Avoid = node, Spread = 1 })
	end
	if self.ctx.Services.QuestService then
		self.ctx.Services.QuestService:Progress(player, "Gather", 1, "Berries")
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("NodeHit", { Position = pos, Kind = "Bush", Node = node })
	return true
end

function ResourceService:SetupBush(node)
	if node:GetAttribute("Node") ~= "Bush" or bushes[node] then
		return
	end
	local world = Workspace:FindFirstChild("World")
	if not (world and node:IsDescendantOf(world)) then
		return
	end
	local part = node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local function prompt(name, action, key, offset, how)
		local p = Instance.new("ProximityPrompt")
		p.Name = name
		p.ObjectText = "Berry Bush"
		p.ActionText = action
		p.KeyboardKeyCode = key
		p.HoldDuration = 0.25
		p.MaxActivationDistance = 14 -- พุ่มใหญ่ขึ้น
		p.RequiresLineOfSight = false
		p.UIOffset = offset
		p.Parent = part
		p.Triggered:Connect(function(player)
			if not player:GetAttribute("InRun") or self.ctx.Services.SurvivalService:IsIncapacitated(player) then
				return
			end
			self:PickBerry(player, node, how)
		end)
		return p
	end
	local berries = berryParts(node)
	local cf = node:GetPivot()
	local max = Random.new(math.floor(cf.X * 7 + cf.Z * 13)):NextInteger(BERRY_MIN, BERRY_MAX)
	-- ลูกในโมเดลเกิน -> ซ่อนลูกส่วนเกินถาวร
	for i = #berries, max + 1, -1 do
		berries[i].Transparency = 1
		table.remove(berries, i)
	end
	local st = { Node = node, Berries = berries, Max = max, Count = max }
	st.Eat = prompt("BushEat", "Eat Berries", Enum.KeyCode.E, Vector2.new(0, -40), "Eat")
	st.Pick = prompt("BushPick", "Put in Sack", Enum.KeyCode.F, Vector2.new(0, 40), "Sack")
	bushes[node] = st
	node:SetAttribute("Depleted", false)
	node:SetAttribute("MaxBerries", max)
	showBerries(st)
	node.Destroying:Connect(function()
		bushes[node] = nil
	end)
end

function ResourceService:Start(ctx)
	self.ctx.State:GetAttributeChangedSignal("Night"):Connect(function()
		self:CheckTrees()
		-- พุ่มที่หมด: ครบ BERRY_COOLDOWN วัน -> งอกคืนเต็มพุ่ม · คืนนับย้อน (เริ่มรอบใหม่) = เต็มทันที
		local night = self.ctx.State:GetAttribute("Night") or 1
		for _, st in pairs(bushes) do
			if st.EmptyNight and (night - st.EmptyNight >= BERRY_COOLDOWN or night < st.EmptyNight) then
				st.EmptyNight = nil
				st.Count = st.Max
				showBerries(st)
			end
		end
	end)
	CollectionService:GetInstanceAddedSignal("ResourceNode"):Connect(function(node)
		task.defer(self.SetupBush, self, node)
	end)
	for _, node in ipairs(CollectionService:GetTagged("ResourceNode")) do
		self:SetupBush(node)
	end
end

return ResourceService
