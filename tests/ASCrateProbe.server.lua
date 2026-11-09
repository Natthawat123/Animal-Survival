--[[ ASCrateProbe (server) — build_rbxlx.py --crateprobe
	ตรวจกล่องทุกใบในแมพจริง: จมดิน? / มีของทับ (ต้นไม้/หิน/พุ่ม)? / มองเห็นจากรอบๆ กี่ทิศ? / หมุดแผนที่ตรงกล่องไหม?
	แล้วพาผู้เล่นไปยืนข้างกล่องที่ "หายากที่สุด" ให้ client ถ่ายภาพ + เปิดแผนที่ถ่ายเทียบหมุด ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASCrateProbe") then
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
local world = Workspace.World
local folder = world:FindFirstChild("SupplyCrates")
local crates = folder and folder:GetChildren() or {}
local pins = ReplicatedStorage:FindFirstChild("MapPins")

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude
local ov = OverlapParams.new()
ov.FilterType = Enum.RaycastFilterType.Include
ov.FilterDescendantsInstances = { world }

local function propName(part)
	local m = part
	while m.Parent and m.Parent ~= world and m.Parent.Parent ~= world do
		m = m.Parent
	end
	return m.Name
end

local results = {}
local bad = { sunk = 0, buried = 0, covered = 0, hidden = 0, pin = 0 }
for i, crate in ipairs(crates) do
	local cf, size = crate:GetBoundingBox()
	local pos = crate:GetPivot().Position
	local g = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 300, pos.Z), Vector3.new(0, -600, 0), terrainOnly)
	local groundY = g and g.Position.Y or pos.Y
	local bottom, top = cf.Position.Y - size.Y / 2, cf.Position.Y + size.Y / 2
	local sunk = groundY - bottom
	-- ของในโลกที่ทับตัวกล่อง
	local over = {}
	for _, p in ipairs(Workspace:GetPartBoundsInBox(cf, size * 1.05, ov)) do
		if not p:IsDescendantOf(crate) and p.Transparency < 0.9 then
			over[propName(p)] = true
		end
	end
	local overList = {}
	for k in pairs(over) do
		table.insert(overList, k)
	end
	-- มองจาก 8 ทิศ ระยะ 22 สตั๊ด ความสูงตา
	sight.FilterDescendantsInstances = { player.Character }
	local clear = 0
	local center = cf.Position
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local eyeXZ = Vector3.new(center.X + math.cos(a) * 22, 0, center.Z + math.sin(a) * 22)
		local eg = Workspace:Raycast(eyeXZ + Vector3.new(0, groundY + 300, 0), Vector3.new(0, -600, 0), terrainOnly)
		local eye = Vector3.new(eyeXZ.X, (eg and eg.Position.Y or groundY) + 5, eyeXZ.Z)
		local hit = Workspace:Raycast(eye, center - eye, sight)
		if not hit or hit.Instance:IsDescendantOf(crate) then
			clear += 1
		end
	end
	-- หมุดแผนที่
	local pinD = math.huge
	for _, pin in ipairs(pins and pins:GetChildren() or {}) do
		pinD = math.min(pinD, ((pin.Value - pos) * Vector3.new(1, 0, 1)).Magnitude)
	end
	local flags = {}
	if sunk > size.Y * 0.4 then
		table.insert(flags, "SUNK")
		bad.sunk += 1
	end
	if top < groundY then
		table.insert(flags, "BURIED")
		bad.buried += 1
	end
	if #overList > 0 then
		table.insert(flags, "COVERED")
		bad.covered += 1
	end
	if clear <= 2 then
		table.insert(flags, "HIDDEN")
		bad.hidden += 1
	end
	if pinD > 3 then
		table.insert(flags, "PINOFF")
		bad.pin += 1
	end
	local _, biome = ctx.Layout:HeightAt(pos.X, pos.Z)
	results[i] = { crate = crate, clear = clear, flags = flags, score = (#overList > 0 and 10 or 0) + (8 - clear) + (sunk > size.Y * 0.4 and 10 or 0) }
	print(string.format("[AS] CRATE %02d tier=%d biome=%s pos=(%.0f,%.0f,%.0f) size=(%.1f,%.1f,%.1f) ground=%.1f sunk=%.1f clear=%d/8 pinD=%.1f over=[%s] %s",
		i, crate:GetAttribute("Tier") or 0, tostring(biome), pos.X, pos.Y, pos.Z, size.X, size.Y, size.Z, groundY, sunk, clear, pinD, table.concat(overList, ","), table.concat(flags, " ")))
end
print(string.format("[AS] CRATE TOTAL n=%d pins=%d sunk=%d buried=%d covered=%d hidden=%d pinoff=%d",
	#crates, pins and #pins:GetChildren() or 0, bad.sunk, bad.buried, bad.covered, bad.hidden, bad.pin))

-- ถ่ายภาพ: กล่องที่หายากสุด 4 ใบ + ปกติ 1 ใบ
table.sort(results, function(a, b)
	return a.score > b.score
end)
local shots = {}
for k = 1, math.min(2, #results) do
	table.insert(shots, results[k])
end
if #results > 2 then
	table.insert(shots, results[#results])
end
for k, r in ipairs(shots) do
	local c = r.crate
	local cpos = c:GetPivot().Position
	S.DevService:Teleport(player, cpos + Vector3.new(10, 3, 0))
	task.wait(4) -- รอ streaming ส่งกล่องมาให้ client
	ReplicatedStorage:SetAttribute("CrateShotTarget", cpos)
	ReplicatedStorage:SetAttribute("CrateShotName", string.format("crate%d_clear%d_%s", k, r.clear, #r.flags > 0 and table.concat(r.flags, "-") or "OK"))
	ReplicatedStorage:SetAttribute("CrateShotSeq", k)
	task.wait(18) -- client ถ่ายภาพกล่อง + ภาพแผนที่ (attribute จาก client ไม่ส่งกลับ server -> รอตามเวลา)
end
ReplicatedStorage:SetAttribute("CrateShotSeq", -1)
task.wait(1)
print("[TEST] DONE crateprobe")
