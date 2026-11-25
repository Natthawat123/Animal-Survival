--[[ ASWolfProbe (client) — จิ้งจอกจันทราบนจอผู้เล่น: ชิ้นที่มองเห็น / ตำแหน่ง + ภาพจากหลังผู้เล่นมองไปที่จิ้งจอก ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASWolfProbe") then
	return
end
local cam = workspace.CurrentCamera
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look()
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("WolfShot"):Connect(function()
	local name = ReplicatedStorage:GetAttribute("WolfShot")
	local model
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("Hidden") ~= nil and m:FindFirstChild("HumanoidRootPart") then
			model = m
		end
	end
	local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (model and me) then
		print("[AS] WOLFC no model on client")
		return
	end
	local vis, total, minT = 0, 0, 1
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			total += 1
			local tr = math.max(p.Transparency, p.LocalTransparencyModifier)
			minT = math.min(minT, tr)
			if tr < 0.95 then
				vis += 1
			end
		end
	end
	local pos = model:GetPivot().Position
	print(string.format("[AS] WOLFC %s parts=%d visible=%d minT=%.2f hiddenAttr=%s distOnClient=%.0f y=%.0f", name, total, vis, minT, tostring(model:GetAttribute("Hidden")), (pos - me.Position).Magnitude, pos.Y))
	look = function()
		local p = model:GetPivot().Position
		local m = me.Position
		local back = (m - p) * Vector3.new(1, 0, 1)
		back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
		return CFrame.lookAt(m + back * 14 + Vector3.new(0, 8, 0), p + Vector3.new(0, 3, 0))
	end
	task.wait(0.6)
	print("[SHOT] " .. name)
	task.wait(1)
	look = nil
	cam.CameraType = Enum.CameraType.Custom
end)
