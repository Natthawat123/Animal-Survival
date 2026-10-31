--[[
	ASRealmProbe (server) — build_rbxlx.py --realmprobe (แมพขนาดจริง)
	1) ศาลเจ้า/วิหารทุกธาตุ: ยืนหน้าประตูมิติ (ถ่าย) -> วาร์ปเข้า (ถ่ายในห้อง) -> วัดของเล่นแนบพื้นไหม [REALM] -> วาร์ปออก (ถ่าย)
	2) รังบอส ลม/ไฟ (+อื่นๆ): เดินเข้ารังจริง ให้บอสตื่นเอง (Kind Guardian) -> ปล่อย AI สู้จริง 30 วิ
	   วัดทิศหน้าบอสเทียบผู้เล่นตอนร่ายสกิล [LAIRDIR] · บอส/ผู้เล่นตกพื้น/ลอยไหม [LAIRY] · ถ่ายภาพเป็นช่วงๆ
	กล้อง: attribute ผู้เล่น ProbeCam = "behind" (หลังตัวมองไป ProbeTarget) | "side" (มุมข้างผู้เล่น+บอส)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASRealmProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
player.CharacterAdded:Wait()
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local function find(name)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
end
local t0 = os.clock()
repeat
	task.wait(3)
until (find("Sanctum_Fire") and find("Shrine_Fire") and find("Lair_Fire")) or os.clock() - t0 > 900
task.wait(6)
-- เริ่มรอบจริง (โหมดเทสต์นี้ไม่ออกจากล็อบบี้เอง) -> ผู้เล่น InRun, บอสเล็งได้, ระบบกลางคืนทำงานตามปกติ
require(Server:WaitForChild("LobbyService")):Depart(player)
require(Server:WaitForChild("DirectorService")):StartRun()
ReplicatedStorage:WaitForChild("GameState"):SetAttribute("TestClock", 13) -- ภาพทดสอบ: ตรึงกลางวัน
task.wait(10)
print("[REALM] run started inRun=" .. tostring(player:GetAttribute("InRun")))
local PortalService = require(Server:WaitForChild("PortalService"))
local AnimalService = require(Server:WaitForChild("AnimalService"))
-- อมตะระหว่างเทสต์ (ธงอมตะของเกม: ไม่โดนดาเมจ ไม่ล้ม -> รอบไม่จบกลางเทสต์)
player:SetAttribute("TestGod", true)
task.spawn(function()
	while true do
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = h.MaxHealth
		end
		task.wait(0.2)
	end
end)
local function root()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function shot(n)
	task.wait(0.6)
	print("[SHOT] rp_" .. n)
	task.wait(0.8)
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(pos, ignore)
	rp.FilterDescendantsInstances = { ignore, player.Character }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rp)
	return hit and hit.Position.Y
end
local function standAt(pos, look)
	local c = player.Character
	c:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), Vector3.new(look.X, pos.Y + 3, look.Z)))
	pcall(function()
		player:RequestStreamAroundAsync(pos, 5)
	end)
	task.wait(4) -- รอเครื่องผู้เล่นโหลดพื้นที่ (StreamingEnabled) ก่อนถ่าย
end

---------------------------------------------------------------- 1) ประตูมิติ (--realmprobe=lairs ข้ามส่วนนี้)
local onlyV = ReplicatedStorage:FindFirstChild("ASRealmOnly") and ReplicatedStorage.ASRealmOnly.Value or ""
local lairsOnly = onlyV:sub(1, 5) == "lairs"
-- "lairs:Fire@MeteorRoar" = สั่งบอสใช้สกิลนั้นทันทีหลังเปิดตัว + ถ่ายถี่ๆ
local forceSkill = onlyV:match("@(%w+)$")
onlyV = onlyV:gsub("@.*$", "")
local lairList = onlyV:match("^lairs:(.+)$") and string.split(onlyV:match("^lairs:(.+)$"), ",") or { "Air", "Fire", "Earth", "Water" }
for _, kind in ipairs(lairsOnly and {} or { "Shrine", "Sanctum" }) do
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local m = find(kind .. "_" .. el)
		local out = m and m:FindFirstChild("PortalOut", true)
		local veil = out and out:FindFirstChild("PortalVeil", true)
		if not veil then
			print("[REALM] MISSING portal " .. kind .. "_" .. el)
			continue
		end
		local front = (veil.CFrame * CFrame.new(0, 0, -22)).Position
		standAt(front, veil.Position)
		player:SetAttribute("ProbeTarget", veil.Position)
		player:SetAttribute("ProbeCam", "behind")
		task.wait(2)
		-- ซุ้มลอยไหม: ก้นซุ้มเทียบดิน
		local acf, asz = out:GetBoundingBox()
		local tp = RaycastParams.new()
		tp.FilterType = Enum.RaycastFilterType.Include
		tp.FilterDescendantsInstances = { workspace.Terrain }
		local gh = workspace:Raycast(acf.Position + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), tp)
		print(string.format("[REALM] %s_%s portal bottom-ground=%.1f", kind, el, (acf.Position.Y - asz.Y / 2) - (gh and gh.Position.Y or 0)))
		shot(kind .. el .. "_out")
		-- เข้า
		PortalService:Teleport(player, veil:GetAttribute("Dest"), veil:GetAttribute("DestLook"))
		task.wait(3)
		local realm = m:FindFirstChild("Realm", true)
		local floor = realm and realm:FindFirstChild("RealmFloor")
		local top = realm and realm:GetAttribute("FloorTop") or 0
		local r = root()
		print(string.format("[REALM] %s_%s inside player-floor=%.1f", kind, el, r and (r.Position.Y - 3 - top) or -999))
		-- ของเล่นแนบพื้นไหม
		for _, n in ipairs({ "Cage", "Obelisk1", "Obelisk2", "Obelisk3", "VaultChest" }) do
			local o = m:FindFirstChild(n, true)
			if o then
				local ocf, osz = o:GetBoundingBox()
				print(string.format("[REALM] %s_%s %s bottom-floor=%.1f", kind, el, n, (ocf.Position.Y - osz.Y / 2) - top))
			end
		end
		local center = floor and floor.Position or (r and r.Position)
		player:SetAttribute("ProbeTarget", center)
		shot(kind .. el .. "_in")
		-- มุมกว้างเห็นทั้งเกาะ (ยืนที่จุดเข้า มองไปอาคาร) จากสูง
		player:SetAttribute("ProbeCam", "wide")
		shot(kind .. el .. "_wide")
		player:SetAttribute("ProbeCam", "behind")
		-- ออก
		local back = realm and realm:FindFirstChild("PortalBack", true)
		local bveil = back and back:FindFirstChild("PortalVeil", true)
		if bveil then
			PortalService:Teleport(player, bveil:GetAttribute("Dest"), bveil:GetAttribute("DestLook"))
			task.wait(3)
			local r2 = root()
			local g2 = r2 and groundBelow(r2.Position)
			print(string.format("[REALM] %s_%s back player-ground=%.1f", kind, el, (r2 and g2) and (r2.Position.Y - 3 - g2) or -999))
		else
			print("[REALM] MISSING back portal " .. kind .. "_" .. el)
		end
		-- ทำความสะอาดผู้พิทักษ์ที่ตื่นในห้อง
		for _, a in ipairs(AnimalService:All()) do
			if a.Kind == "Guardian" and not a.Model:GetAttribute("IsBoss") then
				AnimalService:Remove(a)
			end
		end
	end
end

---------------------------------------------------------------- 1.5) ซากวิหาร (ธาตุละ 1 แห่ง)
for _, el in ipairs(lairsOnly and {} or { "Earth", "Water", "Air", "Fire" }) do
	local rm = find("Ruins_" .. el)
	local b = rm and rm:FindFirstChild("RuinBuilding")
	if rm then
		local cf0, sz0 = (b or rm):GetBoundingBox()
		local dir = (Vector3.new(-cf0.X, 0, -cf0.Z)).Unit
		local stand = cf0.Position + dir * (math.max(sz0.X, sz0.Z) * 0.5 + 25)
		standAt(Vector3.new(stand.X, cf0.Position.Y - sz0.Y / 2, stand.Z), cf0.Position)
		local tp = RaycastParams.new()
		tp.FilterType = Enum.RaycastFilterType.Include
		tp.FilterDescendantsInstances = { workspace.Terrain }
		local gh = workspace:Raycast(cf0.Position + Vector3.new(0, 100, 0), Vector3.new(0, -300, 0), tp)
		print(string.format("[RUIN] %s %s bottom-ground=%.1f", el, b and b.Name or "none", (cf0.Position.Y - sz0.Y / 2) - (gh and gh.Position.Y or 0)))
		player:SetAttribute("ProbeTarget", cf0.Position)
		player:SetAttribute("ProbeCam", "behind")
		shot("ruin" .. el)
	end
end

---------------------------------------------------------------- 2) รังบอส (สู้จริง)
player:SetAttribute("ProbeCam", "")
local IDS = { Earth = "Terragon", Water = "Leviathan", Air = "TempestRoc", Fire = "Solfang" }
for _, el in ipairs(onlyV == "realms" and {} or lairList) do
	local lair = find("Lair_" .. el)
	local sp = lair and lair:FindFirstChild("BossSpawn")
	if not sp then
		print("[LAIR] MISSING " .. el)
		continue
	end
	local c = sp.Position
	local dir = (Vector3.new(-c.X, 0, -c.Z)).Unit
	local stand = c + dir * 55
	local tp = RaycastParams.new()
	tp.FilterType = Enum.RaycastFilterType.Exclude
	tp.FilterDescendantsInstances = { player.Character }
	local gh = workspace:Raycast(stand + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), tp)
	standAt(Vector3.new(stand.X, gh and gh.Position.Y or c.Y, stand.Z), c)
	-- รอบอสตื่นเอง (SpiritService.Tick)
	local boss
	for _ = 1, 40 do
		task.wait(0.5)
		for _, a in ipairs(AnimalService:All()) do
			if a.Id == IDS[el] and not a.Dead then
				boss = a
			end
		end
		if boss then
			break
		end
	end
	if not boss then
		local SS = require(Server:WaitForChild("SpiritService"))
		local L = SS.lairs and SS.lairs[el]
		local r = root()
		print(string.format("[LAIR] boss did not wake %s dist=%.0f inRun=%s cleared=%s hasBoss=%s phase=%s", el,
			(r and L) and (r.Position - L.Pos).Magnitude or -1, tostring(player:GetAttribute("InRun")), tostring(L and L.Cleared), tostring(L and L.Boss ~= nil),
			tostring(workspace:FindFirstChild("GameState") and workspace.GameState:GetAttribute("Phase"))))
		if L and not L.Boss and not L.Cleared then
			SS:WakeLair(L, player) -- ปลุกตรงๆ (ยังเป็นบอสรังจริง) เพื่อทดสอบต่อ
			task.wait(1)
			for _, a in ipairs(AnimalService:All()) do
				if a.Id == IDS[el] and not a.Dead then
					boss = a
				end
			end
		end
		if not boss then
			continue
		end
	end
	player:SetAttribute("ProbeCam", "side")
	task.wait(9) -- ฉากเปิดตัว
	if forceSkill then
		boss.NextAbility = math.huge
		while boss.Casting do
			task.wait(0.2)
		end
		print("[LAIR] force " .. forceSkill)
		require(Server:WaitForChild("BossAbilities")).Run(AnimalService.ctx, boss, forceSkill, player)
		local tf = os.clock()
		for k = 1, 12 do
			while os.clock() - tf < 0.9 + k * 0.3 do
				task.wait()
			end
			shot(string.format("force%s_%02d", forceSkill, k))
		end
		boss.NextAbility = os.clock() + 2
	end
	local t1 = os.clock()
	local lastCast
	local n = 0
	while os.clock() - t1 < 32 and not boss.Dead do
		task.wait(0.5)
		local r = root()
		if r and boss.Root.Parent then
			local to = ((r.Position - boss.Root.Position) * Vector3.new(1, 0, 1))
			local fw = boss.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local off = (to.Magnitude > 1 and fw.Magnitude > 0.1) and math.deg(math.acos(math.clamp(fw.Unit:Dot(to.Unit), -1, 1))) or -1
			local cast = boss.Model:GetAttribute("Cast")
			if cast and cast ~= lastCast then
				print(string.format("[LAIRDIR] %s %s off=%.0f", el, cast, off))
			end
			lastCast = cast
			-- บอส/ผู้เล่นเทียบพื้นใต้ตัว
			local bg = groundBelow(boss.Root.Position + Vector3.new(0, 4, 0), boss.Model)
			local pg = groundBelow(r.Position, nil)
			n += 1
			if n % 4 == 0 then
				print(string.format("[LAIRST] %s dist=%.0f casting=%s nextIn=%.1f state=%s hip=%.1f", el, to.Magnitude, tostring(boss.Casting),
					(boss.NextAbility or 0) - os.clock(), tostring(boss.Model:GetAttribute("State")), boss.Hum.HipHeight + boss.Root.Size.Y / 2))
				print(string.format("[LAIRY] %s boss-ground=%s player-ground=%s", el,
					bg and string.format("%.1f", boss.Root.Position.Y - bg) or "nofloor", pg and string.format("%.1f", r.Position.Y - pg) or "nofloor"))
			end
			if n % 6 == 0 then
				shot("lair" .. el .. "_" .. n)
			end
			-- ผู้เล่นเดินวนรอบบอส (ทดสอบการหัน)
			local ang = os.clock() * 0.35
			local want = boss.Root.Position + Vector3.new(math.cos(ang) * 50, 0, math.sin(ang) * 50)
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:MoveTo(want)
			end
		end
	end
	AnimalService:Remove(boss)
	player:SetAttribute("ProbeCam", "")
	task.wait(2)
end
print("[TEST] DONE probe")
