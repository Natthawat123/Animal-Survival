--[[ ASDropProbe (client) — เข้าแมพ -> ขอเสกของตก -> log ว่าเครื่องผู้เล่นได้ชิ้นส่วนครบไหม/อยู่ตรงไหน + กรอบขาว + ถ่ายภาพ ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASDropProbe") then
	return
end
local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
local lobby = Workspace:WaitForChild("Lobby", 30)
local zone = lobby and lobby:FindFirstChild("MatchBox1", true)
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 60 do
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if zone and r then
		r.CFrame = zone.CFrame
	end
	task.wait(0.5)
end
print("[AS] DROP inRun", player:GetAttribute("InRun"))
task.wait(8)
local char = player.Character
local root = char:WaitForChild("HumanoidRootPart")
local ev = ReplicatedStorage:WaitForChild("DropProbe")
ev:FireServer("spawn")

local function report(tag)
	local hl = Workspace.Drops:FindFirstChild("PickupHighlight", true)
	print("[AS] DROP " .. tag .. " highlight=" .. tostring(hl and hl.Enabled) .. " adornee=" .. tostring(hl and hl.Adornee and hl.Adornee.Name))
	for _, m in ipairs(Workspace.Drops:GetChildren()) do
		local r = m.PrimaryPart
		local n, vis, lo = 0, 0, math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				n += 1
				if p.Transparency < 1 then
					vis += 1
					lo = math.min(lo, p.Position.Y)
				end
			end
		end
		local gy = "?"
		if r then
			local hit = Workspace:Raycast(r.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), (function()
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { Workspace.Drops, char }
				return rp
			end)())
			gy = hit and string.format("%.2f", hit.Position.Y) or "none"
		end
		local pr = r and r:FindFirstChild("Pickup")
		print(string.format("[AS] DROP client@%s %s parts=%d vis=%d root=%s visLowY=%.2f groundY=%s prompt=%s",
			tag, m.Name, n, vis, r and tostring(r.Position) or "nil", lo, gy, tostring(pr and pr.Enabled)))
	end
end

local cam = Workspace.CurrentCamera
for _, t in ipairs({ 0.3, 2, 6 }) do
	task.wait(t == 0.3 and 0.3 or (t == 2 and 1.7 or 4))
	report(tostring(t))
end
cam.CameraType = Enum.CameraType.Scriptable
local look = root.CFrame.LookVector
cam.CFrame = CFrame.lookAt(root.Position - look * 6 + Vector3.new(0, 7, 0), root.Position + look * 8)
task.wait(1)
pcall(function()
	require(script.Parent:WaitForChild("Client"):WaitForChild("Backpack")).ToggleInventory(true)
end)
task.wait(0.5)
print("[SHOT] drop_view")
task.wait(1.5)
-- เดินไปหาของแล้วกดเก็บผ่านปุ่ม E (ProximityPrompt)
local hum = char:FindFirstChildOfClass("Humanoid")
hum:MoveTo(root.Position + look * 6)
task.wait(1.5)
task.wait(0.5)
local hlm = Workspace.Drops:FindFirstChild("PickupHighlight", true)
local fm = hlm and hlm.Parent
local fp = fm and fm.PrimaryPart and fm.PrimaryPart.Position or root.Position + look * 4
cam.CFrame = CFrame.lookAt(fp + Vector3.new(5, 6, 5), fp)
task.wait(0.5)
report("near")
print("[SHOT] drop_near")
task.wait(1.5)
for _, m in ipairs(Workspace.Drops:GetChildren()) do
	local pr = m.PrimaryPart and m.PrimaryPart:FindFirstChild("Pickup")
	if pr and pr.Enabled then
		pr:InputHoldBegin()
		task.wait(0.05)
		pr:InputHoldEnd()
		print("[AS] DROP fired prompt on", m.Name)
	end
end
task.wait(1)
ev:FireServer("inv")
task.wait(1)
print("[AS] DROP DONE")
