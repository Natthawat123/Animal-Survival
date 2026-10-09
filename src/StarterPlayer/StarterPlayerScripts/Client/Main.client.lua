--[[
	ANIMAL SURVIVAL — client bootstrap
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local state = ReplicatedStorage:WaitForChild("GameState")

local Client = script.Parent
local UIKit = require(Client:WaitForChild("UIKit"))
local HUD = require(Client:WaitForChild("HUD"))
local Cinematics = require(Client:WaitForChild("Cinematics"))
local AtmosphereController = require(Client:WaitForChild("AtmosphereController"))
local AmbientFX = require(Client:WaitForChild("AmbientFX"))
local AnimalAnimator = require(Client:WaitForChild("AnimalAnimator"))
local CombatClient = require(Client:WaitForChild("CombatClient"))
local Menus = require(Client:WaitForChild("Menus"))
local MapUI = require(Client:WaitForChild("MapUI"))
local SkinStreamer = require(Client:WaitForChild("SkinStreamer"))

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[AS] client init " .. name .. ":", err)
	end
end

safe("Cinematics", Cinematics.Init, state)
safe("HUD", HUD.Init, state)
safe("Atmosphere", AtmosphereController.Init, state)
safe("AmbientFX", AmbientFX.Init, state, AtmosphereController)
safe("Animator", AnimalAnimator.Init)
safe("Skins", SkinStreamer.Init)
safe("Combat", CombatClient.Init, state, HUD)
safe("Menus", Menus.Init, state, HUD)
safe("Map", MapUI.Init, state, HUD, AtmosphereController)
safe("Dev", require(script.Parent:WaitForChild("DevPanel")).Init)

Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
	HUD.Notify(text, kind)
end)
Remotes.Get("Inventory").OnClientEvent:Connect(function(data)
	local bag, camp = data.Bag or {}, data.Camp or {}
	local merged = {}
	for id, n in pairs(camp) do
		merged[id] = n
	end
	for id, n in pairs(bag) do
		merged[id] = (merged[id] or 0) + n
	end
	HUD.SetInventory(merged)
	HUD.SetSack(data.Used or 0, data.Cap or 0)
	Menus.SetInventory(merged, bag, camp, data.Used, data.Cap)
end)
-- ถือกระสอบ: เปิดหน้ากระสอบ + คลิกของบนพื้นเพื่อเก็บ (แบบ 99 Nights)
do
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local function hookTool(tool)
		if not (tool:IsA("Tool") and tool:GetAttribute("Kind") == "Sack") or tool:GetAttribute("SackHooked") then
			return
		end
		tool:SetAttribute("SackHooked", true)
		tool.Equipped:Connect(function()
			Menus.ToggleBag(true)
		end)
		tool.Unequipped:Connect(function()
			Menus.ToggleBag(false)
		end)
		tool.Activated:Connect(function()
			local target = mouse.Target
			-- คลิกกองไฟ = โยนไม้/ถ่าน/เนื้อดิบจากกระสอบเข้าไป
			local camp = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Sites") and Workspace.World.Sites:FindFirstChild("Camp")
			local fireModel = camp and camp:FindFirstChild("Campfire")
			if target and fireModel and (target:IsDescendantOf(fireModel) or (camp:FindFirstChild("CampfireRing") and target:IsDescendantOf(camp.CampfireRing))
				or (fireModel.PrimaryPart and (mouse.Hit.Position - fireModel.PrimaryPart.Position).Magnitude < 6)) then
				Remotes.Get("ThrowFuel"):FireServer()
				return
			end
			local drops = Workspace:FindFirstChild("Drops")
			while target and drops and target.Parent ~= drops do
				target = target.Parent
			end
			if target and drops and target:IsA("Model") then
				Remotes.Get("PickupDrop"):FireServer(target)
			end
		end)
	end
	local function hookContainer(c)
		for _, t in ipairs(c:GetChildren()) do
			hookTool(t)
		end
		c.ChildAdded:Connect(hookTool)
	end
	hookContainer(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(function(char)
		hookContainer(char)
		hookContainer(player:WaitForChild("Backpack"))
	end)
	if player.Character then
		hookContainer(player.Character)
	end
end

Remotes.Get("Cinematic").OnClientEvent:Connect(function(kind, data)
	local ok, err = pcall(Cinematics.Handle, kind, data or {}, Menus, CombatClient)
	if not ok then
		warn("[AS] cinematic", kind, err)
	end
end)
Remotes.Get("HitFx").OnClientEvent:Connect(function(kind, data)
	CombatClient.HandleFx(kind, data or {}, HUD)
end)
Remotes.Get("Profile").OnClientEvent:Connect(function(profile)
	Menus.SetProfile(profile)
end)

-- หลังโหลดเสร็จ: เปิดหน้าเลือกคลาสครั้งแรก
Cinematics.OnLoaded = function()
	task.spawn(function()
		local ok, profile = pcall(function()
			return Remotes.Get("GetProfile"):InvokeServer()
		end)
		if ok and profile then
			Menus.SetProfile(profile)
		end
		if not ReplicatedStorage:FindFirstChild("ASAutoTest") then
			Menus.OpenClasses()
		end
	end)
end
if state:GetAttribute("Ready") and Players.LocalPlayer.Character then
	Cinematics.OnLoaded()
end

-- กันตกทะลุโลก: ล็อบบี้อยู่ไกลจากแมพ (StreamingEnabled) -> ตรึงตัวไว้จนพื้นใต้เท้าโหลดมาถึงเครื่องจริง
local function holdUntilGround(char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.15) -- รอ server ย้ายตัวไปจุดเกิดก่อน
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local held = false
	local t0 = os.clock()
	while char.Parent and os.clock() - t0 < 15 do
		if workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params) then
			break
		end
		held = true
		root.Anchored = true
		task.wait(0.1)
	end
	if held and root.Parent then
		root.Anchored = false
	end
end
Players.LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(holdUntilGround, char)
end)

local _ = UIKit
print("[AS] client ready")
