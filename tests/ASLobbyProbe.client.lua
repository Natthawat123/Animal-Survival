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
local ev = ReplicatedStorage:WaitForChild("ProbeEquip", 30)
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
root.Anchored = true
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
for _, id in ipairs({ "OldAxe", "Bow", "EmberBlade", "TidalTrident" }) do
	local ok, hs, ts = ev:InvokeServer(id)
	print("[PROBE] weapon", id, ok, "handle", hs, "tool", ts)
	task.wait(1.2)
	-- มุมเฉียงหน้า-ขวาของตัวละคร (เห็นแขนขวาที่ถือ)
	local cf = root.CFrame
	cam.CFrame = CFrame.lookAt(cf.Position + cf.RightVector * 9 + Vector3.new(0, 1.5, 0), cf.Position + cf.RightVector * 1.5 + Vector3.new(0, 0.5, 0))
	task.wait(0.8)
	print("[SHOT] weapon_" .. id)
	task.wait(1.6)
end
print("[TEST] DONE probe")
