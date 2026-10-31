--[[ ASGateProbe (client) — มองซุ้มตรงหน้า (ฝั่ง -Z) / เฉียงข้าง แล้วถ่ายภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASGateProbe") then
	return
end
local shot = ReplicatedStorage:WaitForChild("GateShot", 900)
local target = ReplicatedStorage:WaitForChild("GateTarget", 60)
local cam = workspace.CurrentCamera
local side = false
RunService.RenderStepped:Connect(function()
	local v = target.Value
	if v and v.Parent then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 50
		local m = v.Parent
		local _, size = m:GetBoundingBox()
		local d = math.max(size.X, size.Y) * 1.3 + 8
		local c = v.Position
		local from = side and (c + Vector3.new(d * 0.6, 2, -d * 0.75)) or (c + Vector3.new(0, 1, -d))
		cam.CFrame = CFrame.lookAt(from, c)
	end
end)
shot.Changed:Connect(function(v)
	if v ~= "" then
		side = v:match("_side$") ~= nil
		task.wait(0.5)
		print("[SHOT] gate_" .. v)
	end
end)
