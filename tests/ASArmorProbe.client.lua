--[[ ASArmorProbe (client) — ถ่ายเกราะบนตัว (หน้า/ข้าง/หลัง) + หน้าคราฟต์หมวดเกราะ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASArmorProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local cf = root.CFrame
		cam.CFrame = CFrame.lookAt((cf * view).Position, cf.Position + Vector3.new(0, 0.6, 0))
	elseif not view then
		cam.CameraType = Enum.CameraType.Custom
	end
end)
local shot = ReplicatedStorage:WaitForChild("ArmorShot", 600)
shot.Changed:Connect(function(v)
	if v == "menu" then
		view = nil
		local Menus = require(script.Parent:WaitForChild("Client"):WaitForChild("Menus"))
		Menus.OpenCraft()
		task.wait(0.5)
		local win = player.PlayerGui:FindFirstChild("CraftWindow", true)
		local box = win and win:FindFirstChild("Search", true)
		if box then
			box.Text = "เกราะ"
		end
		task.wait(1)
		print("[SHOT] armor_menu")
		return
	end
	view = CFrame.new(0, 1.2, -6.5)
	task.wait(1.5)
	print("[SHOT] armor_" .. v .. "_front")
	task.wait(2)
	view = CFrame.new(-6, 1, -2)
	task.wait(1.5)
	print("[SHOT] armor_" .. v .. "_side")
	task.wait(2)
	view = CFrame.new(1.5, 1.4, 6)
	task.wait(1.5)
	print("[SHOT] armor_" .. v .. "_back")
end)
