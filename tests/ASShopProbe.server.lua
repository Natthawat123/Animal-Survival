--[[ ASShopProbe (server) — build_rbxlx.py --medprobe · ทีมล้มหมด + มีตั๋วคืนชีพ = รอก่อนแพ้ · ใช้ตั๋ว = ลุกขึ้น รอบเล่นต่อ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
repeat
	task.wait(0.5)
until ReplicatedStorage:GetAttribute("WildDone")
local player = Players:GetPlayers()[1]
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local surv, data = S.SurvivalService, S.DataService
local state = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.State
player:SetAttribute("TestGod", nil)
local d = data:Get(player)
d.ReviveTokens = 1
player:SetAttribute("ReviveTokens", 1)
S.DevService:Teleport(player, require(game:GetService("ServerScriptService").Server.RejoinService).ctx.CampPosition + Vector3.new(20, 0, 0))
task.wait(1)
surv:Down(player, "Test")
task.wait(1.5)
print(string.format("[AS] SHOPPROBE downed=%s wipeAt=%s phase=%s", tostring(surv:IsDowned(player)), tostring(state:GetAttribute("WipeAt") ~= nil), tostring(state:GetAttribute("Phase"))))
ReplicatedStorage:SetAttribute("ShopStep", "downed")
task.wait(6)
print(string.format("[AS] SHOPPROBE after ticket downed=%s tokens=%s wipeAt=%s phase=%s", tostring(surv:IsDowned(player)), tostring(player:GetAttribute("ReviveTokens")), tostring(state:GetAttribute("WipeAt") ~= nil), tostring(state:GetAttribute("Phase"))))
ReplicatedStorage:SetAttribute("ShopStep", "store")
task.wait(5)
-- ไม่มีตั๋ว: ปุ่มซื้อคืนชีพ (Robux) ขึ้น · ไม่กดภายใน WipeGrace = แพ้
d.ReviveTokens = 0
player:SetAttribute("ReviveTokens", 0)
surv:Down(player, "Test")
task.wait(2)
ReplicatedStorage:SetAttribute("ShopStep", "buy")
task.wait(17)
print("[AS] SHOPPROBE no ticket after grace phase=" .. tostring(state:GetAttribute("Phase")))
print("[AS] SHOPPROBE done")
