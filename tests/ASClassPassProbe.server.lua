--[[ ASClassPassProbe (server) — build_rbxlx.py --classprobe
	แวมไพร์ดูดเลือด/แรงตอนกลางคืน · คลาสพาส (Sage) ไม่อยู่ในสต็อก ซื้อด้วย Ruby ไม่ได้ · มีพาส = ได้คลาส
	ผล: "[AS] CLASSPASS PASS/FAIL ..." · จบ "[AS] CLASSPASS DONE" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASClassProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player.Character and player.Character:FindFirstChildOfClass("Humanoid")
task.wait(5)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Items = require(ReplicatedStorage.Shared.Items)
local ctx = require(game:GetService("ServerScriptService").Server.DirectorService).ctx
local S = ctx.Services
local fails = 0
local function check(name, ok, detail)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] CLASSPASS %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end

check("order-has-new", table.find(Classes.Order, "Vampire") ~= nil and Classes.Order[#Classes.Order] == "Sage")
check("collect-count", Classes.CollectCount == #Classes.Order - 1, Classes.CollectCount)
local inStock = false
for day = 1, 60 do
	for roll = 0, 3 do
		if Classes.Stock(day, roll, player.UserId).Sage then
			inStock = true
		end
	end
end
check("sage-never-in-stock", not inStock)
check("sage-not-owned", not Classes.IsOwned("Sage", { Owned = {} }, player))

-- แวมไพร์: ดูดเลือด
player:SetAttribute("Class", "Vampire")
player:SetAttribute("ClassLevel", 1)
check("vampire-perk", S.SurvivalService:Perk(player, "KillHealPct", 0) == 0.02)
local a = S.AnimalService:Spawn("MossWolf", player.Character.HumanoidRootPart.Position + Vector3.new(0, 0, 12), { Kind = "Wild" })
task.wait(0.5)
a.Model:Destroy()
player:SetAttribute("Class", "Survivor")
player:SetAttribute("ClassLevel", 1)

-- พาส -> ได้คลาส
local data = S.DataService:Get(player)
local had = data and data.Owned.Sage
if data then
	data.Owned.Sage = nil
end
S.MonetizationService:GrantPass(player, "SeasonPass")
task.wait(2)
check("pass-attr", player:GetAttribute("Pass_SeasonPass") == true)
check("pass-grants-class", data ~= nil and data.Owned.Sage == true)
check("isowned-with-pass", Classes.IsOwned("Sage", { Owned = {} }, player))
-- คืนค่าเดิม (ไม่ให้เซฟของเทสค้าง)
if data and not had then
	data.Owned.Sage = nil
end
player:SetAttribute("Pass_SeasonPass", nil)
print(string.format("[AS] CLASSPASS RESULT fails=%d", fails))
print("[AS] CLASSPASS DONE")
