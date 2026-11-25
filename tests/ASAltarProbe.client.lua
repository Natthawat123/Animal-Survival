--[[ ASAltarProbe (client) — ถ่ายภาพแท่นหินกะโหลก ก่อน/หลังเก็บ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASAltarProbe") then
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
ReplicatedStorage:GetAttributeChangedSignal("AltarShot"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("AltarShot")
	local cf = ReplicatedStorage:GetAttribute("AltarCam")
	look = typeof(cf) == "CFrame" and cf or nil
	task.wait(1.6)
	print("[SHOT] " .. s)
end)
