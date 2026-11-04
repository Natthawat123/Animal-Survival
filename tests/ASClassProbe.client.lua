--[[
	ASClassProbe — ใช้เฉพาะ build_rbxlx.py --classprobe · เปิดร้านคลาส เลือกทีละคลาส แล้วถ่ายภาพ (ตัวละครกลาง + รูปวงกลมซ้าย)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASClassProbe") then
	return
end
task.wait(14)
-- ป้ายซุ้มประตูแคมป์ (ปิดไว้ — เทสนี้ดูร้านคลาส)
local board = nil
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
print("[AS] CLASSSHOT step require")
local Client = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client", 30)
local ClassShop = require(Client:WaitForChild("ClassShop", 30))
local Classes = require(ReplicatedStorage.Shared.Classes)
print("[AS] CLASSSHOT step open")
-- เปิดร้านตรงๆ (Menus.OpenShop ปิดร้านค้าอื่นก่อน — ไม่จำเป็นในเทส)
local ok, err = pcall(ClassShop.Open)
print("[AS] CLASSSHOT opened ok=" .. tostring(ok) .. " " .. tostring(err) .. " isOpen=" .. tostring(ClassShop.IsOpen()))
task.wait(8) -- ร้านเปิด/โหลดเสร็จก่อน (เคยถ่ายช้ากว่าการเลือกไปหนึ่งคลาส)
for _, id in ipairs(Classes.Order) do
	ClassShop.Select(id)
	task.wait(3)
	print("[SHOT] class_" .. id)
	task.wait(1)
end
pcall(ClassShop.Close)
-- คนขายคลาสหลังโต๊ะ: ถ่ายสองฝั่ง (เช็กว่าหันหน้าออกหาทางเข้า)
local npc = workspace:FindFirstChild("CounselorModel", true)
if npc then
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local cf, size = npc:GetBoundingBox()
	local look = npc:GetPivot().LookVector
	for _, side in ipairs({ { "vendor_front", 1 }, { "vendor_back", -1 } }) do
		cam.CFrame = CFrame.lookAt(cf.Position + look * side[2] * (size.Y * 1.6) + Vector3.new(0, size.Y * 0.2, 0), cf.Position)
		task.wait(2)
		print("[SHOT] " .. side[1])
		task.wait(1)
	end
	cam.CameraType = Enum.CameraType.Custom
else
	print("[AS] CLASSSHOT no CounselorModel")
end
print("[TEST] DONE probe")
