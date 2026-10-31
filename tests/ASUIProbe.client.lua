--[[
	ASUIProbe — ใช้เฉพาะ build_rbxlx.py --uiprobe · เปิดหน้าต่างธีมไม้ทีละหน้า แล้วถ่ายภาพ
	(ภารกิจ 4 แท็บ / ป้ายความสำเร็จ / ร้านค้า / ตั้งค่า)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASUIProbe") then
	return
end
task.wait(16)
local client = script.Parent:WaitForChild("Client")
local QuestUI = require(client:WaitForChild("QuestUI"))
local StoreUI = require(client:WaitForChild("StoreUI"))
local SettingsUI = require(client:WaitForChild("SettingsUI"))
local LobbyUI = require(client:WaitForChild("LobbyUI"))

local function shot(name)
	task.wait(2)
	print("[SHOT] ui_" .. name)
	task.wait(1.5)
end

for _, tab in ipairs({ "Quests", "Login", "Season", "Codes" }) do
	QuestUI.Open(tab)
	shot("quest_" .. tab)
end
QuestUI.Close()

local badge = Players.LocalPlayer.PlayerGui:FindFirstChild("BadgeWindow", true)
if badge then
	badge.Visible = true
	LobbyUI.Refresh()
	shot("badges")
	badge.Visible = false
end

StoreUI.Open()
shot("store")
StoreUI.Close()

SettingsUI.Open()
shot("settings")
SettingsUI.Close()

-- โต๊ะคราฟต์ + พ่อค้าเร่ (ปกติเปิดในแมพ แต่เปิดในล็อบบี้ได้เพื่อดูหน้าตา)
local Menus = require(client:WaitForChild("Menus"))
Menus.OpenCraft()
shot("craft")
Menus.CloseCraft()
Menus.OpenTrader()
shot("trader")
Players.LocalPlayer.PlayerGui:FindFirstChild("TraderWindow", true).Visible = false

-- หน้าล็อกอินอาจเด้งทับตอนเริ่ม: ถ่ายแท็บภารกิจซ้ำอีกรอบท้ายสุด
QuestUI.Open("Quests")
shot("quest_Quests")
print("[TEST] DONE probe")
