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
local DIST = { Shrine = 95, Lair = 120, Sanctum = 150, Ruins = 80 }
for _, kind in ipairs({ "Shrine", "Ruins", "Sanctum", "Lair" }) do
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
		local play = m:FindFirstChild("Cage", true) or m:FindFirstChild("Obelisk1", true)
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
shot.Value = "DONE"
