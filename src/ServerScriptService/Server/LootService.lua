--[[
	LootService — หีบในซากปรักหักพัง (เปิดได้รอบละครั้ง) + อันตรายในโลก (ลาวา/ปล่องไฟ)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local LootService = {}

local LOOT = {
	Earth = { { "Wood", 3, 6 }, { "Iron", 1, 3 }, { "TerraCore", 0, 2 }, { "Bandage", 0, 1 }, { "Berries", 2, 4 } },
	Water = { { "Fiber", 3, 5 }, { "Iron", 1, 2 }, { "TidePearl", 0, 2 }, { "Bandage", 0, 1 }, { "CookedMeat", 1, 2 } },
	Air = { { "Stone", 3, 5 }, { "Iron", 1, 3 }, { "GaleFeather", 0, 2 }, { "Bandage", 0, 1 }, { "Pelt", 1, 2 } },
	Fire = { { "Coal", 2, 4 }, { "Iron", 1, 3 }, { "EmberShard", 0, 2 }, { "Bandage", 0, 1 }, { "Stone", 2, 4 } },
}

-- กล่อง 3 ระดับ (โมเดล Props/Chest1-3 · ไม่มี = กล่องไม้เดิม) กระจายทั่วแมพ Config.CrateCount ใบ
--   ระดับ 1 (ธรรมดา) / 2 (หายาก) / 3 (ตำนาน) : สุ่มตามน้ำหนัก Config.CrateTierWeight · ระดับสูง = อาวุธดีขึ้น ของมากขึ้น
local TIER_TOOLS = {
	{ { "StoneAxe", 20 }, { "Spear", 18 }, { "Dagger", 18 }, { "SpikedClub", 16 }, { "Pickaxe", 12 }, { "Torch", 10 }, { "Bow", 6 } },
	{ { "IronSword", 22 }, { "Mace", 20 }, { "IronAxe", 18 }, { "Bow", 14 }, { "Crossbow", 8 }, { "GoodSack", 8 }, { "Katana", 5 } },
	{ { "Katana", 20 }, { "BattleAxe", 20 }, { "Crossbow", 18 }, { "WarHammer", 14 }, { "Scythe", 14 }, { "GiantSack", 6 } },
}
local TIER_EXTRA = {
	{ count = { 2, 3 }, pool = { { "Bandage", 1, 1 }, { "CookedMeat", 1, 2 }, { "Berries", 2, 4 }, { "Coal", 1, 3 }, { "Wood", 3, 5 }, { "Fiber", 2, 4 }, { "Pelt", 1, 2 } } },
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
	{ "Coal", 1, 3 }, { "Wood", 3, 5 }, { "Fiber", 2, 4 }, { "Pelt", 1, 2 },
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

function LootService:Open(chest, player)
	if chest:GetAttribute("Opened") then
		return
	end
	chest:SetAttribute("Opened", true)
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
	local lid = chest:FindFirstChild("Lid")
	if lid then
		TweenService:Create(lid, TweenInfo.new(0.6, Enum.EasingStyle.Back), { CFrame = lid.CFrame * CFrame.new(0, 0.6, 1.2) * CFrame.Angles(math.rad(-70), 0, 0) }):Play()
	end
	local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = false
	end
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
	if crate:GetAttribute("Opened") then
		return
	end
	crate:SetAttribute("Opened", true)
	local rng = Random.new()
	local tier = math.clamp(crate:GetAttribute("Tier") or 1, 1, 3)
	local pos = crate:GetPivot().Position + Vector3.new(0, 2, 0)
	local got = self:GiveTierLoot(tier, pos, rng)
	if tier >= 2 then
		self.ctx.Services.DataService:AddDiamonds(player, rng:NextInteger(tier == 3 and 3 or 1, tier == 3 and 6 or 2), TIER_NAME[tier])
	end
	self.ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = pos, Chest = true })
	-- กล่องเปิดแล้ว: จางหายไป (เริ่มรอบใหม่ค่อยกลับมา)
	for _, d in ipairs(crate:GetDescendants()) do
		if d:IsA("BasePart") then
			d:SetAttribute("BaseTransparency", d:GetAttribute("BaseTransparency") or d.Transparency)
			if d:GetAttribute("BaseCollide") == nil then
				d:SetAttribute("BaseCollide", d.CanCollide)
			end
			TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			d.CanCollide = false
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
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
	local weights = Config.CrateTierWeight or { 24, 12, 4 }
	local rng = Random.new((self.ctx.State:GetAttribute("Seed") or 1) + 777)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { Workspace.Terrain, world }
	local placed = {}
	local tries = 0
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
		if hit and hit.Instance == Workspace.Terrain and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.85 then
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
			local crate = PropBuilder.Imported("Chest" .. tier, cf, ({ 3.4, 3.8, 4.4 })[tier], folder, true)
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
			glow.Range = 8 + tier * 3
			glow.Brightness = 0.6 + tier * 0.3
			glow.Parent = body
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = TIER_NAME[tier]
			prompt.HoldDuration = 0.4 + tier * 0.3
			prompt.MaxActivationDistance = 10
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
end

function LootService:Reset()
	for _, crate in ipairs(self.crates and self.crates:GetChildren() or {}) do
		crate:SetAttribute("Opened", false)
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
		chest:SetAttribute("Opened", false)
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
				surv:Damage(p, 14 * dt, "Lava", { Burn = 5 })
			end
			for _, v in ipairs(vents) do
				if (v:GetPivot().Position - r.Position).Magnitude < 6 then
					surv:Damage(p, 10 * dt, "Lava", { Burn = 4 })
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
