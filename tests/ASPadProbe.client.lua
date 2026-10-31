--[[ ASPadProbe (client) — build_rbxlx.py --padprobe · ขึ้นแท่นแล้วต้องยังไม่นับ จนกว่าจะเลือกจำนวนคน ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASPadProbe") then
	return
end
local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
task.wait(2)
local zone = workspace:WaitForChild("Lobby"):FindFirstChild("MatchBox1", true)
local r = player.Character:WaitForChild("HumanoidRootPart")
r.CFrame = zone.CFrame
task.wait(8)
print(string.format("[AS] PADPROBE before pad=%s picked=%s countdown=%s", tostring(player:GetAttribute("Pad")), tostring(zone:GetAttribute("Picked")), tostring(zone:GetAttribute("Countdown"))))
print("[SHOT] pad_wait")
task.wait(1.5)
require(ReplicatedStorage.Shared.Remotes).Get("PadSize"):FireServer(zone:GetAttribute("PadIndex"), 2)
task.wait(2)
print(string.format("[AS] PADPROBE after picked=%s countdown=%s", tostring(zone:GetAttribute("Picked")), tostring(zone:GetAttribute("Countdown"))))
print("[SHOT] pad_count")
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 30 do
	task.wait(0.5)
end
print("[AS] PADPROBE inRun=" .. tostring(player:GetAttribute("InRun")) .. string.format(" after %.0fs", os.clock() - t0))
print("[AS] PADPROBE done")
