--[[ ASMedProbe (server) — build_rbxlx.py --medprobe · ถือผ้าพันแผล/ชุดปฐมพยาบาล (โมเดลในมือ) + ท่าพันแผล + ยกเลิกตอนขยับ + ท่าก้มช่วยเพื่อน ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local surv, inv, camp = S.SurvivalService, S.InventoryService, S.CampService
inv:Add(player, "Bandage", 3, true)
inv:Add(player, "Medkit", 2, true)
task.wait(1)
local shot = Instance.new("StringValue")
shot.Name = "MedShot"
shot.Parent = ReplicatedStorage
local bench = camp.benchPos
local stand = bench + Vector3.new(14, 3, 14)
player.Character:PivotTo(CFrame.lookAt(stand, Vector3.new(bench.X, stand.Y, bench.Z)))
task.wait(2)
local char = player.Character
local hum = char:FindFirstChildOfClass("Humanoid")
local function hp()
	return string.format("%d/%d", hum.Health, hum.MaxHealth)
end
local function equip(id)
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("MedKind") == id then
			hum:EquipTool(t)
			local n = 0
			for _, d in ipairs(t:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then
					n += 1
				end
			end
			print(string.format("[AS] MEDPROBE equip %s handle=%s visibleParts=%d", id, tostring(t:FindFirstChild("Handle") ~= nil), n))
			return t
		end
	end
	print("[AS] MEDPROBE equip " .. id .. " NOT FOUND")
end
local function show(v, wait)
	shot.Value = v
	task.wait(wait or 4)
end

equip("Bandage")
task.wait(1)
show("bandage_hold")
surv:Damage(player, 60, "Test")
task.wait(0.5)
print("[AS] MEDPROBE before self hp=" .. hp() .. " bandage=" .. inv:Count(player, "Bandage"))
surv:UseMedical(player, "Bandage")
print("[AS] MEDPROBE channel MedUse=" .. tostring(player:GetAttribute("MedUse")) .. " time=" .. tostring(player:GetAttribute("MedTime")))
shot.Value = "self_front"
task.wait(2.5)
print("[AS] MEDPROBE after self hp=" .. hp() .. " bandage=" .. inv:Count(player, "Bandage") .. " MedUse=" .. tostring(player:GetAttribute("MedUse")))

-- ยกเลิก: ขยับตัวระหว่างพันแผล -> ไม่เสียของ
surv:Damage(player, 30, "Test")
task.wait(0.5)
local before = inv:Count(player, "Bandage")
surv:UseMedical(player, "Bandage")
task.wait(0.5)
char:PivotTo(char:GetPivot() * CFrame.new(0, 0, -5))
task.wait(0.6)
print(string.format("[AS] MEDPROBE cancel move bandage %d->%d MedUse=%s hp=%s", before, inv:Count(player, "Bandage"), tostring(player:GetAttribute("MedUse")), hp()))
task.wait(1)

-- ยกเลิก: โดนตีระหว่างพันแผล
before = inv:Count(player, "Bandage")
surv:UseMedical(player, "Bandage")
task.wait(0.5)
surv:Damage(player, 5, "Test")
task.wait(0.5)
print(string.format("[AS] MEDPROBE cancel hit bandage %d->%d MedUse=%s", before, inv:Count(player, "Bandage"), tostring(player:GetAttribute("MedUse"))))
task.wait(1)

-- ชุดปฐมพยาบาล
equip("Medkit")
task.wait(1)
show("medkit_hold")
surv:UseMedical(player, "Medkit")
shot.Value = "medkit_side"
task.wait(3)
print("[AS] MEDPROBE after medkit hp=" .. hp() .. " medkit=" .. inv:Count(player, "Medkit"))

-- ท่าก้มช่วยเพื่อน (ไม่มีผู้เล่นที่ 2 -> ตั้งท่าตรงๆ)
surv:SetMedPose(player, "Revive", 3, nil, "Bandage")
show("revive_side", 4)
show("revive_front", 4)
surv:SetMedPose(player, nil)
task.wait(1)
-- เลือดเต็ม = ไม่ใช้
surv:UseMedical(player, "Bandage")
print("[AS] MEDPROBE full hp MedUse=" .. tostring(player:GetAttribute("MedUse")))
print("[AS] MEDPROBE done")
