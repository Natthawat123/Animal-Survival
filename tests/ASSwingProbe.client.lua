--[[ ASSwingProbe (client) — ถ่ายทุกท่าตีของทุกอาวุธ ทุกคีย์เฟรม ค้างภาพไว้ที่แต่ละคีย์ (SwingAnim.HoldAt)
	ชื่อภาพ: sw_<ท่า>_<อาวุธ>_<คีย์> -> tools/swing_sheet.py รวมเป็นชีท ]]
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
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("SwingGo")
local char = player.Character
local hum = char:FindFirstChildOfClass("Humanoid")
hum.AutoRotate = false

local function hideUI()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
end
local VIEW = CFrame.new(6, 2.5, -8) -- เฉียงหน้าขวา เห็นทั้งตัว + อาวุธ
local function shot(name)
	view = VIEW
	task.wait(0.45)
	print("[SHOT] " .. name)
	task.wait(1.7)
end

-- อาวุธตัวแทนของแต่ละชุดท่า (ท่าที่ซ้ำกับอาวุธก่อนหน้า = ข้าม)
local ORDER = { "OldAxe", "BattleAxe", "FourfoldBlade", "Pickaxe", "BuildHammer", "SpikedClub", "Mace", "WarHammer", "IronSword", "Katana", "Dagger",
	"Scythe", "Spear", "TidalTrident", "Torch", "EmberStaff", "ArcaneStaff", "VerdantStaff", "Bow", "Crossbow" }
-- SwingOnly (attribute บน ReplicatedStorage, คั่นด้วย ,) = ถ่ายเฉพาะท่าเหล่านี้
local only = ReplicatedStorage:GetAttribute("SwingOnly")
local done = {}
if only then
	local want = {}
	for name in string.gmatch(only, "[^,]+") do
		want[name] = true
	end
	for name in pairs(SwingAnim.Styles) do
		done[name] = not want[name]
	end
end
for _, id in ipairs(ORDER) do
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
			tool = t
		end
	end
	if tool then
		hum:EquipTool(tool)
		task.wait(1.2)
		hideUI()
		SwingAnim.Play(player, id) -- อุ่นเครื่อง: ให้โมเดล/ข้อต่อพร้อมก่อนภาพแรก
		task.wait(1.5)
		for i, name in ipairs(SwingAnim.Sets[id]) do
			if not done[name] then
				done[name] = true
				for k, key in ipairs(SwingAnim.Styles[name].Keys) do
					SwingAnim.ForceCombo, SwingAnim.HoldAt = i, key[1]
					SwingAnim.Play(player, id)
					task.wait(0.1)
					shot(string.format("sw_%s_%s_%d", name, id, k))
				end
			end
		end
		SwingAnim.ForceCombo, SwingAnim.HoldAt = nil, nil
		task.wait(1.1)
		hum:UnequipTools()
		task.wait(0.4)
	else
		print("[AS] SWINGPROBE no tool " .. id)
	end
end
print("[TEST] DONE swingprobe")
