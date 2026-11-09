--[[ ASBerryProbe (server) — build_rbxlx.py --berryprobe
	พุ่มเบอร์รี่: ชี้ลูกบนต้นแล้วเก็บ (ไม่มี ProximityPrompt) · แปลงเบอร์รี่โตเป็นช่วง ๆ แล้วลูกออก เก็บหมด = ปลูกใหม่
	+ ถ่ายโมเดลใหม่: พุ่ม / ลูกเบอร์รี่ (ไอเทม) / หนังสัตว์ (ไอเทม)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASBerryProbe") then
	return
end
local Items = require(ReplicatedStorage.Shared.Items)
Items.Structures.FarmPlot.GrowTime = 12 -- เร่งให้เห็นทุกช่วงโตในเทส
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
player:SetAttribute("TestGod", true)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services

local shot = Instance.new("StringValue")
shot.Name = "BerryShot"
shot.Parent = ReplicatedStorage
local aim = Instance.new("ObjectValue")
aim.Name = "BerryAim"
aim.Parent = ReplicatedStorage
local function snap(name, wait)
	shot.Value = ""
	task.wait(0.1)
	shot.Value = name
	task.wait(wait or 2)
end
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] BERRYPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
local function berries(src)
	local vis, all = 0, 0
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Berry" then
			all += 1
			if d.Transparency < 0.95 and not d:GetAttribute("Picked") then
				vis += 1
			end
		end
	end
	return vis, all
end
local function firstBerry(src)
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Berry" and d.Transparency < 0.95 and not d:GetAttribute("Picked") then
			return d
		end
	end
end

-- 1) พุ่มในป่า: ติดแท็ก ไม่มีปุ่มกด มีลูกชื่อ Berry
local bushes, prompted = {}, 0
for _, n in ipairs(CollectionService:GetTagged("BerrySource")) do
	if n:GetAttribute("Node") == "Bush" then
		table.insert(bushes, n)
		if n:FindFirstChildWhichIsA("ProximityPrompt", true) then
			prompted += 1
		end
	end
end
check("bushes_tagged", #bushes > 5, "n=" .. #bushes)
check("no_prompts", prompted == 0, "prompted=" .. prompted)
local root = player.Character.HumanoidRootPart
table.sort(bushes, function(a, b)
	return (a:GetPivot().Position - root.Position).Magnitude < (b:GetPivot().Position - root.Position).Magnitude
end)
local bush = bushes[1]
if bush then
	local vis, all = berries(bush)
	check("bush_berries", vis >= 5 and vis == bush:GetAttribute("Berries"), string.format("visible=%d all=%d attr=%s", vis, all, tostring(bush:GetAttribute("Berries"))))
	local p = bush:GetPivot().Position
	local stand = p + Vector3.new(0, 3, 8)
	player.Character:PivotTo(CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z)))
	task.wait(2)
	-- client เล็งกล้องไปที่ลูก -> ต้องขึ้นกรอบ + ป้าย (client ตรวจแล้วพิมพ์ผล) แล้วยิง PickBerry เหมือนกดคลิก
	local target = firstBerry(bush)
	aim.Value = target
	task.wait(4)
	snap("bush_aim", 1)
	if (S.InventoryService:Get(player).Berries or 0) > 0 then S.InventoryService:Remove(player, "Berries", S.InventoryService:Get(player).Berries) end
	local sack0 = S.InventoryService:Get(player).Berries or 0
	ReplicatedStorage:SetAttribute("BerryClick", target and target:GetFullName() or "")
	local t = os.clock()
	repeat
		task.wait(0.2)
	until (S.InventoryService:Get(player).Berries or 0) > sack0 or os.clock() - t > 6
	task.wait(0.5)
	local vis2 = berries(bush)
	check("click_pick", (S.InventoryService:Get(player).Berries or 0) == sack0 + 1 and vis2 == vis - 1 and target.Transparency >= 0.95,
		string.format("sack %d->%d visible %d->%d", sack0, S.InventoryService:Get(player).Berries or 0, vis, vis2))
	-- ไกลเกิน = ไม่ให้
	local far = firstBerry(bush)
	player.Character:PivotTo(CFrame.new(p + Vector3.new(0, 3, 40)))
	task.wait(0.3)
	S.ResourceService:OnPickRequest(player, bush, far, "Sack")
	check("far_rejected", berries(bush) == vis2, "visible=" .. berries(bush))
	player.Character:PivotTo(CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z)))
	task.wait(0.5)
	-- กินจากต้น
	player:SetAttribute("Hunger", 40)
	task.wait(0.2)
	S.ResourceService:OnPickRequest(player, bush, firstBerry(bush), "Eat")
	task.wait(0.3)
	check("eat_from_bush", (player:GetAttribute("Hunger") or 0) > 40 and berries(bush) == vis2 - 1, "hunger=" .. tostring(player:GetAttribute("Hunger")))
	-- เก็บจนหมด
	for _ = 1, 10 do
		local b = firstBerry(bush)
		if not b then
			break
		end
		task.wait(0.15)
		S.ResourceService:OnPickRequest(player, bush, b, "Sack")
	end
	task.wait(0.5)
	check("bush_empty", berries(bush) == 0 and bush:GetAttribute("Berries") == 0, "left=" .. berries(bush))
	aim.Value = nil
	snap("bush_empty", 1)
end

-- 2) ไอเทมใหม่: ลูกเบอร์รี่ + หนังสัตว์ ตกบนพื้น
local base = root.Position + root.CFrame.LookVector * 7
S.DropService:Spawn("Berries", 1, base + Vector3.new(-2, 2, 0))
S.DropService:Spawn("Pelt", 1, base + Vector3.new(2, 2, 0))
task.wait(2.5)
aim.Value = nil
ReplicatedStorage:SetAttribute("BerryCam", "drops")
snap("drops", 2)

-- 3) แปลงเบอร์รี่: ต้นกล้า -> โต -> ลูกออก -> เก็บหมด -> กลับเป็นต้นกล้า
local spot = root.Position + root.CFrame.LookVector * 14
local hit = workspace:Raycast(spot + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0))
if hit then
	spot = hit.Position
end
local farm = S.BuildingService:Spawn("FarmPlot", CFrame.new(spot), 150, 150, player.UserId)
check("farm_tagged", CollectionService:HasTag(farm, "BerrySource"), "")
ReplicatedStorage:SetAttribute("BerryCam", "farm")
local farmObj = Instance.new("ObjectValue")
farmObj.Name = "BerryFarm"
farmObj.Value = farm
farmObj.Parent = ReplicatedStorage
local function cropH()
	local crops = farm:FindFirstChild("Crops")
	local _, sz = crops:GetBoundingBox()
	return sz.Y
end
task.wait(1)
local h0 = cropH()
check("farm_sprout_noberry", berries(farm) == 0 and not farm:GetAttribute("Ripe"), string.format("vis=%d h=%.2f", berries(farm), h0))
snap("farm_1sprout", 1)
task.wait(4)
local h1 = cropH()
snap("farm_2grow", 1)
task.wait(4)
local h2 = cropH()
snap("farm_3big", 1)
local t0 = os.clock()
repeat
	task.wait(0.3)
until farm:GetAttribute("Ripe") or os.clock() - t0 > 10
task.wait(0.8)
local h3 = cropH()
local fv = berries(farm)
check("farm_grows", h0 < h1 and h1 < h2 and h2 < h3, string.format("h %.2f %.2f %.2f %.2f", h0, h1, h2, h3))
check("farm_ripe", farm:GetAttribute("Ripe") == true and fv == Items.Structures.FarmPlot.Yield, string.format("visible=%d yield=%d", fv, Items.Structures.FarmPlot.Yield))
aim.Value = firstBerry(farm)
task.wait(2)
snap("farm_4ripe_aim", 1)
aim.Value = nil
if (S.InventoryService:Get(player).Berries or 0) > 0 then S.InventoryService:Remove(player, "Berries", S.InventoryService:Get(player).Berries) end
local sack1 = S.InventoryService:Get(player).Berries or 0
local fp = farm:GetPivot().Position
player.Character:PivotTo(CFrame.lookAt(fp + Vector3.new(0, 3, 7), fp))
task.wait(0.5)
for _ = 1, 20 do
	local b = firstBerry(farm)
	if not b then
		break
	end
	task.wait(0.15)
	S.ResourceService:OnPickRequest(player, farm, b, "Sack")
end
task.wait(1)
local got = (S.InventoryService:Get(player).Berries or 0) - sack1
check("farm_harvest", got == fv and berries(farm) == 0 and not farm:GetAttribute("Ripe"), string.format("got=%d", got))
task.wait(0.6)
local h4 = cropH()
check("farm_replant", h4 < h2 and (farm:GetAttribute("GrowAt") or 0) > os.clock(), string.format("h=%.2f", h4))
snap("farm_5replant", 1)
print(string.format("[AS] BERRYPROBE TOTAL fails=%d", fails))
print("[TEST] DONE berryprobe")
