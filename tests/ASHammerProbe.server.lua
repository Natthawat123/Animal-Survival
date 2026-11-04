--[[ ASHammerProbe (server) — build_rbxlx.py --hammerprobe
	ค้อนช่าง: คราฟต์ได้ · ไม่ถือค้อน = ย้าย/รื้อไม่ได้ · ย้ายได้ (เลือดเท่าเดิม) · ย้ายทับของอื่นไม่ได้ · ย้ายเตียงไม่ข้ามวันซ้ำ
	รื้อ = หายไป + คืนวัตถุดิบครึ่งหนึ่งเป็นของบนพื้น
	ผล: "[AS] HAMMERPROBE PASS/FAIL ..." · จบด้วย "[AS] HAMMERPROBE DONE" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASHammerProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)

local Dir = require(game:GetService("ServerScriptService").Server.DirectorService)
local ctx = Dir.ctx
local S = ctx.Services
local B = S.BuildingService
local inv = S.InventoryService
local st = ctx.State
local fails = 0
local function check(name, ok, detail)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] HAMMERPROBE %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end
local function shot(name, delay)
	ReplicatedStorage:SetAttribute("HammerShot", name .. ":" .. delay .. ":" .. os.clock())
end
player:SetAttribute("TestGod", true)

-- ยืนข้างกองไฟ หันออกนอกแคมป์
local camp = ctx.CampPosition
local out = Vector3.new(1, 0, 0)
local function ground(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, camp.Y + 80, z), Vector3.new(0, -200, 0), B.rayParams)
	return hit and hit.Position or Vector3.new(x, camp.Y, z)
end
local stand = ground(camp.X + 16, camp.Z)
player.Character:PivotTo(CFrame.lookAt(stand + Vector3.new(0, 3, 0), stand + Vector3.new(0, 3, 0) + out))
task.wait(1)

-- คราฟต์ค้อน
check("recipe", require(ReplicatedStorage.Shared.Recipes).ById.BuildHammer ~= nil)
check("toolbuild", require(game:GetService("ServerScriptService").Server.ToolFactory).Build("BuildHammer") ~= nil)
inv:Add(player, "Wood", 10, true)
inv:Add(player, "Stone", 10, true)
S.CraftService = S.CraftService
inv:Add(player, "BuildHammer", 1)
task.wait(1)
local tool = player.Backpack:FindFirstChild("Builder's Hammer") or player.Character:FindFirstChild("Builder's Hammer")
check("hammer-tool", tool ~= nil and tool:GetAttribute("ItemId") == "BuildHammer", tool and tool.Name)

-- สิ่งก่อสร้าง 3 ชิ้น
local a = B:Spawn("LogWall", CFrame.new(ground(camp.X + 30, camp.Z - 8)), 200, 300, player.UserId)
local b = B:Spawn("Lantern", CFrame.new(ground(camp.X + 30, camp.Z + 10)), 120, 120, player.UserId)
local bed = B:Spawn("Bed", CFrame.new(ground(camp.X + 22, camp.Z + 22)), 150, 150, player.UserId)
task.wait(1)

-- ไม่ถือค้อน: ย้ายไม่ได้
local p0 = a:GetPivot().Position
check("no-hammer-move-blocked", B:Move(player, a, CFrame.new(ground(camp.X + 30, camp.Z - 26))) == false and (a:GetPivot().Position - p0).Magnitude < 0.1)

-- ถือค้อน
player.Character:FindFirstChildOfClass("Humanoid"):EquipTool(tool)
task.wait(1.5)
shot("hold", 0.5)
task.wait(2)

-- ย้าย: ไปจุดใหม่ เลือดเท่าเดิม
local target = ground(camp.X + 30, camp.Z - 26)
check("move-ok", B:Move(player, a, CFrame.new(target) * CFrame.Angles(0, math.rad(45), 0)) == true)
check("move-pos", (a:GetPivot().Position - target).Magnitude < 1.5, (a:GetPivot().Position - target).Magnitude)
check("move-keeps-hp", a:GetAttribute("Health") == 200, a:GetAttribute("Health"))
-- ย้ายไปทับตะเกียง: ไม่ได้
local pA = a:GetPivot().Position
check("move-overlap-blocked", B:Move(player, a, CFrame.new(b:GetPivot().Position)) == false and (a:GetPivot().Position - pA).Magnitude < 0.1)
-- ย้ายนิดเดียว (ทับตัวเองได้)
check("move-onto-self-ok", B:Move(player, a, CFrame.new(pA + Vector3.new(1, 0, 0))) == true)
-- ย้ายออกนอกแคมป์: ไม่ได้
check("move-outside-blocked", B:Move(player, a, CFrame.new(ground(camp.X + 400, camp.Z))) == false)

-- เตียง: ย้ายแล้ววันไม่เพิ่ม
local n0, bonus0 = Dir.night, st:GetAttribute("BonusDays") or 0
check("bed-move-ok", B:Move(player, bed, CFrame.new(ground(camp.X + 22, camp.Z + 34))) == true)
check("bed-move-no-skip", Dir.night == n0 and (st:GetAttribute("BonusDays") or 0) == bonus0, Dir.night)

-- เมนู + โหมดย้าย (ภาพ)
local tv = Instance.new("ObjectValue")
tv.Name = "HammerTarget"
tv.Value = b
tv.Parent = ReplicatedStorage
task.wait(0.5)
ReplicatedStorage:SetAttribute("HammerMenu", os.clock())
shot("menu", 1.2)
task.wait(3)
ReplicatedStorage:SetAttribute("HammerMove", os.clock())
shot("move_ghost", 1.5)
task.wait(3.5)
ReplicatedStorage:SetAttribute("HammerStop", os.clock())
task.wait(1)

-- รื้อ: หายไป + ของคืนครึ่งหนึ่ง (LogWall = ไม้ 6 -> 3)
local drops = Workspace:FindFirstChild("Drops")
local function dropCount(id, near)
	local n = 0
	for _, d in ipairs((drops and drops:GetChildren()) or Workspace:GetDescendants()) do
		if d:GetAttribute("ItemId") == id and (d:GetPivot().Position - near).Magnitude < 15 then
			n += d:GetAttribute("Count") or 1
		end
	end
	return n
end
local wallPos = a:GetPivot().Position
local before = dropCount("Wood", wallPos)
check("demolish-ok", B:Demolish(player, a) == true)
shot("demolish", 0.4)
task.wait(1.5)
check("demolish-gone", a.Parent == nil)
local got = dropCount("Wood", wallPos) - before
check("demolish-refund", got == 3, got)
-- รื้อซ้ำ (ของหายแล้ว) ไม่พัง
check("demolish-twice-safe", B:Demolish(player, a) == false)

-- เก็บค้อน: รื้อไม่ได้
player.Character:FindFirstChildOfClass("Humanoid"):UnequipTools()
task.wait(0.5)
check("unequipped-demolish-blocked", B:Demolish(player, b) == false and b.Parent ~= nil)

print(string.format("[AS] HAMMERPROBE RESULT fails=%d", fails))
print("[AS] HAMMERPROBE DONE")
