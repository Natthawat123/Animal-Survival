--[[ ASFogProbe (server) — build_rbxlx.py --fogprobe · พาผู้เล่นไปชนกำแพงหมอกทีละเลเวลกองไฟ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASFogProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(8)
local Camp = require(Server:WaitForChild("CampService"))
local shot = ReplicatedStorage:FindFirstChild("ProbeShot") or Instance.new("StringValue")
shot.Name = "ProbeShot"
shot.Parent = ReplicatedStorage
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -3000, 0), rp)
	return hit and hit.Position.Y or 30
end
local function setLevel(lv)
	Camp.level = lv
	Camp.fuel = Camp:Info().MaxFuel
	Camp:Publish()
end
local dir = Vector3.new(1, 0, 0.35).Unit
for _, lv in ipairs({ 1, 2, 3 }) do
	setLevel(lv)
	task.wait(lv == 1 and 1 or 7)
	local R = Camp:RevealRadius()
	local char = player.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	local start = dir * (R - 90)
	char:PivotTo(CFrame.lookAt(Vector3.new(start.X, ground(start.X, start.Z) + 4, start.Z), Vector3.new(start.X, ground(start.X, start.Z) + 4, start.Z) + dir))
	task.wait(2)
	shot.Value = "fog_L" .. lv .. "_approach"
	task.wait(1.5)
	-- เดินพุ่งออกไปนอกหมอก 6 วิ
	local far = dir * (R + 400)
	hum:MoveTo(Vector3.new(far.X, 0, far.Z))
	task.wait(6)
	local d = (char.HumanoidRootPart.Position * Vector3.new(1, 0, 1)).Magnitude
	print(string.format("[AS] FOGPROBE L%d reveal=%d dist=%.1f %s", lv, R, d, d <= R + 1 and "BLOCKED" or "LEAKED"))
	shot.Value = "fog_L" .. lv .. "_wall"
	task.wait(1.5)
end
-- กลางคืน
local st = ReplicatedStorage:FindFirstChild("GameState")
if st then
	st:SetAttribute("TestClock", 22)
end
task.wait(3)
shot.Value = "fog_night"
task.wait(1.5)
print("[TEST] DONE probe")
