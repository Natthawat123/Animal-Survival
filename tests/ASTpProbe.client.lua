--[[ ASTpProbe (client) — ถ่ายภาพหินวาร์ป / หน้าต่างเลือกปลายทาง / หลังวาร์ป / แผนที่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASTpProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local MapUI = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("MapUI"))
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("TpShot"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("TpShot")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if s == "model" and root then
		-- หาหินวาร์ปที่ใกล้ตัวสุด
		local best, bd
		for _, m in ipairs(workspace:FindFirstChild("Structures") and workspace.Structures:GetChildren() or {}) do
			if m:GetAttribute("Kind") == "Teleporter" then
				local d = (m:GetPivot().Position - root.Position).Magnitude
				if not bd or d < bd then
					best, bd = m, d
				end
			end
		end
		if best then
			local p = best:GetPivot().Position
			look = CFrame.lookAt(p + Vector3.new(9, 7, 11), p + Vector3.new(0, 1.5, 0))
			task.wait(1.2)
			print("[SHOT] tp_model")
			task.wait(2)
			look = nil
			cam.CameraType = Enum.CameraType.Custom
		end
	elseif s == "menu" then
		print("[SHOT] tp_menu")
	elseif s == "arrived" then
		local g = player.PlayerGui:FindFirstChild("TeleportUI")
		for _, f in ipairs(g and g:GetChildren() or {}) do
			if f:IsA("GuiObject") then
				f.Visible = false -- ปิดหน้าต่างเลือก (server สั่งวาร์ปตรงๆ ไม่ผ่านปุ่ม)
			end
		end
		task.wait(0.5)
		print("[SHOT] tp_arrived")
	elseif s == "slope" then
		local c = ReplicatedStorage:GetAttribute("TpSlope")
		if c then
			look = CFrame.lookAt(c + Vector3.new(13, 1.5, 4), c + Vector3.new(0, 0.5, 0))
			task.wait(1.2)
			print("[SHOT] tp_slope_side")
			look = CFrame.lookAt(c + Vector3.new(-4, 1.5, -13), c + Vector3.new(0, 0.5, 0))
			task.wait(1.2)
			print("[SHOT] tp_slope_side2")
			task.wait(0.5)
			look = nil
			cam.CameraType = Enum.CameraType.Custom
		end
	elseif s == "feet" then
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r then
			look = CFrame.lookAt(r.Position + Vector3.new(7, -1.2, 2), r.Position + Vector3.new(0, -2.2, 0))
			task.wait(1)
			print("[SHOT] tp_feet")
			task.wait(0.5)
			look = nil
			cam.CameraType = Enum.CameraType.Custom
		end
	elseif s == "ride_arrived" then
		print("[SHOT] tp_ride_arrived")
	elseif s == "map" then
		MapUI.Toggle()
		task.wait(1.2)
		print("[SHOT] tp_map")
		task.wait(2.5)
		MapUI.Close()
	end
end)
