--[[ ASGripProbe (client) — ลองท่าจับหลายแบบของหน้าไม้/เคียว · ชื่อแบบแสดงบนจอ (ภาพกับชื่อไม่เหลื่อมกัน) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASGripProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt((root.CFrame * view).Position, root.Position + Vector3.new(0, 2.5, -1.5))
	end
end)
local gui = Instance.new("ScreenGui")
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(500, 70)
label.Position = UDim2.new(0.5, -250, 0, 120)
label.TextScaled = true
label.Font = Enum.Font.GothamBlack
label.TextColor3 = Color3.new(1, 1, 0)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.Parent = gui
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("GripGo")
local hum = player.Character:FindFirstChildOfClass("Humanoid")
local A, P = CFrame.Angles, math.pi
local HOLD = CFrame.new(0, -0.25, -0.5)
local SETS = {
	Crossbow = { { "XB_final" } },
	Scythe = { { "SC_final" } },
}
view = CFrame.new(9, 3, -1) -- ด้านขวา ถอยไกล เห็นทั้งด้ามเคียว
for _, id in ipairs({ "Crossbow", "Scythe" }) do
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
			tool = t
		end
	end
	if tool then
		hum:EquipTool(tool)
		task.wait(1)
		local base = tool.Grip
		for _, c in ipairs(SETS[id]) do
			tool.Grip = base * (c[2] or CFrame.identity)
			label.Text = c[1]
			-- ซ่อน UI เกมทั้งหมด (แผนที่/เมนูที่เด้งขึ้นมาบัง) เหลือแค่ป้ายชื่อแบบ
			for _, g in ipairs(player.PlayerGui:GetChildren()) do
				if g:IsA("ScreenGui") and g ~= gui then
					g.Enabled = false
				end
			end
			task.wait(0.6)
			print("[SHOT] grip_" .. c[1])
			task.wait(3.2)
		end
		hum:UnequipTools()
		task.wait(0.5)
	end
end
