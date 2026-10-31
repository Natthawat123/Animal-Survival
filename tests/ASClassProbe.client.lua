--[[
	ASClassProbe — ใช้เฉพาะ build_rbxlx.py --classprobe · เปิดร้านคลาส เลือกทีละคลาส แล้วถ่ายภาพ (ตัวละครกลาง + รูปวงกลมซ้าย)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASClassProbe") then
	return
end
task.wait(14)
-- ป้ายซุ้มประตูแคมป์
local board = workspace:FindFirstChild("CampSignBoard", true)
if board then
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(board.Position + board.CFrame.LookVector * 22 + Vector3.new(0, -3, 0), board.Position)
	task.wait(3)
	print("[SHOT] camp_sign")
	task.wait(1.5)
	cam.CFrame = CFrame.lookAt(board.Position - board.CFrame.LookVector * 22 + Vector3.new(0, -3, 0), board.Position)
	task.wait(3)
	print("[SHOT] camp_sign_back")
	task.wait(1.5)
	cam.CameraType = Enum.CameraType.Custom
end
local Menus = require(script.Parent:WaitForChild("Client"):WaitForChild("Menus"))
local ClassShop = require(script.Parent:WaitForChild("Client"):WaitForChild("ClassShop"))
local Classes = require(ReplicatedStorage.Shared.Classes)
Menus.OpenShop("Classes")
task.wait(8) -- ร้านเปิด/โหลดเสร็จก่อน (เคยถ่ายช้ากว่าการเลือกไปหนึ่งคลาส)
for _, id in ipairs(Classes.Order) do
	ClassShop.Select(id)
	task.wait(4)
	print("[SHOT] class_" .. id)
	task.wait(1.5)
end
print("[TEST] DONE probe")
