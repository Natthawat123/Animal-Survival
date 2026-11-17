--[[ ASStorageProbe (server) — build_rbxlx.py --storageprobe · กล่องเก็บของ 20/40 + ประตูไม้ (เปิด/ปิด, ต่อกำแพง, รื้อ, เซฟ) + ภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASStorageProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local Items = require(ReplicatedStorage.Shared.Items)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Storage, B, inv = S.StorageService, S.BuildingService, S.InventoryService
player:SetAttribute("TestGod", true)
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] STORAGE %s %s %s", ok and "PASS" or "FAIL", name, tostring(info or "")))
end

check("recipes", Recipes.ById.StorageBox and Recipes.ById.BigStorageBox and Recipes.ById.WoodDoor ~= nil)
check("capacity-spec", Items.Structures.StorageBox.Storage == 20 and Items.Structures.BigStorageBox.Storage == 40)

-- คราฟต์จริง (ของพอ) -> ได้สิ่งก่อสร้างในกระเป๋า
inv:Add(player, "Wood", 60, true)
inv:Add(player, "Iron", 4, true)
S.CampService.bench = math.max(S.CampService.bench or 1, 2)
player.Character:PivotTo(CFrame.new(S.CampService.benchTopPos + Vector3.new(0, 2, 4)))
task.wait(0.5)
for _, id in ipairs({ "StorageBox", "BigStorageBox", "WoodDoor" }) do
	local n0 = inv:Count(player, id)
	S.CampService:Craft(player, id, 1)
	check("craft-" .. id, inv:Count(player, id) == n0 + 1, inv:Count(player, id))
end

-- วางข้างแคมป์
local camp = ctx.CampPosition
local function ground(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, camp.Y + 200, z), Vector3.new(0, -400, 0), rp)
	return Vector3.new(x, hit and hit.Position.Y or camp.Y, z)
end
local base = camp + Vector3.new(28, 0, 10)
local small = B:Spawn("StorageBox", CFrame.new(ground(base.X, base.Z)), 200, 200, player.UserId)
local big = B:Spawn("BigStorageBox", CFrame.new(ground(base.X + 9, base.Z)), 300, 300, player.UserId)
local door = B:Spawn("WoodDoor", CFrame.new(ground(base.X + 4, base.Z + 12)), 300, 300, player.UserId)
local wall = B:Spawn("LogWall", CFrame.new(ground(base.X + 16, base.Z + 12)), 300, 300, player.UserId)
check("spawned", small and big and door and wall and small:FindFirstChild("Body") and door:FindFirstChild("Leaf") ~= nil)
check("prompts", small.Body:FindFirstChild("StoragePrompt") ~= nil and door:FindFirstChild("DoorPrompt", true) ~= nil)

local root = player.Character.HumanoidRootPart
player.Character:PivotTo(CFrame.lookAt(small:GetPivot().Position + Vector3.new(4, 4, -9), small:GetPivot().Position))
task.wait(1)

-- ต้องมีกระสอบ: ให้กระสอบดี (20) แล้วเก็บไม้ 15 + หิน 10 ใส่กระสอบ
inv:Add(player, "GoodSack", 1, true)
for id, n in pairs(inv:Get(player)) do
	if Items.Bulk(id) then
		inv:Remove(player, id, n)
	end
end
inv:AddToSack(player, "Wood", 12)
inv:AddToSack(player, "Stone", 8)
check("usable-near", Storage:Usable(player, small))
local put = Storage:Put(player, small, "Wood", 5)
check("put-5", put == 5 and Storage.Contents(small).Wood == 5 and inv:Count(player, "Wood") == 7, string.format("put=%d box=%s sack=%d", put, tostring(Storage.Contents(small).Wood), inv:Count(player, "Wood")))
local all = Storage:PutAll(player, small)
check("putall-cap-20", Storage.Used(Storage.Contents(small)) == 20 and all == 15, string.format("moved=%d used=%d", all, Storage.Used(Storage.Contents(small))))
check("box-full-left-in-sack", inv:Used(player) == 0, inv:Used(player))
local tk = Storage:Take(player, small, "Stone", 3)
check("take-3", tk == 3 and inv:Count(player, "Stone") == 3 and Storage.Contents(small).Stone == 5, string.format("take=%d sack=%d", tk, inv:Count(player, "Stone")))
check("attr-used", small:GetAttribute("Used") == 17, small:GetAttribute("Used"))
-- กล่องใหญ่ 40
inv:AddToSack(player, "Wood", 17)
Storage:PutAll(player, big)
local tkAll = Storage:TakeAll(player, small)
Storage:PutAll(player, big)
check("big-holds-40", Storage.Used(Storage.Contents(big)) <= 40 and Storage.Used(Storage.Contents(big)) >= 30, Storage.Used(Storage.Contents(big)))
check("takeall", tkAll > 0, tkAll)
-- ไกลเกิน = ใช้ไม่ได้
player.Character:PivotTo(CFrame.new(small:GetPivot().Position + Vector3.new(40, 4, 0)))
task.wait(0.3)
check("far-not-usable", not Storage:Usable(player, small))

-- ประตู: เปิด = บานหมุนออก / ปิด = กลับที่เดิม
local leaf = door.Leaf.Panel
local p0 = leaf.Position
Storage:SetDoor(door, true)
local p1 = leaf.Position
Storage:SetDoor(door, false)
local p2 = leaf.Position
check("door-opens", (p1 - p0).Magnitude > 2 and door:GetAttribute("Open") == false, string.format("moved %.1f", (p1 - p0).Magnitude))
check("door-closes-back", (p2 - p0).Magnitude < 0.05, string.format("%.3f", (p2 - p0).Magnitude))
check("door-breakable", Items.Structures.WoodDoor.Breakable == true)
check("door-wallsnap", require(ReplicatedStorage.Shared.WallSnap).IsWall("WoodDoor"))

-- เซฟ/โหลด: ของในกล่องอยู่ครบ
local ser = B:Serialize()
local found
for _, r in ipairs(ser) do
	if r[1] == "BigStorageBox" then
		found = r
	end
end
check("serialize-contents", found and type(found[9]) == "string" and found[9]:find("Wood") ~= nil, found and found[9])
local copy = B:Spawn("BigStorageBox", CFrame.new(ground(base.X + 9, base.Z - 8)), 300, 300, player.UserId, found and found[9])
check("restore-contents", copy and Storage.Used(Storage.Contents(copy)) == Storage.Used(Storage.Contents(big)), copy and Storage.Used(Storage.Contents(copy)))
-- รื้อ = ของหล่นพื้น
player.Character:PivotTo(CFrame.lookAt(copy:GetPivot().Position + Vector3.new(0, 4, -8), copy:GetPivot().Position))
task.wait(0.3)
inv:Add(player, "BuildHammer", 1, true)
task.wait(0.3)
inv:EquipItem(player, "BuildHammer")
task.wait(0.5)
local spilled = Storage.Used(Storage.Contents(copy))
local okD = B:Demolish(player, copy)
task.wait(0.5)
local near = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("ItemId") and (d:GetPivot().Position - copy:GetPivot().Position).Magnitude < 14 then
		near += d:GetAttribute("Count") or 1
	end
end
check("demolish-spills", okD and Storage.Used(Storage.Contents(copy)) == 0 and near >= spilled, string.format("ok=%s spilled=%d nearDrops=%d", tostring(okD), spilled, near))

-- ภาพ: กล่อง 2 ใบ + ประตูต่อกำแพง (เปิด) + หน้าต่างกล่อง
Storage:SetDoor(door, true)
player.Character:PivotTo(CFrame.lookAt(base + Vector3.new(4, 5, -12), base + Vector3.new(6, 2, 4)))
task.wait(2)
print("[SHOT] storage_models")
task.wait(1.5)
inv:AddToSack(player, "Wood", 6)
inv:AddToSack(player, "Fiber", 3)
player.Character:PivotTo(CFrame.lookAt(big:GetPivot().Position + Vector3.new(0, 4, -8), big:GetPivot().Position))
task.wait(0.5)
ctx.Remotes.Get("Storage"):FireClient(player, "Open", big)
task.wait(2)
print("[SHOT] storage_ui")
task.wait(1.5)
print(string.format("[AS] STORAGE fails=%d", fails))
print("[TEST] DONE storage")
