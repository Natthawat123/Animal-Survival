--[[ ASDropProbe (server) — build_rbxlx.py --dropprobe · เสกของตกหน้าผู้เล่น แล้ว log ชิ้นส่วน/ตำแหน่งฝั่งเซิร์ฟเวอร์ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASDropProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local ev = Instance.new("RemoteEvent")
ev.Name = "DropProbe"
ev.Parent = ReplicatedStorage

local function report(tag, m)
	local r = m.PrimaryPart
	local n, vis, lo = 0, 0, math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			n += 1
			if p.Transparency < 1 then
				vis += 1
				lo = math.min(lo, p.Position.Y)
			end
		end
	end
	-- พื้นจริงใต้ของ (Terrain + สิ่งที่ชนได้) -> ช่องว่างใต้ของ (gap > 0.6 = ลอย)
	local gy = -999
	if r then
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(r.Position + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), rp)
		gy = hit and hit.Position.Y or -999
	end
	print(string.format("[AS] DROP %s %s parts=%d vis=%d root=%s anch=%s visLowY=%.2f groundY=%.2f gap=%.2f rootH=%.2f",
		tag, m.Name, n, vis, r and tostring(r.Position) or "nil", r and tostring(r.Anchored) or "-", lo, gy, lo - gy, r and r.Size.Y or 0))
end

ev.OnServerEvent:Connect(function(player, what)
	local drops = require(Server:WaitForChild("DropService"))
	if what == "inv" then
		local inv = require(Server:WaitForChild("InventoryService"))
		print("[AS] DROP inv Wood=", inv:Count(player, "Wood"), "Stone=", inv:Count(player, "Stone"), "Meat=", inv:Count(player, "RawMeat"), "cap=", inv:Capacity(player))
		return
	end
	-- เช็กแถบเครื่องมือ Roblox: สิ่งก่อสร้างเป็น Tool + แจ้งเตือนแบบใหม่
	local inv = require(Server:WaitForChild("InventoryService"))
	inv:Add(player, "LogWall", 3)
	inv:Add(player, "Lantern", 1)
	local notify = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Notify")
	if notify then task.spawn(function()
		task.wait(4.5) -- ให้ขึ้นตรงกับตอนถ่ายภาพ drop_view
		notify:FireClient(player, "🔨 คราฟต์สำเร็จ: กำแพงไม้ x3", "Good")
		notify:FireClient(player, "🐾 ฝูงสัตว์ระลอกที่ 1 กำลังมุ่งหน้ามาที่กองไฟ!", "Danger")
		notify:FireClient(player, "🌙 คืนนี้ค่อนข้างสงบ... ฝูงสัตว์จะบุกแคมป์ในอีก 4 คืน", "Info")
	end) end
	local cf = player.Character:GetPivot()
	local base = cf.Position + cf.LookVector * 8
	drops:Spawn("Wood", 3, base + cf.RightVector * -3)
	drops:Spawn("Stone", 2, base)
	drops:Spawn("RawMeat", 1, base + cf.RightVector * 3)
	-- แบบทิ้งจากกระสอบ (วางลงพื้นทันที)
	drops:Spawn("Coal", 1, cf.Position + cf.LookVector * 5 + cf.RightVector * 6, { Spread = 0.5, Place = true })
	drops:Spawn("Bone", 1, cf.Position + cf.LookVector * 5 - cf.RightVector * 6, { Spread = 0.5, Place = true })
	-- ทดสอบหนัก: 40 ชิ้นรอบตัว (ในดิน/บนพื้น/กลางอากาศ/โยน/ใต้หลังคาโต๊ะคราฟต์/วางทันที)
	local ids = { "Wood", "Stone", "Coal", "Bone", "Iron", "Fiber", "Berries", "RawMeat", "Pelt", "Bandage" }
	local rng = Random.new(7)
	for k = 1, 40 do
		local a = k / 40 * math.pi * 2
		local r = 6 + (k % 5) * 6
		local p = cf.Position + Vector3.new(math.cos(a) * r, ({ -4, 0, 3, 15, -1.5 })[k % 5 + 1], math.sin(a) * r)
		local opts = {}
		if k % 7 == 0 then
			opts.Velocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(10, 40), rng:NextNumber(-20, 20))
		elseif k % 7 == 3 then
			opts.Place = true
		end
		drops:Spawn(ids[k % #ids + 1], 1, p, opts)
	end
	local bench = workspace:FindFirstChild("Workbench", true)
	if bench then
		local bp = bench:GetPivot().Position
		for k = 1, 4 do
			drops:Spawn(ids[k], 1, bp + Vector3.new(k - 2, 6, 0))
		end
	end
	task.delay(9, function()
		local tp = RaycastParams.new()
		tp.FilterType = Enum.RaycastFilterType.Include
		tp.FilterDescendantsInstances = { workspace.Terrain }
		tp.IgnoreWater = false
		local cp = RaycastParams.new()
		cp.FilterType = Enum.RaycastFilterType.Exclude
		cp.RespectCanCollide = true
		cp.IgnoreWater = false
		local ex = { workspace.Drops }
		for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
			table.insert(ex, pl.Character)
		end
		cp.FilterDescendantsInstances = ex
		local total, fell, float = 0, 0, 0
		for _, m in ipairs(workspace.Drops:GetChildren()) do
			local r = m.PrimaryPart
			if r then
				total += 1
				local lo = math.huge
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") and d.Transparency < 1 then
						lo = math.min(lo, d.Position.Y - d.Size.Y / 2)
					end
				end
				local T = workspace:Raycast(r.Position + Vector3.new(0, 60, 0), Vector3.new(0, -400, 0), tp)
				local S = workspace:Raycast(r.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -400, 0), cp)
				local g = (S and (not T or S.Position.Y >= T.Position.Y - 0.5)) and S.Position.Y or (T and T.Position.Y or -999)
				local d = lo - g
				local bad = d < -0.8 and "FELL" or (d > 1.2 and "FLOAT" or nil)
				if bad == "FELL" then
					fell += 1
				elseif bad == "FLOAT" then
					float += 1
				end
				if bad then
					print(string.format("[AS] DROPBAD %s %s lo=%.2f ground=%.2f d=%.2f anch=%s", bad, m.Name, lo, g, d, tostring(r.Anchored)))
				end
			end
		end
		print(string.format("[AS] DROPTEST total=%d fell=%d float=%d", total, fell, float))
	end)
	-- โยนเข้ากองไฟ: ต้องลอยโค้งไปลงกองไฟ ไม่พุ่งขึ้นฟ้า แล้วถูกเผา
	local campSvc = require(Server:WaitForChild("CampService"))
	local fire = campSvc:FirePosition()
	if fire then
		task.delay(2, function()
			local before = {}
			for _, m in ipairs(workspace.Drops:GetChildren()) do
				before[m] = true
			end
			for k = 1, 3 do
				drops:Throw(player, "Wood", 1, fire + Vector3.new(0, 1, 0))
				task.wait(0.4)
			end
			local thrown = {}
			for _, m in ipairs(workspace.Drops:GetChildren()) do
				if not before[m] then
					table.insert(thrown, m)
				end
			end
			local maxUp = -999
			for _ = 1, 30 do
				for _, m in ipairs(thrown) do
					if m.Parent and m.PrimaryPart then
						maxUp = math.max(maxUp, m.PrimaryPart.Position.Y - fire.Y)
					end
				end
				task.wait(0.1)
			end
			local left = 0
			for _, m in ipairs(thrown) do
				if m.Parent then
					left += 1
				end
			end
			print(string.format("[AS] THROWTEST thrown=%d maxAboveFire=%.1f stillThere=%d", #thrown, maxUp, left))
		end)
	end
	for _, t in ipairs({ 0.3, 2, 6 }) do
		task.delay(t, function()
			for _, m in ipairs(workspace.Drops:GetChildren()) do
				report("server@" .. t, m)
			end
		end)
	end
end)
