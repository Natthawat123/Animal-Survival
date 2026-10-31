--[[ ASLootProbe (client) — เข้ารอบ แล้วสั่งเทสกติกาดรอปใหม่ทีละข้อ + ถ่ายภาพหัวใจ 4 ธาตุ / ออร่า ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLootProbe") then
	return
end
local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
local lobby = Workspace:WaitForChild("Lobby", 30)
local zone = lobby and lobby:FindFirstChild("MatchBox1", true)
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 60 do
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if zone and r then
		r.CFrame = zone.CFrame
		if player:GetAttribute("Pad") then
			pcall(function()
				require(ReplicatedStorage.Shared.Remotes).Get("PadSize"):FireServer(zone:GetAttribute("PadIndex") or 1, 1)
			end)
		end
	end
	task.wait(0.5)
end
print("[AS] LOOT inRun", player:GetAttribute("InRun"))
task.wait(8)
local rf = ReplicatedStorage:WaitForChild("LootProbe")
local cam = Workspace.CurrentCamera

local RunService = game:GetService("RunService")
-- บังคับกล้องทุกเฟรมระหว่างถ่าย (สคริปต์กล้องของเกมดึงกลับ)
local function shot(name, cf, hold)
	RunService:BindToRenderStep("ProbeCam", Enum.RenderPriority.Last.Value + 10, function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf()
	end)
	task.wait(hold or 1.5)
	print("[SHOT] " .. name)
	task.wait(1.2)
	RunService:UnbindFromRenderStep("ProbeCam")
	cam.CameraType = Enum.CameraType.Custom
end

local function step(name)
	local ok, res, pos = pcall(rf.InvokeServer, rf, name)
	print(string.format("[AS] LOOT %s ok=%s %s", name, tostring(ok), tostring(res)))
	return pos
end

-- หีบร่อนจากฟ้า / อุกกาบาต: กดค้าง prompt จริงแบบผู้เล่น
for _, ev in ipairs({ "meteor", "supply" }) do
	local pos = step(ev)
	if pos then
		task.wait(1.5)
		local pname = ev == "supply" and "OpenSupply" or "Claim"
		local prompt
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Name == pname and d.Enabled then
				prompt = d
			end
		end
		if prompt then
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.4)
			prompt:InputHoldEnd()
		else
			print("[AS] LOOT no client prompt", pname)
		end
		step("result")
		shot(ev .. "_loot", function()
			return CFrame.lookAt(pos + Vector3.new(10, 8, 10), pos)
		end)
	end
end
step("inv")
step("scout")
local hp = step("hearts")
if hp then
	task.wait(1.5)
	shot("hearts", function()
		return CFrame.lookAt(hp + Vector3.new(0, 7, 16), hp)
	end)
end
local bp = step("boss")
if bp then
	shot("boss_drops", function()
		return CFrame.lookAt(bp + Vector3.new(14, 10, 14), bp)
	end)
end
step("sanctum")
task.wait(1)
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if root then
	shot("aura", function()
		return CFrame.lookAt(root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 1.5, 0), root.Position)
	end, 2)
end
step("seal")
step("resume")
step("auras")

print("[AS] LOOT ALLDONE")
