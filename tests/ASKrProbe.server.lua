--[[ ASKrProbe (server) — build_rbxlx.py --krprobe · อีเวนต์ลอยกระทง: คืน 20 -> ประตู -> มิติแม่น้ำ -> เก็บกระทง -> ครบ 20 -> ปิดงานคืนถัดไป ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASKrProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local K = S.KrathongService
player:SetAttribute("TestGod", true)
local st = ctx.State
local function shot(name, cf)
	ReplicatedStorage:SetAttribute("KrCam", cf)
	ReplicatedStorage:SetAttribute("KrShot", name)
	task.wait(3.5)
end
st:SetAttribute("Night", 20)
task.wait(4)
local spot = st:GetAttribute("Event_Krathong")
print("[AS] KRPROBE started=" .. tostring(K.active) .. " spot=" .. tostring(spot) .. " gate=" .. tostring(K.gate ~= nil) .. " realm=" .. tostring(K.realm ~= nil))
if not spot then
	print("[TEST] DONE krprobe")
	return
end
-- ประตู
S.DevService:Teleport(player, K.gateFront + Vector3.new(0, 3, -10))
task.wait(4)
local camp = ctx.CampPosition
local face = CFrame.lookAt(spot, Vector3.new(camp.X, spot.Y, camp.Z))
shot("kr_gate", CFrame.lookAt((face * CFrame.new(18, 14, -70)).Position, spot + Vector3.new(0, 16, 0)))
-- เข้ามิติ
S.PortalService:Teleport(player, K.plaza + Vector3.new(6, 4, 0), K.plaza + K.frame.LookVector * 20, nil, false)
task.wait(12)
local F = K.frame
print(string.format("[AS] KRPROBE inside floating=%d villagers=%d", #K.floating, (function()
	local n = 0
	for _, c in ipairs(K.realm:GetChildren()) do
		if c.Name == "Villager" then
			n += 1
		end
	end
	return n
end)()))
local probeM = K.floating[#K.floating]
local z0 = probeM and probeM.PrimaryPart and F:PointToObjectSpace(probeM.PrimaryPart.Position)
shot("kr_realm_wide", CFrame.lookAt((F * CFrame.new(-60, 40, -200)).Position, (F * CFrame.new(0, 0, -20)).Position))
shot("kr_river", CFrame.lookAt((F * CFrame.new(-30, 8, -60)).Position, (F * CFrame.new(10, 0, -110)).Position))
task.wait(5) -- ให้วัดความลื่นฝั่ง client จบ
if probeM and probeM.Parent and z0 then
	local z1 = F:PointToObjectSpace(probeM.PrimaryPart.Position)
	print(string.format("[AS] KRPROBE drift dz=%.1f dx=%.1f yOff=%.2f (expect dz>0, floating on water)", z1.Z - z0.Z, z1.X - z0.X, probeM.PrimaryPart.Position.Y - K.waterY))
end
-- เก็บ 3 อัน
for i = 1, 3 do
	local m = K.floating[1]
	if m then
		K:Collect(player, m)
	end
	task.wait(0.4)
end
print("[AS] KRPROBE collected=" .. tostring(player:GetAttribute("Krathongs")))
shot("kr_hud", nil)
-- เก็บให้ครบ 20 (สร้างกระทงชั่วคราวให้ครบ)
local guard = 0
while (player:GetAttribute("Krathongs") or 0) < 20 and guard < 40 do
	guard += 1
	local m = K:MakeKrathong(F * CFrame.new(0, K.waterY - F.Y + 0.25, 0))
	m.Parent = K.realm
	K:Collect(player, m)
	task.wait(0.15)
end
local extra = K:MakeKrathong(F * CFrame.new(0, K.waterY - F.Y + 0.25, 0))
extra.Parent = K.realm
K:Collect(player, extra) -- เกิน 20 ต้องไม่นับ
print("[AS] KRPROBE final=" .. tostring(player:GetAttribute("Krathongs")) .. " extraStillThere=" .. tostring(extra.Parent ~= nil))
task.wait(1.5)
shot("kr_wish", nil)
-- คืนถัดไป -> ปิดงาน
st:SetAttribute("Night", 21)
st:SetAttribute("Phase", "Night")
task.wait(5)
local r = player.Character.HumanoidRootPart
print(string.format("[AS] KRPROBE ended active=%s gate=%s event=%s playerY=%.0f", tostring(K.active), tostring(K.gate ~= nil), tostring(st:GetAttribute("Event_Krathong")), r.Position.Y))
print("[TEST] DONE krprobe")
