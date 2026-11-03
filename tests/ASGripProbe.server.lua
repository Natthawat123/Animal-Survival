--[[ ASGripProbe (server) — build_rbxlx.py --gripprobe · ให้หน้าไม้+เคียว แล้ว client หมุนท่าจับไล่ทุกทิศ ถ่ายภาพเลือกทิศที่ถูก ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASGripProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
player:SetAttribute("TestGod", true)
ctx.Services.DevService:Teleport(player, ctx.CampPosition + Vector3.new(45, 0, 45))
task.wait(1)
for _, id in ipairs({ "Crossbow", "Scythe" }) do
	ctx.Services.InventoryService:Add(player, id, 1, true)
end
ReplicatedStorage:SetAttribute("GripGo", true)
task.wait(60)
print("[AS] GRIPPROBE done")
