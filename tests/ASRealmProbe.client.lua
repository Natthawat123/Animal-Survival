--[[ ASRealmProbe (client) — กล้องตาม attribute ProbeCam: behind = หลังผู้เล่นมองไป ProbeTarget · side = มุมข้างผู้เล่น+บอส · "" = ปกติ
	ซ่อน UI ระหว่างถ่าย (เห็นฉากชัด) ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASRealmProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local function boss()
	local f = workspace:FindFirstChild("Animals")
	for _, m in ipairs(f and f:GetChildren() or {}) do
		if m:GetAttribute("IsBoss") then
			return m
		end
	end
end
RunService:BindToRenderStep("ASRealmCam", Enum.RenderPriority.Last.Value + 10, function()
	local mode = player:GetAttribute("ProbeCam") or ""
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	if mode == "" or not r then
		cam.CameraType = Enum.CameraType.Custom
		return
	end
	local L = game:GetService("Lighting")
	L.ClockTime = 13
	L.FogEnd, L.FogStart = 100000, 100000
	L.Brightness = 2.5
	L.Ambient = Color3.fromRGB(150, 150, 150)
	L.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
	for _, e in ipairs(L:GetChildren()) do
		if e:IsA("Atmosphere") then
			e.Density, e.Haze = 0.2, 0
		elseif e:IsA("ColorCorrectionEffect") or e:IsA("BlurEffect") then
			e.Enabled = false
		end
	end
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name ~= "Chat" then
			g.Enabled = false
		end
	end
	cam.CameraType = Enum.CameraType.Scriptable
	if mode == "behind" then
		local t = player:GetAttribute("ProbeTarget")
		if typeof(t) ~= "Vector3" then
			return
		end
		local d = (t - r.Position) * Vector3.new(1, 0, 1)
		d = d.Magnitude > 0.1 and d.Unit or Vector3.zAxis
		cam.CFrame = CFrame.lookAt(r.Position - d * 45 + Vector3.new(0, 55, 0), t)
	elseif mode == "wide" then
		local t = player:GetAttribute("ProbeTarget")
		if typeof(t) ~= "Vector3" then
			return
		end
		local d = (t - r.Position) * Vector3.new(1, 0, 1)
		d = d.Magnitude > 0.1 and d.Unit or Vector3.zAxis
		cam.CFrame = CFrame.lookAt(r.Position - d * 30 + Vector3.new(0, 70, 0), t + d * 40)
	else
		local b = boss()
		local bp = b and b:GetBoundingBox().Position or r.Position
		local mid = (bp + r.Position) / 2
		local d = (bp - r.Position) * Vector3.new(1, 0, 1)
		d = d.Magnitude > 0.1 and d.Unit or Vector3.zAxis
		local side = d:Cross(Vector3.yAxis)
		cam.CFrame = CFrame.lookAt(mid + side * 95 + Vector3.new(0, 45, 0), mid)
	end
end)
