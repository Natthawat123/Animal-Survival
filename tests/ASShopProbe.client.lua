--[[ ASShopProbe (client) — ถ่ายหน้าจอตอนล้ม (ปุ่มตั๋วคืนชีพ + นับถอยหลัง) แล้วกดใช้ตั๋ว · ถ่ายหน้าร้าน (ปุ่ม Gift + ราคาจริง) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("ShopStep") == "downed"
task.wait(0.5)
local hud = require(script.Parent:WaitForChild("Client"):WaitForChild("HUD"))
print("[AS] SHOPPROBE btn visible=" .. tostring(hud.ReviveBtn and hud.ReviveBtn.Visible) .. " text=" .. tostring(hud.ReviveBtn and hud.ReviveBtn.Text) .. " downedText=" .. tostring(hud.DownedText.Text))
print("[SHOT] shop_downed")
task.wait(1.5)
Remotes.Get("UseReviveToken"):FireServer()
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("ShopStep") == "store"
local Menus = require(script.Parent:WaitForChild("Client"):WaitForChild("Menus"))
Menus.OpenShop("Diamonds")
task.wait(2.5)
print("[SHOT] shop_store")
repeat
	task.wait(0.3)
until ReplicatedStorage:GetAttribute("ShopStep") == "buy"
pcall(function() require(script.Parent.Client.StoreUI).Close() end)
task.wait(0.5)
print("[AS] SHOPPROBE buy btn visible=" .. tostring(hud.ReviveBtn.Visible) .. " text=" .. tostring(hud.ReviveBtn.Text))
print("[SHOT] shop_buyrevive")
