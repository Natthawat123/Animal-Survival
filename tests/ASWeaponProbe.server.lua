--[[
	ASWeaponProbe (server) — ใช้เฉพาะ build_rbxlx.py --lobbyprobe
	ให้ผู้เล่นถืออาวุธทีละชิ้น (ToolFactory) ตามคำขอจาก client -> ถ่ายภาพท่าถือ
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASLobbyProbe") then
	return
end
local ToolFactory = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ToolFactory"))
local ev = Instance.new("RemoteFunction")
ev.Name = "ProbeEquip"
ev.Parent = ReplicatedStorage
ev.OnServerInvoke = function(player, itemId)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	hum:UnequipTools()
	for _, t in ipairs(player.Backpack:GetChildren()) do
		t:Destroy()
	end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			t:Destroy()
		end
	end
	local tool = ToolFactory.Build(itemId)
	if not tool then
		return false
	end
	tool.Parent = player.Backpack
	hum:EquipTool(tool)
	local h = tool:FindFirstChild("Handle")
	local _, size = tool:GetBoundingBox()
	return true, h and tostring(h.Size) or "", tostring(size)
end

-- แกลเลอรีไอเทมจาก Creator Store (ของตก + สิ่งก่อสร้าง) ลอยเหนือล็อบบี้ ให้ client ถ่ายภาพ
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local StructureModels = require(Shared:WaitForChild("StructureModels"))
local DROPS = { "Fiber", "Bone", "Berries", "RawMeat", "CookedMeat", "Stew", "Bandage", "Wood", "Pelt",
	"TerraCore", "TidePearl", "GaleFeather", "Stone", "Iron", "Coal", "BeastHeart", "Medkit", "GoodSack", "GiantSack", "OldSack" }
local STRUCTS = { "CookPot", "SpikeTrap", "FarmPlot", "EmberTotem", "Lantern", "Bed", "TerraTotem", "TideTotem", "Ballista", "GaleTotem", "LogWall", "StoneWall", "SunBeacon" }
game:GetService("Players").PlayerAdded:Connect(function(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart")
	task.wait(3)
	local base = root.Position + Vector3.new(0, 80, 0)
	local g = Instance.new("Model")
	g.Name = "ProbeGallery"
	local floor = Instance.new("Part")
	floor.Anchored, floor.Size, floor.Color = true, Vector3.new(320, 1, 120), Color3.fromRGB(70, 74, 80)
	floor.CFrame = CFrame.new(base - Vector3.new(0, 0.5, 0))
	floor.Parent = g
	local function place(m, pos)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		m:PivotTo(CFrame.new(pos))
		m.Parent = g
	end
	for i, id in ipairs(DROPS) do
		local m = ItemModels.Clone(id, 2, { Ground = true })
		if m then
			place(m, base + Vector3.new(-100 + ((i - 1) % 10) * 3.4, 0, ((i - 1) // 10) * 4.5))
		end
	end
	for i, id in ipairs(STRUCTS) do
		local m = StructureModels.Build(id)
		if m then
			place(m, base + Vector3.new(60 + ((i - 1) % 5) * 15, 0, ((i - 1) // 5) * 20))
		end
	end
	g:SetAttribute("Base", base)
	g.Parent = workspace
end)

-- แกลเลอรีของในแมพ (PropBuilder) แถวที่ 3
game:GetService("Players").PlayerAdded:Connect(function(player)
	local PropBuilder = require(Shared:WaitForChild("PropBuilder"))
	local g = workspace:WaitForChild("ProbeGallery", 60)
	local base = g:GetAttribute("Base") + Vector3.new(0, 0, 60)
	local kinds = { "IronRock", "CoalRock", "TerraCrystal", "TideCrystal", "GaleCrystal", "EmberCrystal", "IceSpire", "ObsidianSpire", "BerryBush", "Flowers", "Coral", "Kelp", "LavaVent" }
	for i, k in ipairs(kinds) do
		local t = PropBuilder.GetTemplate(k, Random.new(1))
		if t then
			local m = t:Clone()
			m:PivotTo(CFrame.new(base + Vector3.new(-60 + (i - 1) * 10, 0, 0)))
			m.Parent = g
		end
	end
	PropBuilder.Imported("ChestLP", CFrame.new(base + Vector3.new(-60, 0, 25)), 4.6, g)
	PropBuilder.Imported("TraderNPC", CFrame.new(base + Vector3.new(-50, 0, 25)), 3.8, g)
	PropBuilder.Imported("MeteorLP", CFrame.new(base + Vector3.new(-30, 0, 25)), 13, g)
	PropBuilder.Imported("RuinsIsland", CFrame.new(base + Vector3.new(10, 0, 30)), 40, g)
	PropBuilder.Imported("IcePalace", CFrame.new(base + Vector3.new(0, 0, 160)) * CFrame.Angles(0, math.pi, 0), 140, g)
	local em = ItemModels.Clone("EmberShard", 1.5, { Ground = true })
	if em then
		for _, p in ipairs(em:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		em:PivotTo(CFrame.new(base + Vector3.new(-66, 0, 25)))
		em.Parent = g
	end
	g:SetAttribute("MapsReady", true)
end)

-- สัตว์ที่ต้องไปช่วย 4 ตัว (หันหน้าทาง -Z ทุกตัว) ให้ถ่ายจากด้านหน้า
game:GetService("Players").PlayerAdded:Connect(function()
	local AnimalModels = require(Shared:WaitForChild("AnimalModels"))
	local g = workspace:WaitForChild("ProbeGallery", 60)
	local base = g:GetAttribute("Base") + Vector3.new(-140, 0, 0)
	for i, id in ipairs({ "TerraPup", "TidePup", "GalePup", "EmberPup" }) do
		local ok, m = pcall(AnimalModels.Build, id)
		if ok and m then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			m:PivotTo(CFrame.new(base + Vector3.new((i - 2.5) * 7, 3, 0)))
			m.Parent = g
		else
			warn("[PROBE] pup", id, m)
		end
	end
	g:SetAttribute("PupsReady", true)
end)
