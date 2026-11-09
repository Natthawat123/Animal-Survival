--[[ ASDropProbe (server) — build_rbxlx.py --dropprobe · เสกของตกหน้าผู้เล่น แล้ว log ชิ้นส่วน/ตำแหน่งฝั่งเซิร์ฟเวอร์ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASDropProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")

-- --dropprobe=ride: สัตว์เลี้ยงน้ำ (ขนาดจริง) -> ขี่ -> พาไปน้ำลึก -> วัดยอดหัว/ตัวเทียบผิวน้ำ
local rmode = ReplicatedStorage:FindFirstChild("ASDropMode")
if rmode and rmode.Value == "ride" then
	task.spawn(function()
		local Players = game:GetService("Players")
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local state = ReplicatedStorage:WaitForChild("GameState")
		repeat
			task.wait(1)
		until state:GetAttribute("Ready") and player.Character
		task.wait(4)
		-- เข้ารอบจริงก่อน (อยู่ล็อบบี้ = ถูกดึงกลับล็อบบี้ วาร์ปไปแมพไม่ได้)
		require(Server:WaitForChild("LobbyService")):Depart(player)
		task.wait(8)
		player:SetAttribute("TestGod", true)
		state:SetAttribute("TestClock", 13)
		local AnimalService = require(Server:WaitForChild("AnimalService"))
		local MountService = require(Server:WaitForChild("MountService"))
		local Animals = require(ReplicatedStorage.Shared.Animals)
		local layout = AnimalService.ctx.Layout
		local water
		for r = 60, 1200, 20 do
			for k = 0, 23 do
				local a = k / 24 * math.pi * 2
				local x, z = math.cos(a) * r, math.sin(a) * r
				-- น้ำจริง: ผิวบนสุดเป็นวัสดุ Water และพื้นใต้น้ำลึกพอ (ไม่ใช่ลาวา/โคลน)
				local wp = RaycastParams.new()
				wp.FilterType = Enum.RaycastFilterType.Include
				wp.FilterDescendantsInstances = { workspace.Terrain }
				wp.IgnoreWater = false
				local top = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), wp)
				if top and top.Material == Enum.Material.Water then
					wp.IgnoreWater = true
					local floor = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), wp)
					if floor and top.Position.Y - floor.Position.Y > 10 then
						water = Vector3.new(x, top.Position.Y, z)
						break
					end
				end
			end
			if water then
				break
			end
		end
		print("[AS] RIDEPROBE water", water, "WL", layout.WaterLevel)
		local results = {}
		for _, el in ipairs({ "Water", "Earth" }) do
			local id = Animals.Spirits[el]
			local skin = Animals.Data[id].Model.Skin
			local shore = water + Vector3.new(0, 0, 0)
			local r0 = player.Character.HumanoidRootPart.Position
			local a = AnimalService:Spawn(id, r0 + Vector3.new(6, 2, 0), { Kind = "Spirit", SizeMult = (skin.PetScale or 1.9) * 1.35 })
			a.Pet = true
			MountService:AddPet(a)
			task.wait(1)
			MountService:Mount(player, a)
			task.wait(1)
			player.Character:PivotTo(CFrame.new(shore + Vector3.new(0, 6, 0)))
			pcall(function()
				player:RequestStreamAroundAsync(shore, 5)
			end)
			task.wait(6)
			local cf, size = a.Model:GetBoundingBox()
			local top = cf.Position.Y + size.Y / 2
			local hrp = player.Character.HumanoidRootPart
			local WS = water.Y -- ผิวน้ำจริง
			local line = string.format("[AS] RIDEPROBE %s size=%.1f petTop-surface=%.2f petBottom-surface=%.2f hrp-surface=%.2f state=%s", el, size.Y, top - WS,
				cf.Position.Y - size.Y / 2 - WS, hrp.Position.Y - WS, tostring(player.Character.Humanoid:GetState()))
			print(line)
			print("[SHOT] ride_" .. el)
			task.wait(2.5)
			MountService:Dismount(player)
			task.wait(1)
			AnimalService:Remove(a)
			task.wait(2)
		end
		print("[AS] RIDEPROBE FINISHED")
	end)
	return
end

-- --dropprobe=world: ให้พาสโลก -> เปิดห้องโลก (รหัส 1234, 3 คน) -> client ถ่ายเมนู Worlds -> จำลองทีมล้มหมด ถ่ายหน้าต่างชุบ
local wmode = ReplicatedStorage:FindFirstChild("ASDropMode")
if wmode and wmode.Value == "world" then
	task.spawn(function()
		local Players = game:GetService("Players")
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local state = ReplicatedStorage:WaitForChild("GameState")
		repeat
			task.wait(1)
		until state:GetAttribute("Ready") and player.Character
		task.wait(4)
		local world = require(Server:WaitForChild("WorldService"))
		-- จำลองว่าซื้อสร้างโลกแล้ว 1 ครั้ง (สิทธิ์ 1) แล้วกดสร้าง
		local dsv = require(Server:WaitForChild("DataService"))
		local d = dsv:Get(player)
		d.WorldCredits = (d.WorldCredits or 0) + 1
		world:Create(player, "Wolf Den", "1234", 8)
		print("[AS] WORLDPROBE credits-after=" .. tostring(d.WorldCredits))
		task.wait(1)
		local room = ReplicatedStorage.Worlds:FindFirstChild(tostring(player.UserId))
		print(string.format("[AS] WORLDPROBE room=%s locked=%s size=%s night=%s attr=%s", tostring(room ~= nil), tostring(room and room:GetAttribute("Locked")),
			tostring(room and room:GetAttribute("Size")), tostring(room and room:GetAttribute("Night")), tostring(player:GetAttribute("WorldRoom"))))
		print("[AS] WORLDPROBE open-menu")
		task.wait(26)
		world:Leave(player)
		task.wait(1)
		print(string.format("[AS] WORLDPROBE closed room=%s", tostring(ReplicatedStorage.Worlds:FindFirstChild(tostring(player.UserId)) ~= nil)))
		print("[AS] WORLDPROBE menu-noroom")
		task.wait(14)
		-- จำลองทีมล้มหมด (ภาพหน้าต่างชุบ)
		player:SetAttribute("InRun", true)
		player:SetAttribute("Downed", true)
		state:SetAttribute("WipeAt", workspace:GetServerTimeNow() + 30)
		print("[AS] WORLDPROBE wipe")
		task.wait(6)
		state:SetAttribute("WipeAt", nil)
		player:SetAttribute("Downed", false)
		player:SetAttribute("InRun", false)
		print("[AS] WORLDPROBE FINISHED")
	end)
	return
end

-- --dropprobe=overlap: วางของจากกระสอบ 10 ชิ้นจุดเดียวกัน + ดรอปแบบตัดไม้ 12 ท่อน -> นับคู่ที่ทับกัน
local mode = ReplicatedStorage:FindFirstChild("ASDropMode")
if mode and mode.Value == "overlap" then
	task.spawn(function()
		local player = game:GetService("Players"):GetPlayers()[1] or game:GetService("Players").PlayerAdded:Wait()
		local t0 = os.clock()
		repeat
			task.wait(1)
		until (player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")) or os.clock() - t0 > 240
		task.wait(5)
		local drops = require(Server:WaitForChild("DropService"))
		local cf = player.Character:GetPivot()
		local function overlaps(list)
			local n, worst = 0, 99
			for i = 1, #list do
				for j = i + 1, #list do
					local a, b = list[i], list[j]
					if a.Parent and b.Parent then
						local sa, sb = a:GetExtentsSize(), b:GetExtentsSize()
						local ra, rb = math.max(sa.X, sa.Z) * 0.4, math.max(sb.X, sb.Z) * 0.4
						local d = ((a:GetPivot().Position - b:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
						worst = math.min(worst, d - ra - rb)
						if d < ra + rb then
							n += 1
						end
					end
				end
			end
			return n, worst
		end
		-- 1) ทิ้งจากกระสอบรัวๆ ยืนที่เดิม (จุดเดียวกันหมด)
		local placed = {}
		local spot = cf.Position + cf.LookVector * 5
		for _, id in ipairs({ "Wood", "Wood", "Wood", "Stone", "Stone", "Coal", "Wood", "RawMeat", "Wood", "Iron" }) do
			table.insert(placed, drops:Spawn(id, 1, spot, { Spread = 0.5, Place = true }))
			task.wait(0.15)
		end
		task.wait(1.5)
		local n1, w1 = overlaps(placed)
		print(string.format("[AS] DROPOV place count=%d overlaps=%d worstGap=%.2f", #placed, n1, w1))
		print("[SHOT] dropov_place")
		task.wait(2)
		-- 2) แบบตัดไม้: ท่อนไม้เด้งออกจากโคนต้นทีละท่อน (มี Dir หันมาทางผู้เล่น)
		local chopAt = cf.Position + cf.RightVector * 16 + cf.LookVector * 8
		local dir = ((cf.Position - chopAt) * Vector3.new(1, 0, 1)).Unit
		local chopped = {}
		for _ = 1, 12 do
			table.insert(chopped, drops:Spawn("Wood", 1, chopAt + dir * 3, { Dir = dir, Spread = 2 }))
			task.wait(0.25)
		end
		task.wait(1.5)
		local n2, w2 = overlaps(chopped)
		print(string.format("[AS] DROPOV chop count=%d overlaps=%d worstGap=%.2f", #chopped, n2, w2))
		print("[SHOT] dropov_chop")
		task.wait(2)
		print(string.format("[AS] DROPOV FINISHED fails=%d", (n1 > 0 and 1 or 0) + (n2 > 0 and 1 or 0)))
	end)
	return
end
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
