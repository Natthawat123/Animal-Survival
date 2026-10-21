--[[
	ASLobbyProbe — ใช้เฉพาะ build_rbxlx.py --lobbyprobe
	ตรวจอาวุธจาก Creator Store: ให้ตัวละครถือทีละชิ้น ถ่ายจากด้านข้าง (เห็นหัวอาวุธ + ทิศคม)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLobbyProbe") then
	return
end
local player = Players.LocalPlayer
Workspace:WaitForChild("Lobby", 60)
task.wait(6)
for _, g in ipairs(player.PlayerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local g = Workspace:WaitForChild("ProbeGallery", 60)
task.wait(4)
local base = g:GetAttribute("Base")
repeat
	task.wait(0.5)
until g:GetAttribute("MapsReady")
task.wait(2)
local M = base + Vector3.new(0, 0, 60)
repeat
	task.wait(0.5)
until g:GetAttribute("PupsReady")
task.wait(1)
local P0 = base + Vector3.new(-140, 0, 0)
local shots = {
	{ "pups_front", P0 + Vector3.new(0, 5, -16), P0 + Vector3.new(0, 2.5, 0) },
}
local _old2 = {
	{ "map_props_a", M + Vector3.new(-40, 8, -22), M + Vector3.new(-40, 3, 0) },
	{ "map_props_b", M + Vector3.new(0, 10, -24), M + Vector3.new(0, 3, 0) },
	{ "map_things", M + Vector3.new(-25, 14, -2), M + Vector3.new(-20, 3, 28) },
	{ "map_palace", M + Vector3.new(0, 70, 20), M + Vector3.new(0, 30, 160) },
}
local _old = {
	{ "items_drops", base + Vector3.new(-84.7, 6, -13), base + Vector3.new(-84.7, 0.5, 2.5) },
	{ "items_drops_b", base + Vector3.new(-90, 4, -7), base + Vector3.new(-90, 0.5, 4.5) },
	{ "items_structs_a", base + Vector3.new(84, 14, -22), base + Vector3.new(84, 3, 0) },
	{ "items_structs_b", base + Vector3.new(90, 22, -4), base + Vector3.new(90, 4, 30) },
	{ "items_structs_c", base + Vector3.new(90, 30, -10), base + Vector3.new(80, 14, 40) },
}
for _, s in ipairs(shots) do
	cam.CFrame = CFrame.lookAt(s[2], s[3])
	task.wait(1.5)
	print("[SHOT] " .. s[1])
	task.wait(2)
end
print("[TEST] DONE probe")
