--[[ ASSackProbe (server) — ให้ถือกระสอบทีละแบบ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSackProbe") then
	return
end
local shot = Instance.new("StringValue")
shot.Name = "SackShot"
shot.Parent = ReplicatedStorage
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(12)
local ToolFactory = require(game:GetService("ServerScriptService").Server.ToolFactory)
local hum = player.Character:FindFirstChildOfClass("Humanoid")
for _, id in ipairs({ "OldSack", "GoodSack", "GiantSack" }) do
	hum:UnequipTools()
	local t = ToolFactory.Build(id)
	t.Parent = player.Backpack
	hum:EquipTool(t)
	task.wait(1)
	shot.Value = id
	task.wait(4)
	t:Destroy()
end
print("[TEST] DONE probe")
