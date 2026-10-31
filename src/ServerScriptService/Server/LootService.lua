--[[
	LootService — หีบในซากปรักหักพัง (เปิดได้รอบละครั้ง) + อันตรายในโลก (ลาวา/ปล่องไฟ)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LootService = {}

local LOOT = {
	Earth = { { "Wood", 3, 6 }, { "Iron", 1, 3 }, { "TerraCore", 0, 2 }, { "Bandage", 0, 1 }, { "Berries", 2, 4 } },
	Water = { { "Fiber", 3, 5 }, { "Iron", 1, 2 }, { "TidePearl", 0, 2 }, { "Bandage", 0, 1 }, { "CookedMeat", 1, 2 } },
	Air = { { "Stone", 3, 5 }, { "Iron", 1, 3 }, { "GaleFeather", 0, 2 }, { "Bandage", 0, 1 }, { "Pelt", 1, 2 } },
	Fire = { { "Coal", 2, 4 }, { "Iron", 1, 3 }, { "EmberShard", 0, 2 }, { "Bandage", 0, 1 }, { "Stone", 2, 4 } },
}

-- กล่องเสบียงกระจายทั่วแมพ: อาวุธ/เครื่องมือทั่วไป 1 ชิ้น (ไม่มีของธาตุ) + ของใช้อีก 2-3 อย่าง
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
		self.ctx.Services.DataService:AddDiamonds(player, rng:NextInteger(1, 3), "หีบสมบัติ")
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
	prompt.ActionText = "เปิดหีบ"
	prompt.ObjectText = "หีบโบราณ"
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
	local drops = self.ctx.Services.DropService
	local pos = crate:GetPivot().Position + Vector3.new(0, 2, 0)
	local got = {}
	local tool = weighted(rng, CRATE_TOOLS)
	drops:Spawn(tool, 1, pos, { Spread = 3 })
	got[tool] = 1
	local pool = table.clone(CRATE_EXTRA)
	for _ = 1, rng:NextInteger(2, 3) do
		local e = table.remove(pool, rng:NextInteger(1, #pool))
		local n = rng:NextInteger(e[2], e[3])
		drops:Spawn(e[1], n, pos, { Spread = 3 })
		got[e[1]] = n
	end
	if rng:NextNumber() < 0.08 then
		drops:Spawn("Medkit", 1, pos, { Spread = 3 })
		got.Medkit = 1
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
	local count = math.clamp(math.floor(60 * (size / 6144) ^ 2), 15, 60)
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
			if ok and (p - Vector3.new(x, p.Y, z)).Magnitude < size * 0.06 then
				ok = false
			end
		end
		local hit = ok and Workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -3000, 0), rp)
		-- ต้องตกบนพื้นดินโล่ง (ไม่ใช่น้ำ/บนหิน/ในซาก) และไม่ชันเกิน
		if hit and hit.Instance == Workspace.Terrain and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.85 then
			local cf = CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local crate = PropBuilder.StoreModel("Crate", cf, folder)
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
			local body = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true)
			-- แสงเรืองอ่อนๆ ให้มองเห็นจากไกล (โดยเฉพาะกลางคืน)
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 214, 140)
			glow.Range = 10
			glow.Brightness = 0.8
			glow.Parent = body
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "เปิดกล่อง"
			prompt.ObjectText = "กล่องเสบียง"
			prompt.HoldDuration = 0.6
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
		warn("[AS] วางกล่องเสบียงไม่ได้:", err)
	end
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			pcall(self.HazardTick, self, dt)
		end
	end)
end

return LootService
