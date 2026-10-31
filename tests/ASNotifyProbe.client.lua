--[[ ASNotifyProbe (client) — build_rbxlx.py --medprobe · ยิงเหตุการณ์ที่เคยซ้อนกันพร้อมกัน แล้วถ่ายจอ: ป้ายใหญ่ต้องขึ้นทีละอัน แถบข้อความไม่ทับป้าย ไม่มีไอคอน/เส้น ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
local player = Players.LocalPlayer
repeat
	task.wait(0.5)
until ReplicatedStorage:GetAttribute("MedDone")
task.wait(2)
local Client = script.Parent:WaitForChild("Client")
local Cinematics = require(Client:WaitForChild("Cinematics"))
local HUD = require(Client:WaitForChild("HUD"))
local combat = { Shake = function() end }
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Custom

-- เริ่มคืน: NIGHT + กวางกลวง + ฝูงระลอก + ข้อความแถบ ขึ้นพร้อมกัน (รูป 3 ที่ผู้ใช้ส่งมา)
Cinematics.Handle("NightStart", { Night = 5, Element = "Earth", Title = "คืนแห่งปฐพี" }, nil, combat)
Cinematics.Handle("StalkerWarning", { In = 5 }, nil, combat)
HUD.Notify("🐾 ฝูงสัตว์ระลอกที่ 1 มาแล้ว", "Danger")
HUD.Notify("มีบางอย่างจ้องมองจากความมืด", "Danger")
task.wait(1)
print("[AS] NOTIFY night feedVisible=" .. tostring(HUD.Feed.Visible) .. " bannerUp=" .. tostring(player:GetAttribute("BannerUp")))
print("[SHOT] notify_night_1s")
task.wait(4.5)
print("[SHOT] notify_night_5s")
task.wait(4)
local nn = 0
for _, c in ipairs(HUD.Feed:GetChildren()) do
	nn += c:IsA("Frame") and 1 or 0
end
print("[AS] NOTIFY after feedVisible=" .. tostring(HUD.Feed.Visible) .. " bannerUp=" .. tostring(player:GetAttribute("BannerUp")) .. " shown=" .. nn)
print("[SHOT] notify_night_9s")
task.wait(4)
-- เช้า: DAWN (ไม่มีแล้ว) + DAY
Cinematics.Handle("Dawn", { Night = 4 }, nil, combat)
Cinematics.Handle("DayStart", { Day = 5 }, nil, combat)
task.wait(1)
print("[SHOT] notify_dawn")
task.wait(4)
-- ล้ม: ไม่มีป้าย DOWNED · ข้อความติดจอสั้น
player:SetAttribute("Downed", true)
Cinematics.Handle("Downed", {}, nil, combat)
task.wait(1.5)
print("[SHOT] notify_downed")
task.wait(1)
player:SetAttribute("Downed", nil)
-- ข้อความซ้ำภายใน 4 วิ = ขึ้นครั้งเดียว
HUD.Notify("กระสอบเต็ม", "Warn")
HUD.Notify("กระสอบเต็ม", "Warn")
HUD.Notify("วัตถุดิบไม่พอ", "Error")
task.wait(0.5)
local n = 0
for _, c in ipairs(HUD.Feed:GetChildren()) do
	if c:IsA("Frame") then
		n += 1
	end
end
print("[AS] NOTIFY feed count=" .. n .. " (ควร 2)")
print("[SHOT] notify_feed")
task.wait(1)
print("[AS] NOTIFYPROBE done")
