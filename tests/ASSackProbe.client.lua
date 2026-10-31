--[[ ASSackProbe (client) — build_rbxlx.py --sackprobe · ถือกระสอบแต่ละแบบ แล้วถ่ายจากด้านหน้า/ด้านข้าง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASSackProbe") then
	return
end
local player = Players.LocalPlayer
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(10)
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local cf = root.CFrame
		cam.CFrame = CFrame.lookAt((cf * view).Position, cf.Position + Vector3.new(0, 0.5, 0))
	end
end)
local shot = ReplicatedStorage:WaitForChild("SackShot", 60)
shot.Changed:Connect(function(v)
	if v == "" then
		return
	end
	view = CFrame.new(-1.5, 1.5, -8)
	task.wait(0.8)
	print("[SHOT] sack_" .. v .. "_front")
	task.wait(1.2)
	view = CFrame.new(-8, 1, -1)
	task.wait(0.8)
	print("[SHOT] sack_" .. v .. "_side")
end)
