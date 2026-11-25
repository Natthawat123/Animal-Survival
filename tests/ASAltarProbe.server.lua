--[[ ASAltarProbe (server) — build_rbxlx.py --altarprobe · แท่นหินกะโหลกกลางหมู่บ้านชนเผ่า 3 ไบโอม: มีจริง · ไม่จม/ไม่โดนบัง · กดเก็บได้ · เก็บซ้ำไม่ได้ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASAltarProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
local altars = CollectionService:GetTagged("SkullAltar")
print("[AS] ALTAR count=" .. #altars)
for _, a in ipairs(altars) do
	local stone = a.PrimaryPart
	local id = a:GetAttribute("KeyStone")
	local prompt = stone and stone:FindFirstChildOfClass("ProximityPrompt")
	-- มีอะไรทึบบังรอบหินไหม (ยกเว้นแท่นตัวเอง)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { a }
	local blocked = 0
	for _, p in ipairs(workspace:GetPartBoundsInBox(stone.CFrame, Vector3.new(4, 4, 4), op)) do
		if p.CanCollide and p.Transparency < 0.9 then
			blocked += 1
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local g = workspace:Raycast(stone.Position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), rp)
	S.DevService:Teleport(player, stone.Position + Vector3.new(0, -2, -8))
	task.wait(3)
	ReplicatedStorage:SetAttribute("AltarCam", CFrame.lookAt(stone.Position + Vector3.new(14, 10, -26), stone.Position))
	ReplicatedStorage:SetAttribute("AltarShot", "altar_" .. tostring(a:GetAttribute("Element")))
	task.wait(3.5)
	local inv = S.InventoryService
	local n0 = inv:Count(player, id)
	-- กดเก็บ 2 ครั้ง (ตัวเดียวกับที่ปุ่ม E เรียก): ครั้งที่ 2 ต้องไม่ได้เพิ่ม
	S.LootService:TakeAltar(a, player)
	local n1 = inv:Count(player, id)
	S.LootService:TakeAltar(a, player)
	local n2 = inv:Count(player, id)
	print(string.format("[AS] ALTAR %s id=%s prompt=%s dist=%.0f groundGap=%.1f blocked=%d take %d->%d again->%d opened=%s",
		tostring(a:GetAttribute("Element")), tostring(id), tostring(prompt ~= nil), prompt and prompt.MaxActivationDistance or -1,
		g and (stone.Position.Y - g.Position.Y) or -1, blocked, n0, n1, n2, tostring(a:GetAttribute("Opened_" .. player.UserId))))
	task.wait(2.5)
	ReplicatedStorage:SetAttribute("AltarShot", "altar_" .. tostring(a:GetAttribute("Element")) .. "_taken")
	task.wait(3.5)
end
print("[TEST] DONE altarprobe")
