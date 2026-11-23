--[[ ASVillageMapProbe (server) — build_rbxlx.py --villagemapprobe : หมุดหน้ากากหมู่บ้านชนเผ่าบนแผนที่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASVillageMapProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
player:SetAttribute("TestGod", true)
ctx.State:SetAttribute("CampReveal", 99999) -- เปิดหมอกทั้งแมพ (เห็นหมุดทุกหมู่บ้าน)
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] VMAPPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
local villages = 0
for _, v in ipairs(CollectionService:GetTagged("Village")) do
	if v:IsDescendantOf(workspace) then
		villages += 1
	end
end
task.wait(3)
local folder = ReplicatedStorage:FindFirstChild("MapVillages")
local pins, capital = 0, 0
for _, p in ipairs(folder and folder:GetChildren() or {}) do
	pins += 1
	if p:GetAttribute("Capital") then
		capital += 1
	end
end
check("pins_match_villages", villages > 0 and pins == villages, string.format("villages=%d pins=%d capital=%d", villages, pins, capital))
local flag = Instance.new("BoolValue")
flag.Name = "VMapShot"
flag.Parent = ReplicatedStorage
task.wait(8)
print(string.format("[AS] VMAPPROBE TOTAL fails=%d", fails))
print("[TEST] DONE vmapprobe")
