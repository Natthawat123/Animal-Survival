--[[ ASHitFxProbe (client) — กล้องข้างตัวผู้เล่น ถ่ายตอนตีรัว ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASHitFxProbe") then
	return
end
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local v = ReplicatedStorage:WaitForChild("HitFxCam", 900)
RunService:BindToRenderStep("HitFxCam", Enum.RenderPriority.Last.Value, function()
	if v.Value ~= CFrame.new() then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = v.Value
	end
end)
v:GetAttributeChangedSignal("Shot"):Connect(function()
	for k = 1, 4 do
		print("[SHOT] hitfx_" .. tostring(v:GetAttribute("Shot")) .. "_" .. k)
		task.wait(0.45)
	end
end)
