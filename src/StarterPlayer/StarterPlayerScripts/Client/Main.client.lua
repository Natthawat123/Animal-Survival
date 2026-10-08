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

Remotes.Get("Notify").OnClientEvent:Connect(function(text, kind)
	HUD.Notify(text, kind)
end)
Remotes.Get("Inventory").OnClientEvent:Connect(function(inv)
	HUD.SetInventory(inv)
	Menus.SetInventory(inv)
end)
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
