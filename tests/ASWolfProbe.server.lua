--[[ ASWolfProbe (server) — build_rbxlx.py --wolfprobe · จิ้งจอกจันทรา (Moonfang) กลางคืน: เกิด · วาปมาไล่ · บนจอผู้เล่นเห็นตัวไหม (client นับชิ้นที่มองเห็น + ภาพ) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASWolfProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local D, A = S.DirectorService, S.AnimalService
local st = ctx.State
player:SetAttribute("TestGod", true)
local root = player.Character.HumanoidRootPart
local camp = ctx.CampPosition
D.skip = true
task.wait(1.5)
D.skip = true
local t = 0
repeat
	task.wait(0.5)
	t += 0.5
until st:GetAttribute("Phase") == "Night" or t > 15
print("[AS] WOLF phase=" .. tostring(st:GetAttribute("Phase")))
S.DevService:Teleport(player, camp + Vector3.new(1, 0, 0.3).Unit * 140 + Vector3.new(0, 4, 0))
local shots = 0
for i = 1, 40 do
	task.wait(1)
	for _, a in ipairs(A:All()) do
		if not a.Dead and a.Kind == "Stalker" then
			local d = (a.Root.Position - root.Position).Magnitude
			print(string.format("[AS] WOLF t=%d hidden=%s state=%s dist=%.0f", i, tostring(a.Hidden), tostring(a.State), d))
			if not a.Hidden and d < 30 and shots < 3 then
				shots += 1
				ReplicatedStorage:SetAttribute("WolfShot", "wolf_near_" .. shots)
			end
		end
	end
end
print("[TEST] DONE wolfprobe")
