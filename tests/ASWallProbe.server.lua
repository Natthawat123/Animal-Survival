--[[ ASWallProbe (server) — build_rbxlx.py --wallprobe
	กำแพงไม้/หินดูดต่อกัน: วางแนวตรง 3 ท่อน -> หักมุม (หิน) -> ต่ออีก 2 ท่อน -> ตรวจว่าเซิร์ฟเวอร์ยอมวาง + ไม่มีช่องว่าง/ซ้อน
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASWallProbe") then
	return
end
local WallSnap = require(ReplicatedStorage.Shared.WallSnap)
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
player:SetAttribute("TestGod", true)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local Build, inv = S.BuildingService, S.InventoryService
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local oldNotify = ctx.Notify
ctx.Notify = function(p, msg, kind)
	print("[AS] WALLPROBE notify: " .. tostring(msg))
	return oldNotify(p, msg, kind)
end
local folder = workspace:WaitForChild("Structures")
local fire = S.CampService:FirePosition()
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] WALLPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
inv:Add(player, "LogWall", 6, true)
inv:Add(player, "StoneWall", 4, true)
local start = fire + Vector3.new(-14, 0, 22)
local function stand(p)
	player.Character:PivotTo(CFrame.new(p + Vector3.new(0, 4, 6)))
	task.wait(0.3)
end
local placed = {}
local function newest()
	local best, t = nil, -1
	for _, m in ipairs(folder:GetChildren()) do
		if not table.find(placed, m) then
			best = m
		end
	end
	return best
end
local function place(kind, cf, tag)
	stand(cf.Position)
	local _, yy = cf:ToOrientation()
	print(string.format("[AS] WALLPROBE try %s %s pos=%.1f,%.1f,%.1f yaw=%.0f", tag, kind, cf.X, cf.Y, cf.Z, math.deg(yy)))
	local ok = Build:Place(player, kind, cf)
	task.wait(0.2)
	local m = ok and newest()
	if m then
		table.insert(placed, m)
	end
	check("place_" .. tag, ok == true and m ~= nil, kind)
	return m
end
-- ท่อนแรก: วางอิสระ
local first = place("LogWall", CFrame.new(start), "first")
-- ต่อตรงไปทาง +X (เล็งเลยปลายไปนิด)
local function snapAt(kind, aim, tag)
	local cf = WallSnap.Find(kind, aim, folder)
	check("snap_found_" .. tag, cf ~= nil, string.format("aim=%.0f,%.0f", aim.X, aim.Z))
	if not cf then
		return nil
	end
	return place(kind, cf, tag)
end
local function ends(m)
	local _, sz = m:GetBoundingBox()
	return sz
end
local w = first
local dir = Vector3.xAxis
if w then
	local bcf, bsz = w:GetBoundingBox()
	dir = bsz.X >= bsz.Z and bcf.RightVector or bcf.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
end
local perp = Vector3.new(-dir.Z, 0, dir.X)
if w then
	local bcf, bsz = w:GetBoundingBox()
	print(string.format("[AS] WALLPROBE first pivot=%s bbox=%s size=%s dir=%s", tostring(w:GetPivot().Position), tostring(bcf.Position), tostring(bsz), tostring(dir)))
end
local last = w
for i = 2, 3 do
	local c = last:GetBoundingBox().Position
	last = snapAt("LogWall", c + dir * 13, "straight" .. i) or last
end
-- หักมุม: เล็งไปทาง -Z (เข้าหาแคมป์) จากปลายท่อนสุดท้าย
local c3 = last:GetBoundingBox().Position
local corner = snapAt("StoneWall", c3 + dir * 6 - perp * 7, "corner")
local tail = corner
for i = 1, 2 do
	if tail then
		local cc = tail:GetBoundingBox().Position
		tail = snapAt(i == 1 and "StoneWall" or "LogWall", cc - perp * 13, "after_corner" .. i) or tail
	end
end
-- ตรวจช่องว่าง: ระยะศูนย์กลางท่อนตรงที่ติดกันต้อง ~ ความยาวท่อน (ไม่ห่าง/ไม่ซ้อน)
if #placed >= 3 then
	local a, b = placed[1]:GetBoundingBox().Position, placed[2]:GetBoundingBox().Position
	local _, sz = placed[1]:GetBoundingBox()
	local len = math.max(sz.X, sz.Z)
	local gap = ((a - b) * Vector3.new(1, 0, 1)).Magnitude - len
	check("no_gap_straight", math.abs(gap) < 1.2, string.format("gap=%.2f len=%.2f", gap, len))
end
-- เล็งไกลจากกำแพงทุกท่อน = ไม่ดูด (วางอิสระ)
check("no_snap_far", WallSnap.Find("LogWall", start + Vector3.new(0, 0, 40), folder) == nil, "")
local shot = Instance.new("StringValue")
shot.Name = "WallShot"
shot.Parent = ReplicatedStorage
local center = Vector3.zero
for _, m in ipairs(placed) do
	center += m:GetBoundingBox().Position
end
center /= math.max(1, #placed)
shot:SetAttribute("Center", center)
player.Character:PivotTo(CFrame.new(center + Vector3.new(0, 4, 24)))
task.wait(1)
shot.Value = "top"
task.wait(2.5)
shot.Value = "side"
task.wait(2.5)
print(string.format("[AS] WALLPROBE TOTAL placed=%d fails=%d", #placed, fails))
print("[TEST] DONE wallprobe")
