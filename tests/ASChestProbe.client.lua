--[[ ASChestProbe (client) — ถืออาวุธใหม่ทีละชิ้น ถ่ายภาพมุมข้าง แล้วตี 1 ครั้ง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASChestProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt((root.CFrame * view).Position, root.Position + Vector3.new(0, 0.5, 0))
	end
end)
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("ChestStep") == "weapons"
local hum = player.Character:FindFirstChildOfClass("Humanoid")
view = CFrame.new(7, 1.5, -3) -- ฝั่งขวา (มือที่ถือของ)
for _, id in ipairs({ "Dagger", "SpikedClub", "IronSword", "Mace", "BattleAxe", "Crossbow", "Katana", "WarHammer", "Scythe" }) do
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
			tool = t
		end
	end
	if tool then
		hum:EquipTool(tool)
		task.wait(0.8)
		print("[SHOT] wpn_" .. id)
		task.wait(2.5) -- ตัวถ่ายภาพอ่าน log ช้า: ถือค้างไว้ก่อนตี/เก็บ
		local ok, err = pcall(function()
			tool:Activate()
		end)
		task.wait(0.9)
		print("[AS] CHESTPROBE swing " .. id .. " ok=" .. tostring(ok) .. " " .. tostring(err or ""))
		hum:UnequipTools()
		task.wait(0.3)
	else
		print("[AS] CHESTPROBE missing tool " .. id)
	end
end
ReplicatedStorage:SetAttribute("ChestStep", "done")
view = nil -- ปล่อยกล้องให้เทสลูกสัตว์ (ASPetProbe) คุมต่อ
cam.CameraType = Enum.CameraType.Custom
