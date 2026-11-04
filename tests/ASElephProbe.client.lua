--[[ ASElephProbe (client) — กล้องมุมข้างเฉียงหน้า ตามตัวช้าง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASElephProbe") then
	return
end
local cam = workspace.CurrentCamera
RunService.RenderStepped:Connect(function()
	local m = ReplicatedStorage:GetAttribute("ElephFocus") and nil
	m = workspace:FindFirstChild("Animals") and workspace.Animals:FindFirstChild("InkOctopus")
	if not (m and m.PrimaryPart) then
		return
	end
	local p = m.PrimaryPart.Position
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(p + Vector3.new(4, 6, -20), p + Vector3.new(0, 1.5, 0))
end)
