--[[ ASArenaProbe (client) — กล้องมุมสูงมองลงกลางรังบอส (attribute ArenaCenter/ArenaH) + ถ่ายภาพตาม ArenaShot ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASArenaProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")
RunService.RenderStepped:Connect(function()
	local c = player:GetAttribute("ArenaCenter")
	if typeof(c) == "Vector3" then
		-- เทสต์เท่านั้น: ปิดหมอกไกล (กล้องอยู่สูง ภาพเคยขาวโพลน)
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			atm.Density = 0
			atm.Haze = 0
		end
		Lighting.FogEnd = 1e5
		local h = player:GetAttribute("ArenaH") or 120
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(c + Vector3.new(h * 0.15, h, h * 0.75), c)
	end
end)
player:GetAttributeChangedSignal("ArenaShot"):Connect(function()
	local n = player:GetAttribute("ArenaShot")
	if n then
		task.wait(0.1)
		print("[SHOT] " .. n)
	end
end)
