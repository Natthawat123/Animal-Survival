--[[ ASVillageMapProbe (client) — เปิดแผนที่ถ่ายหมุดหมู่บ้าน (จำลองว่าค้นพบทุกหมู่บ้านแล้ว) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASVillageMapProbe") then
	return
end
local player = game:GetService("Players").LocalPlayer
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local MapUI = require(client:WaitForChild("MapUI"))
local HUD = require(client:WaitForChild("HUD"))
ReplicatedStorage:WaitForChild("VMapShot", 900)
local folder = ReplicatedStorage:WaitForChild("MapVillages", 30)
for i = 1, #folder:GetChildren() do
	HUD.Discovered["Village_" .. i] = true
end
if MapUI.Toggle then
	MapUI.Toggle()
end
task.wait(2.5)
local n = 0
for _, d in ipairs(player.PlayerGui:GetDescendants()) do
	if d.Name == "VillagePin" and d.Visible then
		n += 1
	end
end
print("[AS] VMAPPROBE client visible pins=" .. n)
print("[SHOT] village_map")
