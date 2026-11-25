--[[ ASTribeProbe (client) — ภาพตอนปีนถึงยอดหอ/เสาประตูป้อม ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASTribeProbe") then
	return
end
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local look
RunService:BindToRenderStep("TribeCam", Enum.RenderPriority.Last.Value, function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage.ChildAdded:Connect(function(c)
	if c.Name ~= "TribeShot" then
		return
	end
	local p = c.Value
	local lad = c:GetAttribute("Look")
	local away = (Vector3.new(lad.X, 0, lad.Z) - Vector3.new(p.X, 0, p.Z))
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
	look = CFrame.lookAt(p + away * 22 + Vector3.new(0, 8, 0), Vector3.new(lad.X, p.Y - 10, lad.Z))
	task.wait(1)
	print("[SHOT] tribe_climb_" .. tostring(c:GetAttribute("N")))
end)
