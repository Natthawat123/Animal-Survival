--[[ ASSizeProbe (client) — ถ่ายภาพแถวม่อน 3 ระดับต่อธาตุ เทียบกับตัวผู้เล่น ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASSizeProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("SizeShot"):Connect(function()
	local row = ReplicatedStorage:GetAttribute("SizeShot")
	local base = ReplicatedStorage:GetAttribute("SizeBase")
	if row == "done" or not base then
		look = nil
		cam.CameraType = Enum.CameraType.Custom
		return
	end
	-- ผู้เล่นยืนหน้าแถว (ไว้เทียบขนาด)
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(base + Vector3.new(-40, 4, 4)))
	end
	task.wait(1.5)
	look = CFrame.lookAt(base + Vector3.new(-6, 11, 52), base + Vector3.new(-6, 5, 0))
	task.wait(1.5)
	print("[SHOT] size_" .. row)
	task.wait(2)
end)
