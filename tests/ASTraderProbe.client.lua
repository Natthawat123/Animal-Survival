--[[ ASTraderProbe (client) — มองจากกลางแคมป์ไปทางพ่อค้า ถ่ายภาพทุกขั้นที่ server สั่ง (TraderStep) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASTraderProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
RunService.RenderStepped:Connect(function()
	local tr = workspace:FindFirstChild("Trader")
	if tr and ReplicatedStorage:GetAttribute("TraderStep") then
		local p = tr:GetPivot().Position
		cam.CameraType = Enum.CameraType.Scriptable
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local from = root and root.Position or p + Vector3.new(20, 10, 0)
		local dir = Vector3.new(p.X - from.X, 0, p.Z - from.Z)
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
		cam.CFrame = CFrame.lookAt(p - dir * 26 + Vector3.new(0, 12, 0) + dir:Cross(Vector3.yAxis) * 10, p + Vector3.new(0, 3, 0))
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("TraderStep"):Connect(function()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
	task.wait(0.6)
	print("[SHOT] trader_" .. ReplicatedStorage:GetAttribute("TraderStep"))
end)
