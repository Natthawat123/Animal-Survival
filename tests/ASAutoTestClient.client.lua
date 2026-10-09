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
	inv = inv.Bag or inv
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
-- ตัวละครอาจเกิดใหม่หลังเข้าแมพ -> ใช้ตัวปัจจุบันเสมอ
local function refreshChar()
	char = player.Character or player.CharacterAdded:Wait()
	root = char:WaitForChild("HumanoidRootPart")
	hum = char:WaitForChild("Humanoid")
end

local cam = Workspace.CurrentCamera
local function moveTo(pos)
	root.CFrame = CFrame.new(pos)
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.4)
end
local function ground(x, z)
	return cmd:InvokeServer("height", x, z)
end



-- โหมดโชว์ VFX (build --vfxshow): เล่นเอฟเฟกต์ในคลังทีละตัวบนเวทีลอยฟ้า แล้วถ่ายภาพ
if ReplicatedStorage:FindFirstChild("ASVFXShow") then
	local VFXLib = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("VFXLib"))
	local cp = state:GetAttribute("CampPos") or Vector3.zero
	local stage = cp + Vector3.new(0, 520, 0)
	cmd:InvokeServer("galleryStage", stage)
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
	moveTo(stage + Vector3.new(0, 4, -80))
	root.Anchored = true
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local filter = ReplicatedStorage.ASVFXShow.Value
	local list = {}
	for _, path in ipairs(VFXLib.List()) do
		if filter == "*" or path:sub(1, #filter) == filter then
			table.insert(list, path)
		end
	end
	print("[TEST] vfx count", #list)
	for i, path in ipairs(list) do
		local m = VFXLib.Play(path, CFrame.new(stage + Vector3.new(0, 3, 0)), { Duration = 2.2 })
		if m then
			local cf, size = m:GetBoundingBox()
			local r = math.clamp(math.max(size.X, size.Y, size.Z), 12, 120)
			cam.CFrame = CFrame.lookAt(stage + Vector3.new(r * 0.9, r * 0.5, -r * 1.3), stage + Vector3.new(0, r * 0.25, 0))
			print(string.format("[TEST] vfx %d %s size=%.0f", i, path, r))
			local safe = path:gsub("[^%w%-]", "_")
			shot(string.format("vfx_%03d_%s", i, safe), 0.9)
			task.wait(1.2)
		end
	end
	cmd:InvokeServer("done", "vfx")
	return
end

-- โหมดแกลเลอรี (build --gallery): ถ่ายสัตว์/ไอเทม/คลาส ทีละตัวบนเวทีลอยฟ้า แล้วจบ
if ReplicatedStorage:FindFirstChild("ASGallery") then
	local cp = state:GetAttribute("CampPos") or Vector3.zero
	local stage = cp + Vector3.new(0, 520, 0)
	cmd:InvokeServer("galleryStage", stage)
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
	moveTo(stage + Vector3.new(0, 4, -60))
	root.Anchored = true
	cam.CameraType = Enum.CameraType.Scriptable
	local function frame(center, size, fov)
		local r = math.max(size.X, size.Y, size.Z)
		cam.FieldOfView = fov or 40
		local dist = r * 1.25 + 3
		cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.55, size.Y * 0.35 + r * 0.25, -dist), center)
	end
	-- 1) สัตว์
	local animals = { "Rabbit", "Deer", "MossWolf", "Thornboar", "StoneBear", "ReefCrab", "RiptideCroc", "GaleHawk", "SkyLynx", "StormRam",
		"EmberFox", "MagmaRhino", "LavaSalamander", "HollowStag", "TerraPup", "TidePup", "GalePup", "EmberPup", "Solfang", "Leviathan", "TempestRoc", "Terragon" }
	for _, id in ipairs(animals) do
		cmd:InvokeServer("galleryClear")
		cmd:InvokeServer("spawn", id, stage + Vector3.new(0, 3, 0))
		task.wait(1)
		cmd:InvokeServer("freeze", true)
		local m
		for _, x in ipairs(Workspace.Animals:GetChildren()) do
			if x:GetAttribute("AnimalId") == id then
				m = x
			end
		end
		task.wait(1.5)
		if m then
			local cf, size = m:GetBoundingBox()
			frame(cf.Position, size)
		end
		shot("gal_animal_" .. id, 1.2)
	end
	cmd:InvokeServer("galleryClear")
	-- 2) ไอเทม (เครื่องมือ + สิ่งก่อสร้าง)
	local tools = { "OldAxe", "StoneAxe", "IronAxe", "Pickaxe", "Spear", "Torch", "Bow", "TerraHammer", "TidalTrident", "GaleBow", "EmberBlade", "FourfoldBlade" }
	local structs = { "LogWall", "StoneWall", "SpikeTrap", "Lantern", "Ballista", "Bed", "FarmPlot", "CookPot", "TerraTotem", "TideTotem", "GaleTotem", "EmberTotem", "SunBeacon" }
	for _, list in ipairs({ { "Tool", tools }, { "Structure", structs } }) do
		for _, id in ipairs(list[2]) do
			cmd:InvokeServer("galleryClear")
			local res = cmd:InvokeServer("galleryItem", { Kind = list[1], Id = id, Pos = stage })
			task.wait(1.5)
			if res then
				frame(res[1], res[2], list[1] == "Tool" and 30 or 40)
			end
			shot("gal_item_" .. id, 1)
		end
	end
	cmd:InvokeServer("galleryClear")
	-- 3) คลาส (ตัวละครในร้าน)
	local okCA, ClassAvatars = pcall(function()
		return require(script.Parent:WaitForChild("Client"):WaitForChild("ClassAvatars"))
	end)
	if okCA then
		local Classes = require(ReplicatedStorage.Shared.Classes)
		for _, id in ipairs(Classes.Order) do
			local m = ClassAvatars.Build(id)
			m.Parent = Workspace
			m:PivotTo(CFrame.new(stage) * CFrame.Angles(0, -0.35, 0))
			task.wait(1)
			cam.FieldOfView = 32
			cam.CFrame = CFrame.lookAt(stage + Vector3.new(2.5, 4, -13), stage + Vector3.new(0, 2.8, 0))
			shot("gal_class_" .. id, 1)
			m:Destroy()
		end
	end
	cmd:InvokeServer("done", "gallery")
	return
end

-- 1) ตัดไม้
refreshChar()
local tool = player.Backpack:WaitForChild("ขวานเก่า", 10) or player.Backpack:FindFirstChildOfClass("Tool")
check("has starter tool", tool ~= nil)
local woodBefore = inventory.Wood or 0
local target
for _, node in ipairs(game:GetService("CollectionService"):GetTagged("ResourceNode")) do
	if node:GetAttribute("Node") == "Tree" and node:GetAttribute("Yield") == "Wood" and node:GetPivot().Position.Y > 25 then -- บนบก ไม่ใช่ริมน้ำ
		local d = (node:GetPivot().Position - root.Position).Magnitude
		local fromCamp = (node:GetPivot().Position - state:GetAttribute("CampPos")) * Vector3.new(1, 0, 1)
		if d < 600 and fromCamp.Magnitude > 70 and (not target or d < (target:GetPivot().Position - root.Position).Magnitude) then
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
		if tool.Parent ~= char then
			hum:EquipTool(tool)
			task.wait(0.2)
		end
		tool:Activate()
		task.wait(0.1)
		tool:Deactivate() -- เหมือนปล่อยเมาส์ (ไม่งั้น Roblox ไม่ยิง Activated ครั้งถัดไป)
		task.wait(0.6)
	end
	shot("play_chop", 0.5)
	cam.CameraType = Enum.CameraType.Custom
end
task.wait(2.5)
-- ของตกบนพื้น -> เก็บใส่กระสอบ
local dropsNear = 0
for _, d in ipairs(Workspace:WaitForChild("Drops"):GetChildren()) do
	if d.PrimaryPart and (d.PrimaryPart.Position - root.Position).Magnitude < 30 then
		dropsNear += 1
		Remotes.Get("PickupDrop"):FireServer(d)
	end
end
check("wood dropped on ground", dropsNear > 0, dropsNear)
task.wait(1)
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

-- 2.5) ภาพถือเครื่องมือแต่ละชิ้น (เช็กมุมจับ)
if SHOTS then
	refreshChar()
	moveTo(campPos + Vector3.new(0, 4, 26))
	root.Anchored = true
	local k = 0
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") then
			k += 1
			hum:EquipTool(t)
			task.wait(0.6)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(root.Position + root.CFrame.RightVector * 8 + Vector3.new(0, 2, 0), root.Position + Vector3.new(0, 1.5, 0))
			shot("hold_" .. k, 0.3)
			-- ทิศของส่วนหัวเครื่องมือเทียบกับตัว (หน้า = -Z, ขวา = +X, ขึ้น = +Y)
			local h = t:FindFirstChild("Handle")
			if h then
				local best, bd = nil, -1
				for _, p in ipairs(t:GetDescendants()) do
					if p:IsA("BasePart") then
						local rel = root.CFrame:VectorToObjectSpace(p.Position - h.Position)
						local vol = p.Size.X * p.Size.Y * p.Size.Z
						if rel.Y > 0.5 and vol > bd then
							best, bd = rel, vol
						end
					end
				end
				local function axis(v)
					local r = root.CFrame:VectorToObjectSpace(v)
					return string.format("(%.2f,%.2f,%.2f)", r.X, r.Y, r.Z)
				end
				print(string.format("[TEST] hold %s headRel=%s hX=%s hY=%s hZ=%s size=%s", t:GetAttribute("ItemId") or "?", tostring(best),
					axis(h.CFrame.RightVector), axis(h.CFrame.UpVector), axis(-h.CFrame.LookVector), tostring(h.Size)))
			end
			hum:UnequipTools()
		end
	end
	cam.CameraType = Enum.CameraType.Custom
	root.Anchored = false
end

-- 3) โยนไม้เข้ากองไฟ (แบบ 99 Nights: ไม่มีปุ่มกดที่กองไฟ)
moveTo(campPos + Vector3.new(9, 4, 9))
local woodHad = inventory.Wood or 0
for _ = 1, 3 do
	Remotes.Get("ThrowFuel"):FireServer()
	task.wait(0.45)
end
task.wait(2.5)
local leftover = 0
for _, d in ipairs(Workspace.Drops:GetChildren()) do
	if d.PrimaryPart and (d.PrimaryPart.Position - campPos).Magnitude < 7 then
		leftover += 1
	end
end
check("threw wood into fire", (inventory.Wood or 0) <= woodHad - 3 and leftover == 0, woodHad, inventory.Wood, leftover)
-- ภาพแคมป์
moveTo(campPos + Vector3.new(10, 5, 10))
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(24, 14, 26), campPos + Vector3.new(-4, 2, -4))
shot("play_camp", 1)
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(-70, 62, 70), campPos + Vector3.new(0, 4, 0))
shot("play_camp_aerial", 1)
cam.CFrame = CFrame.lookAt(campPos + Vector3.new(12, 6, -16), campPos + Vector3.new(-22, 3, 8))
shot("play_camp_tents", 1)
cam.CameraType = Enum.CameraType.Custom

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

-- 6.5) บอส 4 ไบโอมจากโมเดลใหม่ (กลางวัน ภาพชัด)
cmd:InvokeServer("showcase")
local bossIds = { "Terragon", "Leviathan", "TempestRoc", "Solfang" }
local bossMade = 0
for i, id in ipairs(bossIds) do
	local bx, bz = campPos.X + 8, campPos.Z + 18 -- กลางลานแคมป์ (โล่ง ไม่มีต้นไม้บัง)
	local gy = ground(bx, bz)
	moveTo(Vector3.new(bx - 20, gy + 8, bz - 30))
	task.wait(1)
	cmd:InvokeServer("spawn", id, Vector3.new(bx, gy + 3, bz))
	local m
	for _ = 1, 20 do
		for _, x in ipairs(Workspace.Animals:GetChildren()) do
			if x:GetAttribute("AnimalId") == id then
				m = x
			end
		end
		if m and m:FindFirstChild("Skin") then
			break
		end
		task.wait(0.25)
	end
	if m and m:FindFirstChild("Skin") then
		bossMade += 1
		local function frontShot(name, wait_)
			local cf, size = m:GetBoundingBox()
			local r = math.max(size.X, size.Y, size.Z)
			local look = m.PrimaryPart.CFrame.LookVector
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(cf.Position + look * r * 0.95 + m.PrimaryPart.CFrame.RightVector * r * 0.3 + Vector3.new(0, r * 0.55, 0), cf.Position)
			shot(name, wait_)
		end
		task.wait(2)
		frontShot("boss_" .. id .. "_1", 0.3)
		-- รอบอสร่ายสกิล -> ถ่ายตอนง้าง + ตอนกระแทก
		local t0 = os.clock()
		while not m:GetAttribute("Cast") and os.clock() - t0 < 12 and m.Parent do
			task.wait(0.1)
		end
		local castName = m:GetAttribute("Cast")
		local windup = m:GetAttribute("CastTime") or 1
		frontShot("boss_" .. id .. "_2", windup * 0.6)
		task.wait(math.max(0, windup * 0.4))
		frontShot("boss_" .. id .. "_3", 0.12)
		cam.CameraType = Enum.CameraType.Custom
		print(string.format("[TEST] boss %s size=%s cast=%s", id, tostring(m:GetExtentsSize()), tostring(castName)))
	else
		print("[TEST] boss missing", id)
	end
	cmd:InvokeServer("clearAnimals")
end
check("bosses spawn from new models", bossMade == #bossIds, bossMade)

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
-- สัตว์ถูกเอาออกจากเกมหมด: ต้องไม่มีตัวไหนเกิดเลย แม้ตอนกลางคืน
check("no animals in world", #Workspace.Animals:GetChildren() == 0, #Workspace.Animals:GetChildren())

-- 9) แผนที่
local okMap, MapUI = pcall(function()
	return require(script.Parent:WaitForChild("Client"):WaitForChild("MapUI"))
end)
if okMap and MapUI.Toggle then
	MapUI.Toggle()
	shot("play_map", 2.5)
	MapUI.Toggle()
end

-- 10) เครื่องมือนักพัฒนา (DEV)
do
	local dev = ReplicatedStorage.Remotes:WaitForChild("DevCmd")
	local okAll, bad = true, {}
	local calls = {
		{ "info" }, { "heal" }, { "give", "IronAxe", 1 }, { "giveCategory", "Resource", 10 },
		{ "setNight", 3 }, { "fuel" }, { "fireLevel", 1 }, { "benchLevel", 1 },
		{ "diamonds", 50 }, { "unlockAll" }, { "maxClass" }, { "speed", 1 }, { "bloodMoon" }, { "bloodMoon" }, { "tp", "camp" },
	}
	for _, c in ipairs(calls) do
		local ok, res = pcall(function()
			return dev:InvokeServer(c[1], c[2], c[3])
		end)
		if not ok or type(res) ~= "string" or res:find("❌") or res:find("⛔") then
			okAll = false
			table.insert(bad, c[1] .. "=" .. tostring(res))
		end
	end
	check("dev commands", okAll, table.concat(bad, "; "))
	local panel = player.PlayerGui:FindFirstChild("DevPanel")
	check("dev panel exists", panel ~= nil)
	if panel then
		for _, f in ipairs(panel:GetChildren()) do
			if f:IsA("Frame") then
				f.Visible = true
			end
		end
		cam.CameraType = Enum.CameraType.Custom
		shot("dev_panel", 1.5)
	end
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
