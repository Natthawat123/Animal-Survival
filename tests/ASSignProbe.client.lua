--[[ ASSignProbe (client) — ถ่ายภาพป้ายหน้าประตู + ฉากได้บัพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASSignProbe") then
	return
end
local cam = workspace.CurrentCamera
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("SignShot"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("SignShot")
	if s == "buff" then
		look = nil
		cam.CameraType = Enum.CameraType.Custom
		task.wait(0.9)
		print("[SHOT] sign_teambuff")
		return
	elseif s == "done" then
		look = nil
		cam.CameraType = Enum.CameraType.Custom
		return
	end
	local cf = ReplicatedStorage:GetAttribute("SignCF")
	if typeof(cf) ~= "CFrame" then
		return
	end
	task.wait(0.5)
	-- มองป้ายตรงๆ จากด้านหน้า (-Z ของป้าย) ห่าง 15 stud
	look = CFrame.lookAt((cf * CFrame.new(3, 1, -15)).Position, cf.Position)
	task.wait(1.5)
	print("[SHOT] sign_" .. s)
	task.wait(1.5)
	-- มุมกว้าง: เห็นป้ายกับประตู
	look = CFrame.lookAt((cf * CFrame.new(18, 8, -38)).Position, (cf * CFrame.new(20, 4, 0)).Position)
	task.wait(1)
	print("[SHOT] sign_" .. s .. "_wide")
end)
