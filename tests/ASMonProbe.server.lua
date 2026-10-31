--[[ ASMonProbe (server) — build_rbxlx.py --monprobe · เรียกสัตว์ไบโอมน้ำทีละตัว: ยืน / เดิน / โจมตี / ตาย ให้ client ถ่ายภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMonProbe") then
	return
end
local shot = Instance.new("StringValue")
shot.Name = "MonShot"
shot.Parent = ReplicatedStorage
local target = Instance.new("ObjectValue")
target.Name = "MonTarget"
target.Parent = ReplicatedStorage
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(8)
player:SetAttribute("TestGod", true)
local AnimalService = require(game:GetService("ServerScriptService").Server.AnimalService)
local layout
for _ = 1, 30 do
	local ok, l = pcall(function()
		return AnimalService.ctx.Layout
	end)
	if ok and l then
		layout = l
		break
	end
	task.wait(1)
end
local cp = Vector3.new(0, layout:HeightAt(0, 0), 0)
-- หาจุดน้ำลึกใกล้แคมป์ (ให้วาฬ)
local waterAt
for r = 60, 900, 20 do
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local x, z = math.cos(a) * r, math.sin(a) * r
		if layout:HeightAt(x, z) < layout.WaterLevel - 6 then
			waterAt = Vector3.new(x, layout.WaterLevel + 1, z)
			break
		end
	end
	if waterAt then
		break
	end
end
print("[AS] MONPROBE water", waterAt)
local function step(name, wait)
	shot.Value = name
	task.wait(wait or 1.6)
end
local ids = { "ReefCrab", "InkOctopus", "TideOrca" }
local custom = ReplicatedStorage:FindFirstChild("ASMonIds")
if custom and custom.Value ~= "" then
	ids = string.split(custom.Value, ",")
end
for _, id in ipairs(ids) do
	local at = Vector3.new(cp.X + 40, 0, cp.Z + 30)
	if id == "TideOrca" and waterAt then
		at = waterAt
	end
	local h = id == "TideOrca" and waterAt and waterAt.Y or (layout:HeightAt(at.X, at.Z) + 1)
	local a = AnimalService:Spawn(id, Vector3.new(at.X, h, at.Z), { Kind = "Wild", Yaw = 0 })
	if not a then
		print("[AS] MONPROBE missing " .. id)
		continue
	end
	a.IntroUntil = os.clock() + 1000 -- ไม่ให้ AI คุม (สคริปต์นี้สั่งเอง)
	target.Value = a.Model
	player.Character:PivotTo(CFrame.new(a.Root.Position + Vector3.new(0, 4, 40)))
	task.wait(2.5)
	local fl = a.Root:FindFirstChild("Float")
	print(string.format("[AS] MONPROBE %s rootY=%.1f WL=%.1f float=%s state=%s floor=%.1f", id, a.Root.Position.Y, layout.WaterLevel, tostring(fl and fl.Enabled),
		tostring(a.Hum:GetState()), layout:HeightAt(a.Root.Position.X, a.Root.Position.Z)))
	step(id .. "_idle", 1.8)
	AnimalService:MoveTo(a, a.Root.Position + Vector3.new(0, 0, -60), 0.6)
	task.wait(1.2)
	do
		local v = a.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local lk = a.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
		print(string.format("[AS] MONPROBE %s walk speed=%.1f facing-vs-move=%.0f deg", id, v.Magnitude, v.Magnitude > 0.5 and math.deg(math.acos(math.clamp(v.Unit:Dot(lk.Unit), -1, 1))) or -1))
	end
	step(id .. "_walk", 1.5)
	if custom and custom.Value ~= "" then
		-- โหมดเช็กทิศหน้า: ถ่ายข้างขวา (หัวต้องอยู่ขวาจอ) + หน้าตรง (ต้องเห็นหน้า) ระหว่างเดิน
		AnimalService:MoveTo(a, a.Root.Position + Vector3.new(0, 0, -120), 0.35)
		task.wait(0.8)
		step(id .. "_side1", 1.3)
		step(id .. "_side2", 1.1)
		step(id .. "_side3", 1.3)
		step(id .. "_front", 1.5)
		AnimalService:Stop(a)
		task.wait(1)
		step(id .. "_rest", 1.5)
		AnimalService:Remove(a)
		target.Value = nil
		continue
	end
	AnimalService:Stop(a)
	task.wait(1)
	for n = 1, 2 do
		AnimalService:MarkAttack(a, "Bite")
		task.wait(0.12)
		step(id .. "_atk" .. n .. "a", 0.3)
		step(id .. "_atk" .. n .. "b", 1.6)
	end
	AnimalService:Kill(a, nil)
	task.wait(0.4)
	step(id .. "_dead", 2)
	task.wait(1.5)
	target.Value = nil
end
if custom and custom.Value ~= "" then
	print("[AS] MONPROBE FINISHED") -- ไม่ใช้ [TEST] DONE: ตัวรันของเซสชันอื่นอ่าน log รวมกัน จะพาลจบเทสต์เขา
else
	print("[TEST] DONE probe")
end
