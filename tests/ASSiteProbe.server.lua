--[[
	ASSiteProbe (server) — ใช้เฉพาะ build_rbxlx.py --siteprobe
	พาผู้เล่นไปจุดชมศาลเจ้า/ฐานบอส/วิหารทีละธาตุ (มองจากฝั่งแคมป์ + มุมเฉียง) ให้ client ถ่ายภาพ
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSiteProbe") then
	return
end
local shot = Instance.new("StringValue")
shot.Name = "ProbeShot"
shot.Parent = ReplicatedStorage
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = player.Character or player.CharacterAdded:Wait()
task.wait(12)
local function find(name)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
end
-- แมพขนาดจริงสร้างนาน: รอจนจุดสำคัญ + วิหารถูกสร้างครบ
local t0 = os.clock()
repeat
	task.wait(3)
until (find("Lair_Fire") and find("Sanctum_Fire") and find("Shrine_Fire")) or os.clock() - t0 > 900
task.wait(5)
-- ถ่ายตอนกลางวัน (กลางคืน+หมอกไบโอมไฟมองไม่เห็นอะไร)
local Lighting = game:GetService("Lighting")
task.spawn(function()
	while true do
		Lighting.ClockTime = 13
		task.wait(0.2)
	end
end)
local DIST = { Shrine = 95, Lair = 120, Sanctum = 150, Village = 150, Stronghold = 260 }
-- build_rbxlx.py --siteprobe --sitekinds=Sanctum,Shrine -> ตรวจเฉพาะชนิดที่ระบุ (เร็วกว่า)
local KINDS = { "Shrine", "Village", "Stronghold", "Sanctum", "Lair" }
local only = ReplicatedStorage:FindFirstChild("ASSiteKinds")
if only and only.Value ~= "" then
	KINDS = string.split(only.Value, ",")
end
for _, kind in ipairs(KINDS) do
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local m = find(kind .. "_" .. el)
		if not m then
			print("[PROBE] missing " .. kind .. "_" .. el)
			continue
		end
		local c = m:GetPivot().Position
		local spawnPart = m:FindFirstChild("BossSpawn")
		if spawnPart then
			c = spawnPart.Position -- รังบอส: มองจากลานสู้ข้างในรัง
			print(string.format("[SITE] %s spawn dist-from-center=%.0f", m.Name, (Vector3.new(c.X, 0, c.Z) - Vector3.new(m:GetPivot().X, 0, m:GetPivot().Z)).Magnitude))
		end
		-- วัดอาคาร: ลอย/จม (ก้นอาคารเทียบพื้น Terrain) + ชนได้จริงไหม (ยิงลงที่มุม: ชนแบบกล่อง = โดนยอดกล่องทุกจุด)
		local big
		for _, ch in ipairs(m:GetChildren()) do
			if ch:IsA("Model") and ch.Name ~= "Cage" then
				local _, sz = ch:GetBoundingBox()
				if not big or sz.Magnitude > big[2].Magnitude then
					big = { ch, sz }
				end
			end
		end
		if big then
			local bcf, sz = big[1]:GetBoundingBox()
			local bottom = bcf.Position.Y - sz.Y / 2
			local tp = RaycastParams.new()
			tp.FilterType = Enum.RaycastFilterType.Include
			tp.FilterDescendantsInstances = { workspace.Terrain }
			local mp = RaycastParams.new()
			mp.FilterType = Enum.RaycastFilterType.Include
			mp.FilterDescendantsInstances = { big[1] }
			local out = {}
			for _, o in ipairs({ { 0, 0 }, { 0.42, 0.42 }, { -0.42, 0.42 }, { 0.42, -0.42 }, { -0.42, -0.42 } }) do
				local p = bcf * Vector3.new(sz.X * o[1], 0, sz.Z * o[2])
				local th = workspace:Raycast(Vector3.new(p.X, bottom + 300, p.Z), Vector3.new(0, -800, 0), tp)
				local mh = workspace:Raycast(Vector3.new(p.X, bottom + sz.Y + 20, p.Z), Vector3.new(0, -(sz.Y + 60), 0), mp)
				table.insert(out, string.format("g%+.0f m%s", th and th.Position.Y - bottom or -999, mh and string.format("%.0f", mh.Position.Y - bottom) or "-"))
			end
			local coll = 0
			for _, d in ipairs(big[1]:GetDescendants()) do
				if d:IsA("BasePart") and d.CanCollide then
					coll += 1
				end
			end
			print(string.format("[SITE] %s_%s %s size=%.0f,%.0f,%.0f collide=%d | %s", kind, el, big[1].Name, sz.X, sz.Y, sz.Z, coll, table.concat(out, " ")))
		end
		-- ของเล่นอยู่บนอาคารไหม + มีทางขึ้นไหม
		local play = m:FindFirstChild("Cage", true) or m:FindFirstChild("Obelisk1", true) or (kind == "Village" and m:FindFirstChild("Chest", true))
		local playPos = play and play:GetPivot().Position
		if playPos then
			print(string.format("[PLAY] %s item=%s up=%.0f stairs=%s lift=%s", m.Name, play.Name, playPos.Y - c.Y, tostring(m:FindFirstChild("Stairs", true) ~= nil), tostring(m:FindFirstChild("LiftPad", true) ~= nil)))
		end
		local toCamp = Vector3.new(-c.X, 0, -c.Z).Unit
		local side = toCamp:Cross(Vector3.yAxis)
		local d = DIST[kind]
		local views = { { toCamp * d + Vector3.new(0, d * 0.35, 0), "front" }, { (toCamp + side).Unit * d * 0.8 + Vector3.new(0, d * 0.12, 0), "side" }, { toCamp * d * 1.7 + Vector3.new(0, d * 1.3, 0), "top" } }
		if playPos and kind ~= "Lair" then
			table.insert(views, { playPos - c + toCamp * 40 + Vector3.new(0, 22, 0), "play", playPos })
		end
		for _, v in ipairs(views) do
			local cam = c + v[1]
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = true
				char:PivotTo(CFrame.new(cam + Vector3.new(0, 30, 0)))
			end
			pcall(function()
				player:RequestStreamAroundAsync(c, 10)
			end)
			task.wait(4)
			shot.Value = string.format("%s_%s_%s|%f,%f,%f|%f,%f,%f", kind, el, v[2], cam.X, cam.Y, cam.Z, (v[3] or c).X, v[3] and v[3].Y or c.Y + d * 0.08, (v[3] or c).Z)
			task.wait(5)
		end
	end
end
-- ป้อมชนเผ่า: วางหินกะโหลก 3 ก้อน -> ประตูต้องเปิด
local hold = find("Stronghold_Fire")
if hold then
	local SSS = game:GetService("ServerScriptService")
	local VS = require(SSS.Server.VillageService)
	local Inv = require(SSS.Server.InventoryService)
	player:SetAttribute("InRun", true)
	local gate = hold:FindFirstChild("StrongholdGate")
	local sockets = {}
	for _, d in ipairs(hold:GetDescendants()) do
		if d:GetAttribute("Stone") and d:IsA("BasePart") then
			table.insert(sockets, d)
		end
	end
	print("[STRONGHOLD] sockets=" .. #sockets .. " gateOpen=" .. tostring(gate and gate:GetAttribute("Open")))
	-- ไม่มีหิน: ต้องไม่ติด
	if sockets[1] then
		VS:PlaceStone(sockets[1], player)
		print("[STRONGHOLD] no-stone filled=" .. tostring(sockets[1]:GetAttribute("Filled")))
	end
	for _, s in ipairs(sockets) do
		Inv:Add(player, s:GetAttribute("Stone"), 1, true)
		VS:PlaceStone(s, player)
		print("[STRONGHOLD] placed " .. s:GetAttribute("Stone") .. " filled=" .. tostring(s:GetAttribute("Filled")))
	end
	task.wait(4)
	print("[STRONGHOLD] gateOpen=" .. tostring(gate and gate:GetAttribute("Open")))
	local c = hold:GetPivot().Position
	local toCamp = Vector3.new(-c.X, 0, -c.Z).Unit
	local gp = gate:GetPivot().Position
	local cam = gp + toCamp * 70 + Vector3.new(0, 30, 0)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		char:PivotTo(CFrame.new(cam + Vector3.new(0, 30, 0)))
	end
	task.wait(4)
	shot.Value = string.format("Stronghold_gate_open|%f,%f,%f|%f,%f,%f", cam.X, cam.Y, cam.Z, gp.X, gp.Y + 8, gp.Z)
	task.wait(5)
	-- ข้างในป้อม: จากหลังประตูมองไปที่วิหาร · บนยอดวิหาร
	local temple = c + (-toCamp) * 46
	for _, v in ipairs({ { gp - toCamp * 25 + Vector3.new(0, 26, 0), temple + Vector3.new(0, 14, 0), "inside" },
		{ c + toCamp * 30 + Vector3.new(0, 70, 0), temple, "aerial" }, { temple + toCamp * 20 + Vector3.new(0, 40, 0), temple + Vector3.new(0, 34, 0), "temple_top" } }) do
		char:PivotTo(CFrame.new(v[1] + Vector3.new(0, 30, 0)))
		task.wait(4)
		shot.Value = string.format("Stronghold_%s|%f,%f,%f|%f,%f,%f", v[3], v[1].X, v[1].Y, v[1].Z, v[2].X, v[2].Y, v[2].Z)
		task.wait(5)
	end
	-- หีบหัวหน้าเผ่า 3 หมู่บ้าน: เปิดแล้วต้องได้หินกะโหลกเข้ากระสอบ
	local Loot = require(SSS.Server.LootService)
	for _, vn in ipairs({ "Village_Earth", "Village_Water", "Village_Air" }) do
		local vm = find(vn)
		local chief
		for _, d in ipairs(vm and vm:GetDescendants() or {}) do
			if d:IsA("Model") and d:GetAttribute("KeyStone") then
				chief = d
			end
		end
		if chief then
			local key = chief:GetAttribute("KeyStone")
			local before = Inv:Count(player, key)
			local pr = chief:FindFirstChildWhichIsA("ProximityPrompt", true)
			Loot:Open(chief, player)
			print(string.format("[STRONGHOLD] chest %s key=%s before=%d after=%d prompt=%s los=%s", vn, key, before, Inv:Count(player, key), tostring(pr ~= nil), tostring(pr and pr.RequiresLineOfSight)))
		else
			print("[STRONGHOLD] chest " .. vn .. " NO CHIEF CHEST")
		end
	end
	VS:ResetStronghold()
	task.wait(1)
	print("[STRONGHOLD] after reset gateOpen=" .. tostring(gate:GetAttribute("Open")))
end
shot.Value = "DONE"
