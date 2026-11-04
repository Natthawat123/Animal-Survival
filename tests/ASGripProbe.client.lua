--[[ ASGripProbe (client) — ตรวจท่าถืออาวุธประจำคลาสแบบละเอียด
	วัดเป็นตัวเลข: มือขวาห่างแกนด้ามเท่าไร (ควร < 0.6) · จับตรงไหนของด้าม (0 = ปลายล่าง, 1 = หัว) · หัวชี้ขึ้นไหม (up > 0.5)
	ถ่าย 4 มุม (หน้า/ขวา/หลัง/ซ้าย) + กลางท่าฟาด · ผล "[AS] GRIP <id> <ท่า> dist=.. along=.. up=.." ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASGripProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view -- CFrame กล้องเทียบกับตัว (หน้าตัว = -Z)
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
label.Size = UDim2.fromOffset(560, 60)
label.Position = UDim2.new(0.5, -280, 0, 110)
label.TextScaled = true
label.Font = Enum.Font.GothamBlack
label.TextColor3 = Color3.new(1, 1, 0)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.Parent = gui
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("GripGo")
local char = player.Character
local hum = char:FindFirstChildOfClass("Humanoid")
hum.AutoRotate = false -- ตัวไม่หมุนตามกล้องระหว่างถ่าย

-- ชิ้นที่มองเห็นของอาวุธ (MeshPart ที่ใหญ่สุด) -> แกนยาว + ปลายสองข้าง
local function measure(tool, tag)
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local best
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 and (not best or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	if not (hand and best) then
		print("[AS] GRIP " .. tool:GetAttribute("ItemId") .. " " .. tag .. " missing parts")
		return
	end
	-- แกนยาวของชิ้น = แกนที่ Size ยาวสุด
	local s = best.Size
	local axis, half = Vector3.yAxis, s.Y / 2
	if s.X > s.Y and s.X > s.Z then
		axis, half = Vector3.xAxis, s.X / 2
	elseif s.Z > s.Y and s.Z > s.X then
		axis, half = Vector3.zAxis, s.Z / 2
	end
	local dir = best.CFrame:VectorToWorldSpace(axis)
	if dir.Y < 0 then
		dir = -dir -- ให้ชี้ด้านบนของจอ (หัวอยู่ปลายบน)
	end
	local rel = hand.Position - best.Position
	local along = rel:Dot(dir)
	local dist = (rel - dir * along).Magnitude
	local frac = (along + half) / (2 * half)
	-- หัวอาวุธอยู่ปลายไหน: ปลายที่ "หนา" กว่า = หัว (คทา/เคียว) — ดูจากภาพ
	print(string.format("[AS] GRIP %s %s dist=%.2f along=%.2f up=%.2f len=%.1f", tool:GetAttribute("ItemId"), tag, dist, frac, dir.Y, half * 2))
end

local IDS = { "ArcaneStaff", "BloodScythe", "VerdantStaff" }
local VIEWS = {
	{ "front", CFrame.new(0, 2, -9) }, { "right", CFrame.new(9, 2, 0) },
	{ "back", CFrame.new(0, 2, 9) }, { "left", CFrame.new(-9, 2, 0) },
}
local function hideUI()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui then
			g.Enabled = false
		end
	end
end
for _, id in ipairs(IDS) do
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
		for _, v in ipairs(VIEWS) do
			view = v[2]
			label.Text = id .. " · " .. v[1]
			task.wait(0.9)
			print("[SHOT] grip_" .. id .. "_" .. v[1])
			task.wait(2.6)
		end
		-- กลางท่าฟาด (มุมขวา)
		view = CFrame.new(9, 2, -2)
		label.Text = id .. " · swing"
		task.wait(0.6)
		tool:Activate()
		task.wait(0.18)
		measure(tool, "swing")
		print("[SHOT] grip_" .. id .. "_swing")
		task.wait(2.6)
		hum:UnequipTools()
		task.wait(0.6)
	else
		print("[AS] GRIPPROBE no tool " .. id)
	end
end
print("[AS] GRIPPROBE DONE")
