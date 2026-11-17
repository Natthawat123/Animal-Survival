--[[ ASTotemProbe (client) — ภาพเสาระดับพื้น (ฐานกับดิน) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASTotemProbe") then
	return
end
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local look
RunService:BindToRenderStep("TotemCam", Enum.RenderPriority.Last.Value, function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
local c = ReplicatedStorage:WaitForChild("TotemCenter", 900)
c:GetAttributeChangedSignal("Shot"):Connect(function()
	local n = c:GetAttribute("Shot")
	local p = c.Value
	if n == 1 then
		look = CFrame.lookAt(p + Vector3.new(0, 4, 22), p + Vector3.new(0, 3, 0))
	elseif n == 2 then
		-- ต่ำติดพื้นข้างฐานเสาต้นแรก
		local t = p + Vector3.new(-13.5, 0, 0)
		look = CFrame.lookAt(t + Vector3.new(5, 0.8, 5), t + Vector3.new(0, 0.6, 0))
	else
		local s = ReplicatedStorage:FindFirstChild("TotemSlope")
		if s then
			look = CFrame.lookAt(s.Value + Vector3.new(6, 1.2, 6), s.Value + Vector3.new(0, 1, 0))
		end
	end
	task.wait(1.5)
	print("[SHOT] totem_" .. n)
end)
