--[[ ASLidProbe (client) — กล้องจ้องหีบ 3 ใบ (มุมหน้าเฉียงบน / มุมข้าง) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASLidProbe") then
	return
end
local cam = workspace.CurrentCamera
RunService.RenderStepped:Connect(function()
	local focus = ReplicatedStorage:GetAttribute("LidFocus")
	if typeof(focus) ~= "Vector3" then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local eye = ReplicatedStorage:GetAttribute("LidSide") and Vector3.new(30, 12, 6) or Vector3.new(4, 13, -27)
	cam.CFrame = CFrame.lookAt(focus + eye, focus + Vector3.new(0, 2.5, 0))
end)
