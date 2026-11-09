--[[
	LootService — หีบในซากปรักหักพัง (เปิดได้รอบละครั้ง) + อันตรายในโลก (ลาวา/ปล่องไฟ)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ChestLid = require(game:GetService("ReplicatedStorage").Shared.ChestLid)
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local LootService = {}

local LOOT = {
	Earth = { { "Iron", 1, 3 }, { "TerraCore", 0, 2 }, { "Bandage", 0, 1 }, { "Berries", 2, 4 } },
	Water = { { "Fiber", 3, 5 }, { "Iron", 1, 2 }, { "TidePearl", 0, 2 }, { "Bandage", 0, 1 }, { "CookedMeat", 1, 2 } },
	Air = { { "Stone", 3, 5 }, { "Iron", 1, 3 }, { "GaleFeather", 0, 2 }, { "Bandage", 0, 1 }, { "Pelt", 1, 2 } },
	Fire = { { "Coal", 2, 4 }, { "Iron", 1, 3 }, { "EmberShard", 0, 2 }, { "Bandage", 0, 1 }, { "Stone", 2, 4 } },
}

-- กล่อง 3 ระดับ (โมเดล Props/Chest1-3 · ไม่มี = กล่องไม้เดิม) กระจายทั่วแมพ Config.CrateCount ใบ
--   ระดับ 1 (ธรรมดา) / 2 (หายาก) / 3 (ตำนาน) : สุ่มตามน้ำหนัก Config.CrateTierWeight · ระดับสูง = อาวุธดีขึ้น ของมากขึ้น
local TIER_TOOLS = {
	-- น้ำหนัก = % (แต่ละระดับรวม 100)
	{ { "StoneAxe", 18 }, { "Spear", 16 }, { "Dagger", 16 }, { "SpikedClub", 14 }, { "Pickaxe", 10 }, { "Torch", 9 }, { "Bow", 6 }, { "GoodSack", 11 } },
	{ { "IronSword", 18 }, { "Mace", 18 }, { "IronAxe", 16 }, { "Bow", 12 }, { "Crossbow", 7 }, { "Katana", 6 }, { "GoodSack", 13 }, { "GiantSack", 10 } },
	{ { "Katana", 20 }, { "BattleAxe", 21 }, { "Crossbow", 19 }, { "WarHammer", 14 }, { "Scythe", 14 }, { "GiantSack", 12 } },
}
-- ของใช้ในกล่อง (ไม่มีไม้ — ไม้หาเองจากต้นไม้)
local TIER_EXTRA = {
	{ count = { 2, 3 }, pool = { { "Bandage", 1, 1 }, { "CookedMeat", 1, 2 }, { "Berries", 2, 4 }, { "Coal", 1, 3 }, { "Fiber", 2, 4 }, { "Pelt", 1, 2 } } },
	{ count = { 3, 4 }, pool = { { "Bandage", 1, 2 }, { "CookedMeat", 2, 3 }, { "Iron", 2, 4 }, { "Coal", 2, 4 }, { "Pelt", 2, 3 }, { "Bone", 2, 3 }, { "AnyEssence", 1, 1 } } },
	{ count = { 4, 5 }, pool = { { "Medkit", 1, 1 }, { "Iron", 4, 6 }, { "Coal", 3, 5 }, { "Pelt", 3, 4 }, { "AnyEssence", 1, 2 }, { "AnyEssence", 1, 2 }, { "Stew", 1, 2 } } },
}
local TIER_NAME = { "Supply Crate", "Rare Chest", "Legendary Chest" }
local TIER_LIGHT = { Color3.fromRGB(150, 255, 170), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 214, 110) }
local ESSENCES = { "TerraCore", "TidePearl", "GaleFeather", "EmberShard" }
LootService.TierTools = TIER_TOOLS

-- (เดิม) กล่องเสบียงกระจายทั่วแมพ: อาวุธ/เครื่องมือทั่วไป 1 ชิ้น (ไม่มีของธาตุ) + ของใช้อีก 2-3 อย่าง
local CRATE_TOOLS = { { "StoneAxe", 25 }, { "Spear", 22 }, { "Bow", 15 }, { "Pickaxe", 15 }, { "Torch", 13 }, { "IronAxe", 7 }, { "GoodSack", 3 } }
local CRATE_EXTRA = {
	{ "Bandage", 1, 1 }, { "CookedMeat", 1, 2 }, { "Berries", 2, 4 }, { "Iron", 1, 3 },
	{ "Coal", 1, 3 }, { "Fiber", 2, 4 }, { "Pelt", 1, 2 },
}

local function weighted(rng, list)
	local total = 0
	for _, e in ipairs(list) do
		total += e[2]
	end
	local r = rng:NextNumber() * total
	for _, e in ipairs(list) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return list[1][1]
end

function LootService:Init(ctx)
	self.ctx = ctx
	self.chests = {}
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Include
	self.rayParams.FilterDescendantsInstances = { Workspace.Terrain }
end

-- เอฟเฟกต์เปิดกล่อง (ทุกคนที่อยู่ใกล้เห็น): กล่องสั่น -> เด้ง -> แสงพุ่ง + ประกาย · tier 1-3 = ยิ่งสูงยิ่งอลัง
--   หีบที่มีฝาจริง (ChestLid): สั่น -> ฝาเด้งเปิด (เครื่องผู้เล่นเล่นแอนิเมชัน) แล้วเซิร์ฟเวอร์ตั้งฝาเปิดค้างไว้
--   only = ผู้เล่น: กล่องส่วนตัว (เปิดได้ทุกคน คนละรอบ) -> เล่นเฉพาะเครื่องคนเปิด ไม่ขยับฝาฝั่งเซิร์ฟเวอร์
function LootService:ChestFx(model, pos, tier, color, only)
	tier = math.clamp(tier or 1, 1, 3)
	local data = { Model = model, Position = pos, Tier = tier, Color = color or TIER_LIGHT[tier] }
	if only then
		self.ctx.Remotes.Get("HitFx"):FireClient(only, "ChestOpen", data)
		return
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("ChestOpen", data)
	local lid, hinge = ChestLid.Find(model)
	if lid then
		local closed = ChestLid.Closed(lid)
		task.delay(1.2, function()
			if lid.Parent and model:GetAttribute("Opened") ~= false then
				lid.CFrame = ChestLid.CFrameAt(closed, hinge, 1)
			end
		end)
	end
end

-- ปิดฝาคืน (เริ่มรอบใหม่)
function LootService.CloseLid(model)
	local lid = ChestLid.Find(model)
	if lid and typeof(lid:GetAttribute("ClosedCF")) == "CFrame" then
		lid.CFrame = lid:GetAttribute("ClosedCF")
	end
end

-- กล่องเปิดได้ทุกคน คนละ 1 ครั้งต่อรอบ: จำคนที่เปิดแล้วเป็น attribute "Opened_<UserId>" (client ซ่อนกล่องเฉพาะเครื่องคนนั้น)
local function openKey(player)
	return "Opened_" .. player.UserId
end
local function clearOpened(inst)
	for k in pairs(inst:GetAttributes()) do
		if string.sub(k, 1, 7) == "Opened_" then
			inst:SetAttribute(k, nil)
		end
	end
end

function LootService:Open(chest, player)
	local key = openKey(player)
	if chest:GetAttribute(key) or not player:GetAttribute("InRun") then
		return
	end
	chest:SetAttribute(key, true)
	local el = chest:GetAttribute("Element") or "Earth"
	local rng = Random.new()
	local got = {}
	for _, entry in ipairs(LOOT[el]) do
		local n = rng:NextInteger(entry[2], entry[3])
		if n > 0 then
			n = self.ctx.Services.DropService:SpawnLoot(entry[1], n, chest:GetPivot().Position + Vector3.new(0, 1, 0))
			got[entry[1]] = n > 0 and n or nil
		end
	end
	if rng:NextNumber() < 0.15 then
		self.ctx.Services.DataService:AddDiamonds(player, rng:NextInteger(1, 3), "Treasure Chest")
	end
	self.ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = chest:GetPivot().Position, Chest = true })
	self:ChestFx(chest, chest:GetPivot().Position, 2, nil, player)
end

function LootService:SetupChest(chest)
	local body = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Chest"
	prompt.ObjectText = "Ancient Chest"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		self:Open(chest, player)
	end)
	chest:SetAttribute("LidCF", chest.Lid.CFrame)
	table.insert(self.chests, chest)
end

---------------------------------------------------------------- กล่องเสบียง (กระจายทั่วแมพ)
function LootService:OpenCrate(crate, player)
	local key = openKey(player)
	if crate:GetAttribute(key) then
		return
	end
	crate:SetAttribute(key, true)
	local pin = self.pins and self.pins[crate]
	if pin then
		pin:SetAttribute(key, true)
	end
	local rng = Random.new()
	local tier = math.clamp(crate:GetAttribute("Tier") or 1, 1, 3)
	local pos = crate:GetPivot().Position + Vector3.new(0, 2, 0)
	local got = self:GiveTierLoot(tier, pos, rng)
	if tier >= 2 then
		self.ctx.Services.DataService:AddDiamonds(player, rng:NextInteger(tier == 3 and 3 or 1, tier == 3 and 4 or 2), TIER_NAME[tier])
	end
	self.ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = pos, Chest = true })
	-- เอฟเฟกต์ + ปิดปุ่ม + กล่องจางหาย: เฉพาะเครื่องคนเปิด (CombatClient) · คนอื่นยังเปิดกล่องนี้ได้
	self:ChestFx(crate, pos, tier, nil, player)
end

-- ของในกล่องระดับ tier (1-3) วางพื้นรอบ pos · คืน { [id] = จำนวน } (วิหารใช้ระดับ 3)
function LootService:GiveTierLoot(tier, pos, rng)
	rng = rng or Random.new()
	local drops = self.ctx.Services.DropService
	local got = {}
	local function give(id, n)
		if id == "AnyEssence" then
			id = ESSENCES[rng:NextInteger(1, #ESSENCES)]
		end
		if n > 0 then
			drops:Spawn(id, n, pos, { Spread = 3 })
			got[id] = (got[id] or 0) + n
		end
	end
	give(weighted(rng, TIER_TOOLS[tier]), 1)
	local ex = TIER_EXTRA[tier]
	local pool = table.clone(ex.pool)
	for _ = 1, rng:NextInteger(ex.count[1], ex.count[2]) do
		local e = table.remove(pool, rng:NextInteger(1, #pool))
		give(e[1], rng:NextInteger(e[2], e[3]))
	end
	if tier == 1 and rng:NextNumber() < 0.08 then
		give("Medkit", 1)
	end
	return got
end

function LootService:SpawnCrates()
	local layout = self.ctx.Layout
	local world = Workspace:FindFirstChild("World")
	if not (layout and world) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SupplyCrates"
	folder.Parent = world
	local PropBuilder = require(game:GetService("ReplicatedStorage").Shared.PropBuilder)
	local size = layout.Size or 6144
	local count = Config.CrateCount or 40
	local weights = Config.CrateTierWeight or { 18, 14, 8 }
	local rng = Random.new((self.ctx.State:GetAttribute("Seed") or 1) + 777)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Workspace.Terrain, world }
	local placed = {}
	local tries = 0
	-- ห้ามซ้อนในของ: เดิมเช็กแค่ยิงลงจากฟ้าตรงจุดเดียว -> กล่องเกิดในก้อนหิน/แท่งน้ำแข็ง/ซากที่ยื่นมาคลุม
	--   (มีปุ่ม Open แต่มองไม่เห็นกล่อง · เทส --crateprobe เจอ 3/40 ใบ) -> ต้องโล่งทั้งกล่อง + ขอบรอบ
	local clearParams = OverlapParams.new()
	clearParams.FilterType = Enum.RaycastFilterType.Include
	clearParams.FilterDescendantsInstances = { world }
	local function spotClear(p)
		for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(p + Vector3.new(0, 4.5, 0)), Vector3.new(11, 8, 11), clearParams)) do
			local s = part.Size
			-- หญ้า/เฟิร์นเล็กๆ (ทะลุได้) ไม่นับ · ของแข็งทุกชิ้น (หินแร่แยกเป็นก้อนเล็ก) + ของใหญ่ (ต้นไม้ พุ่ม ซาก) = ไม่โล่ง
			if part.Transparency < 0.9 and not part:IsDescendantOf(folder) and (part.CanCollide or math.max(s.X, s.Y, s.Z) > 3) then
				return false
			end
		end
		return true
	end
	while #placed < count and tries < count * 30 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), size * 0.42 * math.sqrt(rng:NextNumber(0.02, 1))
		local x, z = math.cos(a) * r, math.sin(a) * r
		local ok = r > 150 -- ไม่วางในแคมป์
		for _, p in ipairs(placed) do
			if ok and (p - Vector3.new(x, p.Y, z)).Magnitude < size * (tries < count * 15 and 0.06 or 0.035) then
				ok = false
			end
		end
		local hit = ok and Workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -3000, 0), rp)
		-- ต้องตกบนพื้นดินโล่ง (ไม่ใช่น้ำ/บนหิน/ในซาก) และไม่ชันเกิน
		if hit and hit.Instance == Workspace.Terrain and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.85 and spotClear(hit.Position) then
			local cf = CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			-- ระดับ: สุ่มตามน้ำหนัก (ครบจำนวนแน่นอน: ระดับ 3 = weights[3] ใบ ฯลฯ)
			local tier = 1
			do
				local left = { weights[1], weights[2], weights[3] }
				for _, c in ipairs(folder:GetChildren()) do
					local t = c:GetAttribute("Tier")
					if t then
						left[t] -= 1
					end
				end
				local total = math.max(0, left[1]) + math.max(0, left[2]) + math.max(0, left[3])
				local roll = rng:NextNumber() * math.max(total, 1)
				for t = 3, 1, -1 do
					roll -= math.max(0, left[t])
					if roll <= 0 and left[t] > 0 then
						tier = t
						break
					end
				end
			end
			local width = ({ 5.4, 6.2, 7.2 })[tier]
			local crate = PropBuilder.Imported("Chest" .. tier .. "Open", cf, width, folder, true) -- ฝาเปิดได้จริง
				or PropBuilder.Imported("Chest" .. tier, cf, width, folder, true)
			crate = crate or PropBuilder.StoreModel("Crate", cf, folder)
			if not crate then
				crate = Instance.new("Model")
				local box = Instance.new("Part")
				box.Name = "Body"
				box.Size = Vector3.new(3.6, 3.6, 3.6)
				box.CFrame = cf * CFrame.new(0, 1.8, 0)
				box.Anchored = true
				box.Color = Color3.fromRGB(150, 106, 64)
				box.Material = Enum.Material.WoodPlanks
				box.Parent = crate
				crate.PrimaryPart = box
				crate.Parent = folder
			end
			crate.Name = "SupplyCrate"
			crate:SetAttribute("Tier", tier)
			local body = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true)
			-- แสงเรืองอ่อนๆ ตามสีระดับ ให้มองเห็นจากไกล (โดยเฉพาะกลางคืน)
			local glow = Instance.new("PointLight")
			glow.Color = TIER_LIGHT[tier]
			glow.Range = 11 + tier * 4
			glow.Brightness = 0.6 + tier * 0.3
			glow.Parent = body
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = TIER_NAME[tier]
			prompt.HoldDuration = 0.4 + tier * 0.3
			prompt.MaxActivationDistance = 13
			prompt.RequiresLineOfSight = false
			prompt.Parent = body
			prompt.Triggered:Connect(function(player)
				if player:GetAttribute("InRun") and not self.ctx.Services.SurvivalService:IsIncapacitated(player) then
					self:OpenCrate(crate, player)
				end
			end)
			CollectionService:AddTag(crate, "SupplyCrate")
			table.insert(placed, hit.Position)
		end
	end
	self.crates = folder
	self:PublishPins()
end

-- หมุดกล่องบนแผนที่: ReplicatedStorage.MapPins (Vector3Value "Crate" · Tier/Opened)
--   กล่องจริงอยู่ไกล = StreamingEnabled ไม่ส่งมาให้ client -> ต้องส่งตำแหน่งแยกไว้ให้ MapUI
function LootService:PublishPins()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local old = ReplicatedStorage:FindFirstChild("MapPins")
	if old then
		old:Destroy()
	end
	local pins = Instance.new("Folder")
	pins.Name = "MapPins"
	self.pins = {}
	for _, crate in ipairs(self.crates and self.crates:GetChildren() or {}) do
		local pin = Instance.new("Vector3Value")
		pin.Name = "Crate"
		pin.Value = crate:GetPivot().Position
		pin:SetAttribute("Tier", crate:GetAttribute("Tier") or 1)
		self.pins[crate] = pin -- เปิดแล้ว = "Opened_<UserId>" (หมุดจางเฉพาะคนที่เปิด)
		pin.Parent = pins
	end
	pins.Parent = ReplicatedStorage
end

function LootService:Reset()
	for _, pin in pairs(self.pins or {}) do
		clearOpened(pin)
	end
	for _, crate in ipairs(self.crates and self.crates:GetChildren() or {}) do
		clearOpened(crate)
		LootService.CloseLid(crate)
		for _, d in ipairs(crate:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = d:GetAttribute("BaseTransparency") or d.Transparency
				local bc = d:GetAttribute("BaseCollide")
				if bc ~= nil then
					d.CanCollide = bc
				end
			elseif d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = true
			end
		end
	end
	for _, chest in ipairs(self.chests) do
		clearOpened(chest)
		LootService.CloseLid(chest)
		local lid = chest:FindFirstChild("Lid")
		if lid and chest:GetAttribute("LidCF") then
			lid.CFrame = chest:GetAttribute("LidCF")
		end
		local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Enabled = true
		end
	end
end

-- ลาวา / ปล่องไฟ
function LootService:HazardTick(dt)
	local surv = self.ctx.Services.SurvivalService
	local vents = CollectionService:GetTagged("Hazard")
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and surv:IsAlive(p) then
			local res = Workspace:Raycast(r.Position, Vector3.new(0, -7, 0), self.rayParams)
			if res and res.Material == Enum.Material.CrackedLava then
				surv:Damage(p, 2 * dt, "Lava") -- ลาวา: 2 ดาเมจ/วิ
			end
			for _, v in ipairs(vents) do
				if (v:GetPivot().Position - r.Position).Magnitude < 6 then
					surv:Damage(p, 2 * dt, "Lava")
				end
			end
		end
	end
end

function LootService:Start(ctx)
	for _, chest in ipairs(CollectionService:GetTagged("Chest")) do
		self:SetupChest(chest)
	end
	local ok, err = pcall(self.SpawnCrates, self)
	if not ok then
		warn("[AS] Couldn't place supply crate:", err)
	end
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			pcall(self.HazardTick, self, dt)
		end
	end)
end

return LootService
