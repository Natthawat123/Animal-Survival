--[[
	ASSiteProbe (client) — ใช้เฉพาะ build_rbxlx.py --siteprobe · ถ่ายภาพตามจุดที่ server ส่งมา
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASSiteProbe") then
	return
end
local player = game:GetService("Players").LocalPlayer
local shot = ReplicatedStorage:WaitForChild("ProbeShot", 120)
task.wait(8)
for _, g in ipairs(player.PlayerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
-- ปิดหมอก/บรรยากาศไบโอมตอนถ่าย (ให้เห็นตัวอาคารชัด)
game:GetService("RunService"):BindToRenderStep("ProbeClearFog", Enum.RenderPriority.Last.Value + 50, function()
	local L = game:GetService("Lighting")
	L.FogEnd = 100000
	L.ClockTime = 13
	for _, a in ipairs(L:GetChildren()) do
		if a:IsA("Atmosphere") then
			a.Density = 0.02
			a.Haze = 0
		end
	end
end)
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local function vec(s)
	local x, y, z = s:match("([^,]+),([^,]+),([^,]+)")
	return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end
while true do
	local v = shot.Value
	if v == "DONE" then
		break
	end
	local name, a, b = v:match("([^|]+)|([^|]+)|([^|]+)")
	if name then
		cam.CFrame = CFrame.lookAt(vec(a), vec(b))
		task.wait(2.5)
		print("[SHOT] " .. name)
		task.wait(1)
	end
	shot.Changed:Wait()
end
print("[TEST] DONE probe")
