--[[ ASSwingProbe (client) — ถ่ายท่าถือหอก/ตรีศูล + ทุกท่าในคอมโบ ค้างภาพที่จังหวะง้าง/ฟาดโดน (SwingAnim.HoldAt)
	วัดตัวเลข: ทิศหัวอาวุธเทียบหน้าตัว "[AS] SWING <id> <ท่า> fwd=.. up=.." (fwd > 0.5 = ชี้ไปข้างหน้า) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASSwingProbe") then
	return
end
local SwingAnim = require(script.Parent:WaitForChild("Client"):WaitForChild("SwingAnim"))
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local flat = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToOrientation()), 0)
		cam.CFrame = CFrame.lookAt((flat * view).Position, root.Position + Vector3.new(0, 1.5, 0))
	end
end)
local gui = Instance.new("ScreenGui")
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(560, 50)
label.Position = UDim2.new(0.5, -280, 0, 110)
label.TextScaled = true
label.Font = Enum.Font.GothamBlack
label.TextColor3 = Color3.new(1, 1, 0)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.Parent = gui
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("SwingGo")
local char = player.Character
local hum = char:FindFirstChildOfClass("Humanoid")
hum.AutoRotate = false
local root = char:FindFirstChild("HumanoidRootPart")

-- ทิศหัวอาวุธ: แกนยาวของชิ้นใหญ่สุด หันไปทางปลายที่ห่างมือ
local function measure(tool, tag)
	local hand = char:FindFirstChild("RightHand")
	local best
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 and (not best or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	if not (hand and best) then
		return
	end
	local s = best.Size
	local axis = Vector3.yAxis
	if s.X > s.Y and s.X > s.Z then
		axis = Vector3.xAxis
	elseif s.Z > s.Y and s.Z > s.X then
		axis = Vector3.zAxis
	end
	local dir = best.CFrame:VectorToWorldSpace(axis)
	if (best.Position - hand.Position):Dot(dir) < 0 then
		dir = -dir
	end
	local fwd = root.CFrame.LookVector
	print(string.format("[AS] SWING %s %s fwd=%.2f up=%.2f", tool:GetAttribute("ItemId"), tag, dir:Dot(fwd), dir.Y))
end

local function hideUI()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui then
			g.Enabled = false
		end
	end
end
local SIDE, FRONT = CFrame.new(9, 2, -1), CFrame.new(3, 2, -9)
local function shot(name, v, text)
	view = v
	label.Text = text
	task.wait(0.8)
	print("[SHOT] swing_" .. name)
	task.wait(2.4)
end

local COMBOS = { Spear = { { "A", 0.3, 0.5 }, { "B", 0.25, 0.55 } }, TidalTrident = { { "A", 0.3, 0.5 }, { "B", 0.25, 0.55 }, { "C", 0.3, 0.5 } } }
for _, id in ipairs({ "Spear", "TidalTrident" }) do
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
			tool = t
		end
	end
	if tool then
		hum:EquipTool(tool)
		task.wait(1.5)
		hideUI()
		measure(tool, "idle")
		shot(id .. "_idle_side", SIDE, id .. " · hold")
		shot(id .. "_idle_front", FRONT, id .. " · hold (front)")
		for i, c in ipairs(COMBOS[id]) do
			for _, ph in ipairs({ { "wind", c[2] }, { "hit", c[3] } }) do
				SwingAnim.ForceCombo, SwingAnim.HoldAt = i, ph[2]
				SwingAnim.Play(player, id)
				task.wait(0.1)
				measure(tool, c[1] .. "_" .. ph[1])
				shot(id .. "_" .. c[1] .. "_" .. ph[1], SIDE, id .. " · " .. c[1] .. " " .. ph[1])
			end
		end
		SwingAnim.ForceCombo, SwingAnim.HoldAt = nil, nil
		task.wait(1.2)
		hum:UnequipTools()
		task.wait(0.6)
	else
		print("[AS] SWINGPROBE no tool " .. id)
	end
end
print("[TEST] DONE swingprobe")
