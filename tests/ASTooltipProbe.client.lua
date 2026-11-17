--[[ ASTooltipProbe (client) — build_rbxlx.py --tooltipprobe · การ์ดไอเทม "หาได้จากไหน" ทุกไอเทม (เช็ก error) + ภาพการ์ด ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASTooltipProbe") then
	return
end
local player = Players.LocalPlayer
repeat
	task.wait(1)
until player:GetAttribute("InRun")
task.wait(5)
local Items = require(ReplicatedStorage.Shared.Items)
local ItemTooltip = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("ItemTooltip"))
local empty, bad = {}, 0
for id in pairs(Items.Data) do
	local ok, w = pcall(ItemTooltip.Where, id)
	if not ok then
		bad += 1
		print("[AS] TOOLTIP ERROR", id, w)
	elseif #w == 0 then
		table.insert(empty, id)
	end
end
table.sort(empty)
print(string.format("[AS] TOOLTIP errors=%d noSource=%d [%s]", bad, #empty, table.concat(empty, ",")))
for _, id in ipairs({ "Fiber", "Iron", "Pelt", "TerraCore", "Katana", "GiantSack", "CookedMeat", "Medkit" }) do
	print("[AS] TOOLTIP " .. id .. " | " .. table.concat(ItemTooltip.Where(id), " / "))
end
for _, id in ipairs({ "Fiber", "Iron", "TerraCore", "Katana" }) do
	ItemTooltip.Show(id, "Top")
	task.wait(1.2)
	print("[SHOT] tooltip_" .. id)
	task.wait(1.2)
end
ItemTooltip.Hide()
print("[TEST] DONE tooltip")
