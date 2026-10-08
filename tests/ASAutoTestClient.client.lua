--[[
	ASAutoTestClient — เล่นเกมแทนคนแล้วถ่ายภาพ (ทุกบรรทัด [SHOT] ชื่อ = ถ่ายภาพหน้าต่าง Studio)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASAutoTest") then
	return
end
local SHOTS = ReplicatedStorage:FindFirstChild("ASShots") ~= nil

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local cmd = remotes:WaitForChild("TestCmd")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local results = {}
local function check(name, ok, extra)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (extra and (" (" .. tostring(extra) .. ")") or ""))
	print("[TEST] " .. (ok and "PASS " or "FAIL ") .. name .. (extra and (" " .. tostring(extra)) or ""))
end

local function shot(name, wait)
	task.wait(wait or 1.5)
	print("[SHOT] " .. name)
	task.wait(1.8)
end

local inventory = {}
Remotes.Get("Inventory").OnClientEvent:Connect(function(inv)
	inventory = inv
end)

-- ===== ล็อบบี้ =====
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
task.wait(4)
check("spawn in lobby", root.Position.Y > 1500, root.Position)
local cam0 = Workspace.CurrentCamera
local lobby = Workspace:WaitForChild("Lobby", 10)
if lobby then
	local lp = lobby:GetPivot().Position
	cam0.CameraType = Enum.CameraType.Scriptable
	cam0.CFrame = CFrame.lookAt(Vector3.new(lp.X + 70, lp.Y + 45, lp.Z + 85), Vector3.new(lp.X, lp.Y + 5, lp.Z - 10))
	shot("lobby_overview", 2)
	cam0.CFrame = CFrame.lookAt(Vector3.new(lp.X + 2, lp.Y + 9, lp.Z + 92), Vector3.new(lp.X, lp.Y + 8, lp.Z - 50))
	shot("lobby_spawnview", 1.5)
	cam0.CFrame = CFrame.lookAt(Vector3.new(lp.X - 120, lp.Y + 120, lp.Z + 170), Vector3.new(lp.X + 10, lp.Y, lp.Z - 20))
	shot("lobby_aerial", 1.5)
	cam0.CFrame = CFrame.lookAt(Vector3.new(lp.X + 30, lp.Y + 14, lp.Z + 44), Vector3.new(lp.X + 70, lp.Y + 4, lp.Z + 4))
	shot("lobby_boxes", 1.2)
	cam0.CameraType = Enum.CameraType.Custom
	local okM, Menus = pcall(function()
		return require(script.Parent:WaitForChild("Client"):WaitForChild("Menus"))
	end)
	if okM then
		Menus.OpenShop("Kits")
		shot("lobby_shop", 1.5)
		Menus.OpenShop("Classes")
		shot("lobby_classes", 4)
		task.wait(2)
		local okCS, ClassShop = pcall(function()
			return require(script.Parent:WaitForChild("Client"):WaitForChild("ClassShop"))
		end)
		if okCS then
			ClassShop.Select("Beastwarden")
			shot("lobby_classes_beast", 3)
			task.wait(2)
			ClassShop.Select("Medic")
			shot("lobby_classes_medic", 3)
			task.wait(2)
		end
		Menus.OpenShop("Kits") -- ปิดร้านคลาส (คืนกล้อง)
		pcall(function()
			player.PlayerGui.Menus:GetChildren()[1].Visible = false
		end)
		for _, g in ipairs(player.PlayerGui.Menus:GetChildren()) do
			if g:IsA("Frame") then
				g.Visible = false
			end
		end
	end
end
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
-- เดินเข้าประตู
local zone = lobby and lobby:FindFirstChild("MatchBox1", true)
if zone then
	root.CFrame = zone.CFrame
end
local tDep = os.clock()
while not player:GetAttribute("InRun") and os.clock() - tDep < 40 do
	task.wait(0.5)
	if zone and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and not player:GetAttribute("InRun") then
		player.Character.HumanoidRootPart.CFrame = zone.CFrame
	end
end
check("departed via portal", player:GetAttribute("InRun") == true)
task.wait(3)
char = player.Character
root = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")
task.wait(4)
check("spawned", root.Position.Magnitude < 200, root.Position)
check("camp exists", Workspace:FindFirstChild("World") and Workspace.World.Sites:FindFirstChild("Camp") ~= nil)
shot("play_spawn", 2)

local cam = Workspace.CurrentCamera
local function moveTo(pos)
	root.CFrame = CFrame.new(pos)
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.4)
end
local function ground(x, z)
	return cmd:InvokeServer("height", x, z)
end

-- 1) ตัดไม้
local tool = player.Backpack:WaitForChild("ขวานเก่า", 10) or player.Backpack:FindFirstChildOfClass("Tool")
check("has starter tool", tool ~= nil)
local woodBefore = inventory.Wood or 0
local target
for _, node in ipairs(game:GetService("CollectionService"):GetTagged("ResourceNode")) do
	if node:GetAttribute("Node") == "Tree" and node:GetAttribute("Yield") == "Wood" then
		local d = (node:GetPivot().Position - root.Position).Magnitude
		if d < 600 and (not target or d < (target:GetPivot().Position - root.Position).Magnitude) then
			target = node
		end
	end
end
if tool and target then
	hum:EquipTool(tool)
	local tp = target:GetPivot().Position
	local dir = (root.Position - tp) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	local stand = tp + dir * 4.5
	moveTo(Vector3.new(stand.X, tp.Y + 4, stand.Z))
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(tp.X, root.Position.Y, tp.Z))
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(root.Position + dir * 14 + Vector3.new(4, 7, 4), tp + Vector3.new(0, 6, 0))
	for _ = 1, 12 do
		tool:Activate()
		task.wait(0.1)
		tool:Deactivate() -- เหมือนปล่อยเมาส์ (ไม่งั้น Roblox ไม่ยิง Activated ครั้งถัดไป)
		task.wait(0.6)
	end
	shot("play_chop", 0.5)
	cam.CameraType = Enum.CameraType.Custom
end
task.wait(0.5)
check("chopped wood", (inventory.Wood or 0) > woodBefore, inventory.Wood)

-- 2) คราฟต์ + สร้าง
cmd:InvokeServer("give", { Wood = 80, Stone = 40, Fiber = 20, Iron = 20, Coal = 10, Bone = 6, Pelt = 6, Berries = 6, RawMeat = 4 })
task.wait(0.5)
local bench = Workspace.World.Sites.Camp.Workbench
moveTo(bench:GetPivot().Position + Vector3.new(0, 4, 6))
Remotes.Get("Craft"):FireServer("LogWall")
Remotes.Get("Craft"):FireServer("LogWall")
Remotes.Get("Craft"):FireServer("SpikeTrap")
Remotes.Get("Craft"):FireServer("StoneAxe")
Remotes.Get("Craft"):FireServer("Torch")
Remotes.Get("Craft"):FireServer("Lantern")
task.wait(1)
check("crafted wall", (inventory.LogWall or 0) >= 2, inventory.LogWall)
local campPos = state:GetAttribute("CampPos")
for i, kind in ipairs({ "LogWall", "LogWall", "SpikeTrap", "Lantern" }) do
	local ang = math.rad(-30 + i * 25)
	local p = campPos + Vector3.new(math.cos(ang) * 30, 0, math.sin(ang) * 30)
	moveTo(p + Vector3.new(0, 6, -10))
	Remotes.Get("PlaceStructure"):FireServer(kind, CFrame.new(p) * CFrame.Angles(0, -ang + math.pi / 2, 0))
	task.wait(0.4)
end
task.wait(1)
check("structures placed", #Workspace.Structures:GetChildren() >= 3, #Workspace.Structures:GetChildren())

-- 3) เติมไฟ + ภาพแคมป์
moveTo(campPos + Vector3.new(10, 5, 10))
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(24, 14, 26), campPos + Vector3.new(-4, 2, -4))
shot("play_camp", 1)
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(-70, 62, 70), campPos + Vector3.new(0, 4, 0))
shot("play_camp_aerial", 1)
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(12, 6, -16), campPos + Vector3.new(-22, 3, 8))
shot("play_camp_tents", 1)
cam.CameraType = Enum.CameraType.Custom

-- 4) สัตว์ทุกแบบรอบแคมป์
local zoo = { "MossWolf", "StoneBear", "ReefCrab", "EmberFox", "SkyLynx", "MagmaRhino", "HollowStag" }
local zooCenter = campPos + Vector3.new(120, 0, 0)
for i, id in ipairs(zoo) do
	local x, z = zooCenter.X + (i - 4) * 14, zooCenter.Z + 30
	cmd:InvokeServer("spawn", id, Vector3.new(x, ground(x, z) + 2, z))
end
moveTo(Vector3.new(zooCenter.X, ground(zooCenter.X, zooCenter.Z - 20) + 4, zooCenter.Z - 20))
cmd:InvokeServer("freeze", true)
task.wait(1)
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(Vector3.new(zooCenter.X, ground(zooCenter.X, zooCenter.Z) + 16, zooCenter.Z - 30), Vector3.new(zooCenter.X, ground(zooCenter.X, zooCenter.Z + 30) + 4, zooCenter.Z + 30))
shot("play_zoo", 1)
cmd:InvokeServer("freeze", false)
cam.CameraType = Enum.CameraType.Custom
check("animals alive", #Workspace.Animals:GetChildren() >= 5, #Workspace.Animals:GetChildren())

-- 5) ต่อสู้: ตีหมาป่า
local axe = player.Backpack:FindFirstChild("ขวานหิน") or char:FindFirstChildOfClass("Tool") or tool
if axe then
	hum:EquipTool(axe)
end
local wolf
-- เลือกหมาป่าตัวในสวนสัตว์ทดสอบ (ใกล้สุด) ไม่ใช่หมาป่าป่าที่อยู่ไกลนอกระยะ streaming
local bestD = math.huge
for _, m in ipairs(Workspace.Animals:GetChildren()) do
	if m:GetAttribute("AnimalId") == "MossWolf" and m.PrimaryPart then
		local d = (m:GetPivot().Position - zooCenter).Magnitude
		if d < bestD then
			wolf, bestD = m, d
		end
	end
end
if wolf and axe then
	local hp0 = wolf:GetAttribute("Health")
	cmd:InvokeServer("freeze", true) -- ให้หมาป่ายืนนิ่ง ทดสอบแค่ระบบตีโดน
	print(string.format("[TEST] wolf dist=%.1f tool=%s", bestD, tostring(axe.Name)))
	for _ = 1, 8 do
		if not wolf.Parent then
			break
		end
		local wp = wolf:GetPivot().Position
		moveTo(wp + Vector3.new(0, 2, -5))
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(wp.X, root.Position.Y, wp.Z))
		if axe.Parent ~= char then
			hum:EquipTool(axe)
			task.wait(0.2)
		end
		axe:Activate()
		task.wait(0.1)
		axe:Deactivate()
		print(string.format("[TEST] swing parent=%s d=%.1f hp=%s", tostring(axe.Parent and axe.Parent.Name), (root.Position - (wolf.PrimaryPart and wolf.PrimaryPart.Position or wp)).Magnitude, tostring(wolf:GetAttribute("Health"))))
		task.wait(0.65)
	end
	cmd:InvokeServer("freeze", false)
	check("damaged wolf", not wolf.Parent or (wolf:GetAttribute("Health") or hp0) < hp0, wolf:GetAttribute("Health"))
else
	check("damaged wolf", false, "no wolf/axe", wolf, axe)
end

-- 6) แต่ละไบโอม (ภาพระดับพื้น)
if SHOTS then
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local site = state:GetAttribute("Site_" .. el)
		if site then
			local dir = Vector3.new(site.X, 0, site.Z).Unit
			local guess = Vector3.new(site.X, 0, site.Z) - dir * 380
			local p = cmd:InvokeServer("safe", guess.X, guess.Z)
			local h = p.Y
			moveTo(Vector3.new(p.X, math.max(h, 20) + 6, p.Z))
			task.wait(3)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 10, 0) - dir * 14, Vector3.new(site.X, math.max(h, 20) + 30, site.Z))
			shot("play_biome_" .. el, 2.5)
			cam.CameraType = Enum.CameraType.Custom
		end
	end
	moveTo(campPos + Vector3.new(14, 5, 0))
end

-- 7) รอกลางคืน
local t0 = os.clock()
while state:GetAttribute("Phase") ~= "Night" and os.clock() - t0 < 90 do
	task.wait(1)
end
check("night started", state:GetAttribute("Phase") == "Night", state:GetAttribute("Phase"))
task.wait(8)
moveTo(campPos + Vector3.new(8, 5, 8))
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(60, 30, 60), campPos)
shot("play_night", 1)
cam.CameraType = Enum.CameraType.Custom
local raiders = 0
for _, m in ipairs(Workspace.Animals:GetChildren()) do
	if m:GetAttribute("Kind") == "Raid" then
		raiders += 1
	end
end
check("raid spawned", raiders > 0, raiders)

-- 8) บอส
cmd:InvokeServer("spawnRaid", "Terragon")
task.wait(5)
local boss
for _, m in ipairs(Workspace.Animals:GetChildren()) do
	if m:GetAttribute("AnimalId") == "Terragon" then
		boss = m
	end
end
check("boss spawned", boss ~= nil)
if boss then
	local bp = boss:GetPivot().Position
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(bp + Vector3.new(50, 30, 50), bp + Vector3.new(0, 10, 0))
	shot("play_boss", 1)
	cam.CameraType = Enum.CameraType.Custom
end

-- 9) แผนที่
local okMap, MapUI = pcall(function()
	return require(script.Parent:WaitForChild("Client"):WaitForChild("MapUI"))
end)
if okMap and MapUI.Toggle then
	MapUI.Toggle()
	shot("play_map", 2.5)
	MapUI.Toggle()
end

local errors = cmd:InvokeServer("errors")
check("no server errors", errors == 0, errors)
local passed = 0
for _, r in ipairs(results) do
	if r:sub(1, 4) == "PASS" then
		passed += 1
	end
end
cmd:InvokeServer("done", string.format("%d/%d passed", passed, #results))
