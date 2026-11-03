--[[ ASPetProbe (client) — มุมกล้องจับกล่อง/แอร์ดรอป/ลูกสัตว์ + เดินตอนขี่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASChestProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local target
RunService.RenderStepped:Connect(function()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if ReplicatedStorage:GetAttribute("RideWalk") and hum then
		hum:Move(Vector3.new(0, 0, -1), true)
	end
	local f = ReplicatedStorage:FindFirstChild("PetFollow")
	local obj = f and f.Value
	local t = (obj and obj.Parent and obj:GetPivot().Position) or target
	if t then
		cam.CameraType = Enum.CameraType.Scriptable
		-- มองจากด้านข้าง (แกน X ของโลก) ให้เห็นขาก้าว
		cam.CFrame = CFrame.lookAt(t + Vector3.new(14, 4, 2), t + Vector3.new(0, 1.5, 0))
	end
end)
local step = ReplicatedStorage:WaitForChild("PetStep", 900)
step.Changed:Connect(function(v)
	target = ReplicatedStorage:GetAttribute("PetTarget")
	task.wait(1.0)
	print("[SHOT] " .. v)
end)
