--[[ ASChestProbe (server) — build_rbxlx.py --chestprobe · กล่อง 3 ระดับ (จำนวน/ของ) + อาวุธใหม่ 9 ชิ้น (ถือ/ตี) + ของระดับวิหาร ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASChestProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
local folder = Workspace.World:FindFirstChild("SupplyCrates")
local by = { 0, 0, 0 }
local sample = {}
for _, c in ipairs(folder and folder:GetChildren() or {}) do
	local t = c:GetAttribute("Tier")
	if t then
		by[t] += 1
		sample[t] = sample[t] or c
	end
end
print(string.format("[AS] CHESTPROBE crates total=%d tier1=%d tier2=%d tier3=%d model1=%s", #(folder and folder:GetChildren() or {}), by[1], by[2], by[3], tostring(sample[1] and sample[1]:FindFirstChildWhichIsA("MeshPart", true) ~= nil)))
for t = 1, 3 do
	local c = sample[t]
	if c then
		S.DevService:Teleport(player, c:GetPivot().Position + Vector3.new(6, 0, 0))
		task.wait(1)
		local okT, errT = pcall(S.LootService.OpenCrate, S.LootService, c, player)
		task.wait(0.5)
		local items = {}
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:GetAttribute("ItemId") and d:IsA("Model") and (d:GetPivot().Position - c:GetPivot().Position).Magnitude < 14 then
				table.insert(items, d:GetAttribute("ItemId") .. "x" .. tostring(d:GetAttribute("Count") or 1))
			end
		end
		print(string.format("[AS] CHESTPROBE open tier%d ok=%s err=%s drops=[%s]", t, tostring(okT), tostring(errT), table.concat(items, ",")))
	end
end
local okS, got = pcall(S.LootService.GiveTierLoot, S.LootService, 3, ctx.CampPosition + Vector3.new(30, 5, 0))
local gl = {}
for id, n in pairs(okS and got or {}) do
	table.insert(gl, id .. "x" .. n)
end
print("[AS] CHESTPROBE sanctum tier3 ok=" .. tostring(okS) .. " got=[" .. table.concat(gl, ",") .. "]")
-- อาวุธใหม่: ใส่กระเป๋า -> client ถือทีละชิ้นแล้วถ่ายภาพ + ตี
S.DevService:Teleport(player, ctx.CampPosition + Vector3.new(40, 0, 40))
task.wait(1)
for _, id in ipairs({ "Dagger", "SpikedClub", "IronSword", "Mace", "BattleAxe", "Crossbow", "Katana", "WarHammer", "Scythe" }) do
	S.InventoryService:Add(player, id, 1, true)
end
task.wait(1)
local n = 0
for _, t in ipairs(player.Backpack:GetChildren()) do
	if t:IsA("Tool") and t:FindFirstChild("Handle") then
		n += 1
	end
end
print("[AS] CHESTPROBE weapon tools with handle=" .. n)
ReplicatedStorage:SetAttribute("ChestStep", "weapons")
task.wait(50) -- client ถือ/ตีครบ 9 ชิ้น (attribute จาก client ไม่ส่งกลับมาที่ server)
ReplicatedStorage:SetAttribute("ChestWeaponsDone", true)
print("[AS] CHESTPROBE done")
