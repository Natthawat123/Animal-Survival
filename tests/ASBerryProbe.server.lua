--[[ ASBerryProbe (server) — build_rbxlx.py --berryprobe · พุ่มเบอร์รี่มีปุ่มเก็บ/กิน + กินจากพุ่ม/กระสอบได้ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASBerryProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
player:SetAttribute("TestGod", true)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local bushes, prompted = {}, 0
for _, n in ipairs(CollectionService:GetTagged("ResourceNode")) do
	if n:GetAttribute("Node") == "Bush" and n:IsDescendantOf(workspace.World) then
		table.insert(bushes, n)
		if n:FindFirstChild("BushEat", true) then
			prompted += 1
		end
	end
end
print(string.format("[AS] BERRYPROBE bushes=%d prompted=%d", #bushes, prompted))
-- พุ่มใกล้แคมป์สุด -> ยืนหน้าพุ่ม ถ่ายปุ่ม
local root = player.Character.HumanoidRootPart
table.sort(bushes, function(a, b)
	return (a:GetPivot().Position - root.Position).Magnitude < (b:GetPivot().Position - root.Position).Magnitude
end)
local bush = bushes[1]
local shot = Instance.new("StringValue")
shot.Name = "BerryShot"
shot.Parent = ReplicatedStorage
local function info(tag)
	local vis = 0
	for _, d in ipairs(bush:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Size.Magnitude < 3 then
			vis += 1
		end
	end
	print(string.format("[AS] BERRYPROBE %s berries=%s/%s visibleSmall=%d depleted=%s hunger=%s sack=%s", tag, tostring(bush:GetAttribute("Berries")),
		tostring(bush:GetAttribute("MaxBerries")), vis, tostring(bush:GetAttribute("Depleted")), tostring(math.floor(player:GetAttribute("Hunger") or 0)),
		tostring(S.InventoryService:Get(player).Berries)))
end
if bush then
	local p = bush:GetPivot().Position
	local stand = p + Vector3.new(0, 3, 7)
	player.Character:PivotTo(CFrame.lookAt(stand, Vector3.new(p.X, stand.Y, p.Z)))
	task.wait(4)
	info("full")
	shot.Value = "full"
	task.wait(2)
	player:SetAttribute("Hunger", 40)
	S.ResourceService:PickBerry(player, bush, "Sack")
	S.ResourceService:PickBerry(player, bush, "Sack")
	S.ResourceService:PickBerry(player, bush, "Eat")
	S.ResourceService:Hit(player, bush, {})
	task.wait(0.5)
	info("picked4")
	shot.Value = "picked"
	task.wait(22)
	info("regrow20s")
	shot.Value = "regrow"
	task.wait(2)
end
print("[AS] BERRYPROBE done")
