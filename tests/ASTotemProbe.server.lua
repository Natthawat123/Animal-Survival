--[[ ASTotemProbe (server) — build_rbxlx.py --totemprobe
	เสา 4 ธาตุโมเดลใหม่: วางด้วย BuildingService:Place (ทางเดียวกับผู้เล่น) บนพื้นราบ + พื้นเอียง
	วัด: ฐานเสาเทียบผิวดิน (จม/ลอย) · วางซ้อนต้องไม่ได้ · เดินทะลุไม่ได้ (ชน) · ภาพระดับพื้น ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASTotemProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
local camp = ctx.CampPosition
local KINDS = { "TerraTotem", "TideTotem", "GaleTotem", "EmberTotem" }
for _, k in ipairs(KINDS) do
	S.InventoryService:Add(player, k, 4, true)
end
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] TOTEMPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
local notes = {}
local n0 = ctx.Notify
ctx.Notify = function(p, t, k)
	table.insert(notes, tostring(t))
	return n0(p, t, k)
end
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(p)
	local h = workspace:Raycast(Vector3.new(p.X, p.Y + 30, p.Z), Vector3.new(0, -80, 0), terrainOnly)
	return h and h.Position.Y
end
local function newest(kind, near)
	for _, s in ipairs(S.BuildingService:All()) do
		if s:GetAttribute("Kind") == kind and ((s:GetPivot().Position - near) * Vector3.new(1, 0, 1)).Magnitude < 1 then
			return s
		end
	end
end
-- ฐานเสา: ก้นโมเดล (กล่องแนวโลก) เทียบดินที่กลาง + 4 มุมฐาน
local function measure(m)
	local cf, size = m:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local c = m:GetPivot().Position
	local r = math.min(size.X, size.Z) * 0.45
	local lowest, highest = math.huge, -math.huge
	for _, off in ipairs({ Vector3.zero, Vector3.new(r, 0, r), Vector3.new(-r, 0, r), Vector3.new(r, 0, -r), Vector3.new(-r, 0, -r) }) do
		local g = groundY(c + off)
		if g then
			lowest, highest = math.min(lowest, g), math.max(highest, g)
		end
	end
	-- floatGap: ก้นสูงกว่าดินจุดต่ำสุด (บวก = เห็นช่องลอย) · sunk: ดินจุดสูงสุดสูงกว่าก้น (บวก = ฐานจมดิน)
	return bottom - lowest, highest - bottom, size
end
local function placeAt(kind, p)
	player.Character:PivotTo(CFrame.new(p + Vector3.new(0, 4, 9)))
	task.wait(0.4)
	table.clear(notes)
	local g = groundY(p) or p.Y
	local ok = S.BuildingService:Place(player, kind, CFrame.new(Vector3.new(p.X, g, p.Z)))
	task.wait(0.3)
	return ok, newest(kind, p), table.concat(notes, " | ")
end

-- 1) พื้นราบในแคมป์ เรียง 4 ต้น
local base = camp + Vector3.new(-18, 0, 22)
local flat = {}
for i, kind in ipairs(KINDS) do
	local p = base + Vector3.new((i - 1) * 9, 0, 0)
	local ok, m, why = placeAt(kind, p)
	check("place_flat_" .. kind, ok == true and m ~= nil, why)
	if m then
		flat[i] = m
		local gap, sunk, size = measure(m)
		check("ground_flat_" .. kind, gap < 0.35 and sunk < 0.6, string.format("floatGap=%.2f sunk=%.2f size=%.1f,%.1f,%.1f", gap, sunk, size.X, size.Y, size.Z))
		local mp = m:FindFirstChildWhichIsA("MeshPart", true)
		check("model_" .. kind, mp ~= nil and m:FindFirstChildWhichIsA("SurfaceAppearance", true) ~= nil and mp.CanCollide, "collide=" .. tostring(mp and mp.CanCollide))
	end
end
-- 2) วางซ้อนจุดเดิม = ต้องไม่ได้
do
	-- เสามีได้ธาตุละ 1 ต้นต่อเซิร์ฟ: รื้อเสาไฟก่อน แล้วลองวางเสาไฟทับเสาดิน
	if flat[4] then
		S.BuildingService:Vanish(flat[4])
		task.wait(1)
	end
	S.InventoryService:Add(player, "EmberTotem", 1, true)
	local ok, _, why = placeAt("EmberTotem", base + Vector3.new(0.5, 0, 0.5))
	check("no_overlap", ok ~= true, why)
end
-- 3) ชนได้: ยิงแนวนอนเข้าหาเสา (เดินทะลุไม่ได้)
if flat[1] then
	local c = flat[1]:GetPivot().Position
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { flat[1] }
	rp.RespectCanCollide = true
	local hit = workspace:Raycast(c + Vector3.new(0, 3, 6), Vector3.new(0, 0, -12), rp)
	check("solid", hit ~= nil, hit and hit.Instance.Name or "ray passes through")
end
-- 4) พื้นเอียง: หาจุดชันใกล้แคมป์ (ในเขตวางได้) วางเสาไฟ
local layout = ctx.Layout
S.CampService.level = 6 -- เขตแคมป์กว้างสุด (หาพื้นเอียงที่วางได้)
S.CampService:Publish()
local slopeSpot
for r = 30, 115, 4 do
	for k = 0, 35 do
		local a = k * math.pi / 18
		local p = camp + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local g0, g1 = groundY(p), groundY(p + Vector3.new(2, 0, 0))
		local g2 = groundY(p + Vector3.new(0, 0, 2))
		if g0 and g1 and g2 and math.max(math.abs(g1 - g0), math.abs(g2 - g0)) > 0.6 and math.max(math.abs(g1 - g0), math.abs(g2 - g0)) < 2 then
			slopeSpot = Vector3.new(p.X, g0, p.Z)
			break
		end
	end
	if slopeSpot then
		break
	end
end
if slopeSpot then
	local ok, m, why = placeAt("EmberTotem", slopeSpot)
	check("place_slope", ok == true and m ~= nil, why)
	if m then
		local gap, sunk = measure(m)
		check("ground_slope", gap < 0.35, string.format("floatGap=%.2f sunk=%.2f", gap, sunk))
		local sh = Instance.new("Vector3Value")
		sh.Name = "TotemSlope"
		sh.Value = m:GetPivot().Position
		sh.Parent = ReplicatedStorage
	end
else
	print("[AS] TOTEMPROBE no slope spot in camp")
end
-- ภาพ: ระดับพื้นข้างเสา (เห็นฐานกับดินชัด)
local c = Instance.new("Vector3Value")
c.Name = "TotemCenter"
c.Value = base + Vector3.new(13.5, 0, 0)
c.Parent = ReplicatedStorage
player.Character:PivotTo(CFrame.new(base + Vector3.new(13.5, 4, 30)))
task.wait(3)
c:SetAttribute("Shot", 1)
task.wait(3)
c:SetAttribute("Shot", 2)
task.wait(3)
if slopeSpot then
	c:SetAttribute("Shot", 3)
	task.wait(3)
end
print(string.format("[AS] TOTEMPROBE TOTAL fails=%d", fails))
print("[TEST] DONE totemprobe")
