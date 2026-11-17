--[[ ASTreeProbe (server) — build_rbxlx.py --treeprobe · ต้นไม้งอกคืนแยกทีละต้น (ย่อเวลาเหลือ 10 วิ): ตัด 3 ต้นห่างกัน 4 วิ -> ต้องงอกห่างกัน 4 วิ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASTreeProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun")
task.wait(2)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local R = ctx.Services.ResourceService
local Config = require(ReplicatedStorage.Shared.Config)
Config.TreeRegrowSeconds = 10
local trees = {}
for _, n in ipairs(CollectionService:GetTagged("ResourceNode")) do
	if n:GetAttribute("Node") == "Tree" and not n:GetAttribute("Depleted") and n:IsDescendantOf(workspace) then
		table.insert(trees, n)
		if #trees == 3 then
			break
		end
	end
end
local t0 = os.clock()
for i, n in ipairs(trees) do
	R:Fell(n)
	print(string.format("[AS] TREEPROBE fell tree%d t=%.1f", i, os.clock() - t0))
	task.wait(4)
end
-- ทำให้ "เปลี่ยนวัน" กลางทาง: ต้องไม่ทำให้งอกพร้อมกัน
ctx.State:SetAttribute("Night", (ctx.State:GetAttribute("Night") or 1) + 8)
local regrown = {}
while os.clock() - t0 < 30 do
	for i, n in ipairs(trees) do
		if not regrown[i] and not n:GetAttribute("Depleted") then
			regrown[i] = os.clock() - t0
			print(string.format("[AS] TREEPROBE regrow tree%d t=%.1f", i, regrown[i]))
		end
	end
	task.wait(0.2)
end
print(string.format("[AS] TREEPROBE result gaps=%.1f,%.1f (expect ~4,~4)", (regrown[2] or 0) - (regrown[1] or 0), (regrown[3] or 0) - (regrown[2] or 0)))
print("[TEST] DONE treeprobe")
