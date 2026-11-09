--[[ ASGeyserProbe (client) — build_rbxlx.py --geyserprobe
	เล่นเอฟเฟกต์พวยน้ำของบอสน้ำ (BossImpact Style=Geyser) ตรงหน้าผู้เล่น แล้วถ่ายภาพมุมใกล้/มุมไกล
	เช็กว่าน้ำวน (WaterTornado) ไม่ขยายใหญ่จนบังทั้งแมพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASGeyserProbe") then
	return
end
local player = Players.LocalPlayer
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(6)
local BossFX = require(script.Parent:WaitForChild("Client"):WaitForChild("BossFX"))
for _, g in ipairs(player.PlayerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
local cam = workspace.CurrentCamera
local root = player.Character.HumanoidRootPart
local center = root.Position + root.CFrame.LookVector * 40
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local hit = workspace:Raycast(center + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), rp)
center = hit and hit.Position or center
cam.CameraType = Enum.CameraType.Scriptable
local function view(dist, up)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist, up, dist * 0.6), center + Vector3.new(0, 12, 0))
end
for round = 1, 2 do
	local far = round == 2
	view(far and 160 or 55, far and 90 or 22)
	task.wait(1.5)
	print(string.format("[SHOT] geyser_%s_0", far and "far" or "near")) -- ภาพเทียบ: ก่อนปล่อยพวยน้ำ
	task.wait(1.2)
	BossFX.Handlers.BossImpact({ Pos = center, Radius = 10, Element = "Water", Style = "Geyser" })
	for i, t in ipairs({ 0.35, 0.6, 0.8 }) do
		task.wait(t)
		local n = 0
		local f = workspace:FindFirstChild("BossFX")
		for _, d in ipairs(f and f:GetDescendants() or {}) do
			if d:IsA("SpecialMesh") then
				n = math.max(n, d.Scale.X, d.Scale.Z)
			end
		end
		print(string.format("[AS] GEYSER round=%d shot=%d maxMeshScale=%.0f", round, i, n))
		print(string.format("[SHOT] geyser_%s_%d", far and "far" or "near", i))
		task.wait(0.4)
	end
	task.wait(2.5)
end
print("[TEST] DONE geyserprobe")
