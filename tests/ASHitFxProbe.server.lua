--[[ ASHitFxProbe (server) — build_rbxlx.py --hitfxprobe : เอฟเฟกต์ตีธรรมดาอาวุธธาตุ 5 ชิ้น (ตีรัวใส่มอนหุ่น แล้ว client ถ่าย) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASHitFxProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local SSS = game:GetService("ServerScriptService")
local ctx = require(SSS.Server.RejoinService).ctx
local ToolFactory = require(SSS.Server.ToolFactory)
local S = ctx.Services
player:SetAttribute("TestGod", true)
local spot = ctx.CampPosition + Vector3.new(60, 0, 60)
local function ground(p)
	return Vector3.new(p.X, ctx.Layout:HeightAt(p.X, p.Z), p.Z)
end
local me = ground(spot) + Vector3.new(0, 3, 0)
local fails = 0
dealtSum = 0
local da = S.CombatService.DamageAnimal
S.CombatService.DamageAnimal = function(self, a, dmg, ...)
	dealtSum += dmg
	return da(self, a, dmg, ...)
end
local cam = Instance.new("CFrameValue")
cam.Name = "HitFxCam"
cam.Parent = ReplicatedStorage
local function equip(id)
	S.InventoryService:Add(player, id, 1, true)
	task.wait(0.3)
	S.InventoryService:EquipItem(player, id)
end
for _, id in ipairs({ "TerraHammer", "TidalTrident", "GaleBow", "EmberBlade", "FourfoldBlade" }) do
	local far = id == "GaleBow" and 14 or 7
	local target = ground(spot + Vector3.new(0, 0, -far)) + Vector3.new(0, 2, 0)
	S.DevService:Teleport(player, me)
	task.wait(0.3)
	player.Character:PivotTo(CFrame.lookAt(me, Vector3.new(target.X, me.Y, target.Z)))
	equip(id)
	task.wait(0.3)
	local held = player.Character:FindFirstChildOfClass("Tool")
	print("[AS] HITFXPROBE held", id, held and held:GetAttribute("ItemId"), tostring((player.Character:GetPivot().Position - me).Magnitude))
	local a = S.AnimalService:Spawn("ReefCrab", target, { Kind = "Wild", HealthMult = 200 })
	task.wait(0.8)
	-- กล้องหลังไหล่ (มุมเดียวกับตอนเล่นจริง)
	local fwd = ((target - me) * Vector3.new(1, 0, 1)).Unit
	local side = fwd:Cross(Vector3.new(0, 1, 0))
	cam.Value = CFrame.lookAt(me - fwd * 11 + side * 3 + Vector3.new(0, 5, 0), target + Vector3.new(0, 1, 0))
	dealtSum = 0
	local t0 = os.clock()
	local shot = false
	local hitsBefore = a and a.Hum and a.Hum.Health
	while os.clock() - t0 < 6 do
		S.CombatService.lastAttack[player] = 0
		player.Character:PivotTo(CFrame.lookAt(me, Vector3.new(target.X, me.Y, target.Z)))
		if a and a.Root then
			a.Root.Anchored = true
			a.Model:PivotTo(CFrame.new(target) * (a.Model:GetPivot() - a.Model:GetPivot().Position))
		end
		local aim = ((a and a.Root and a.Root.Position or target) - (me + Vector3.new(0, 1.5, 0))).Unit
		local ok, err = pcall(S.CombatService.OnAttack, S.CombatService, player, aim)
		if not ok then
			print("[AS] HITFXPROBE err " .. tostring(err))
		end
		if not shot and os.clock() - t0 > 0.5 then
			shot = true
			cam:SetAttribute("Shot", id)
		end
		task.wait(0.22)
	end
	local dealt = dealtSum
	if dealt <= 0 then
		fails += 1
	end
	print(string.format("[AS] HITFXPROBE %s %s dealt=%d", dealt > 0 and "PASS" or "FAIL", id, dealt))
	if a then
		S.AnimalService:Remove(a)
	end
	task.wait(0.5)
end
print(string.format("[AS] HITFXPROBE TOTAL fails=%d", fails))
print("[TEST] DONE hitfxprobe")
