--[[ ASArmorProbe (server) — build_rbxlx.py --armorprobe · คราฟต์เกราะไม้/เหล็ก/ทอง -> เลือดเพิ่ม + โมเดลบนตัว + ถ่ายภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASArmorProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
player:SetAttribute("TestGod", true)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local camp, inv = S.CampService, S.InventoryService
camp:Restore(3, 4, 200)
for id, n in pairs({ Wood = 40, Fiber = 30, Iron = 60, Pelt = 20, EmberShard = 10, TerraCore = 10 }) do
	inv:Add(player, id, n, true)
end
local shot = Instance.new("StringValue")
shot.Name = "ArmorShot"
shot.Parent = ReplicatedStorage
local bench = camp.benchPos
local stand = bench + Vector3.new(14, 3, 14)
player.Character:PivotTo(CFrame.lookAt(stand, Vector3.new(bench.X, stand.Y, bench.Z)))
task.wait(2)
-- เสื้อเลเยอร์บนตัว: นับ Accessory ที่มี WrapLayer + ชื่อ
local function layered()
	local c = player.Character
	local names = {}
	for _, a in ipairs(c:GetChildren()) do
		if a:IsA("Accessory") and a:FindFirstChildWhichIsA("WrapLayer", true) then
			table.insert(names, a.Name)
		end
	end
	return string.format("layeredAttr=%s rig=%s wraps=[%s]", tostring(c:GetAttribute("ArmorLayered")), c:FindFirstChildOfClass("Humanoid").RigType.Name, table.concat(names, ", "))
end
local function hp()
	local h = player.Character:FindFirstChildOfClass("Humanoid")
	return h and string.format("%d/%d", h.Health, h.MaxHealth) or "?"
end
print("[AS] ARMORPROBE base hp=" .. hp() .. " rig=" .. (player.Character:FindFirstChild("UpperTorso") and "R15" or "R6"))
for _, id in ipairs({ "WoodArmor", "IronArmor", "GoldArmor" }) do
	camp:Craft(player, id, 1)
	task.wait(1)
	task.wait(2) -- เสื้อเลเยอร์โหลดจากแคตตาล็อก
	print(string.format("[AS] ARMORPROBE %s armor=%s hp=%s %s", id, tostring(player:GetAttribute("Armor")), hp(), layered()))
	shot.Value = id
	task.wait(10)
end
-- รองรับทุกขนาดตัว: ปรับสเกลตัว (ตัวใหญ่หนา / ตัวเล็ก) -> เกราะต้องปรับตามเอง
local function sizes(tag)
	local c = player.Character
	local t = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
	local v = c:FindFirstChild("ArmorVisual")
	local bs = v and select(2, v:GetBoundingBox())
	print(string.format("[AS] ARMORPROBE size_%s torso=%s armor=%s", tag, tostring(t and t.Size), tostring(bs)))
end
sizes("normal")
local hum = player.Character:FindFirstChildOfClass("Humanoid")
local function scale(w, d, h)
	for name, v in pairs({ BodyWidthScale = w, BodyDepthScale = d, BodyHeightScale = h }) do
		local nv = hum:FindFirstChild(name)
		if not nv then
			nv = Instance.new("NumberValue")
			nv.Name = name
			nv.Parent = hum
		end
		nv.Value = v
	end
end
scale(1.6, 1.8, 1.3)
task.wait(2)
sizes("big")
shot.Value = "big"
task.wait(10)
scale(0.6, 0.6, 0.7)
task.wait(2)
sizes("small")
shot.Value = "small"
task.wait(10)
scale(1, 1, 1)
task.wait(1)
-- ระดับต่ำกว่าคราฟต์ไม่ได้
camp:Craft(player, "WoodArmor", 1)
print("[AS] ARMORPROBE downgrade armor=" .. tostring(player:GetAttribute("Armor")) .. " wood=" .. tostring(inv:Count(player, "Wood")))
-- เกิดใหม่: เกราะ/เลือดยังอยู่
player:LoadCharacter()
task.wait(4)
task.wait(3)
print("[AS] ARMORPROBE respawn hp=" .. hp() .. " " .. layered())
shot.Value = "menu"
task.wait(4)
print("[AS] ARMORPROBE done")
