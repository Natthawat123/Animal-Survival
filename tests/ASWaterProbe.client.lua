--[[ ASWaterProbe (client) — ภาพวาฬในน้ำ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASWaterProbe") then
	return
end
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local v = ReplicatedStorage:WaitForChild("WaterOrca", 900)
local on = false
RunService:BindToRenderStep("WaterCam", Enum.RenderPriority.Last.Value, function()
	local m = on and v.Value
	if m and m.Parent then
		local p = m:GetPivot().Position
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(p + Vector3.new(26, 12, 26), p)
	end
end)
v:GetAttributeChangedSignal("Shot"):Connect(function()
	on = true
	task.wait(1.5)
	print("[SHOT] water_orca")
end)
