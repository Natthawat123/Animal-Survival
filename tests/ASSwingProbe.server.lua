--[[ ASSwingProbe (server) — build_rbxlx.py --swingprobe · ให้อาวุธตัวแทนทุกชุดท่า แล้ว client ถ่ายทุกคีย์เฟรมของทุกท่า ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSwingProbe") then
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
for _, id in ipairs({ "OldAxe", "BattleAxe", "FourfoldBlade", "Pickaxe", "BuildHammer", "SpikedClub", "Mace", "WarHammer", "IronSword", "Katana", "Dagger", "Scythe", "Spear", "TidalTrident", "Torch", "EmberStaff", "ArcaneStaff", "VerdantStaff", "Bow", "Crossbow" }) do
	ctx.Services.InventoryService:Add(player, id, 1, true)
end
-- ReplicatedStorage:SetAttribute("SwingOnly", "ChopX,Rise") -- เปิดบรรทัดนี้ = ถ่ายเฉพาะท่าที่ระบุ (ปิด = ถ่ายทุกท่า)
ReplicatedStorage:SetAttribute("SwingGo", true)
