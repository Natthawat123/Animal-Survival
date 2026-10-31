--[[ ASCookProbe (server) — build_rbxlx.py --cookprobe · ย่างเนื้อที่กองไฟ + กองไฟไม่ดูดของจากไกล ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASCookProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
player:SetAttribute("TestGod", true)
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local camp, drops, inv = S.CampService, S.DropService, S.InventoryService
local fire = camp:FirePosition()
local function cooked()
	local n = 0
	for _, d in ipairs(drops:Near(fire, 14, 10)) do
		if d.Id == "CookedMeat" then
			n += d.Count
		end
	end
	return n
end
local shot = Instance.new("StringValue")
shot.Name = "CookShot"
shot.Parent = ReplicatedStorage
inv:Add(player, "RawMeat", 3, true)
-- ไกล 25 สตัด: โยนไม่ได้
local far = fire + Vector3.new(0, 2, 25)
player.Character:PivotTo(CFrame.lookAt(far, Vector3.new(fire.X, far.Y, fire.Z)))
task.wait(1)
camp:ThrowFrom(player, "Meat")
print("[AS] COOKPROBE far raw=" .. tostring(inv:Count(player, "RawMeat")))
-- ใกล้ 8 สตัด: ถ่ายปุ่ม แล้วโยนเนื้อ
local near = fire + Vector3.new(0, 2, 8)
player.Character:PivotTo(CFrame.lookAt(near, Vector3.new(fire.X, near.Y, fire.Z)))
task.wait(3)
shot.Value = "prompts"
task.wait(1.5)
camp:ThrowFrom(player, "Meat")
task.wait(1.6)
shot.Value = "cooking"
task.wait(4)
print("[AS] COOKPROBE near raw=" .. tostring(inv:Count(player, "RawMeat")) .. " cooked=" .. cooked())
shot.Value = "cooked"
task.wait(1.5)
print("[AS] COOKPROBE done")
