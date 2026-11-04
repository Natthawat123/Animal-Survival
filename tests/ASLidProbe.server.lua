--[[ ASLidProbe (server) — build_rbxlx.py --lidprobe · หีบฝาเปิดได้ 3 แบบ (Chest1Open-3Open) วางเรียงหน้ากล้อง แล้วเปิดฝาทีละใบ
	ถ่าย: ปิด -> กำลังเปิด -> เปิดสุด · พิมพ์มุมฝาจริงหลังเปิด (ต้อง ~105° และขอบหน้าฝายกขึ้น) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLidProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
local ChestLid = require(ReplicatedStorage.Shared.ChestLid)
player:SetAttribute("TestGod", true)

local base = ctx.CampPosition + Vector3.new(60, 0, 60)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { Workspace.Terrain }
local folder = Instance.new("Folder")
folder.Name = "LidProbe"
folder.Parent = Workspace
local chests = {}
for i, w in ipairs({ 5.4, 6.2, 7.2 }) do
	local p = base + Vector3.new((i - 2) * 11, 0, 0)
	local hit = Workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), rp)
	local m = PropBuilder.Imported("Chest" .. i .. "Open", CFrame.new(hit and hit.Position or p), w, folder, true)
	local lid, hinge = ChestLid.Find(m)
	print(string.format("[AS] LIDPROBE chest%d model=%s lid=%s hinge=%s", i, tostring(m ~= nil), tostring(lid ~= nil), hinge and tostring(hinge.Position) or "-"))
	chests[i] = m
end
-- ผู้เล่นยืนหน้าหีบ (หน้าหีบ = -Z ของโมเดล) หันเข้าหา
S.DevService:Teleport(player, base + Vector3.new(0, 0, -22))
task.wait(2)
ReplicatedStorage:SetAttribute("LidFocus", base)
task.wait(1.5)
print("[SHOT] lid_closed")
task.wait(3)
for i, m in ipairs(chests) do
	if m then
		m:SetAttribute("Opened", true)
		S.LootService:ChestFx(m, m:GetPivot().Position, i)
	end
end
task.wait(0.75)
print("[SHOT] lid_mid")
task.wait(3)
print("[SHOT] lid_open")
task.wait(2.5)
for i, m in ipairs(chests) do
	local lid, hinge = ChestLid.Find(m)
	if lid then
		local closed = lid:GetAttribute("ClosedCF")
		local front = closed * Vector3.new(0, 0, -lid.Size.Z / 2) -- ขอบหน้าฝาตอนปิด
		local now = lid.CFrame * Vector3.new(0, 0, -lid.Size.Z / 2)
		local _, ang = (closed:ToObjectSpace(lid.CFrame)):ToAxisAngle()
		print(string.format("[AS] LIDPROBE chest%d angle=%.0f frontRise=%.2f (lidZ=%.2f)", i, math.deg(ang), now.Y - front.Y, lid.Size.Z))
	end
end
-- มุมข้าง
ReplicatedStorage:SetAttribute("LidSide", true)
task.wait(1.5)
print("[SHOT] lid_side")
task.wait(3)
print("[AS] LIDPROBE done")
print("[TEST] DONE lidprobe")
