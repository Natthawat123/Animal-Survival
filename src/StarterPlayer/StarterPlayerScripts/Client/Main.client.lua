--[[
	ANIMAL SURVIVAL — client bootstrap
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ปิดหลอดเลือด CoreGui ของ Roblox (เกมมีหลอดเลือดเอง) — ตัวนี้มีขอบจอแดงกะพริบทุกครั้งที่ Health ลด
--   วาดทับทุกหน้าจอรวมถึงหน้าโหลด และเด้งตอนเกมปรับ Health/MaxHealth ตอนเกิด (ไม่ได้โดนตีจริง)
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) then
			break
		end
		task.wait(0.5)
	end
end)

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
local ItemTooltip = require(Client:WaitForChild("ItemTooltip"))
local AutoTool = require(Client:WaitForChild("AutoTool"))
local TeamPing = require(Client:WaitForChild("TeamPing"))
local RejoinUI = require(Client:WaitForChild("RejoinUI"))

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[AS] client init " .. name .. ":", err)
	end
end

-- ล็อกหน้าจอ (Shift Lock ของ Roblox) ใช้ปุ่ม Ctrl แทน Shift (Shift = วิ่ง)
-- MouseLockController อ่านปุ่มจาก StringValue "BoundKeys" ข้างในตัวมัน และฟังตอนค่าเปลี่ยน
task.spawn(function()
	local pm = Client.Parent:WaitForChild("PlayerModule", 30)
	local camMod = pm and pm:WaitForChild("CameraModule", 10)
	local mlc = camMod and camMod:WaitForChild("MouseLockController", 10)
	if not mlc then
		warn("[AS] MouseLockController not found — the screen lock key is still Shift")
		return
	end
	local keys = mlc:FindFirstChild("BoundKeys")
	if not (keys and keys:IsA("StringValue")) then
		keys = Instance.new("StringValue")
		keys.Name = "BoundKeys"
		keys.Parent = mlc
	end
	keys.Value = "LeftControl,RightControl"
end)

-- ภาษา: เริ่มก่อนหน้าจออื่น ข้อความแปลตั้งแต่เฟรมแรก (Localizer)
safe("Localizer", require(Client:WaitForChild("Localizer")).Init)
safe("Cinematics", Cinematics.Init, state)
safe("HUD", HUD.Init, state)
safe("Atmosphere", AtmosphereController.Init, state)
safe("AmbientFX", AmbientFX.Init, state, AtmosphereController)
safe("Animator", AnimalAnimator.Init)
safe("MobBars", require(Client:WaitForChild("MobBars")).Init) -- หลอดเลือดบนหัวสัตว์/มอนทุกตัว
safe("Skins", SkinStreamer.Init)
safe("Combat", CombatClient.Init, state, HUD)
safe("Menus", Menus.Init, state, HUD)
safe("Map", MapUI.Init, state, HUD, AtmosphereController)
safe("NavArrows", require(Client:WaitForChild("NavArrows")).Init, state) -- ไอคอนกองไฟ/หมุด เกาะขอบจอ + ลูกศรชี้ทาง
safe("FogWall", require(Client:WaitForChild("FogWall")).Init, state)
safe("WorldEvents", require(Client:WaitForChild("WorldEventsClient")).Init, state, HUD, MapUI, CombatClient)
safe("Dev", require(script.Parent:WaitForChild("DevPanel")).Init)
safe("PadUI", require(Client:WaitForChild("PadUI")).Init)
safe("Mount", require(Client:WaitForChild("MountClient")).Init) -- ขี่ลูกสัตว์ธาตุ: ท่านั่ง + ปุ่มลง
safe("World", require(Client:WaitForChild("WorldUI")).Init) -- เมนู Worlds: สร้าง/เข้าห้องโลก (WorldService)
safe("Death", DeathClient.Init)
Cinematics.Death = DeathClient
safe("Sound", SoundController.Init, state)
SoundController.Biome = function()
	return AtmosphereController.Biome
end
safe("Tutorial", Tutorial.Init, UIKit.Screen("Tutorial", 60))
safe("Settings", SettingsUI.Init, UIKit.Screen("Settings", 45), { Tutorial = Tutorial.Open, GearParent = HUD.RightCard })
Menus.OnSettings = SettingsUI.Toggle
-- เมนูซ้ายในล็อบบี้เปิดได้ทีละหน้า (กดเมนูอื่น = ปิดหน้าตั้งค่า)
require(Client:WaitForChild("LobbyUI")).Closers.Settings = SettingsUI.Close
safe("Mobile", MobileControls.Init, { Menus = Menus, Map = MapUI, HUD = HUD, Combat = CombatClient })
-- ภารกิจ / ล็อกอิน 7 วัน / Season Pass / โค้ด (ปุ่ม "ภารกิจ" ในล็อบบี้)
local QuestUI = require(Client:WaitForChild("QuestUI"))
safe("Quests", QuestUI.Init, UIKit.Screen("Quests", 33))
-- ความสะดวก: การ์ดรายละเอียดไอเทม / สลับเครื่องมืออัตโนมัติ / ปิงบอกทีม / กลับเข้ารอบเดิม
safe("Tooltip", ItemTooltip.Init)
CombatClient.AutoTool = AutoTool
AutoTool.Blocked = function()
	return Menus.IsBuilding()
end
safe("AutoTool", AutoTool.Init, CombatClient.Swing)
safe("TeamPing", TeamPing.Init, state, HUD, MapUI, SoundController)
safe("Rejoin", RejoinUI.Init)
safe("ClassFX", function()
	local fx = require(Client:WaitForChild("ClassFX"))
	CombatClient.ClassFX = fx
	fx.Init(CombatClient)
end) -- เอฟเฟกต์ตี/สกิลของคลาส 5 ดาว
safe("ClassSkill", function()
	local cs = require(Client:WaitForChild("ClassSkill"))
	cs.Menus = Menus
	cs.Init(CombatClient)
end) -- ช่องสกิลกดของคลาส 5 ดาว (ปุ่ม Q)
safe("PromptUI", require(Client:WaitForChild("PromptUI")).Init) -- การ์ดปุ่มกด E/F/R แบบ 99 Nights (มือถือแตะการ์ดได้)
safe("KeyHints", require(Client:WaitForChild("KeyHints")).Init, { Menus = Menus, HUD = HUD }) -- แผงปุ่มลัดมุมขวาล่าง (คอม)
safe("BuildHammer", require(Client:WaitForChild("BuildHammer")).Init, Menus) -- ค้อนช่าง: ย้าย/รื้อสิ่งก่อสร้าง
safe("MedAnim", require(Client:WaitForChild("MedAnim")).Init) -- ท่าพันแผล/ก้มช่วยเพื่อน + หลอดรอใช้ยา

-- การตั้งค่า -> ระบบต่างๆ
local function applySetting(key, value)
	if key == "Shake" then
		CombatClient.ShakeEnabled = false -- ปิดจอสั่นถาวร
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
	HUD.Pickup = function(id, n, stored)
		pickup(id, n, stored)
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

local holdingSack
local berryHover -- ลูกเบอร์รี่บนต้นที่ชี้อยู่ (BerryPicker ด้านล่าง) -> คลิกกระสอบไม่ไปเก็บของบนพื้นแทน
-- ถือกระสอบ: คลิกของบนพื้น/กองไฟ/เครื่องบด + E เก็บ + F ทิ้ง (แบบ 99 Nights · ไม่มีหน้ารายการของ)
do
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	holdingSack = false
	-- ปุ่ม E/R บนของที่ตก: เปิดเฉพาะชิ้นที่โฟกัส (กรอบขาว) ชิ้นเดียว -> กดแล้วได้ชิ้นที่เห็นแน่ ๆ
	local focus
	local function isDropPrompt(d)
		return d:IsA("ProximityPrompt") and (d.Name == "Pickup" or d.Name == "Use")
	end
	-- ปุ่ม E เก็บ = เฉพาะตอนถือกระสอบในมือ (แบบ 99 Nights) · ปุ่มกิน/ใช้ = ได้ตลอด
	-- ยกเว้นยา/อาวุธ/เกราะ (Direct) เก็บเข้าแถบเครื่องมือได้ตลอด ไม่ต้องถือกระสอบ
	local function canPick(d)
		if d.Name ~= "Pickup" or holdingSack then
			return true
		end
		local m = d:FindFirstAncestorWhichIsA("Model")
		return m ~= nil and m:GetAttribute("Direct") == true
	end
	local function setPrompts(m, on)
		for _, d in ipairs(m and m:GetDescendants() or {}) do
			if isDropPrompt(d) then
				d.Enabled = on and canPick(d)
			end
		end
	end
	local function hasUse(m)
		for _, d in ipairs(m and m:GetDescendants() or {}) do
			if d:IsA("ProximityPrompt") and d.Name == "Use" then
				return true
			end
		end
		return false
	end
	local function dropOf(inst)
		local drops = Workspace:FindFirstChild("Drops")
		while inst and drops and inst.Parent ~= drops do
			inst = inst.Parent
		end
		return drops and inst and inst:IsA("Model") and inst or nil
	end
	task.spawn(function()
		local drops = Workspace:WaitForChild("Drops", 60)
		if drops then
			drops.DescendantAdded:Connect(function(d)
				if isDropPrompt(d) then
					d.Enabled = focus ~= nil and d:IsDescendantOf(focus) and canPick(d)
				end
			end)
			for _, d in ipairs(drops:GetDescendants()) do
				if isDropPrompt(d) then
					d.Enabled = false
				end
			end
		end
	end)
	-- ขอบเข้มรอบของที่ตกใกล้ตัว (มองเห็นบนหิมะขาว/พื้นสีเดียวกับของ) · ชิ้นที่โฟกัสอยู่ใช้กรอบขาวด้านล่างแทน
	do
		local OUTLINE_RANGE, OUTLINE_MAX = 70, 14
		local pool = {}
		local function newOutline()
			local h = Instance.new("Highlight")
			h.Name = "DropOutline"
			h.FillTransparency = 1
			h.OutlineColor = Color3.fromRGB(24, 30, 52)
			h.OutlineTransparency = 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			return h
		end
		-- ใส่กรอบในโมเดลของชิ้นนั้น (โดนเก็บ = กรอบโดนลบตาม -> สร้างใหม่)
		local function attach(i, m)
			local h = pool[i] or newOutline()
			if not pcall(function()
				h.Parent = m
			end) then
				h = newOutline()
				h.Parent = m
			end
			h.Adornee = m
			pool[i] = h
		end
		local function detach(i)
			local h = pool[i]
			if h then
				pcall(function()
					h.Adornee = nil
					h.Parent = nil
				end)
			end
		end
		task.spawn(function()
			while true do
				task.wait(0.4)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local drops = Workspace:FindFirstChild("Drops")
				local near = {}
				if root and drops then
					for _, m in ipairs(drops:GetChildren()) do
						local p = m.PrimaryPart
						if p and not m:FindFirstChild("PickupHighlight") then
							local d = (p.Position - root.Position).Magnitude
							if d < OUTLINE_RANGE then
								table.insert(near, { m, d })
							end
						end
					end
					table.sort(near, function(a, b)
						return a[2] < b[2]
					end)
				end
				for i = 1, OUTLINE_MAX do
					local m = near[i] and near[i][1]
					if m then
						attach(i, m)
					else
						detach(i)
					end
				end
			end
		end)
	end
	-- กรอบขาวรอบของบนพื้นที่ "โฟกัสอยู่" (แบบเกมเอาชีวิตรอดซอมบี้) — ขึ้นตลอด ไม่ต้องถือกระสอบ
	-- เมาส์ชี้ของในระยะเก็บ > ไม่งั้นเลือกชิ้นใกล้สุดที่หันหน้ากล้องไปหา
	do
		local PICK_RANGE = 20 -- ตรงกับ DropService
		local FOCUS_RANGE = 12 -- ระยะเลือกอัตโนมัติ = ระยะปุ่ม E (PROMPT_RANGE ใน DropService)
		-- Highlight ใส่ไว้ในโมเดลของที่โฟกัสเลย (ใส่ใน Camera แล้วไม่ขึ้น) · ของโดนเก็บ/ลบ = กรอบหายตาม แล้วสร้างใหม่
		local hl
		local function makeHighlight()
			hl = Instance.new("Highlight")
			hl.Name = "PickupHighlight"
			hl.FillColor, hl.FillTransparency = Color3.new(1, 1, 1), 0.9
			hl.OutlineColor, hl.OutlineTransparency = Color3.new(1, 1, 1), 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Enabled = false
		end
		makeHighlight()
		local target, nextScan, t0 = nil, 0, os.clock()
		game:GetService("RunService").RenderStepped:Connect(function()
			local now = os.clock()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root or player:GetAttribute("Dead") or player:GetAttribute("Downed") then
				target = nil
			elseif now >= nextScan then
				nextScan = now + 0.1
				target = nil
				local m = dropOf(mouse.Target)
				-- ยืนที่กองไฟ: ไม่เลือกของรอบ ๆ ให้อัตโนมัติ (ปุ่ม E/R ต้องเป็นของกองไฟ โยนต่อได้เรื่อย ๆ) · ชี้เมาส์ที่ของตรง ๆ ยังเก็บได้
				local camp = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Sites") and Workspace.World.Sites:FindFirstChild("Camp")
				local core = camp and camp:FindFirstChild("Campfire") and camp.Campfire:FindFirstChild("FireCore")
				local atFire = core ~= nil and ((core.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 13
				if m and m:GetAttribute("Thrown") then
					m = nil
				end
				if m and m.PrimaryPart and (m.PrimaryPart.Position - root.Position).Magnitude <= PICK_RANGE then
					target = m
				elseif atFire then
					target = nil
				else
					local drops = Workspace:FindFirstChild("Drops")
					local look = Workspace.CurrentCamera.CFrame.LookVector
					look = Vector3.new(look.X, 0, look.Z).Unit
					local best = math.huge
					for _, d in ipairs(drops and drops:GetChildren() or {}) do
						local p = d:IsA("Model") and not d:GetAttribute("Thrown") and d.PrimaryPart
						if p then
							local off = p.Position - root.Position
							local flat = Vector3.new(off.X, 0, off.Z)
							local dist = flat.Magnitude
							if dist <= FOCUS_RANGE and math.abs(off.Y) < 8 then
								-- ของที่อยู่ตรงหน้าได้เปรียบ ของข้างหลังโดนลดคะแนน
								local facing = dist > 0.5 and look:Dot(flat.Unit) or 1
								local score = dist * (1.6 - facing)
								if score < best then
									best, target = score, d
								end
							end
						end
					end
				end
			end
			if target and not (target.Parent and target.PrimaryPart) then
				target = nil
			end
			if not hl.Parent and focus ~= nil then
				-- โมเดลเดิมถูกทำลาย (เก็บไปแล้ว) กรอบหายไปด้วย
				focus = nil
				makeHighlight()
			end
			if focus ~= target then
				setPrompts(focus, false)
				focus = target
				setPrompts(focus, true)
				hl.Adornee = target
				hl.Parent = target
				t0 = now
			end
			-- กรอบขาว: ถือกระสอบ หรือของชิ้นนั้นกิน/ใช้ได้
			hl.Enabled = target ~= nil and (holdingSack or hasUse(target))
			-- กระพริบขอบเบา ๆ ให้สะดุดตา
			hl.OutlineTransparency = 0.15 - 0.15 * math.cos((now - t0) * 5)
		end)
	end
	-- F = เอาของออกจากกระสอบ (ชิ้นล่าสุด) · ยืนใกล้กองไฟ = โยนเข้ากองไฟ
	--   ปุ่ม F ของพุ่มเบอร์รี่/หม้อตุ๋น (ProximityPrompt) ขึ้นอยู่ -> ไม่ทิ้งของ (กันเก็บแล้วทิ้งทันที)
	local fPrompts = {}
	local PPS = game:GetService("ProximityPromptService")
	PPS.PromptShown:Connect(function(prompt)
		if prompt.KeyboardKeyCode == Enum.KeyCode.F then
			fPrompts[prompt] = true
		end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		fPrompts[prompt] = nil
	end)
	local function fPromptUp()
		for prompt in pairs(fPrompts) do
			if prompt.Parent and prompt.Enabled then
				return true
			end
			fPrompts[prompt] = nil
		end
		return false
	end
	game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
		-- Backspace = ทิ้งของที่ถืออยู่ในมือ (กระสอบ = ทิ้งชิ้นล่าสุดในกระสอบ)
		if not gp and input.KeyCode == Enum.KeyCode.Backspace and player:GetAttribute("InRun") then
			Remotes.Get("DropHeld"):FireServer()
			return
		end
		if gp or input.KeyCode ~= Enum.KeyCode.F then
			return
		end
		if holdingSack and player:GetAttribute("InRun") and not fPromptUp() then
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
			setPrompts(focus, true) -- เปิดปุ่ม E เก็บของชิ้นที่โฟกัสอยู่ทันที
		end)
		tool.Unequipped:Connect(function()
			holdingSack = false
			setPrompts(focus, true)
		end)
		tool.Activated:Connect(function()
			if berryHover then
				return -- คลิกนี้ใช้เก็บลูกบนต้น (BerryPicker)
			end
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
			-- คลิก = เก็บชิ้นที่มีกรอบขาวอยู่ (ไม่ต้องเล็งโดนเป๊ะ ๆ)
			target = focus or dropOf(target)
			if target then
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

-- เก็บเบอร์รี่ที่ต้น (พุ่มในป่า + แปลงเบอร์รี่): ชี้ลูกบนต้น -> ลูกนั้นมีกรอบขาว + ป้ายเล็ก
--   คลิก/แตะ/E = เก็บใส่กระสอบ · R = กินเลย · จอยเกม = เล็งกลางจอ ปุ่ม X เก็บ
--   ไม่ใช้ปุ่ม ProximityPrompt แล้ว (ลูกบนต้นหายทีละลูกตามที่เก็บจริง)
do
	local CollectionService = game:GetService("CollectionService")
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local RANGE = 15 -- ระยะเอื้อม (เซิร์ฟเวอร์ยอม 18)
	local AIM_PX = 64 -- ห่างจากเมาส์ไม่เกินกี่พิกเซลถึงนับว่าชี้ลูกนั้น
	local pickRemote = Remotes.Get("PickBerry")

	local hl = Instance.new("Highlight")
	hl.Name = "BerryHighlight"
	hl.FillColor, hl.FillTransparency = Color3.new(1, 1, 1), 0.55
	hl.OutlineColor, hl.OutlineTransparency = Color3.new(1, 1, 1), 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = false

	-- ป้ายข้างลูก: ชื่อพุ่ม + จำนวนลูก · [E] ใส่กระสอบ · [R] กิน
	local tip = Instance.new("BillboardGui")
	tip.Name = "BerryTip"
	tip.Size = UDim2.fromOffset(190, 74)
	tip.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	tip.AlwaysOnTop = true
	tip.LightInfluence = 0
	tip.MaxDistance = 40
	tip.Enabled = false
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 3)
	list.Parent = tip
	local function row(order)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, 22)
		f.LayoutOrder = order
		f.Parent = tip
		return f
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.LayoutOrder = 0
	title.Parent = tip
	local function keyRow(order, key, text)
		local f = row(order)
		local k = Instance.new("TextLabel")
		k.Name = "Key"
		k.Size = UDim2.fromOffset(22, 22)
		k.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		k.TextColor3 = Color3.fromRGB(30, 30, 30)
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 13
		k.Text = key
		k.Parent = f
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = k
		local t = Instance.new("TextLabel")
		t.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		t.BackgroundTransparency = 0.35
		t.Position = UDim2.fromOffset(26, 0)
		t.Size = UDim2.new(1, -26, 1, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 14
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = "  " .. text
		t.Parent = f
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(0, 5)
		c2.Parent = t
		return f, k
	end
	local sackRow, sackKey = keyRow(1, "E", "Put in Sack")
	local eatRow = keyRow(2, "R", "Eat Berries")
	require(Client:WaitForChild("KeyHints")).Extra.Berry = function()
		if berryHover then
			return { { "Put in Sack", "E" }, { "Eat Berries", "R" } }
		end
		return nil
	end
	task.spawn(function()
		tip.Parent = player:WaitForChild("PlayerGui")
	end)

	-- ลูกที่ยังเก็บได้ใกล้ตัว (สแกนทุก 0.15 วิ)
	local cands, nextScan = {}, 0
	local pending = setmetatable({}, { __mode = "k" }) -- [ลูก] = เวลาที่หยุดรอ
	local function scan(root)
		cands = {}
		for _, src in ipairs(CollectionService:GetTagged("BerrySource")) do
			if src:IsDescendantOf(Workspace) then
				local ok, piv = pcall(src.GetPivot, src)
				if ok and (piv.Position - root.Position).Magnitude < RANGE + 14 then
					for _, d in ipairs(src:GetDescendants()) do
						if d.Name == "Berry" and d:IsA("BasePart") and d.Transparency < 0.95 and not d:GetAttribute("Picked")
							and (pending[d] or 0) < os.clock() then
							table.insert(cands, { Source = src, Part = d })
						end
					end
				end
			end
		end
	end
	-- ลูกที่ใกล้จุดบนจอที่สุด (เมาส์/นิ้วแตะ/กลางจอ)
	local function aimAt(screen, root)
		local cam = Workspace.CurrentCamera
		local best, bd
		for _, c in ipairs(cands) do
			local p = c.Part
			if p.Parent and p.Transparency < 0.95 and (p.Position - root.Position).Magnitude <= RANGE then
				local v, on = cam:WorldToViewportPoint(p.Position)
				if on then
					local dist = (Vector2.new(v.X, v.Y) - screen).Magnitude
					-- ลูกใหญ่บนจอ (ยืนใกล้) = ยอมให้ชี้คลาดได้มากขึ้น
					local reach = math.max(AIM_PX, p.Size.Magnitude * cam.ViewportSize.Y / math.max(v.Z, 1) * 0.5)
					if dist <= reach and (not bd or dist < bd) then
						best, bd = c, dist
					end
				end
			end
		end
		return best
	end
	local function alive()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not player:GetAttribute("InRun") or player:GetAttribute("Dead") or player:GetAttribute("Downed") then
			return nil
		end
		return root
	end
	local function aimPoint()
		if UIS.MouseEnabled and not Workspace:GetAttribute("ASAimCenter") and UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			return UIS:GetMouseLocation()
		end
		local vp = Workspace.CurrentCamera.ViewportSize
		return Vector2.new(vp.X / 2, vp.Y / 2) -- ล็อกเมาส์กลางจอ (Shift Lock/มุมมองบุคคลที่ 1) / จอยเกม
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local root = alive()
		local target
		if root then
			if now >= nextScan then
				nextScan = now + 0.15
				scan(root)
			end
			-- จอสัมผัสล้วน: ไม่มีเมาส์ชี้ -> โชว์กรอบลูกใกล้กลางจอให้รู้ว่าแตะเก็บได้
			target = aimAt(aimPoint(), root)
		end
		berryHover = target
		if target then
			hl.Adornee = target.Part
			hl.Parent = target.Part
			hl.Enabled = true
			tip.Adornee = target.Part
			local src = target.Source
			local n, max = src:GetAttribute("Berries"), src:GetAttribute("MaxBerries")
			local patch = src:FindFirstChild("Crops") ~= nil
			if n and max then
				title.Text = string.format(patch and "Berry Patch %d/%d" or "Berry Bush %d/%d", n, max)
			else
				title.Text = patch and "Berry Patch" or "Berry Bush"
			end
			local touchOnly = UIS.TouchEnabled and not UIS.MouseEnabled
			sackKey.Text = touchOnly and "👆" or (UIS.GamepadEnabled and not UIS.MouseEnabled and "X" or "E")
			-- คอม (เมาส์+คีย์บอร์ด): ปุ่ม E/R ไปขึ้นแผงปุ่มลัดขวาล่าง (KeyHints.Extra) ป้ายบนลูกเหลือแค่ชื่อ+จำนวน
			local pcKeys = UIS.KeyboardEnabled and not touchOnly and not UIKit.IsTouch
			sackRow.Visible = not pcKeys
			eatRow.Visible = not touchOnly and not pcKeys
			tip.Enabled = true
		else
			hl.Enabled = false
			hl.Adornee = nil
			tip.Enabled = false
		end
	end)

	local function pick(c, how)
		if c and c.Part.Parent then
			pickRemote:FireServer(c.Source, c.Part, how)
			pending[c.Part] = os.clock() + 1 -- กันกดซ้ำลูกเดิมระหว่างรอเซิร์ฟเวอร์ตอบ
			nextScan = 0
		end
	end
	UIS.InputBegan:Connect(function(input, gp)
		local root = alive()
		if not root then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			-- แตะตรงลูก = เก็บ (แตะปุ่มบนจอ gp = true ไม่นับ)
			if not gp then
				pick(aimAt(Vector2.new(input.Position.X, input.Position.Y), root), "Sack")
			end
			return
		end
		if gp or not berryHover then
			return
		end
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			pick(berryHover, "Sack")
		elseif input.KeyCode == Enum.KeyCode.R then
			pick(berryHover, "Eat")
		end
	end)
end

-- กองไฟ: กดค้าง E (ไม้/ถ่าน) หรือ R (เนื้อดิบ) = โยนต่อเนื่องทีละชิ้น ไม่ต้องกดใหม่ทุกชิ้น (แบบ 99 Nights)
do
	local UIS = game:GetService("UserInputService")
	local PPS = game:GetService("ProximityPromptService")
	local WHAT = { FireFuel = "Fuel", FireCook = "Meat" }
	local token = 0
	PPS.PromptTriggered:Connect(function(prompt)
		local what = WHAT[prompt.Name]
		if not what then
			return
		end
		token += 1
		local my = token
		local key, pad = prompt.KeyboardKeyCode, prompt.GamepadKeyCode
		task.spawn(function()
			task.wait(0.4)
			while my == token and prompt.Parent and (UIS:IsKeyDown(key) or UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, pad)) do
				Remotes.Get("ThrowFuel"):FireServer(what)
				task.wait(0.26)
			end
		end)
	end)
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
	-- โหลดการตั้งค่าจากเซฟครั้งแรกที่ได้โปรไฟล์ (ครั้งต่อๆ ไปไม่ทับ เพราะค่าที่เพิ่งปรับอาจยังส่งไปไม่ถึงเซิร์ฟเวอร์)
	if type(profile) == "table" and not ClientSettings.Loaded then
		ClientSettings.Load(profile.Settings)
	end
end)

-- หลังโหลดเสร็จ: เปิดหน้าเลือกคลาสครั้งแรก
Cinematics.OnLoaded = function()
	task.spawn(function()
		-- เซฟของผู้เล่นอาจยังโหลดไม่เสร็จตอนเข้าเกม (DataStore ช้า) -> ลองขอซ้ำ ไม่งั้นการตั้งค่าจะเป็นค่าเริ่มต้น
		local ok, profile
		for _ = 1, 10 do
			ok, profile = pcall(function()
				return Remotes.Get("GetProfile"):InvokeServer()
			end)
			if ok and profile then
				break
			end
			task.wait(1)
		end
		if ok and profile then
			Menus.SetProfile(profile)
			if not ClientSettings.Loaded then
				ClientSettings.Load(profile.Settings)
			end
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

do
	local onLoaded = Cinematics.OnLoaded
	Cinematics.OnLoaded = function()
		if onLoaded then
			onLoaded()
		end
		QuestUI.OnLoaded()
	end
end

local _ = UIKit
print("[AS] client ready")
