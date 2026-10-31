--[[ ASGateProbe (server) — build_rbxlx.py --gateprobe · วางซุ้มประตูมิติทั้ง 8 แบบเรียงกันข้างแคมป์ ให้ client ถ่ายตรงหน้า ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASGateProbe") then
	return
end
local shot = Instance.new("StringValue")
shot.Name = "GateShot"
shot.Parent = ReplicatedStorage
local target = Instance.new("ObjectValue")
target.Name = "GateTarget"
target.Parent = ReplicatedStorage
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(6)
player:SetAttribute("TestGod", true)
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
local folder = Instance.new("Folder")
folder.Name = "GateProbe"
folder.Parent = workspace
local order = { "ShrineEarth", "SanctumEarth", "ShrineWater", "SanctumWater", "ShrineAir", "SanctumAir", "ShrineFire", "SanctumFire" }
local EL = { Earth = "Earth", Water = "Water", Air = "Air", Fire = "Fire" }
for i, key in ipairs(order) do
	local th = PropBuilder.RealmTheme[key]
	local el = EL[key:match("Earth") or key:match("Water") or key:match("Air") or "Fire"]
	-- ลานโล่งในแคมป์ ทีละซุ้ม (ไม่มีต้นไม้บัง)
	local pos = Vector3.new(0, 0, 50)
	local frame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
	local m, veil = PropBuilder.BuildPortal(frame, el, folder, { Name = "Probe_" .. key, Model = th.Gate, Width = th.GateW, Label = key })
	print("[AS] GATEPROBE " .. key .. " " .. tostring(m and m:GetAttribute("VeilInfo")))
	if veil then
		target.Value = veil
		player.Character:PivotTo(CFrame.new(veil.Position + Vector3.new(0, 0, -30)))
		task.wait(2)
		shot.Value = key
		task.wait(1.8)
		shot.Value = key .. "_side"
		task.wait(1.8)
	else
		print("[AS] GATEPROBE fail " .. key)
	end
	if m then
		m:Destroy()
	end
end
print("[TEST] DONE probe")
