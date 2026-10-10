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
local DeathClient = require(Client:WaitForChild("DeathClient"))
local ClientSettings = require(Client:WaitForChild("ClientSettings"))
local SoundController = require(Client:WaitForChild("SoundController"))
local SettingsUI = require(Client:WaitForChild("SettingsUI"))
local Tutorial = require(Client:WaitForChild("Tutorial"))
local MobileControls = require(Client:WaitForChild("MobileControls"))

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
safe("PadUI", require(Client:WaitForChild("PadUI")).Init)
safe("Death", DeathClient.Init)
Cinematics.Death = DeathClient
safe("Sound", SoundController.Init, state)
SoundController.Biome = function()
	return AtmosphereController.Biome
end
safe("Tutorial", Tutorial.Init, UIKit.Screen("Tutorial", 60))
safe("Settings", SettingsUI.Init, UIKit.Screen("Settings", 45), { Tutorial = Tutorial.Open, GearParent = HUD.RightCard })
Menus.OnSettings = SettingsUI.Toggle
safe("Mobile", MobileControls.Init, { Menus = Menus, Map = MapUI })

-- การตั้งค่า -> ระบบต่างๆ
local function applySetting(key, value)
	if key == "Shake" then
		CombatClient.ShakeEnabled = value ~= false
	elseif key == "Hints" then
		HUD.ShowHints = value ~= false
	elseif key == "Graphics" or key == "Quality" then
		AmbientFX.RateMult = ClientSettings.ParticleMult or 1
	end
end
ClientSettings.OnChanged(applySetting)
for _, k in ipairs({ "Shake", "Hints" }) do
	applySetting(k, ClientSettings.Get(k))
end
pcall(ClientSettings.ApplyGraphics)

-- เสียง: ปุ่ม UI / หน้าต่างเด้ง / แจ้งเตือน / เก็บของ
UIKit.OnAnyClick = function()
	SoundController.Play("UiClick")
end
UIKit.OnPop = function()
	SoundController.Play("UiOpen")
end
do
	local notify, pickup = HUD.Notify, HUD.Pickup
	HUD.Notify = function(text, kind)
		notify(text, kind)
		if kind == "Reward" then
			SoundController.Play("Reward")
		elseif kind ~= "Info" then
			SoundController.Play("Notify", (kind == "Danger" or kind == "Error") and 0.75 or 1)
		end
	end
	HUD.Pickup = function(id, n)
		pickup(id, n)
		SoundController.Play("Pickup", 0.9 + math.random() * 0.25)
	end
end

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
-- กันตกทะลุโลก (ฝั่งเครื่องผู้เล่น ซึ่งรู้ว่าพื้นโหลดถึงหรือยัง):
--  ตอนเกิด/วาร์ป: ตรึงตัวจนกว่าจะมีพื้นใต้เท้า · ถ้าร่วงลงต่ำผิดปกติ: ดึงกลับแคมป์แล้วตรึงรอพื้นโหลด
do
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local player = Players.LocalPlayer
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local function groundBelow(root)
		rp.FilterDescendantsInstances = { player.Character }
		return Workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rp) ~= nil
	end
	local function holdUntilGround(root)
		root.Anchored = true
		local t0 = os.clock()
		while root.Parent and os.clock() - t0 < 12 and not groundBelow(root) do
			task.wait(0.2)
		end
		task.wait(0.2)
		if root.Parent then
			root.Anchored = false
		end
	end
	local function watch(char)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		task.wait(0.1)
		if not groundBelow(root) then
			holdUntilGround(root)
		end
		while char.Parent and root.Parent do
			task.wait(0.25)
			if player:GetAttribute("InRun") and root.Position.Y < Config.WaterLevel - 120 then
				local state = ReplicatedStorage:FindFirstChild("GameState")
				local camp = state and state:GetAttribute("CampPos")
				if camp then
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = CFrame.new(camp + Vector3.new(math.random(-8, 8), 6, math.random(-8, 8)))
					pcall(function()
						player:RequestStreamAroundAsync(camp, 10)
					end)
					holdUntilGround(root)
				end
			end
		end
	end
	player.CharacterAdded:Connect(function(c)
		task.spawn(watch, c)
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		local c = player.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			task.delay(0.3, function()
				if root.Parent and not groundBelow(root) then
					holdUntilGround(root)
				end
			end)
		end
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

local holdingSack, refreshPickupPrompts
-- ถือกระสอบ: คลิกของบนพื้น/กองไฟ/เครื่องบด + E เก็บ + F ทิ้ง (แบบ 99 Nights · ไม่มีหน้ารายการของ)
do
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	-- ปุ่ม "เก็บใส่กระสอบ" บนของที่ตก: ขึ้นเฉพาะตอนถือกระสอบ (เปิด/ปิดเฉพาะเครื่องนี้)
	holdingSack = false
	function refreshPickupPrompts()
		local drops = Workspace:FindFirstChild("Drops")
		for _, d in ipairs(drops and drops:GetDescendants() or {}) do
			if d:IsA("ProximityPrompt") and d.Name == "Pickup" then
				d.Enabled = holdingSack
			end
		end
	end
	task.spawn(function()
		local drops = Workspace:WaitForChild("Drops", 60)
		if drops then
			drops.DescendantAdded:Connect(function(d)
				if d:IsA("ProximityPrompt") and d.Name == "Pickup" then
					d.Enabled = holdingSack
				end
			end)
			refreshPickupPrompts()
		end
	end)
	-- F = เอาของออกจากกระสอบ (ชิ้นล่าสุด) · ยืนใกล้กองไฟ = โยนเข้ากองไฟ
	game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
		if gp or input.KeyCode ~= Enum.KeyCode.F then
			return
		end
		if holdingSack and player:GetAttribute("InRun") then
			Remotes.Get("DropItem"):FireServer(nil, 1)
		end
	end)
	local function hookTool(tool)
		if not (tool:IsA("Tool") and tool:GetAttribute("Kind") == "Sack") or tool:GetAttribute("SackHooked") then
			return
		end
		tool:SetAttribute("SackHooked", true)
		tool.Equipped:Connect(function()
			holdingSack = true
			refreshPickupPrompts()
		end)
		tool.Unequipped:Connect(function()
			holdingSack = false
			refreshPickupPrompts()
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
			-- คลิกเครื่องย่อย = โยนวัตถุดิบลงช่องบด
			local bench = camp and camp:FindFirstChild("Workbench")
			local hopper = bench and bench:FindFirstChild("Hopper")
			local crafterModel = bench and bench:FindFirstChild("CrafterModel")
			if target and hopper and (target == hopper or (crafterModel and target:IsDescendantOf(crafterModel) and (mouse.Hit.Position - hopper.Position).Magnitude < 12)) then
				Remotes.Get("ThrowGrind"):FireServer()
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
	pcall(SoundController.OnCinematic, kind, data or {})
end)
Remotes.Get("HitFx").OnClientEvent:Connect(function(kind, data)
	CombatClient.HandleFx(kind, data or {}, HUD)
	if kind == "Eat" or kind == "Heal" then
		SoundController.Play(kind)
	end
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
			ClientSettings.Load(profile.Settings)
			-- ครั้งแรก: หน้าสอนเล่นแบบช่องการ์ตูน
			if not profile.TutorialSeen and not ReplicatedStorage:FindFirstChild("ASAutoTest") then
				task.wait(0.6)
				Tutorial.Open()
			end
		end

	end)
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
