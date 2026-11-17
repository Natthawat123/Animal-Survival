--[[ ASTpProbe (server) — build_rbxlx.py --tpprobe · หินวาร์ป: วาง 3 อัน (ในแคมป์ + นอกแคมป์ไกลๆ) -> เปิดเมนู -> วาร์ป -> เช็กตำแหน่ง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASTpProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
local camp = ctx.CampPosition
local root = player.Character.HumanoidRootPart
local Recipes = require(ReplicatedStorage.Shared.Recipes)
print("[AS] TPPROBE recipe=" .. tostring(Recipes.ById and Recipes.ById.Teleporter ~= nil))
local added = S.InventoryService:Add(player, "Teleporter", 9, true)
print("[AS] TPPROBE added=" .. tostring(added) .. " bag=" .. S.InventoryService:Count(player, "Teleporter"))

-- จับข้อความแจ้งเตือน (วางไม่ได้เพราะอะไร)
local notify0 = ctx.Notify
ctx.Notify = function(pl, text, kind)
	print("[AS] TPPROBE notify " .. tostring(text))
	return notify0(pl, text, kind)
end
-- จุดวาง: ในแคมป์ 1 + นอกแคมป์ไกลๆ บนพื้นดินจริง (ไม่ใช่น้ำ/ลาวา/ชัน) 2 จุด
local layout = ctx.Layout
local function landAt(dir, r0)
	for r = r0, r0 + 400, 40 do
		for k = 0, 11 do
			local a = dir + k * math.pi / 6
			local x, z = camp.X + math.cos(a) * r, camp.Z + math.sin(a) * r
			local h, _, lava = layout:HeightAt(x, z)
			local h2 = layout:HeightAt(x + 6, z)
			local h3 = layout:HeightAt(x, z + 6)
			if not lava and h > layout.WaterLevel + 3 and math.abs(h2 - h) < 2 and math.abs(h3 - h) < 2 then
				return Vector3.new(x, h, z)
			end
		end
	end
end
local spots = { camp + Vector3.new(40, 0, -30), landAt(2.3, 380), landAt(5.5, 380) }
local models = {}
for i, p in ipairs(spots) do
	S.DevService:Teleport(player, p + Vector3.new(0, 3, 14))
	task.wait(2.5)
	local ok = S.BuildingService:Place(player, "Teleporter", CFrame.new(p))
	task.wait(0.5)
	local m
	for _, s in ipairs(S.BuildingService:All()) do
		if s:GetAttribute("Kind") == "Teleporter" and ((s:GetPivot().Position - p) * Vector3.new(1, 0, 1)).Magnitude < 3 then
			m = s
		end
	end
	models[i] = m
	print(string.format("[AS] TPPROBE place%d ok=%s model=%s tpId=%s num=%s fromCamp=%d", i, tostring(ok), tostring(m ~= nil), tostring(m and m:GetAttribute("TpId")), tostring(m and m:GetAttribute("TpNum")), math.floor((p - camp).Magnitude)))
end
-- วัดพื้นรอบหินทุกอัน (ศูนย์กลาง + ขอบ 8 จุด + ห่างออกไป 8 สตั๊ด) เทียบความสูงลาน
do
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	for i, m in ipairs(models) do
		if m then
			local c = m:GetPivot().Position
			local parts = {}
			for _, r in ipairs({ 0, 4.7, 8, 12 }) do
				local ys = {}
				for k = 0, (r == 0 and 0 or 7) do
					local a2 = k / 8 * math.pi * 2
					local q = c + Vector3.new(math.cos(a2) * r, 0, math.sin(a2) * r)
					local h = workspace:Raycast(q + Vector3.new(0, 40, 0), Vector3.new(0, -100, 0), rp)
					table.insert(ys, h and string.format("%.1f%s", h.Position.Y - c.Y, h.Material == Enum.Material.Water and "w" or "") or "x")
				end
				table.insert(parts, "r" .. r .. "[" .. table.concat(ys, " ") .. "]")
			end
			print(string.format("[AS] TPPROBE ground%d pivotY=%.1f layoutY=%.1f %s", i, c.Y, layout:HeightAt(c.X, c.Z), table.concat(parts, " ")))
		end
	end
end
do -- โครงสร้างหินวาร์ป: ความสูงแต่ละชิ้นเทียบจุดวาง
	local m = models[1]
	if m then
		local py = m:GetPivot().Position.Y
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("Model") then
				local cf, sz = c:GetBoundingBox()
				print(string.format("[AS] TPPROBE part %s model bottom=%.2f top=%.2f", c.Name, cf.Y - sz.Y / 2 - py, cf.Y + sz.Y / 2 - py))
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("BasePart") and (d.Name == "Center Circle" or d.Name == "Under Circle") then
						print(string.format("[AS] TPPROBE   %s y=%.2f size=%s up=%s collide=%s shape=%s", d.Name, d.Position.Y - py, tostring(d.Size), tostring(d.CFrame.UpVector), tostring(d.CanCollide), d:IsA("Part") and d.Shape.Name or d.ClassName))
					end
				end
			elseif c:IsA("BasePart") then
				print(string.format("[AS] TPPROBE part %s y=%.2f sizeY~%.2f collide=%s", c.Name, c.Position.Y - py, c.Size.Y, tostring(c.CanCollide)))
			end
		end
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		print("[AS] TPPROBE hip=" .. tostring(hum and hum.HipHeight))
	end
end
local pins = ReplicatedStorage:FindFirstChild("TeleporterPins")
print("[AS] TPPROBE pins=" .. (pins and #pins:GetChildren() or -1) .. " lim=" .. tostring(player:GetAttribute("Lim_Teleporter")))

-- ภาพหินวาร์ปใกล้ๆ (หินอันที่ 2 นอกแคมป์)
ReplicatedStorage:SetAttribute("TpShot", "model")
task.wait(5)
-- เปิดเมนูที่หิน 2 -> วาร์ปไปหิน 3
local m2, m3 = models[2], models[3]
if m2 and m3 then
	S.DevService:Teleport(player, m2:GetPivot().Position + Vector3.new(0, 4, 0)) -- ยืนบนหิน 2
	task.wait(2.5)
	S.TeleporterService:OpenMenu(player, m2)
	task.wait(1.2)
	ReplicatedStorage:SetAttribute("TpShot", "menu")
	task.wait(4)
	S.TeleporterService:Go(player, m2:GetAttribute("TpId"), m3:GetAttribute("TpId"))
	task.wait(4)
	root = player.Character.HumanoidRootPart
	local d = ((root.Position - m3:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
	print(string.format("[AS] TPPROBE warp 2->3 distToDest=%.1f y=%.1f destY=%.1f", d, root.Position.Y, m3:GetPivot().Position.Y))
	ReplicatedStorage:SetAttribute("TpShot", "arrived")
	task.wait(4)
	-- ห่างจากหิน = วาร์ปไม่ได้
	S.DevService:Teleport(player, m3:GetPivot().Position + Vector3.new(60, 3, 0))
	task.wait(2)
	local before = player.Character.HumanoidRootPart.Position
	S.TeleporterService.last[player] = nil
	S.TeleporterService:Go(player, m3:GetAttribute("TpId"), models[1]:GetAttribute("TpId"))
	task.wait(3)
	print(string.format("[AS] TPPROBE farUse moved=%.1f (expect ~0)", (player.Character.HumanoidRootPart.Position - before).Magnitude))
	ReplicatedStorage:SetAttribute("TpShot", "map")
	task.wait(5)
	-- ขี่ลูกสัตว์แล้ววาร์ป: สัตว์ต้องไปด้วย + ยังขี่อยู่ + หินต้นทางไม่พัง (ชิ้นส่วนไม่ขยับ)
	local function partSnap(m)
		local t = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				t[d] = d.CFrame
			end
		end
		return t
	end
	local function moved(m, snap)
		local worst = 0
		for d, cf in pairs(snap) do
			if d.Parent then
				worst = math.max(worst, (d.Position - cf.Position).Magnitude)
			end
		end
		return worst
	end
	local Animals = require(ReplicatedStorage.Shared.Animals)
	local id = Animals.Spirits.Earth
	S.DevService:Teleport(player, m3:GetPivot().Position + Vector3.new(0, 4, 0))
	task.wait(2.5)
	local okP, pet = pcall(S.AnimalService.Spawn, S.AnimalService, id, m3:GetPivot().Position + Vector3.new(6, 2, 0), { Kind = "Spirit", SizeMult = Animals.Data[id].Model.Skin.PetScale or 1.9, Yaw = 0 })
	if okP and pet then
		pet.Pet = true
		pet.Model:SetAttribute("Pet", true)
		S.MountService:AddPet(pet)
		task.wait(1.5)
		S.MountService:Mount(player, pet)
		task.wait(1)
		S.DevService:Teleport(player, m3:GetPivot().Position + Vector3.new(0, 6, 0))
		task.wait(2)
		local snap3 = partSnap(m3)
		S.TeleporterService.last[player] = nil
		S.TeleporterService:Go(player, m3:GetAttribute("TpId"), m2:GetAttribute("TpId"))
		task.wait(1)
		local snapMid = moved(m3, snap3)
		task.wait(3)
		root = player.Character.HumanoidRootPart
		local petD = ((pet.Root.Position - m2:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
		local meD = ((root.Position - m2:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
		print(string.format("[AS] TPPROBE %s ride_warp riding=%s petToDest=%.1f meToDest=%.1f", (player:GetAttribute("Riding") and petD < 10 and meD < 6) and "PASS" or "FAIL", tostring(player:GetAttribute("Riding")), petD, meD))
		local gy = m2:GetPivot().Position.Y
		local feet = pet.Root.Position.Y - pet.Root.Size.Y / 2
		print(string.format("[AS] TPPROBE ride_height petRootY=%.1f padY=%.1f meY=%.1f", pet.Root.Position.Y, gy, root.Position.Y))
		print(string.format("[AS] TPPROBE %s pad_not_broken srcMaxMove=%.2f", (snapMid < 0.05 and moved(m3, snap3) < 0.05) and "PASS" or "FAIL", math.max(snapMid, moved(m3, snap3))))
		ReplicatedStorage:SetAttribute("TpShot", "ride_arrived")
		task.wait(4)
		S.MountService:Dismount(player)
	else
		print("[AS] TPPROBE FAIL pet_spawn " .. tostring(pet))
	end
end
-- วัดลอย: (1) เท้าผู้เล่นห่างผิวลานหลังวาร์ป/ยืนเอง (2) ขอบลานบนพื้นเอียงห่างดิน
local function footGap()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		return 99
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char }
	rp.RespectCanCollide = true
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0), rp)
	local feet = hrp.Position.Y - (hum.HipHeight + hrp.Size.Y / 2)
	return hit and (feet - hit.Position.Y) or 99, hit and hit.Instance:GetFullName() or "none"
end
local fails2 = 0
for i, m in ipairs(models) do
	if m and models[i % #models + 1] then
		local o = models[i % #models + 1]
		S.DevService:Teleport(player, o:GetPivot().Position + Vector3.new(0, 4, 0))
		task.wait(2.5)
		S.TeleporterService.last[player] = nil
		S.TeleporterService:Go(player, o:GetAttribute("TpId"), m:GetAttribute("TpId"))
		task.wait(3.5)
		local g, on = footGap()
		if math.abs(g) > 0.6 then
			fails2 += 1
		end
		print(string.format("[AS] TPPROBE %s foot_after_warp%d gap=%.2f on=%s", math.abs(g) <= 0.6 and "PASS" or "FAIL", i, g, on))
	end
end
-- พื้นเอียง: หาจุดชัน แล้ววางหินวาร์ป -> วัดช่องใต้ขอบลาน (ตัดฐานหินออก = ดูว่าลานลอยไหม · รวมฐาน = มีอะไรรองไหม)
local function slopeSpot()
	for r = 120, 700, 30 do
		for k = 0, 23 do
			local a = k * math.pi / 12
			local x, z = camp.X + math.cos(a) * r, camp.Z + math.sin(a) * r
			local h, _, lava = layout:HeightAt(x, z)
			local hx = layout:HeightAt(x + 5, z)
			if not lava and h > layout.WaterLevel + 3 and math.abs(hx - h) > 2.2 and math.abs(hx - h) < 4.5 then
				return Vector3.new(x, h, z)
			end
		end
	end
end
local sp = slopeSpot()
if sp then
	S.DevService:Teleport(player, sp + Vector3.new(0, 4, 12))
	task.wait(3)
	S.BuildingService:Place(player, "Teleporter", CFrame.new(sp))
	task.wait(0.6)
	local m
	for _, st in ipairs(S.BuildingService:All()) do
		if st:GetAttribute("Kind") == "Teleporter" and ((st:GetPivot().Position - sp) * Vector3.new(1, 0, 1)).Magnitude < 3 then
			m = st
		end
	end
	if m then
		local base = m:FindFirstChild("Foundation")
		local top = m:GetPivot().Position.Y
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local worst, baseBottom = -99, base and (base.Position.Y - base.Size.X / 2) or top
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local q = m:GetPivot().Position + Vector3.new(math.cos(a) * 4.7, 0, math.sin(a) * 4.7)
			local h = workspace:Raycast(q + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rp)
			if h then
				worst = math.max(worst, h.Position.Y - top) -- ดินสูงกว่าลานตรงขอบกี่ stud (บวก = ดินทับลาน)
			end
		end
		local ok = worst <= 0.15 and base ~= nil
		print(string.format("[AS] TPPROBE %s slope_rim groundAbovePlaza=%.2f foundation=%s baseBottomBelow=%.1f", ok and "PASS" or "FAIL", worst, tostring(base ~= nil), top - baseBottom))
		ReplicatedStorage:SetAttribute("TpSlope", m:GetPivot().Position)
		ReplicatedStorage:SetAttribute("TpShot", "slope")
		task.wait(4)
		-- เดินขึ้นยืนเองบนลาน (ไม่ใช่วาร์ป)
		player.Character:PivotTo(CFrame.new(m:GetPivot().Position + Vector3.new(0, 5, 0)))
		task.wait(3)
		local g, on = footGap()
		print(string.format("[AS] TPPROBE %s foot_standing gap=%.2f on=%s", math.abs(g) <= 0.6 and "PASS" or "FAIL", g, on))
		ReplicatedStorage:SetAttribute("TpShot", "feet")
		task.wait(4)
	end
else
	print("[AS] TPPROBE no slope spot")
end
ReplicatedStorage:SetAttribute("TpShot", "done")
task.wait(1)
print("[TEST] DONE tpprobe")
