--[[
	LootService — หีบในซากปรักหักพัง (เปิดได้รอบละครั้ง) + อันตรายในโลก (ลาวา/ปล่องไฟ)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LootService = {}

local LOOT = {
	Earth = { { "Wood", 6, 12 }, { "Iron", 2, 5 }, { "TerraCore", 1, 3 }, { "Bandage", 1, 2 }, { "Berries", 3, 6 } },
	Water = { { "Fiber", 4, 8 }, { "Iron", 1, 3 }, { "TidePearl", 1, 3 }, { "Bandage", 1, 2 }, { "CookedMeat", 2, 3 } },
	Air = { { "Stone", 4, 8 }, { "Iron", 3, 6 }, { "GaleFeather", 2, 4 }, { "Medkit", 0, 1 }, { "Pelt", 1, 3 } },
	Fire = { { "Coal", 3, 7 }, { "Iron", 2, 5 }, { "EmberShard", 1, 3 }, { "Bandage", 1, 2 }, { "Stone", 3, 6 } },
}

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
	local inv = self.ctx.Services.InventoryService
	local rng = Random.new()
	local got = {}
	for _, entry in ipairs(LOOT[el]) do
		local n = rng:NextInteger(entry[2], entry[3])
		if n > 0 then
			inv:Add(player, entry[1], n, true)
			got[entry[1]] = n
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

function LootService:Reset()
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
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			pcall(self.HazardTick, self, dt)
		end
	end)
end

return LootService
