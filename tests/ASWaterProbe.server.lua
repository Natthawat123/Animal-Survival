--[[ ASWaterProbe (server) — build_rbxlx.py --waterprobe
	วาฬ (สัตว์น้ำ) ต้องเกิดในน้ำลึกรอบผู้เล่นเอง: นับจำนวน · ต้องอยู่ผิวน้ำ ไม่ขึ้นบก · ภาพวาฬในน้ำ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASWaterProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local Config = require(ReplicatedStorage.Shared.Config)
local layout = ctx.Layout
local wl = layout.WaterLevel
player:SetAttribute("TestGod", true)
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] WATERPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
-- พาผู้เล่นไปริมน้ำลึกที่ใกล้แคมป์ที่สุด (ห่างแคมป์ > 200)
local spot
for r = 200, layout.Half - 40, 25 do
	for k = 0, 47 do
		local a = k * math.pi / 24
		local x, z = math.cos(a) * r, math.sin(a) * r
		if layout:HeightAt(x, z) < wl - 6 then
			spot = Vector3.new(x, 0, z)
			break
		end
	end
	if spot then
		break
	end
end
check("deep_water_exists", spot ~= nil, spot and tostring(spot) or "")
if spot then
	-- ยืนบนบกใกล้น้ำ: ถอยเข้าหาแคมป์จนเจอบก
	local dir = -spot.Unit
	local land = spot
	for t = 0, 200, 4 do
		local q = spot + dir * t
		local h = layout:HeightAt(q.X, q.Z)
		if h > wl + 1 then
			land = Vector3.new(q.X, h + 4, q.Z)
			break
		end
	end
	player.Character:PivotTo(CFrame.new(land))
end
local function wetList()
	local out = {}
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Animal")) do
		local id = m:GetAttribute("AnimalId")
		if id == "TideOrca" and m.PrimaryPart then
			table.insert(out, m)
		end
	end
	return out
end
local t0 = os.clock()
local n = 0
while os.clock() - t0 < 45 do
	task.wait(5)
	n = #wetList()
	print(string.format("[AS] WATERPROBE t=%d orcas=%d", os.clock() - t0, n))
	if n >= Config.MaxWaterAnimals * 0.5 then
		break
	end
end
check("orcas_spawn", n >= 2, "count=" .. n)
task.wait(8) -- ให้ว่ายไปมาก่อนวัด
local onLand, nearest, nd = 0, nil, math.huge
local me = player.Character.HumanoidRootPart.Position
for _, m in ipairs(wetList()) do
	local p = m.PrimaryPart.Position
	local h = layout:HeightAt(p.X, p.Z)
	if h > wl - 1 or math.abs(p.Y - wl) > 12 then
		onLand += 1
		print(string.format("[AS] WATERPROBE bad orca at %s ground=%.1f", tostring(p), h))
	end
	local d = (p - me).Magnitude
	if d < nd then
		nearest, nd = m, d
	end
end
check("orcas_in_water", onLand == 0, "bad=" .. onLand)
if nearest then
	local v = Instance.new("ObjectValue")
	v.Name = "WaterOrca"
	v.Value = nearest
	v.Parent = ReplicatedStorage
	task.wait(4)
	v:SetAttribute("Shot", 1)
	task.wait(4)
end
print(string.format("[AS] WATERPROBE TOTAL fails=%d", fails))
print("[TEST] DONE waterprobe")
